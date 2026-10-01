---
name: semantic-search
description: Use when you must find where a behavior, concept, or rule lives in a repository and do not know its identifiers or exact strings, or when a first rg search returned nothing useful. Returns ranked code and documentation chunks from the local Qwen index.
---

# Semantic Search

Search the current Git repository by meaning with the locally installed Qwen3 embedding and reranking models.

## When to use

- Concept questions: "where are expired trials blocked", "how is the cache invalidated", "which code retries failed uploads".
- Unfamiliar repositories where names and conventions are unknown.
- After an `rg` search for guessed terms returned nothing relevant or too many unrelated files.

Use `rg` or direct reads instead for known file paths, symbol names, exact strings, and error messages.

## Decide by cost

Check the cost of the next search first: run the command under Run with `status` in place of `search` and without `--query` and `--top-k`. It loads no models, takes about a second, and prints `{indexable_files, indexed_files, stale_files, models_loaded, in_process}`. Weigh that against the `rg` rounds you expect:

- Fewer than about 200 indexable files, or one or two guessed terms likely to hit: use `rg`; a search costs more than it saves.
- `stale_files` in the thousands, including a first index (`indexed_files` 0): the search embeds them first, which can take minutes. Pay that only for a large unfamiliar repository or several concept questions in this session.
- `models_loaded` false: the search loads the models first, which takes tens of seconds. With `in_process` true, as inside the Codex sandbox, every search pays that again; search only when `rg` would need several rounds, and batch related questions into one precise query.
- Index fresh and `models_loaded` true: a search takes seconds; use it for any concept question.

## Run

PowerShell:

```powershell
python "$HOME/.my-ai-configuration/semantic-retrieval/server.py" search --root . --data-dir "$HOME/.my-ai-configuration/semantic-retrieval/data" --model-cache "$HOME/.my-ai-configuration/semantic-retrieval/model-cache" --query "<question in natural language>" --top-k 5
```

Bash:

```bash
python3 "$HOME/.my-ai-configuration/semantic-retrieval/server.py" search --root . --data-dir "$HOME/.my-ai-configuration/semantic-retrieval/data" --model-cache "$HOME/.my-ai-configuration/semantic-retrieval/model-cache" --query "<question in natural language>" --top-k 5
```

The output is a JSON list of `{path, symbol, text, score}`, best match first.

## Use the results

1. Phrase the query as a full question about behavior, not as a keyword list.
2. Open the top hits and verify them against the current files before acting; the index can lag behind uncommitted edits by one refresh.
3. Follow the verified hit with `rg` for its symbols to find callers and tests.

## Cost and limits

- Searches refresh only changed files. Outside a sandbox a background daemon keeps the models loaded for 30 idle minutes; inside the Codex sandbox there is no daemon.
- Only Git-tracked and unignored files up to 512 KB are indexed, by default at most 2000 files per repository.
- If the command fails or the setup is missing, continue with `rg` and state the limitation briefly.
