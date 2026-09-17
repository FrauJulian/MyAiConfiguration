#!/usr/bin/env python3
"""Local MCP semantic search backed by Qwen3 embedding and reranking."""

from __future__ import annotations

import argparse
import ast
import hashlib
import heapq
import json
import os
from pathlib import Path
import re
import sqlite3
import threading


MODEL = "Qwen/Qwen3-Embedding-0.6B"
RERANKER_MODEL = "Qwen/Qwen3-Reranker-0.6B"
EMBEDDING_DIMENSIONS = 1024
CHUNK_TOKENS = 400
OVERLAP_TOKENS = 64
DENSE_CANDIDATES = 50
LEXICAL_CANDIDATES = 50
RERANK_CANDIDATES = 50
FINAL_RESULTS = 5
RRF_K = 60
INDEX_VERSION = 2
RETRIEVAL_INSTRUCTION = "Given a codebase question, retrieve relevant code and documentation that answer the question."
TEXT_EXTENSIONS = {".c", ".cpp", ".cs", ".go", ".java", ".js", ".json", ".md", ".py", ".ps1", ".rs", ".sh", ".toml", ".ts", ".tsx", ".txt", ".yaml", ".yml"}


def sections(text: str, path: str):
    lines = text.splitlines(keepends=True)
    boundaries = {0: "<module>", len(lines): "<module>"}
    suffix = Path(path).suffix.lower()
    if suffix == ".py":
        try:
            tree = ast.parse(text)
        except (SyntaxError, ValueError):
            tree = None

        def visit(node, parent):
            symbol = parent
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                symbol = f"{parent}.{node.name}" if parent != "<module>" else node.name
                start = min([node.lineno, *(item.lineno for item in node.decorator_list)]) - 1
                boundaries[start] = symbol
                boundaries.setdefault(node.end_lineno, parent)
            for child in ast.iter_child_nodes(node):
                visit(child, symbol)

        if tree is not None:
            visit(tree, "<module>")
    else:
        fence = None
        headings = []
        for number, line in enumerate(lines):
            if suffix == ".md":
                marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
                if marker:
                    value = marker[1]
                    if fence is None:
                        fence = value
                    elif value[0] == fence[0] and len(value) >= len(fence):
                        fence = None
                    continue
                heading = re.match(r"^\s{0,3}(#{1,6})\s+(.+?)\s*#*\s*$", line)
                if heading and fence is None:
                    level = len(heading[1])
                    headings = [(depth, title) for depth, title in headings if depth < level]
                    headings.append((level, heading[2]))
                    boundaries[number] = " / ".join(title for _, title in headings)
            elif suffix == ".toml":
                heading = re.match(r"^\s*\[\[?([^\]]+)\]\]?\s*(?:#.*)?$", line)
                if heading:
                    boundaries[number] = heading[1]
            elif suffix in {".js", ".ts", ".tsx", ".cs", ".java", ".go", ".rs", ".c", ".cpp", ".ps1", ".sh"}:
                symbol = re.match(
                    r"^\s*(?:(?:export|default|public|private|protected|internal|static|abstract|async|sealed|partial|pub)\s+)*"
                    r"(?:(?:class|interface|struct|enum|record|function|fn|def)\s+([\w$-]+)"
                    r"|func\s+(?:\([^)]*\)\s*)?([\w]+)"
                    r"|(?:const|let|var)\s+([\w$]+)\s*=.*=>"
                    r"|([\w$-]+)\s*\([^;]*\)\s*\{"
                    r"|[\w<>\[\],?]+\s+([\w]+)\s*\([^;]*\)\s*(?:\{|=>|$))", line)
                if symbol:
                    name = next(value for value in symbol.groups() if value)
                    if name not in {"if", "for", "foreach", "while", "switch", "catch", "using", "lock"}:
                        boundaries[number] = name
    positions = sorted(boundaries)
    for start, end in zip(positions, positions[1:]):
        content = "".join(lines[start:end])
        if content.strip():
            yield boundaries[start], content


