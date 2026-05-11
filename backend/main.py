from fastapi import FastAPI, UploadFile, File, Form
from pydantic import BaseModel
from google import genai
from google.genai import types
from dotenv import load_dotenv

import base64
import mimetypes
import os
import tempfile
import wave

from wahaty_v6 import (
    PARENT_POLICY,
    load_child_memory,
    wahaty_answer_v6,
)

load_dotenv()

app = FastAPI()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL_ID = os.getenv("GEMINI_MODEL_ID", "gemini-2.5-flash")
GEMINI_TTS_MODEL_ID = os.getenv("GEMINI_TTS_MODEL_ID", "gemini-2.5-flash-preview-tts")

client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None


class ChatRequest(BaseModel):
    message: str
    child_name: str = "طفلي"


class ChatResponse(BaseModel):
    answer: str


class VoiceResponse(BaseModel):
    heard_text: str
    answer: str
    audio_base64: str


@app.get("/")
def root():
    return {
        "status": "ok",
        "version": "wahaty_multirag_v6",
    }


def _answer_with_v6(message: str, child_name: str) -> str:
    policy = {**PARENT_POLICY}
    policy["child_name"] = child_name

    child_mem = load_child_memory(child_name)

    result = wahaty_answer_v6(
        query=message,
        policy=policy,
        child_mem=child_mem,
        use_stream=False,
        debug=True,
    )

    return result.get("answer") or "عذرًا، حاول مرة أخرى."


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    try:
        print(f"📩 /chat child={req.child_name} message={req.message[:80]}")
        answer = _answer_with_v6(req.message, req.child_name)
        print(f"✅ /chat answer={answer[:120]}")
        return ChatResponse(answer=answer)
    except Exception as e:
        print("❌ /chat error:", repr(e))
        return ChatResponse(answer="صار خطأ بسيط في النظام، حاولي مرة ثانية.")


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


def tts_answer_to_base64(answer: str) -> str:
    if client is None:
        return ""

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


def transcribe_with_gemini(file_path: str) -> str:
    if client is None:
        return ""

    mime_type = mimetypes.guess_type(file_path)[0] or "audio/wav"

    with open(file_path, "rb") as f:
        audio_bytes = f.read()

    response = client.models.generate_content(
        model=GEMINI_MODEL_ID,
        contents=[
            types.Part.from_text(
                text="حوّل هذا الصوت إلى نص عربي فقط. اكتب الكلام المنطوق كما هو بدون شرح إضافي."
            ),
            types.Part.from_bytes(
                data=audio_bytes,
                mime_type=mime_type,
            ),
        ],
        config=types.GenerateContentConfig(
            temperature=0,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )

    return (getattr(response, "text", "") or "").strip()


@app.post("/voice-chat", response_model=VoiceResponse)
async def voice_chat(
    file: UploadFile = File(...),
    child_name: str = Form("طفلي"),
):
    original_name = file.filename or "audio.wav"
    suffix = os.path.splitext(original_name)[1].lower() or ".wav"

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_audio:
        temp_audio.write(await file.read())
        temp_path = temp_audio.name

    print("📁 Uploaded voice file:", original_name)
    print("📁 Saved temp path:", temp_path)

    try:
        heard_text = transcribe_with_gemini(temp_path)
        print("🎤 heard_text:", heard_text)

        if not heard_text:
            fallback = "ما سمعتك بوضوح، حاولي مرة ثانية."
            return VoiceResponse(
                heard_text="",
                answer=fallback,
                audio_base64=tts_answer_to_base64(fallback),
            )

        answer = _answer_with_v6(heard_text, child_name)
        print("🤖 voice answer:", answer[:120])

        return VoiceResponse(
            heard_text=heard_text,
            answer=answer,
            audio_base64=tts_answer_to_base64(answer),
        )

    except Exception as e:
        print("❌ /voice-chat error:", repr(e))
        fallback = "صار خطأ بسيط، حاولي مرة ثانية."
        return VoiceResponse(
            heard_text="",
            answer=fallback,
            audio_base64=tts_answer_to_base64(fallback),
        )

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
