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

WORDS_PER_UNIT = 30
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


# ─────────────── Kitob lug'ati — tarjimaning ASOSIY manbasi ───────────────
#
# Pack'lardagi tarjimalar `_translations.json` (mashina tarjimasi keshi)
# dan kelardi. U kontekstni bilmaydi va shu sababli xato o'rgatardi:
#   flat    -> "tekis"    (kitobda: kvartira)
#   pen     -> "qalam"    (qalam = pencil; ruchka bo'lishi kerak)
#   window  -> "oyna"     (oyna = ko'zgu; deraza bo'lishi kerak)
#   quite   -> "juda"     (kitob AYNAN farqni o'rgatadi: very=juda, quite=ancha)
#   capital -> "kapital"  (poytaxt)
#
# Kitob lug'ati esa 316 betning HAMMASI skan bilan solishtirib
# tekshirilgan. Shu sababli so'z kitobda bo'lsa — kitobniki olinadi.
_ARTICLE = re.compile(r"^(a|an|the|to)\s+")


def _norm_en(s: str) -> str:
    return _ARTICLE.sub("", (s or "").strip().lower())


def load_book_glosses() -> dict:
    """`data/pages/*/*.json` dagi tekshirilgan en/uz juftliklari."""
    out: dict[str, list[str]] = {}
    pages = TRAINER / "data" / "pages"
    for f in sorted(pages.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for v in d.get("vocabularyOnPage", []):
            en, uz = (v.get("en") or "").strip(), (v.get("uz") or "").strip()
            if not en or not uz:
                continue
            out.setdefault(_norm_en(en), [])
            if uz not in out[_norm_en(en)]:
                out[_norm_en(en)].append(uz)
    return out


# Mashina tarjimasi fe'lni turli shaklda beradi: harakat oti
# (`kiyinish`), buyruq (`tushuntiring`), o'tgan zamon (`sog'indim`) yoki
# sifatdosh (`qo'rqib ketgan`). Ularning HAMMASI fe'l ma'nosini
# bildiradi — kitobdagi `-moq` shakliga to'g'ri keladi.
# DIQQAT: `-ib` bu ro'yxatga KIRMAYDI — "ajoyib" kabi oddiy sifatlar
# ham shunday tugaydi va ular fe'l deb qabul qilinib qolardi.
_VERB_ENDINGS = ("moq", "ish", "sh", "ing", "dim", "di", "gan")


def _is_verb_form(uz: str) -> bool:
    """O'zbekcha matn fe'l ma'nosini bildiradimi."""
    first = (uz or "").strip().split(",")[0].split(";")[0].strip().lower()
    last = first.split()[-1] if first.split() else ""
    return any(last.endswith(e) for e in _VERB_ENDINGS)


def _stem_overlap(a: str, b: str) -> int:
    """Ikki matnning umumiy o'zagi (uzun so'zlarning boshi mos kelishi)."""
    aw = [w for w in re.findall(r"\w+", a.lower()) if len(w) > 3]
    bw = [w for w in re.findall(r"\w+", b.lower()) if len(w) > 3]
    score = 0
    for x in aw:
        for y in bw:
            n = 0
            while n < min(len(x), len(y)) and x[n] == y[n]:
                n += 1
            if n >= 4:
                score += n
    return score


# Shakl qoidasi yeta olmaydigan bir necha so'z: mashina tarjimasi
# GRAMMATIK jihatdan mos, lekin MA'NOSI shu kitobga to'g'ri kelmaydi.
# Ular kitobdagi ma'noga majburan o'tkaziladi.
_FORCE_BOOK = {
    "feed",    # "ozuqa" (yem) -> kitobda "delfinlarni boqmoq"
    "cream",   # "krem" (kosmetika) -> kitobda sut mahsuloti
    "ending",  # "tugash" -> grammatikada "qo'shimcha, oxiri"
    "afraid",  # "qo'rqib" -> "qo'rqqan"
}


def pick_gloss(machine_uz: str, book_options: list[str],
               en: str = "") -> str:
    """Kitobning bir necha ma'nosidan mosini tanlaydi.

    Bitta so'zning bir necha ma'nosi bo'ladi (dress = ko'ylak / kiyinmoq).
    Qaysi ma'no kerakligini mashina tarjimasining SHAKLI ko'rsatadi:
      * `kiyinish` — harakat oti -> fe'l ma'nosi (`kiyinmoq`)
      * `telefon`  — oddiy ot    -> ot ma'nosi

    Kitobda mos SHAKLDAGI ma'no bo'lmasa, mashina tarjimasi qoldiriladi —
    aks holda so'z turkumi almashib, o'quvchiga boshqa so'z o'rgatilardi.
    """
    if not book_options:
        return machine_uz
    if _norm_en(en) in _FORCE_BOOK:
        return min(book_options, key=len)
    want_verb = _is_verb_form(machine_uz)
    same_form = [o for o in book_options if _is_verb_form(o) == want_verb]
    if not same_form:
        return machine_uz  # kitobda bu ma'no yo'q — tegmaymiz
    if len(same_form) == 1:
        return same_form[0]
    return max(same_form, key=lambda o: (_stem_overlap(machine_uz, o), -len(o)))


def module_key(module: str) -> int:
    return MODULE_ORDER.index(module) if module in MODULE_ORDER else 99


def build_level(structured: dict, book: dict | None = None) -> dict:
    """structured.json dan 4 ta asset strukturasini yasaydi."""
    vocab = structured.get("vocabulary", [])
    book = book or {}
    # words.json
    words = []
    for v in vocab:
        uz = v["uz"]
        opts = book.get(_norm_en(v["en"]))
        if opts:
            uz = pick_gloss(uz, opts, v["en"])  # kitob tarjimasi
        words.append({
            "id": v["id"],
            "en": v["en"],
            "uz": uz,
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
        book = load_book_glosses()
        data = build_level(structured, book)
        print(f"[beginner] kitob lug'ati: {len(book)} so'z")
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
