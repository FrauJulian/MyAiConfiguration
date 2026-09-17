#!/usr/bin/env python3
"""Local MCP semantic search backed by Qwen3 embedding and reranking."""

from __future__ import annotations

import argparse
import hashlib
import heapq
import json
import os
from pathlib import Path
import sqlite3
import threading


MODEL = "Qwen/Qwen3-Embedding-0.6B"
RERANKER_MODEL = "Qwen/Qwen3-Reranker-0.6B"
EMBEDDING_DIMENSIONS = 1024
CHUNK_TOKENS = 400
OVERLAP_TOKENS = 64
RERANK_CANDIDATES = 20
FINAL_RESULTS = 20
INDEX_VERSION = 0
RETRIEVAL_INSTRUCTION = "Given a codebase question, retrieve relevant code and documentation that answer the question."
TEXT_EXTENSIONS = {".c", ".cpp", ".cs", ".go", ".java", ".js", ".json", ".md", ".py", ".ps1", ".rs", ".sh", ".toml", ".ts", ".tsx", ".txt", ".yaml", ".yml"}


def chunks(text: str, path: str, tokenizer):
    for symbol, content in [("<module>", text)]:
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
                for (symbol, value), vector in zip(values, vectors):
                    if len(vector) != EMBEDDING_DIMENSIONS:
                        raise ValueError("Embedding must have 1024 dimensions")
                    self.db.execute("insert into chunks values (?, ?, ?, ?)",
                                             (relative, symbol, value, vector.tobytes()))
                self.db.execute("insert or replace into files values (?, ?)", (relative, digest))
            for relative in previous:
                self.delete_path(relative)
                self.db.execute("delete from files where path = ?", (relative,))

    def search(self, query: str, top_k: int):
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
            rows = ({"path": path, "symbol": symbol, "score": float(np.dot(vector, np.frombuffer(blob, dtype=np.float32))), "text": text}
                    for path, symbol, text, blob in self.db.execute("select path, symbol, text, vector from chunks"))
            limit = max(1, min(top_k, 20))
            return self.rerank(query, heapq.nlargest(20, rows, key=lambda item: item["score"]), limit)


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
    def semantic_search(query: str, top_k: int = 5) -> list[dict]:
        """Search repository concepts, behavior, and implementation patterns first with Qwen3 embedding and reranking. Verify returned passages against current files; use direct reads for known paths."""
        return index.search(query, top_k)

    @mcp.tool()
    def rebuild_index() -> str:
        """Rebuild the local repository embedding index."""
        return json.dumps({"chunks": index.rebuild()})

    mcp.run()


if __name__ == "__main__":
    main()
