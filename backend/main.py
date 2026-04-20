from fastapi import FastAPI, UploadFile, File, Form
from pydantic import BaseModel
from google import genai
from google.genai import types
import whisper
import tempfile
import os
import wave
import base64
import json
import hashlib
import datetime

from dotenv import load_dotenv
import os

load_dotenv()
from rag_utils import retrieve_context

app = FastAPI()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL_ID = "gemini-2.5-flash"
GEMINI_TTS_MODEL_ID = "gemini-2.5-flash-preview-tts"

client = genai.Client(api_key=GEMINI_API_KEY)

whisper_model = whisper.load_model("base")

MEMORY_DIR = "child_memories"
os.makedirs(MEMORY_DIR, exist_ok=True)


class ChatRequest(BaseModel):
    message: str
    child_name: str = "طفلي"


class ChatResponse(BaseModel):
    answer: str


class VoiceResponse(BaseModel):
    heard_text: str
    answer: str
    audio_base64: str


def _child_id(name: str) -> str:
    return hashlib.md5(name.encode("utf-8")).hexdigest()[:12]


def _memory_path(name: str) -> str:
    return os.path.join(MEMORY_DIR, f"{_child_id(name)}.json")


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


def load_child_memory(name: str) -> dict:
    path = _memory_path(name)
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            mem = json.load(f)
        mem = {**DEFAULT_CHILD_MEMORY, **mem}
    else:
        mem = DEFAULT_CHILD_MEMORY.copy()
        mem["name"] = name
    return mem


def save_child_memory(mem: dict) -> None:
    mem["last_seen"] = datetime.datetime.now().isoformat()
    path = _memory_path(mem["name"])
    with open(path, "w", encoding="utf-8") as f:
        json.dump(mem, f, ensure_ascii=False, indent=2)


def update_child_memory(mem: dict, query: str, answer: str) -> dict:
    mem["interaction_count"] += 1

    session_turn = {
        "q": query[:100],
        "a": answer[:150],
    }
    mem["session_context"] = (mem["session_context"] + [session_turn])[-6:]

    q_lower = query.lower()

    if "قصة" in query or "احكي" in query or "احك" in query or "story" in q_lower:
        mem["favorite_topics"]["story"] = mem["favorite_topics"].get("story", 0) + 1
    elif "شرح" in query or "درس" in query or "واجب" in query or "مسألة" in query:
        mem["favorite_topics"]["curriculum"] = mem["favorite_topics"].get("curriculum", 0) + 1
    else:
        mem["favorite_topics"]["general"] = mem["favorite_topics"].get("general", 0) + 1

    story_count = mem["favorite_topics"].get("story", 0)
    curriculum_count = mem["favorite_topics"].get("curriculum", 0)

    if story_count > curriculum_count * 2 and story_count > 0:
        mem["preferred_style"] = "story"
    elif curriculum_count > 3:
        mem["preferred_style"] = "detailed"
    else:
        mem["preferred_style"] = "simple"

    return mem


def memory_to_context_str(mem: dict) -> str:
    parts = [f"اسم الطفل: {mem['name']}"]

    if mem.get("grade"):
        parts.append(f"الصف: {mem['grade']}")
    if mem.get("age"):
        parts.append(f"العمر: {mem['age']} سنوات")

    if mem.get("session_context"):
        last = mem["session_context"][-1]
        parts.append(f"آخر سؤال: {last['q']}")
        parts.append(f"آخر رد: {last['a']}")

    parts.append(f"الأسلوب المفضل: {mem.get('preferred_style', 'simple')}")
    return "\n".join(parts)


def build_system_prompt(memory_ctx: str = "") -> str:
    mem_block = f"\n[معلومات عن الطفل]\n{memory_ctx}\n" if memory_ctx else ""

    return f"""
أنت مساعد عربي لطيف للأطفال.{mem_block}

- أجب بالعربية فقط
- استخدم كلمات بسيطة وواضحة
- أجب مباشرة عن السؤال في أول جملة
- يمكن أن تكون الإجابة من 3 إلى 8 أسطر إذا احتاج السؤال ذلك
- لا تجعل الإجابة قصيرة جدًا بشكل مخل
- إذا احتاج السؤال شرحًا، اشرح بلطف وبشكل مبسط
- إذا احتاج مثالًا، أعط مثالًا واحدًا بسيطًا فقط
- راعِ اسم الطفل والمعلومات المتوفرة عنه إذا كانت موجودة
- إذا كان الأسلوب المفضل قصة، يمكن أن يكون الجواب ألطف وأحكى قليلًا
- إذا كان الأسلوب المفضل detailed، يمكنك إعطاء شرح أوضح
- استخدم السياق المعرفي إذا كان موجودًا ومفيدًا
- لا تخترع معلومات إذا كان السياق واضحًا
- لا تقدم أي محتوى ضار أو مخيف أو غير مناسب للأطفال
""".strip()


