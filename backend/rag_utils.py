import faiss
import json
import numpy as np
from sentence_transformers import SentenceTransformer

print("📦 Loading embedding model...")
model = SentenceTransformer("intfloat/multilingual-e5-small")

print("📦 Loading FAISS index...")
index = faiss.read_index("rag_store/loose_faiss.index")

print("📦 Loading chunks...")
with open("rag_store/loose_chunks_meta.jsonl", "r", encoding="utf-8") as f:
    chunks = [json.loads(line) for line in f]

print(f"✅ Loaded {len(chunks)} chunks")
print(f"📏 FAISS dim = {index.d}")


def retrieve_context(query, top_k=5):
    try:
        print("🔎 Query:", query)

        query_embedding = model.encode(
            [f"query: {query}"],
            normalize_embeddings=True
        )
        query_embedding = np.array(query_embedding, dtype="float32")

        print("📏 Query embedding shape:", query_embedding.shape)

        distances, indices = index.search(query_embedding, top_k)

        results = []
        for idx in indices[0]:
            if 0 <= idx < len(chunks):
                chunk = chunks[idx]
                if isinstance(chunk, dict):
                    text = chunk.get("text", "")
                    if text:
                        results.append(text)

        final = "\n".join(results)

        print("📚 Retrieved context:")
        print(final[:300])

        return final

    except Exception as e:
        print("❌ ERROR INSIDE RAG:", repr(e))
        return ""