def chunks(text: str, path: str, tokenizer):
    for symbol, content in sections(text, path):
        offsets = tokenizer(content, add_special_tokens=False, return_offsets_mapping=True)["offset_mapping"]
        start = 0
        while start < len(offsets):
            end = min(start + CHUNK_TOKENS, len(offsets))
            first = 0 if start == 0 else offsets[start][0]
            while end > start:
                last = len(content) if end == len(offsets) else offsets[end][0]
                value = content[first:last].strip()
                if len(tokenizer(value, add_special_tokens=False)["input_ids"]) <= CHUNK_TOKENS:
                    break
                end -= 1
            if value:
                yield symbol, value
            if end == len(offsets):
                break
            start = max(start + 1, end - OVERLAP_TOKENS)


def document_text(path: str, symbol: str, content: str):
    return f"Path: {path}\nSymbol: {symbol}\n\n{content}"


def reciprocal_rank_fusion(*rankings):
    scores = {}
    for ranking in rankings:
        for rank, identifier in enumerate(ranking, 1):
            scores[identifier] = scores.get(identifier, 0.0) + 1.0 / (RRF_K + rank)
    return sorted(scores, key=lambda identifier: (-scores[identifier], identifier))


class Index:
    def __init__(self, root: Path, data: Path):
        self.root = root.resolve()
        self.data = data.resolve()
        self.data.mkdir(parents=True, exist_ok=True)
        identity = json.dumps([os.path.normcase(str(self.root)), MODEL, EMBEDDING_DIMENSIONS,
                               INDEX_VERSION, CHUNK_TOKENS, OVERLAP_TOKENS])
        database = hashlib.sha256(identity.encode()).hexdigest() + ".sqlite3"
        self.db = sqlite3.connect(self.data / database, check_same_thread=False, timeout=30)
        self.db.execute("create table if not exists chunks (path text, symbol text, text text, vector blob)")
        self.db.execute("create index if not exists chunks_path on chunks (path)")
        self.db.execute("create virtual table if not exists lexical using fts5(document)")
        self.db.execute("create table if not exists files (path text primary key, digest text)")
        self.db.commit()
        self.lock = threading.RLock()
        self.model = None
        self.reranker_model = None

    def files(self):
        ignored = {".git", ".venv", "generated", "node_modules", ".my-ai-configuration"}
        result = []
        for directory, directories, filenames in os.walk(self.root):
            directories[:] = sorted(name for name in directories if name not in ignored
                                    and not (Path(directory) / name).is_symlink()
                                    and (Path(directory) / name).resolve().is_relative_to(self.root)
                                    and (Path(directory) / name).resolve() != self.data)
            for name in sorted(filenames):
                path = Path(directory) / name
                if path.is_symlink() or path.suffix.lower() not in TEXT_EXTENSIONS or not path.is_file() or path.stat().st_size > 524288:
                    continue
                result.append(path)
                if len(result) == 2000:
                    return result
        return result

    def encoder(self):
        if self.model is None:
            from sentence_transformers import SentenceTransformer
            self.model = SentenceTransformer(MODEL, truncate_dim=EMBEDDING_DIMENSIONS,
                                             prompts={"query": f"Instruct: {RETRIEVAL_INSTRUCTION}\nQuery: "})
        return self.model

    def reranker(self):
        if self.reranker_model is None:
            from sentence_transformers import CrossEncoder
            self.reranker_model = CrossEncoder(RERANKER_MODEL, prompts={"query": RETRIEVAL_INSTRUCTION}, default_prompt_name="query")
        return self.reranker_model

    def rerank(self, query: str, rows: list[dict], limit: int):
        candidates = rows[:RERANK_CANDIDATES]
        scores = self.reranker().predict([(query, document_text(item["path"], item["symbol"], item["text"]))
                                          for item in candidates], batch_size=8)
        for item, score in zip(candidates, scores):
            item["score"] = round(float(score), 6)
        return sorted(candidates, key=lambda item: item["score"], reverse=True)[:min(limit, FINAL_RESULTS)]

    def delete_path(self, path):
        self.db.execute("delete from lexical where rowid in (select rowid from chunks where path = ?)", (path,))
        self.db.execute("delete from chunks where path = ?", (path,))

    def rebuild(self):
        with self.lock:
            self.refresh(force=True)
            return self.db.execute("select count(*) from chunks").fetchone()[0]

    def refresh(self, force=False):
        previous = dict(self.db.execute("select path, digest from files"))
        with self.db:
            for path in self.files():
                relative = path.relative_to(self.root).as_posix()
                content = path.read_bytes()
                digest = hashlib.sha256(content).hexdigest()
                old_digest = previous.pop(relative, None)
                if not force and digest == old_digest:
                    continue
                values = list(chunks(content.decode("utf-8", errors="ignore"), relative, self.encoder().tokenizer))
                documents = [document_text(relative, symbol, value) for symbol, value in values]
                vectors = self.encoder().encode(documents, normalize_embeddings=True) if documents else []
                self.delete_path(relative)
                for (symbol, value), document, vector in zip(values, documents, vectors):
                    if len(vector) != EMBEDDING_DIMENSIONS:
                        raise ValueError("Embedding must have 1024 dimensions")
                    cursor = self.db.execute("insert into chunks values (?, ?, ?, ?)",
                                             (relative, symbol, value, vector.tobytes()))
                    self.db.execute("insert into lexical(rowid, document) values (?, ?)", (cursor.lastrowid, document))
                self.db.execute("insert or replace into files values (?, ?)", (relative, digest))
            for relative in previous:
                self.delete_path(relative)
                self.db.execute("delete from files where path = ?", (relative,))

    def search(self, query: str, top_k: int = FINAL_RESULTS):
        if not query.strip():
            raise ValueError("query must not be empty")
        with self.lock:
            self.refresh()
            if not self.db.execute("select 1 from chunks limit 1").fetchone():
                return []
            import numpy as np
            vector = self.encoder().encode([query], prompt_name="query", normalize_embeddings=True)[0]
            if len(vector) != EMBEDDING_DIMENSIONS:
                raise ValueError("Embedding must have 1024 dimensions")
            scores = ((identifier, float(np.dot(vector, np.frombuffer(blob, dtype=np.float32))))
                      for identifier, blob in self.db.execute("select rowid, vector from chunks"))
            dense = [identifier for identifier, _ in heapq.nlargest(DENSE_CANDIDATES, scores, key=lambda item: item[1])]
            terms = list(dict.fromkeys(re.findall(r"[^\W_]+", query)))[:128]
            expression = " OR ".join(f'"{term}"' for term in terms)
            lexical = [row[0] for row in self.db.execute(
                "select rowid from lexical where lexical match ? order by bm25(lexical), rowid limit ?",
                (expression, LEXICAL_CANDIDATES))] if terms else []
            identifiers = reciprocal_rank_fusion(dense, lexical)[:RERANK_CANDIDATES]
            placeholders = ",".join("?" for _ in identifiers)
            rows = {identifier: {"path": path, "symbol": symbol, "text": text}
                    for identifier, path, symbol, text in self.db.execute(
                        f"select rowid, path, symbol, text from chunks where rowid in ({placeholders})", identifiers)}
            candidates = [rows[identifier] for identifier in identifiers]
            return self.rerank(query, candidates, max(1, min(top_k, FINAL_RESULTS)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=os.getcwd(), type=Path)
    parser.add_argument("--data-dir", required=True, type=Path)
    parser.add_argument("--model-cache", required=True, type=Path)
    args = parser.parse_args()
    args.model_cache.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("HF_HOME", str(args.model_cache.resolve()))
    from mcp.server.fastmcp import FastMCP

    index = Index(args.root, args.data_dir)
    mcp = FastMCP("my-ai-qwen3-retrieval")

    @mcp.tool()
    def semantic_search(query: str, top_k: int = FINAL_RESULTS) -> list[dict]:
        """Search repository concepts, behavior, and implementation patterns first with Qwen3 embedding and reranking. Verify returned passages against current files; use direct reads for known paths."""
        return index.search(query, top_k)

    @mcp.tool()
    def rebuild_index() -> str:
        """Rebuild the local repository embedding index."""
        return json.dumps({"chunks": index.rebuild()})

    mcp.run()


if __name__ == "__main__":
    main()
