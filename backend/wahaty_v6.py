# -*- coding: utf-8 -*-
"""Wahaty v6 backend module.

This file converts the Colab Multi-RAG pipeline into a local FastAPI-friendly
Python module. It uses local folders inside backend/:
- safety/input_guard.csv
- safety/output_guard.csv
- parent_policy/parent_policy.json
- checkpoints/arabert_intent_classifier/
- rag_store/rag1_general_story.faiss + rag1_general_story_chunks.jsonl
- rag_store/rag2_curriculum_religion.faiss + rag2_curriculum_religion_chunks.jsonl
- rag_store/rag3_emotional.faiss + rag3_emotional_chunks.jsonl
"""

from __future__ import annotations

import csv
import datetime as _dt
import hashlib
import json
import math
import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import faiss
import numpy as np
import torch
from dotenv import load_dotenv
from google import genai
from google.genai import types
from sentence_transformers import SentenceTransformer
from transformers import AutoModelForSequenceClassification, AutoTokenizer

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent
RAG_STORE_DIR = BASE_DIR / "rag_store"
SAFETY_DIR = BASE_DIR / "safety"
PARENT_POLICY_PATH = BASE_DIR / "parent_policy" / "parent_policy.json"
CLASSIFIER_DIR = BASE_DIR / "checkpoints" / "arabert_intent_classifier"
MEMORY_DIR = BASE_DIR / "child_memories"
LOG_DIR = BASE_DIR / "logs"

