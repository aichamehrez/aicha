#!/usr/bin/env python3
"""
TurboVec Vector Memory & Semantic Search Tool for OpenClaw.
Connects local TurboVec vector store with Ollama embedding API.
"""

import os
import sys
import json
import argparse
from pathlib import Path
import httpx

# Ensure UTF-8 output encoding on Windows terminal
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

# Dynamic host configuration (works both on Host and inside OpenClaw container)
OLLAMA_BASE = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434").rstrip('/')
OLLAMA_URL = f"{OLLAMA_BASE}/api/embed"
EMBED_MODEL = "nomic-embed-text"
MEMORY_DIR = Path(__file__).parent / "openclaw-data" / "turbovec_db"

def get_embedding(text: str) -> list:
    """Generate vector embedding using local Ollama instance."""
    try:
        response = httpx.post(
            OLLAMA_URL,
            json={"model": EMBED_MODEL, "input": text},
            timeout=30.0
        )
        response.raise_for_status()
        embeddings = response.json().get("embeddings", [])
        return embeddings[0] if embeddings else []
    except Exception as e:
        # Fallback check if running localhost vs ollama container name
        if "localhost" in OLLAMA_URL:
            try:
                fallback_url = "http://ollama:11434/api/embed"
                response = httpx.post(
                    fallback_url,
                    json={"model": EMBED_MODEL, "input": text},
                    timeout=30.0
                )
                response.raise_for_status()
                embeddings = response.json().get("embeddings", [])
                return embeddings[0] if embeddings else []
            except Exception:
                pass
        sys.stderr.write(f"Error fetching embedding from Ollama ({OLLAMA_URL}): {e}\n")
        return []

def init_db():
    """Initialize TurboVec storage directory."""
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)

def index_file(file_path: str):
    """Index a document into the local vector memory using chunking."""
    path = Path(file_path)
    if not path.exists():
        print(f"File not found: {file_path}")
        return

    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        print(f"Skipping binary/non-UTF8 file: {file_path}")
        return

    if not content.strip():
        print(f"Skipping empty file: {file_path}")
        return

    init_db()
    
    # Chunk content into ~1500 character blocks for complete vector coverage
    chunk_size = 1500
    chunks = [content[i:i + chunk_size] for i in range(0, len(content), chunk_size)]
    
    indexed_count = 0
    for idx, chunk in enumerate(chunks[:10]):  # Cap at top 10 chunks per file
        embedding = get_embedding(chunk)
        if not embedding:
            continue

        chunk_id = f"{path.name}_chunk_{idx}"
        index_record = {
            "id": chunk_id,
            "filename": str(path.name),
            "path": str(path.resolve()),
            "chunk_index": idx,
            "embedding": embedding,
            "preview": chunk[:300]
        }
        
        out_file = MEMORY_DIR / f"{chunk_id}.json"
        out_file.write_text(json.dumps(index_record, indent=2), encoding="utf-8")
        indexed_count += 1
    
    print(f"✅ Successfully indexed {path.name} ({indexed_count} vector chunks) into TurboVec memory.")

def search_memory(query: str):
    """Search indexed vector memory for relevant query context."""
    query_vector = get_embedding(query)
    if not query_vector:
        print("Failed to generate query embedding.")
        return

    init_db()
    results = []
    
    for json_file in MEMORY_DIR.glob("*.json"):
        try:
            data = json.loads(json_file.read_text(encoding="utf-8"))
            doc_vector = data.get("embedding", [])
            if doc_vector and len(doc_vector) == len(query_vector):
                # Compute Cosine Similarity
                dot_product = sum(a * b for a, b in zip(query_vector, doc_vector))
                norm_a = sum(a * a for a in query_vector) ** 0.5
                norm_b = sum(b * b for b in doc_vector) ** 0.5
                score = dot_product / (norm_a * norm_b) if norm_a and norm_b else 0
                
                results.append((score, data))
        except Exception:
            continue

    results.sort(key=lambda x: x[0], reverse=True)
    
    print(f"\n--- TurboVec Vector Search Results for: '{query}' ---")
    if not results:
        print("No matching vector memory found.")
        return

    seen_files = set()
    output_count = 0
    for score, doc in results:
        filename = doc.get("filename", doc.get("id"))
        if filename in seen_files:
            continue
        seen_files.add(filename)
        output_count += 1
        print(f"\n[Similarity Score: {score:.4f}] File: {filename} (Chunk {doc.get('chunk_index', 0)})")
        print(f"Preview: {doc['preview']}...")
        if output_count >= 3:
            break

def main():
    parser = argparse.ArgumentParser(description="TurboVec Vector Memory Manager for OpenClaw")
    parser.add_argument("--index", help="Path to text/markdown file to index into vector memory")
    parser.add_argument("--search", help="Semantic query string to search vector memory")
    
    args = parser.parse_args()
    
    if args.index:
        index_file(args.index)
    elif args.search:
        search_memory(args.search)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
