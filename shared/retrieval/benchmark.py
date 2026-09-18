import argparse
import json
import os
from pathlib import Path
import statistics
import sys
import time


def elapsed(call):
    started = time.monotonic()
    call()
    return time.monotonic() - started


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model-cache', required=True, type=Path)
    parser.add_argument('--max-seconds', type=float, default=float(os.environ.get('QWEN_BENCHMARK_MAX_SECONDS', '8')))
    args = parser.parse_args()
    if args.max_seconds <= 0:
        raise ValueError('--max-seconds must be greater than zero.')
    os.environ['HF_HOME'] = str(args.model_cache)
    from server import shared_encoder, shared_reranker

    encoder = shared_encoder()
    reranker = shared_reranker()
    query = 'Find the implementation that updates the selected client configuration.'
    documents = ['Path: scripts/commands/install.py\n\n' + query] * 50
    print('Benchmark: warming up embedding model...', file=sys.stderr, flush=True)
    encoder.encode([query], prompt_name='query')
    print('Benchmark: probing reranker speed...', file=sys.stderr, flush=True)
    probe = elapsed(lambda: reranker.predict([(query, documents[0])], show_progress_bar=False))
    if probe * len(documents) > args.max_seconds:
        print(json.dumps({
            'embeddingSeconds': None,
            'rerankingSeconds': round(probe, 3),
            'maxSeconds': args.max_seconds,
            'recommended': False,
        }))
        return
    print('Benchmark: measuring full retrieval batch...', file=sys.stderr, flush=True)
    reranker.predict([(query, document) for document in documents], show_progress_bar=False)
    embedding = statistics.median(elapsed(lambda: encoder.encode([query], prompt_name='query')) for _ in range(3))
    reranking = statistics.median(elapsed(lambda: reranker.predict([(query, document) for document in documents], show_progress_bar=False)) for _ in range(3))
    result = {
        'embeddingSeconds': round(embedding, 3),
        'rerankingSeconds': round(reranking, 3),
        'maxSeconds': args.max_seconds,
        'recommended': embedding <= args.max_seconds and reranking <= args.max_seconds,
    }
    print(json.dumps(result))


if __name__ == '__main__':
    main()
