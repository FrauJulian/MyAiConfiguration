#!/usr/bin/env python3
"""Local MCP semantic search backed by Qwen3-Embedding-0.6B."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sqlite3


MODEL = "Qwen/Qwen3-Embedding-0.6B"
TEXT_EXTENSIONS = {".c", ".cpp", ".cs", ".go", ".java", ".js", ".json", ".md", ".py", ".ps1", ".rs", ".sh", ".toml", ".ts", ".tsx", ".txt", ".yaml", ".yml"}


def chunks(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    for start in range(0, len(text), 1050):
        value = text[start:start + 1200].strip()
        if value:
            yield value


class Index:
    def __init__(self, root: Path, data: Path):
        self.root = root.resolve()
        self.data = data.resolve()
        self.data.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(self.data / "index.sqlite3")
        self.db.execute("create table if not exists chunks (path text, text text, vector blob)")
        self.db.commit()
        self.model = None

    def files(self):
        ignored = {".git", ".venv", "generated", "node_modules", ".my-ai-configuration"}
        result = []
        for path in self.root.rglob("*"):
            if len(result) >= 2000 or not path.is_file() or path.suffix.lower() not in TEXT_EXTENSIONS or path.stat().st_size > 524288:
                continue
            if ignored.intersection(path.relative_to(self.root).parts):
                continue
            result.append(path)
        return result

    def encoder(self):
        if self.model is None:
            from sentence_transformers import SentenceTransformer
            self.model = SentenceTransformer(MODEL)
        return self.model

    def rebuild(self):
        encoder = self.encoder()
        values = []
        for path in self.files():
            for value in chunks(path):
                values.append((str(path.relative_to(self.root)), value))
        self.db.execute("delete from chunks")
        if values:
            vectors = encoder.encode([value for _, value in values], normalize_embeddings=True)
            self.db.executemany("insert into chunks values (?, ?, ?)", ((path, value, vector.tobytes()) for (path, value), vector in zip(values, vectors)))
        self.db.commit()
        return len(values)

    def search(self, query: str, top_k: int):
        if not query.strip():
            raise ValueError("query must not be empty")
        if self.db.execute("select count(*) from chunks").fetchone()[0] == 0:
            self.rebuild()
        vector = self.encoder().encode([query], normalize_embeddings=True)[0]
        rows = []
        for path, text, blob in self.db.execute("select path, text, vector from chunks"):
            import numpy as np
            score = float(np.dot(vector, np.frombuffer(blob, dtype=np.float32)))
            rows.append({"path": path, "score": round(score, 6), "text": text})
        return sorted(rows, key=lambda item: item["score"], reverse=True)[:max(1, min(top_k, 20))]


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
        """Find repository passages by meaning with Qwen3-Embedding-0.6B."""
        return index.search(query, top_k)

    @mcp.tool()
    def rebuild_index() -> str:
        """Rebuild the local repository embedding index."""
        return json.dumps({"chunks": index.rebuild()})

    mcp.run()


if __name__ == "__main__":
    main()
