"""Kontent sifatini tekshiradi — HAR BETDAN OLDIN ishga tushiriladi.

Nega kerak: qo'lda yozilgan 300+ bet kontentida xato sezilmay qolishi oson.
Bu skript avval sezilmagan xatolarni topgan:
  * 3 ta mashq butunlay yo'qolgan edi (eksport tuzilmani bilmagan)
  * 2 ta mashqda savol va javob bir xil edi ("hair" -> "hair")
  * dialog qatorlarida matn tushib qolardi ("A: ")
  * o'zbekcha yorliqlar inglizcha ovoz bilan o'qilardi

Ishlatish:
    python -m ingest.check_content
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TRAINER = Path(__file__).resolve().parent.parent
PAGES = TRAINER / "data" / "pages"
ASSETS = TRAINER.parent / "enterprise-app" / "assets" / "content" / "enterprise1"

# Bandlar shu maydonlarning birida bo'lishi mumkin.
ITEM_KEYS = (
    "items", "answers", "pairs", "lines", "profiles", "rows", "sentences",
    "words", "questions", "pictureLabels", "scenes", "modelSentences",
    "modelAnswers", "dialogues", "texts", "structure", "example",
    "sentenceEn", "table",
)

UZ_IN_SPEECH = re.compile(
    r"(qator|to'ldir|tanlang|yozing|tuzing|qarang|Rasm |Matn |bo'yicha"
    r"|Namuna|toping|shakl|-bet|-o'rin)"
)


def check_sources() -> list[tuple[str, str]]:
    """Manba sahifa fayllarini tekshiradi."""
    out = []
    for f in sorted(PAGES.glob("*/p*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            out.append((f.name, f"JSON buzuq: {e}"))
            continue
        tag = f"{d.get('book')} {d.get('bookPage')}-bet"

        for k in ("book", "bookPage", "pdfPage", "unit", "sections"):
            if k not in d:
                out.append((tag, f"maydon yo'q: {k}"))

        for s in d.get("sections", []):
            if not s.get("kind"):
                out.append((tag, "bo'lim kind yo'q"))
            for e in s.get("exercises", []):
                ref = e.get("ref", "?")
                if not e.get("type"):
                    out.append((tag, f"Ex.{ref}: type yo'q"))
                if not e.get("instructionUz"):
                    out.append((tag, f"Ex.{ref}: o'zbekcha ko'rsatma yo'q"))
                if not any(e.get(k) for k in ITEM_KEYS):
                    out.append((tag, f"Ex.{ref}: bandlar yo'q"))

        for k, label in (("vocabularyOnPage", "sahifa lug'ati"),
                         ("sentencePatterns", "gap qoliplari"),
                         ("wordFormation", "so'z yasalishi")):
            if not d.get(k):
                out.append((tag, f"{label} yo'q"))
    return out


def check_export() -> list[tuple[str, str]]:
    """Eksport qilingan asset'larni tekshiradi — o'quvchi ko'radigan holat."""
    out = []
    for f in sorted(ASSETS.glob("unit_*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d["sections"]:
            for e in s["exercises"]:
                loc = f"U{d['unit']} {e['book']} {e['bookPage']}b Ex.{e['ref']}"
                if not e["tasks"]:
                    out.append((loc, "BAND YO'Q — kontent yo'qolgan"))
                    continue
                for i, t in enumerate(e["tasks"]):
                    ans = (t.get("answer") or "").strip().lower()
                    prompt = (t.get("prompt") or "").strip()
                    speak = (t.get("speak") or "").strip()
                    opts = [o.lower() for o in t.get("options", [])]

                    if ans:
                        if (t.get("promptUz") or "").strip().lower() == ans:
                            out.append((loc, f"b{i}: promptUz JAVOBNI beryapti"))
                        if speak.lower() == ans and e["kind"] != "study":
                            out.append((loc, f"b{i}: ovoz JAVOBNI o'qiyapti"))
                        if prompt.lower() == ans and e["kind"] != "study":
                            out.append((loc, f"b{i}: savol = javob (soxta mashq)"))
                        if opts and ans not in opts:
                            out.append((loc, f"b{i}: javob variantlar ichida yo'q"))
                    if opts and len(opts) != len(set(opts)):
                        out.append((loc, f"b{i}: variant takrorlangan"))
                    if opts and len(opts) < 2:
                        out.append((loc, f"b{i}: bitta variant — tanlov yo'q"))
                    if speak and UZ_IN_SPEECH.search(speak):
                        out.append((loc, f"b{i}: o'zbekcha matn ovozga berilyapti"))
                    if e["kind"] in ("choice", "text") and not prompt:
                        out.append((loc, f"b{i}: savol matni bo'sh"))
    return out


def main() -> int:
    src = check_sources()
    exp = check_export()

    print("=== MANBA SAHIFALARI ===")
    for tag, msg in src:
        print(f"  {tag:24s} {msg}")
    print("  muammo yo'q" if not src else f"  jami: {len(src)}")

    print("\n=== EKSPORT (o'quvchi ko'radigan) ===")
    for loc, msg in exp:
        print(f"  {loc:30s} {msg}")
    print("  muammo yo'q" if not exp else f"  jami: {len(exp)}")

    total = len(src) + len(exp)
    print(f"\n{'TOZA' if total == 0 else f'JAMI MUAMMO: {total}'}")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
