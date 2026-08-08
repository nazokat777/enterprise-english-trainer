"""structured.json -> Flutter asset JSON (Faza 3).

Har daraja uchun `enterprise-app/assets/content/<level>/` ichiga yozadi:
  words.json           - barcha lug'at so'zlari (misol gaplar tozalangan)
  units.json           - Unit -> Component(VOCABULARY/HOMEWORK) -> Pack -> word id
  grammar.json         - grammatika mavzulari (qoida + misollar)
  word_formation.json  - so'z oilalari (asos + hosila shakllar)

Beginner = Enterprise 1 (structured.json, tayyor).
Elementary = hali OCR qilinmagan -> bo'sh placeholder yoziladi.

Ishga tushirish:
  python ingest/export_assets.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent          # ingest/
TRAINER = HERE.parent                            # enterprise-trainer/
APP_CONTENT = TRAINER.parent / "enterprise-app" / "assets" / "content"

# Vocab modullarini tabiiy tartibda (Unit raqamlash uchun).
MODULE_ORDER = [
    "Module 1 (Units 1-4)",
    "Module 2 (Units 5-8)",
    "Module 3 (Units 9-12)",
    "Module 4 (Units 13-15)",
    "Qo'shimcha (lug'at/madaniyat)",
]

WORDS_PER_UNIT = 12
PACK_SIZE = 6

_CAPS = re.compile(r"\b[A-Z]{3,}\b")
_JUNK = re.compile(r"[a-z]{6,}")
_VOWEL = re.compile(r"[aeiou]")
_WEIRD = re.compile(r"[^a-zA-Z0-9\s\.,\?\!\'\"-]")


def clean_example(ex: str) -> str:
    """OCR shovqinini filtrlaydi. Toza bo'lsa gapni, aks holda "" qaytaradi."""
    if not ex or not ex.strip():
        return ""
    ex = ex.replace("�", "'").strip()
    words = ex.split()
    if len(words) < 3:
        return ""
    letters = sum(c.isalpha() for c in ex)
    if letters < len(ex) * 0.6:
        return ""
    if _CAPS.search(ex):
        return ""
    if "...." in ex or "eeee" in ex.lower():
        return ""
    if len(_WEIRD.findall(ex)) > 3:
        return ""
    # undosh-og'ir "so'z"lar (OCR chalasi)
    for w in words:
        lw = re.sub(r"[^a-z]", "", w.lower())
        if len(lw) >= 6 and not _VOWEL.search(lw):
            return ""
    return ex


def clean_rule(text: str) -> str:
    """Grammatika qoidasidagi buzuq belgilarni tozalaydi."""
    return (text or "").replace("�", "'").strip()


def module_key(module: str) -> int:
    return MODULE_ORDER.index(module) if module in MODULE_ORDER else 99


def build_level(structured: dict) -> dict:
    """structured.json dan 4 ta asset strukturasini yasaydi."""
    vocab = structured.get("vocabulary", [])
    # words.json
    words = []
    for v in vocab:
        words.append({
            "id": v["id"],
            "en": v["en"],
            "uz": v["uz"],
            "example": clean_example(v.get("example", "")),
            "module": v.get("module", ""),
            "freq": v.get("freq", 0.0),
            "pos": (v.get("pos") or "").replace("—", "").strip(),
            "phonetic": "",  # keyin CMU dict bilan boyitiladi
        })

    # Unit -> Component -> Pack ierarxiyasi.
    ordered = sorted(vocab, key=lambda v: (module_key(v.get("module", "")), -v.get("freq", 0.0)))
    units = []
    n = 0
    for i in range(0, len(ordered), WORDS_PER_UNIT):
        n += 1
        chunk = ordered[i:i + WORDS_PER_UNIT]
        module = chunk[0].get("module", "")
        packs = []
        for k in range(0, len(chunk), PACK_SIZE):
            pack_words = chunk[k:k + PACK_SIZE]
            packs.append({
                "id": f"u{n}-p{k // PACK_SIZE + 1}",
                "name": f"Pack {k // PACK_SIZE + 1}",
                "wordIds": [w["id"] for w in pack_words],
            })
        units.append({
            "id": f"u{n}",
            "code": f"Unit {n}",
            "title": f"{module.split(' (')[0]} - Dars {n}",
            "module": module,
            "order": n,
            "isRevision": n % 4 == 0,
            "components": [
                {"id": f"u{n}-vocab", "type": "VOCABULARY", "order": 0, "packs": packs},
                {"id": f"u{n}-hw", "type": "HOMEWORK", "order": 1, "packs": []},
            ],
        })

    grammar = [
        {
            "id": g["id"],
            "topic": g["topic"],
            "rule_uz": clean_rule(g.get("rule_text", "")),
            "examples": [clean_rule(e) for e in g.get("examples", [])],
            "module": g.get("module", ""),
        }
        for g in structured.get("grammar", [])
    ]

    families = [
        {
            "id": w["id"],
            "base": w["base"],
            "uz": w.get("uz", ""),
            "forms": w.get("forms", []),
        }
        for w in structured.get("word_formation", [])
    ]

    return {
        "words": {"words": words},
        "units": {"units": units},
        "grammar": {"topics": grammar},
        "word_formation": {"families": families},
    }


def empty_level() -> dict:
    return {
        "words": {"words": []},
        "units": {"units": []},
        "grammar": {"topics": []},
        "word_formation": {"families": []},
    }


def write_level(level: str, data: dict) -> None:
    out = APP_CONTENT / level
    out.mkdir(parents=True, exist_ok=True)
    # eski placeholder'ni o'chiramiz
    gk = out / ".gitkeep.json"
    if gk.exists():
        gk.unlink()
    for name, payload in data.items():
        (out / f"{name}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
        )


def main() -> None:
    # Beginner
    structured_path = TRAINER / "data" / "parsed" / "structured.json"
    if structured_path.exists():
        structured = json.loads(structured_path.read_text(encoding="utf-8"))
        data = build_level(structured)
        write_level("beginner", data)
        print(f"[beginner] words={len(data['words']['words'])} "
              f"units={len(data['units']['units'])} "
              f"grammar={len(data['grammar']['topics'])} "
              f"families={len(data['word_formation']['families'])}")
    else:
        print(f"[beginner] {structured_path} topilmadi — o'tkazib yuborildi")

    # Elementary (hali OCR yo'q — bo'sh placeholder)
    elem_path = TRAINER / "data" / "parsed" / "structured-elementary.json"
    if elem_path.exists():
        elem = json.loads(elem_path.read_text(encoding="utf-8"))
        write_level("elementary", build_level(elem))
        print("[elementary] structured-elementary.json dan yozildi")
    else:
        write_level("elementary", empty_level())
        print("[elementary] bo'sh placeholder yozildi (OCR kerak)")


if __name__ == "__main__":
    main()
