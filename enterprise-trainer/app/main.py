"""FastAPI backend (7-bosqich) — barcha qismlarni bog'laydi.

Endpointlar:
  GET  /next      -> keyingi (eng zaif) element uchun yangi mashq
  POST /answer    -> javobni baholaydi, SRS ni yangilaydi, o'zbekcha izoh
  GET  /progress  -> modul % + zaif nuqtalar dashboard ma'lumoti
  POST /ingest    -> PDF -> tuzilma -> baza quvurini ishga tushiradi
  GET  /          -> frontend (statik sahifa)

Bitta foydalanuvchi uchun mo'ljallangan: joriy mashq xotirada saqlanadi.
"""
from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config  # noqa: E402
from core.generator import Exercise, Generator, grade_answer  # noqa: E402
from core.progress import ProgressStore  # noqa: E402
from core.retriever import Retriever  # noqa: E402
from core.srs import Grade, module_progress, next_card, review  # noqa: E402

app = FastAPI(title="Enterprise English Trainer")

STATIC_DIR = Path(__file__).resolve().parent / "static"

# ---- Global holat (bitta foydalanuvchi) ----
store: ProgressStore
retriever: Retriever
generator: Generator
# Joriy taqdim etilgan mashqlar: item_id -> Exercise (javobni baholash uchun).
pending: dict[str, Exercise] = {}


@app.on_event("startup")
def startup() -> None:
    """Ishga tushganda bazani tayyorlaydi va komponentlarni yuklaydi."""
    global store, retriever, generator
    store = ProgressStore()
    if config.STRUCTURED_JSON.exists():
        added = store.seed_from_structured()
        retriever = Retriever()
        generator = Generator(retriever=retriever)
        print(f"[startup] Baza tayyor. Yangi kartalar: {added}")
    else:
        retriever = None  # type: ignore
        generator = None  # type: ignore
        print("[startup] structured.json yo'q. Avval /ingest ni ishga tushiring.")


# ---------- Modellar ----------
class AnswerIn(BaseModel):
    item_id: str
    answer: str


# ---------- Endpointlar ----------
@app.get("/next")
def get_next() -> dict:
    """Keyingi eng zaif element uchun yangi mashq qaytaradi."""
    if generator is None:
        raise HTTPException(503, "Ma'lumotlar tayyor emas. /ingest ni ishga tushiring.")
    cards = store.all_cards()
    card = next_card(cards)
    if card is None:
        return {"done": True, "message_uz": "Tabriklaymiz! Barcha elementlar o'rganildi 🎉"}

    exercise = generator.generate(card.item_id)
    pending[card.item_id] = exercise
    # Javobni mijozга yubormaymiz (server tomonda baholanadi).
    public = {k: v for k, v in exercise.items() if k != "expected_answer"}
    public["mastery"] = card.mastery
    public["category"] = retriever.category_of(card.item_id)
    public["module"] = card.module
    return public


@app.post("/answer")
def post_answer(data: AnswerIn) -> dict:
    """Javobni baholaydi, SRS ni yangilaydi va o'zbekcha izoh qaytaradi."""
    exercise = pending.get(data.item_id)
    if exercise is None:
        raise HTTPException(400, "Bu element uchun faol mashq yo'q. /next ni chaqiring.")

    feedback = grade_answer(data.answer, exercise["expected_answer"])

    # Baho -> SRS Grade: to'g'ri+aniq=GOOD, imlo xatosi bilan=HARD, xato=AGAIN.
    if feedback["correct"]:
        grade = Grade.GOOD if feedback["similarity"] >= 0.999 else Grade.HARD
    else:
        grade = Grade.AGAIN

    card = store.get_card(data.item_id)
    if card is None:
        raise HTTPException(404, "Karta topilmadi.")
    review(card, grade, now=datetime.now())
    store.save_review(card, grade)
    pending.pop(data.item_id, None)

    return {
        "correct": feedback["correct"],
        "message_uz": feedback["message_uz"],
        "expected_answer": exercise["expected_answer"],
        "mnemonic_uz": exercise.get("mnemonic_uz", ""),
        "mastery": card.mastery,
        "is_mastered": card.is_mastered(),
    }


@app.get("/progress")
def get_progress() -> dict:
    """Modul jarayoni va zaif nuqtalar dashboard ma'lumotini qaytaradi."""
    cards = store.all_cards()
    modules = module_progress(cards)
    total = len(cards)
    mastered = sum(1 for c in cards if c.is_mastered())
    return {
        "overall": {
            "total": total,
            "mastered": mastered,
            "percent": round(mastered / total * 100) if total else 0,
        },
        "modules": [
            {"module": m.module, "total": m.total, "mastered": m.mastered,
             "percent": m.percent, "avg_mastery": m.avg_mastery,
             "is_complete": m.is_complete}
            for m in modules
        ],
        "category_accuracy": store.category_accuracy(),
        "weakest_items": store.weakest_items(limit=10),
    }


@app.post("/ingest")
def post_ingest() -> dict:
    """structured.json dan bazani to'ldiradi (PDF->OCR alohida ishga tushiriladi).

    Eslatma: og'ir OCR jarayoni (pdf_extract, structure) terminal orqali
    bir marta ishga tushiriladi. Bu endpoint tayyor structured.json ni
    bazaga yuklaydi.
    """
    if not config.STRUCTURED_JSON.exists():
        raise HTTPException(400, "structured.json yo'q. Avval ingestion skriptlarini ishga tushiring.")
    global retriever, generator
    added = store.seed_from_structured()
    retriever = Retriever()
    generator = Generator(retriever=retriever)
    return {"added": added, "message_uz": f"{added} ta yangi karta qo'shildi."}


# ---------- Frontend ----------
@app.get("/")
def index() -> FileResponse:
    """Bosh sahifa (frontend)."""
    return FileResponse(STATIC_DIR / "index.html")


# Statik fayllar (app.js, style.css).
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