def build_user_prompt(message: str, retrieved_context: str) -> str:
    if retrieved_context and retrieved_context.strip():
        return f"""
السياق المعرفي:
{retrieved_context}

سؤال الطفل:
{message}

اعتمد أولًا على السياق المعرفي في الإجابة، وإذا لم يكن كافيًا فأجب بلطف وبطريقة مبسطة للطفل.
""".strip()

    return message


def build_tts_prompt(answer: str) -> str:
    return f"""
اقرأ النص التالي بالعربية الفصحى بصوت لطيف ودافئ ومناسب للأطفال.
اجعل النبرة هادئة، واضحة، مشجعة، وغير مخيفة.
النص:
{answer}
""".strip()


def save_wave_file(filename: str, pcm_data: bytes, channels=1, rate=24000, sample_width=2):
    with wave.open(filename, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(rate)
        wf.writeframes(pcm_data)


def answer_with_gemini(message: str, child_name: str = "طفلي") -> str:
    child_mem = load_child_memory(child_name)
    memory_ctx = memory_to_context_str(child_mem)

    try:
        retrieved_context = retrieve_context(message, top_k=3)
        print("📚 Retrieved context:")
        print(retrieved_context[:500])
    except Exception as e:
        print("⚠️ RAG retrieval failed:", str(e))
        retrieved_context = ""

    final_user_prompt = build_user_prompt(message, retrieved_context)

    cfg = types.GenerateContentConfig(
        temperature=0.3,
        max_output_tokens=300,
        thinking_config=types.ThinkingConfig(thinking_budget=0),
        system_instruction=build_system_prompt(memory_ctx),
    )

    response = client.models.generate_content(
        model=GEMINI_MODEL_ID,
        contents=final_user_prompt,
        config=cfg,
    )

    answer = (getattr(response, "text", "") or "عذرًا، حاول مرة أخرى").strip()

    child_mem = update_child_memory(child_mem, message, answer)
    save_child_memory(child_mem)

    return answer


def tts_answer_to_base64(answer: str) -> str:
    response = client.models.generate_content(
        model=GEMINI_TTS_MODEL_ID,
        contents=build_tts_prompt(answer),
        config=types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name="Kore",
                    )
                )
            ),
        ),
    )

    pcm_data = response.candidates[0].content.parts[0].inline_data.data

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_wav:
        wav_path = temp_wav.name

    try:
        save_wave_file(wav_path, pcm_data)

        with open(wav_path, "rb") as f:
            wav_bytes = f.read()

        return base64.b64encode(wav_bytes).decode("utf-8")
    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)


@app.get("/")
def root():
    return {"status": "ok"}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    answer = answer_with_gemini(req.message, req.child_name)
    return ChatResponse(answer=answer)


@app.post("/voice-chat", response_model=VoiceResponse)
async def voice_chat(
    file: UploadFile = File(...),
    child_name: str = Form("طفلي")
):
    original_name = file.filename or "audio.wav"
    suffix = os.path.splitext(original_name)[1].lower()

    if suffix == "":
        suffix = ".wav"

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_audio:
        temp_audio.write(await file.read())
        temp_path = temp_audio.name

    print("📁 Uploaded file:", original_name)
    print("📁 Saved temp path:", temp_path)

    try:
        result = whisper_model.transcribe(temp_path, language="ar")
        heard_text = result.get("text", "").strip()

        print("🎤 TEXT:", heard_text)

        if not heard_text:
            print("⚠️ Whisper returned empty text")
            fallback = "ما سمعتك بوضوح، حاول مرة ثانية 😊"
            audio_base64 = tts_answer_to_base64(fallback)
            return VoiceResponse(
                heard_text="",
                answer=fallback,
                audio_base64=audio_base64,
            )

        answer = answer_with_gemini(heard_text, child_name)
        print("🤖 ANSWER:", answer)

        audio_base64 = tts_answer_to_base64(answer)

        return VoiceResponse(
            heard_text=heard_text,
            answer=answer,
            audio_base64=audio_base64,
        )

    except Exception as e:
        print("❌ voice-chat error:", str(e))
        fallback = "صار خطأ، حاولي مرة ثانية 😊"
        audio_base64 = tts_answer_to_base64(fallback)
        return VoiceResponse(
            heard_text="",
            answer=fallback,
            audio_base64=audio_base64,
        )

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
