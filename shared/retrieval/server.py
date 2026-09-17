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
RETRIEVAL_INSTRUCTION = "Given a codebase question, retrieve relevant code and documentation that answer the question."
TEXT_EXTENSIONS = {".c", ".cpp", ".cs", ".go", ".java", ".js", ".json", ".md", ".py", ".ps1", ".rs", ".sh", ".toml", ".ts", ".tsx", ".txt", ".yaml", ".yml"}


def chunks(text: str):
    for start in range(0, len(text), 1050):
        value = text[start:start + 1200].strip()
        if value:
            yield value


class Index:
    def __init__(self, root: Path, data: Path):
        self.root = root.resolve()
        self.data = data.resolve()
        self.data.mkdir(parents=True, exist_ok=True)
        identity = os.path.normcase(str(self.root)) + "\n" + MODEL + "\n" + str(EMBEDDING_DIMENSIONS)
        database = hashlib.sha256(identity.encode()).hexdigest() + ".sqlite3"
        self.db = sqlite3.connect(self.data / database, check_same_thread=False, timeout=30)
        self.db.execute("create table if not exists chunks (path text, text text, vector blob)")
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
        candidates = rows[:min(len(rows), max(limit, 20))]
        scores = self.reranker().predict([(query, item["text"]) for item in candidates])
        for item, score in zip(candidates, scores):
            item["score"] = round(float(score), 6)
        return sorted(candidates, key=lambda item: item["score"], reverse=True)[:limit]

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
                values = list(chunks(content.decode("utf-8", errors="ignore")))
                vectors = self.encoder().encode(values, normalize_embeddings=True) if values else []
                self.db.execute("delete from chunks where path = ?", (relative,))
                self.db.executemany("insert into chunks values (?, ?, ?)",
                                    ((relative, value, vector.tobytes()) for value, vector in zip(values, vectors)))
                self.db.execute("insert or replace into files values (?, ?)", (relative, digest))
            for relative in previous:
                self.db.execute("delete from chunks where path = ?", (relative,))
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
            rows = ({"path": path, "score": float(np.dot(vector, np.frombuffer(blob, dtype=np.float32))), "text": text}
                    for path, text, blob in self.db.execute("select path, text, vector from chunks"))
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