MEMORY_DIR.mkdir(exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL_ID = os.getenv("GEMINI_MODEL_ID", "gemini-2.5-flash")

if not GEMINI_API_KEY:
    print("⚠️ GEMINI_API_KEY is empty. Add it to backend/.env")

client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None

# Same embedding model used by the v6 Multi-RAG notebook.
EMBEDDING_MODEL_ID = "intfloat/multilingual-e5-small"
print("📦 Loading v6 embedding model...")
embedder = SentenceTransformer(EMBEDDING_MODEL_ID)

RAG_FILES = {
    "rag1_general_story": {
        "faiss": RAG_STORE_DIR / "rag1_general_story.faiss",
        "meta": RAG_STORE_DIR / "rag1_general_story_chunks.jsonl",
        "label": "General + Story",
    },
    "rag2_curriculum_religion": {
        "faiss": RAG_STORE_DIR / "rag2_curriculum_religion.faiss",
        "meta": RAG_STORE_DIR / "rag2_curriculum_religion_chunks.jsonl",
        "label": "Curriculum + Religion",
    },
    "rag3_emotional": {
        "faiss": RAG_STORE_DIR / "rag3_emotional.faiss",
        "meta": RAG_STORE_DIR / "rag3_emotional_chunks.jsonl",
        "label": "Emotional",
    },
}

RAG_STORES: Dict[str, Dict[str, Any]] = {}
for rag_id, paths in RAG_FILES.items():
    if not paths["faiss"].exists() or not paths["meta"].exists():
        print(f"⚠️ Missing RAG store for {rag_id}: {paths['faiss'].name} / {paths['meta'].name}")
        continue
    print(f"📦 Loading {rag_id}...")
    index = faiss.read_index(str(paths["faiss"]))
    chunks: List[Dict[str, Any]] = []
    with open(paths["meta"], "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                chunks.append(json.loads(line))
    RAG_STORES[rag_id] = {"index": index, "chunks": chunks, "label": paths["label"]}
    print(f"✅ {rag_id}: {len(chunks)} chunks | dim={index.d}")

# ----------------------------- Normalization -----------------------------

def normalize_arabic(text: str) -> str:
    if not text:
        return ""
    text = text.replace("×", "*").replace("÷", "/")
    text = text.replace("\u0640", "")
    text = re.sub(r"[إأآٱ]", "ا", text)
    text = text.replace("ى", "ي")
    text = text.replace("ة", "ه")
    text = text.replace("ؤ", "و")
    text = text.replace("ئ", "ي")
    text = re.sub(r"[\u064B-\u065F\u0670]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    digit_map = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
    return text.translate(digit_map)


def clean_llm_output(text: str) -> str:
    if not text:
        return ""
    text = text.replace("▁", " ").replace("<0x0A>", "\n")
    text = re.sub(r"<\|.*?\|>", "", text)
    text = re.sub(r"\[/?INST\]", "", text)
    text = re.sub(r"\*{1,3}(.*?)\*{1,3}", r"\1", text)
    text = re.sub(r"#{1,6}\s", "", text)
    text = re.sub(r"`{1,3}(.*?)`{1,3}", r"\1", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

EN_TO_AR_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")

def arabize_digits(text: str) -> str:
    return text.translate(EN_TO_AR_DIGITS) if text else ""

# ----------------------------- Policy / Memory -----------------------------

DEFAULT_POLICY = {
    "child_name": "طفلي",
    "child_age": 8,
    "child_gender": "girl",
    "grade_level": None,
    "strictness": "normal",
    "extra_banned_words": [],
    "extra_banned_topics": [],
    "block_religion": False,
    "block_general": False,
    "log_conversations": True,
    "tts_enabled": True,
    "memory_enabled": True,
}


def load_parent_policy() -> dict:
    if PARENT_POLICY_PATH.exists():
        with open(PARENT_POLICY_PATH, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        return {**DEFAULT_POLICY, **loaded}
    PARENT_POLICY_PATH.parent.mkdir(exist_ok=True)
    with open(PARENT_POLICY_PATH, "w", encoding="utf-8") as f:
        json.dump(DEFAULT_POLICY, f, ensure_ascii=False, indent=2)
    return DEFAULT_POLICY.copy()

PARENT_POLICY = load_parent_policy()

DEFAULT_CHILD_MEMORY = {
    "name": "طفلي",
    "grade": None,
    "age": 8,
    "weak_subjects": [],
    "strong_subjects": [],
    "favorite_topics": {},
    "mood_history": [],
    "interaction_count": 0,
    "last_seen": None,
    "learned_facts": {},
    "preferred_style": "simple",
    "session_context": [],
}


def _child_id(name: str) -> str:
    return hashlib.md5(name.encode("utf-8")).hexdigest()[:12]


def _memory_path(name: str) -> Path:
    return MEMORY_DIR / f"{_child_id(name)}.json"


def load_child_memory(name: str) -> dict:
    path = _memory_path(name)
    if path.exists():
        with open(path, "r", encoding="utf-8") as f:
            mem = json.load(f)
        return {**DEFAULT_CHILD_MEMORY, **mem}
    mem = DEFAULT_CHILD_MEMORY.copy()
    mem["name"] = name
    return mem


def save_child_memory(mem: dict) -> None:
    mem["last_seen"] = _dt.datetime.now().isoformat()
    with open(_memory_path(mem["name"]), "w", encoding="utf-8") as f:
        json.dump(mem, f, ensure_ascii=False, indent=2)


def memory_to_context_str(mem: dict) -> str:
    parts = [f"اسم الطفل: {mem.get('name', 'طفلي')}"]
    if mem.get("grade"):
        parts.append(f"الصف: {mem['grade']}")
    if mem.get("age"):
        parts.append(f"العمر: {mem['age']} سنة")
    if mem.get("weak_subjects"):
        parts.append("يحتاج مساعدة في: " + "، ".join(mem["weak_subjects"][-3:]))
    if mem.get("strong_subjects"):
        parts.append("متميز في: " + "، ".join(mem["strong_subjects"][-3:]))
    if mem.get("session_context"):
        parts.append(f"آخر سؤال: {mem['session_context'][-1].get('q', '')[:80]}")
    parts.append(f"الأسلوب المفضل: {mem.get('preferred_style', 'simple')}")
    return "\n".join(parts)


def update_child_memory(mem: dict, query: str, result: dict, policy: dict) -> dict:
    mem["interaction_count"] = int(mem.get("interaction_count", 0)) + 1
    mem["age"] = policy.get("child_age", mem.get("age", 8))
    if policy.get("grade_level") is not None:
        mem["grade"] = policy["grade_level"]

    intent = result.get("intent", "general")
    mem.setdefault("favorite_topics", {})
    mem["favorite_topics"][intent] = mem["favorite_topics"].get(intent, 0) + 1

    if intent == "emotional":
        mem.setdefault("mood_history", [])
        mem["mood_history"].append({"ts": _dt.datetime.now().isoformat(), "query": query[:120]})
        mem["mood_history"] = mem["mood_history"][-10:]

    mem.setdefault("session_context", [])
    mem["session_context"].append({
        "q": query[:120],
        "a": result.get("answer", "")[:180],
        "route": result.get("rag_id", ""),
        "intent": intent,
    })
    mem["session_context"] = mem["session_context"][-6:]
    return mem

# ----------------------------- Guards -----------------------------

SAFE_BLOCK_MSG = "ما أقدر أساعدك في هذا السؤال لأنه قد يكون غير مناسب أو غير آمن. اسأل أحد الوالدين أو شخصًا كبيرًا تثق به. خلّينا نتحدث عن شيء آمن ومفيد."


def _load_keywords_csv(path: Path) -> List[str]:
    if not path.exists():
        print(f"⚠️ Missing safety CSV: {path}")
        return []
    keywords: List[str] = []
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        if rows and reader.fieldnames:
            possible = ["keyword", "pattern", "text", "word", "phrase", "كلمة", "عبارة"]
            col = next((c for c in possible if c in reader.fieldnames), reader.fieldnames[0])
            for row in rows:
                value = str(row.get(col, "")).strip()
                if value:
                    keywords.append(normalize_arabic(value).lower())
        else:
            f.seek(0)
            for line in f:
                value = line.strip().split(",")[0]
                if value:
                    keywords.append(normalize_arabic(value).lower())
    return list(dict.fromkeys([k for k in keywords if k]))

INPUT_KEYWORDS = _load_keywords_csv(SAFETY_DIR / "input_guard.csv")
OUTPUT_KEYWORDS = _load_keywords_csv(SAFETY_DIR / "output_guard.csv")

INJECTION_PATTERNS = [
    r"ignore\s+(all\s+)?previous\s+instructions?",
    r"forget\s+(your\s+)?instructions?",
    r"jailbreak",
    r"override\s+your\s+(safety|guidelines|rules)",
    r"تجاهل\s+التعليمات",
    r"انت\s+الان\s+بدون\s+قيود",
]


def check_input(query: str, policy: dict) -> dict:
    q = (query or "").strip()
    if not q:
        return {"safe": False, "reason": "سؤال فارغ", "category": "empty", "safe_response_ar": SAFE_BLOCK_MSG}
    if len(q) > 500:
        return {"safe": False, "reason": "السؤال طويل جداً", "category": "too_long", "safe_response_ar": SAFE_BLOCK_MSG}
    q_norm = normalize_arabic(q).lower()
    for kw in INPUT_KEYWORDS:
        if kw and kw in q_norm:
            return {"safe": False, "reason": "محتوى غير مناسب", "category": "banned_keyword", "matched": kw, "safe_response_ar": SAFE_BLOCK_MSG}
    for kw in policy.get("extra_banned_words", []):
        kw_norm = normalize_arabic(str(kw)).lower()
        if kw_norm and kw_norm in q_norm:
            return {"safe": False, "reason": f"محظور من ولي الأمر: {kw}", "category": "parent_ban", "matched": kw, "safe_response_ar": SAFE_BLOCK_MSG}
    for pat in INJECTION_PATTERNS:
        if re.search(pat, q_norm, re.IGNORECASE):
            return {"safe": False, "reason": "محاولة تجاوز الأمان", "category": "injection", "matched": pat, "safe_response_ar": SAFE_BLOCK_MSG}
    return {"safe": True, "reason": "ok", "category": "ok"}


def check_output(response: str) -> dict:
    txt = clean_llm_output(response or "")
    if not txt:
        return {"safe": False, "reason": "empty", "response": "عذرًا، حاول مرة أخرى."}
    if len(txt) > 1200:
        txt = txt[:1200].rstrip() + "..."
    txt_norm = normalize_arabic(txt).lower()
    for kw in OUTPUT_KEYWORDS:
        if kw and kw in txt_norm:
            return {"safe": False, "reason": "unsafe_output_keyword", "matched": kw, "response": SAFE_BLOCK_MSG}
    bad_style = ["نموذج لغوي", "كنموذج", "انا مجرد نموذج", "as an ai", "language model"]
    for phrase in bad_style:
        if normalize_arabic(phrase).lower() in txt_norm:
            return {"safe": False, "reason": "bad_style", "matched": phrase, "response": SAFE_BLOCK_MSG}
    return {"safe": True, "reason": "ok", "response": txt}

# ----------------------------- Intent Classifier -----------------------------

print("📦 Loading AraBERT intent classifier...")
intent_tokenizer = AutoTokenizer.from_pretrained(str(CLASSIFIER_DIR))
intent_model = AutoModelForSequenceClassification.from_pretrained(str(CLASSIFIER_DIR))
intent_model.eval()
if torch.cuda.is_available():
    intent_model.to("cuda")

mapping_path = CLASSIFIER_DIR / "label_mapping.json"
if mapping_path.exists():
    with open(mapping_path, "r", encoding="utf-8") as f:
        mapping = json.load(f)
    id2label = {int(k): v for k, v in mapping["id2label"].items()}
else:
    id2label = {int(k): v for k, v in intent_model.config.id2label.items()}

INTENT_CONFIDENCE_THRESHOLD = 0.70


def predict_intent_raw(text: str) -> Tuple[str, float, Dict[str, float]]:
    inputs = intent_tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=128)
    inputs = {k: v.to(intent_model.device) for k, v in inputs.items()}
    with torch.no_grad():
        outputs = intent_model(**inputs)
        probs = torch.softmax(outputs.logits, dim=-1)[0]
        pred_id = torch.argmax(probs).item()
    label = id2label[pred_id]
    confidence = float(probs[pred_id].item())
    probs_dict = {id2label[i]: float(probs[i].item()) for i in range(len(probs))}
    return label, confidence, probs_dict


def map_label_to_branch(label: str) -> str:
    if label in ["hard_unsafe", "soft_unsafe", "unsafe"]:
        return "unsafe"
    if label in ["emotional", "story", "curriculum", "religion", "general"]:
        return label
    return "general"


def classify_query(query: str) -> dict:
    label, confidence, probs = predict_intent_raw(query)
    final_label = label if confidence >= INTENT_CONFIDENCE_THRESHOLD else "unknown"
    return {
        "query": query,
        "label": label,
        "final_label": final_label,
        "confidence": confidence,
        "branch": map_label_to_branch(final_label),
        "probs": probs,
    }


def route_query(query: str, policy: dict) -> dict:
    q_norm = normalize_arabic(query)
    classifier = classify_query(q_norm)
    intent = classifier["branch"]

    if intent == "religion" and policy.get("block_religion", False):
        return {"intent": intent, "strategy": "blocked", "source": "classifier", "blocked_by_parent": True, "classifier": classifier}
    if intent == "general" and policy.get("block_general", False):
        return {"intent": intent, "strategy": "blocked", "source": "classifier", "blocked_by_parent": True, "classifier": classifier}
    if intent == "unsafe":
        return {"intent": intent, "strategy": "blocked", "source": "classifier", "blocked_by_parent": False, "classifier": classifier}

    # Tiny local math path for simple arithmetic.
    if re.fullmatch(r"[0-9\s\+\-\*\/\.\(\)]+", q_norm):
        return {"intent": "curriculum", "strategy": "tool_call", "source": "local_math", "blocked_by_parent": False, "classifier": classifier}

    strategy = "emotional_mode" if intent == "emotional" else "retrieval"
    return {"intent": intent, "strategy": strategy, "source": "classifier", "blocked_by_parent": False, "classifier": classifier}

# ----------------------------- Retrieval -----------------------------

INTENT_TO_RAG = {
    "general": "rag1_general_story",
    "story": "rag1_general_story",
    "curriculum": "rag2_curriculum_religion",
    "religion": "rag2_curriculum_religion",
    "emotional": "rag3_emotional",
}


def get_rag_id_for_intent(intent: str) -> str:
    rag_id = INTENT_TO_RAG.get(intent, "rag1_general_story")
    if rag_id in RAG_STORES:
        return rag_id
    if RAG_STORES:
        return next(iter(RAG_STORES))
    raise RuntimeError("No RAG stores loaded. Check backend/rag_store files.")


def _extract_text_and_meta(chunk: dict, rag_id: str) -> Tuple[str, dict]:
    text = chunk.get("text") or chunk.get("content") or chunk.get("chunk") or ""
    meta = chunk.get("meta") or chunk.get("metadata") or {}
    if not isinstance(meta, dict):
        meta = {}
    meta.setdefault("rag_id", rag_id)
    meta.setdefault("source_name", chunk.get("source_name") or chunk.get("source") or meta.get("source", ""))
    meta.setdefault("subject", chunk.get("subject") or meta.get("subject", ""))
    meta.setdefault("grade", chunk.get("grade") or meta.get("grade", ""))
    meta.setdefault("page", chunk.get("page") or meta.get("page", None))
    return str(text), meta


def retrieve_multirag(query: str, intent: str, top_k: int = 5, min_score: float = 0.30) -> dict:
    rag_id = get_rag_id_for_intent(intent)
    store = RAG_STORES[rag_id]
    q_emb = embedder.encode([f"query: {query}"], normalize_embeddings=True)
    q_emb = np.asarray(q_emb, dtype="float32")
    scores, idxs = store["index"].search(q_emb, top_k)

    items: List[dict] = []
    best_score = 0.0
    for raw_score, idx in zip(scores[0], idxs[0]):
        if idx < 0 or idx >= len(store["chunks"]):
            continue
        score = float(raw_score)
        best_score = max(best_score, score)
        text, meta = _extract_text_and_meta(store["chunks"][idx], rag_id)
        if not text:
            continue
        items.append({"text": text, "meta": meta, "score": score, "final_score": score})

    use_context = bool(items) and best_score >= min_score
    return {
        "rag_id": rag_id,
        "items": items,
        "best_score": best_score,
        "use_context": use_context,
        "source_label": f"📚 {store['label']}" if use_context else "🧠 Gemini",
        "retrieval_mode": "multirag_local",
    }

# ----------------------------- Generation -----------------------------

def build_system(intent: str, memory_ctx: str, age: int = 8) -> str:
    return f"""
أنت مساعد عربي آمن ولطيف للأطفال داخل تطبيق واحتي.

[معلومات الطفل]
{memory_ctx}

قواعد أساسية:
- أجب بالعربية فقط وبأسلوب بسيط مناسب لطفل عمره حوالي {age} سنوات.
- أجب مباشرة عن سؤال الطفل، بدون مقدمات طويلة.
- لا تبدأ الإجابة بترحيب مثل "أهلاً" أو "مرحباً" إلا إذا كانت رسالة الطفل نفسها تحية.
- لا تكرر اسم الطفل في كل إجابة؛ استخدم الاسم فقط عند الحاجة أو إذا كان الطفل يرسل تحية.
- إذا كان السؤال تعليميًا أو من المناهج، ابدأ بالشرح مباشرة.
- اجعل الإجابة قصيرة وواضحة: من ٣ إلى ٨ أسطر عند الحاجة.
- استخدم أمثلة بسيطة وآمنة عند الحاجة.
- لا تقدم محتوى ضارًا أو مخيفًا أو غير مناسب للأطفال.
- لا تذكر أنك نموذج لغوي.
- إذا كان السؤال خارج السياق المعرفي، أجب من معرفتك العامة بشكل آمن وبسيط.
- إذا كان intent = emotional فكن داعمًا وهادئًا، وشجّع الطفل على إخبار ولي أمره عند الحاجة.

نوع السؤال المصنف: {intent}
""".strip()


def build_user_prompt(query: str, intent: str, items: List[dict]) -> str:
    if not items:
        return query
    parts = []
    for item in items[:5]:
        m = item["meta"]
        parts.append(
            f"[{m.get('subject','')} | الصف {m.get('grade','')} | صفحة {m.get('page','')} | score={item.get('score',0):.2f}]\n{item['text']}"
        )
    ctx = "\n\n".join(parts)
    if intent == "story":
        return f"استفد من السياق إن كان مفيدًا، ثم قدّم قصة قصيرة وآمنة ومناسبة للأطفال.\n\nالسياق:\n{ctx}\n\nطلب الطفل:\n{query}"
    return f"السياق المعرفي:\n{ctx}\n\nسؤال الطفل:\n{query}\n\nأجب اعتمادًا على السياق إذا كان مناسبًا، وإذا لم يكفِ السياق فأجب بلطف وبطريقة مبسطة."


def generate_answer(system: str, user: str, max_tokens: int = 360, temperature: float = 0.25) -> str:
    if client is None:
        return "مفتاح Gemini غير موجود. أضيفي GEMINI_API_KEY في ملف .env ثم أعيدي تشغيل السيرفر."
    try:
        cfg = types.GenerateContentConfig(
            temperature=temperature,
            max_output_tokens=max_tokens,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
            system_instruction=system,
        )
        response = client.models.generate_content(model=GEMINI_MODEL_ID, contents=user, config=cfg)
        return clean_llm_output(getattr(response, "text", "") or "")
    except Exception as e:
        print("⚠️ Gemini generation failed:", repr(e))
        return "عذرًا، صار خطأ بسيط. حاولي مرة ثانية."


def try_solve_math(query: str) -> Tuple[bool, str]:
    try:
        if not re.fullmatch(r"[0-9\s\+\-\*\/\.\(\)]+", query):
            return False, ""
        value = eval(query, {"__builtins__": {}}, {})
        if isinstance(value, (int, float)) and math.isfinite(value):
            return True, f"الناتج هو {value}."
    except Exception:
        pass
    return False, ""


def log_turn(**kwargs: Any) -> None:
    try:
        if not PARENT_POLICY.get("log_conversations", True):
            return
        path = LOG_DIR / f"conversation_log_{_dt.date.today().isoformat()}.jsonl"
        row = {"ts": _dt.datetime.now().isoformat(), **kwargs}
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    except Exception as e:
        print("⚠️ log_turn failed:", repr(e))

# ----------------------------- Public pipeline -----------------------------

def wahaty_answer_v6(query: str, policy: Optional[dict] = None, child_mem: Optional[dict] = None, use_stream: bool = False, debug: bool = False) -> dict:
    policy = {**PARENT_POLICY, **(policy or {})}
    child_name = policy.get("child_name", "طفلي")
    child_mem = child_mem or load_child_memory(child_name)

    q_raw = query or ""
    q_norm = normalize_arabic(q_raw)

    guard = check_input(q_norm, policy)
    if not guard["safe"]:
        answer = guard.get("safe_response_ar", SAFE_BLOCK_MSG)
        log_turn(query=q_raw, answer=answer, intent="unsafe", strategy="blocked", blocked=True, reason=guard.get("reason"))
        return {
            "answer": answer,
            "source_label": "🚫",
            "intent": "unsafe",
            "strategy": "blocked",
            "sources": [],
            "blocked": True,
            "rag_score": 0.0,
            "used_rag": False,
            "eval_score": 0.0,
            "child_mem": child_mem,
            "retrieval_debug": [],
        }

    routing = route_query(q_norm, policy)
    intent = routing["intent"]
    strategy = routing["strategy"]
    if debug:
        print(f"🧭 Router → intent={intent} | strategy={strategy} | conf={routing.get('classifier',{}).get('confidence')}")

    if strategy == "blocked":
        answer = SAFE_BLOCK_MSG if not routing.get("blocked_by_parent") else "هذا الموضوع محظور حسب إعدادات ولي الأمر. خلّينا نسأل عن شيء آمن ومفيد."
        log_turn(query=q_raw, answer=answer, intent=intent, strategy="blocked", blocked=True)
        return {"answer": answer, "source_label": "🚫", "intent": intent, "strategy": "blocked", "sources": [], "blocked": True, "rag_score": 0.0, "used_rag": False, "child_mem": child_mem, "retrieval_debug": []}

    if strategy == "tool_call":
        solved, math_answer = try_solve_math(q_norm)
        if solved:
            final = arabize_digits(math_answer)
            result = {"intent": "curriculum", "strategy": "tool_call", "used_rag": False, "sources": [], "answer": final}
            child_mem = update_child_memory(child_mem, q_raw, result, policy)
            save_child_memory(child_mem)
            return {"answer": final, "source_label": "🧮 حساب محلي", "intent": "curriculum", "strategy": "tool_call", "sources": [], "blocked": False, "rag_score": 1.0, "used_rag": False, "child_mem": child_mem, "retrieval_debug": []}

    retrieval = retrieve_multirag(q_norm, intent=intent, top_k=5)
    items = retrieval["items"] if retrieval["use_context"] else []

    memory_ctx = memory_to_context_str(child_mem)
    age = child_mem.get("age") or policy.get("child_age", 8)
    system = build_system(intent, memory_ctx, age=age)
    user = build_user_prompt(q_norm, intent, items)

    raw = generate_answer(system, user)
    out = check_output(raw)
    final_answer = arabize_digits(clean_llm_output(out["response"]))

    sources = []
    if retrieval["use_context"]:
        for item in items[:3]:
            m = item["meta"]
            sources.append({
                "name": m.get("source_name", ""),
                "score": round(float(item.get("score", 0.0)), 4),
                "subject": m.get("subject", ""),
                "page": m.get("page"),
                "rag_id": m.get("rag_id", retrieval["rag_id"]),
            })

    result = {
        "intent": intent,
        "strategy": strategy,
        "used_rag": retrieval["use_context"],
        "sources": sources,
        "answer": final_answer,
        "rag_id": retrieval["rag_id"],
    }
    child_mem = update_child_memory(child_mem, q_raw, result, policy)
    save_child_memory(child_mem)

    log_turn(query=q_raw, answer=final_answer, intent=intent, strategy=strategy, blocked=False, rag_id=retrieval["rag_id"], best_score=retrieval["best_score"])

    return {
        "answer": final_answer,
        "source_label": retrieval["source_label"],
        "intent": intent,
        "strategy": strategy,
        "sources": sources,
        "blocked": False,
        "rag_score": retrieval["best_score"],
        "used_rag": retrieval["use_context"],
        "eval_score": None,
        "child_mem": child_mem,
        "retrieval_debug": [{
            "intent": intent,
            "strategy": strategy,
            "rag_id": retrieval["rag_id"],
            "best_score": retrieval["best_score"],
            "use_context": retrieval["use_context"],
            "classifier": routing.get("classifier", {}),
        }],
    }

print("✅ Wahaty v6 backend module ready")
