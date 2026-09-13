"""Betma-bet yozilgan sahifalardan DARAJA BO'YIChA ma'lumotnoma yig'adi.

`enterprise-app/assets/content/<level_dir>/grammar.json` va
`word_formation.json` — ilovadagi "Grammatika" va "So'z yasalishi"
bo'limlari shu ikki fayldan o'qiydi. Beginner uchun ular eski OCR
quvuridan (structured.json) to'lgan edi; Elementary uchun bo'sh
placeholder qolib ketgan — betma-bet yozilgan 60+ nazariya bo'limi
unit ichida bor, lekin umumiy ro'yxatga ulanmagan edi.

Manba: `data/pages-<level>/*/pNNN.json`:
  * sections[kind == grammar_theory].exercises[type == explain]
      -> grammar.json topics (qoida = explanationUz, misollar = points.en)
  * wordFormation.groups[].items -> word_formation.json families

Ishga tushirish:
  python -m ingest.export_reference --level elementary
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRAINER = HERE.parent
APP_CONTENT = TRAINER.parent / "enterprise-app" / "assets" / "content"

LEVELS = {
    # level id -> (sahifalar papkasi, asset papkasi)
    "beginner": ("pages", "beginner"),
    "elementary": ("pages-elementary", "elementary"),
}

# Kitob tartibi: Grammar kitobi nazariyasi eng to'liq — avval u,
# so'ng coursebook/workbook'dagi qo'shimcha qoidalar.
BOOK_ORDER = {"grammar": 0, "coursebook": 1, "workbook": 2}

# Grammatika bo'limi hisoblanadigan section turlari.
GRAMMAR_KINDS = {"grammar_theory", "grammar", "grammar_exercise"}

# Mashq izohida qoida borligini bildiradigan belgilar.
RULE_MARK = re.compile(r"QOIDA|QOLIP|QOLIPI|FORMULA", re.I)


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", s or "").strip()


def _key(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()


_PREFIX = re.compile(r"^(grammar|grammatika)\s*(exercises|mashqlari)?\s*[:—\-–]?\s*", re.I)


def _strip_prefix(t: str) -> str:
    """'Grammar: Past Simple' -> 'Past Simple'; 'Grammar' -> ''."""
    out = _PREFIX.sub("", t).strip(" -—:")
    return out


def _first_line(text: str) -> str:
    for ln in (text or "").splitlines():
        ln = _norm(ln).strip(" .:")
        if ln:
            return ln
    return ""


def collect(level: str):
    pages_dir, _ = LEVELS[level]
    root = TRAINER / "data" / pages_dir
    pages = []
    for book in sorted(BOOK_ORDER, key=BOOK_ORDER.get):
        for f in sorted((root / book).glob("p*.json")):
            d = json.loads(f.read_text(encoding="utf-8"))
            d["_book"] = book
            pages.append(d)
    pages.sort(key=lambda d: (d.get("unit", 0), BOOK_ORDER[d["_book"]], d.get("pdfPage", 0)))

    topics: list[dict] = []
    seen_rules: set[str] = set()
    families: list[dict] = []
    seen_fam: set[str] = set()

    for d in pages:
        unit = d.get("unit", 0)
        module = d.get("module", 0)
        for s in d.get("sections", []):
            kind = s.get("kind", "")
            # Grammar kitobi nazariyasi + Coursebook/Workbook'dagi
            # "Grammar" bo'limlari — egasi: "coursebookdagi qoidalarning
            # HAMMASI kirsin".
            if kind not in GRAMMAR_KINDS:
                continue
            for e in s.get("exercises", []):
                is_explain = e.get("type") == "explain"
                rule = _norm(e.get("explanationUz", ""))
                # Mashq izohi faqat ichida QOIDA bo'lsa kiradi (mashqning
                # o'zi emas, qoida qismi qiziq).
                if not is_explain and not RULE_MARK.search(rule):
                    continue
                if not rule or rule in seen_rules:
                    continue
                seen_rules.add(rule)
                title = _strip_prefix(_norm(s.get("title", "")))
                title_uz = _strip_prefix(_norm(s.get("titleUz", "")))
                if _key(title) in ("", "continued", "exercises"):
                    title = ""
                if not is_explain:
                    # Mashq izohining birinchi qatori — aniq mavzu
                    # ("'BE GOING TO' - TASDIQ va INKOR") - umumiy
                    # "Grammar" dan ko'ra foydali.
                    head = _first_line(e.get("explanationUz", ""))
                    if head and len(head) <= 70:
                        title_uz = head
                    ref = _norm(str(e.get("ref", ""))).replace("-mashq", "").replace("mashq", "").strip()
                    if ref:
                        title_uz = f"{title_uz} · {ref}-mashq" if title_uz else f"{ref}-mashq"
                if not title:
                    # Sarlavha yo'q - o'zbekcha mavzu asosiy bo'ladi.
                    title, title_uz = title_uz, ""
                if not title:
                    continue
                if _key(title_uz) == _key(title):
                    title_uz = ""
                examples = [
                    _norm(p.get("en", "")) for p in e.get("points", []) if _norm(p.get("en", ""))
                ]
                topics.append({
                    "id": f"gr-{len(topics) + 1:03d}",
                    "topic": title if not title_uz or title_uz == title else f"{title} — {title_uz}",
                    "rule_uz": e.get("explanationUz", ""),
                    "examples": examples[:8],
                    "module": f"Module {module}" if module else "",
                    "unit": unit if isinstance(unit, int) and unit < 800 else 0,
                    "source": e.get("bookRef", ""),
                })

        wf = d.get("wordFormation") or {}
        for g in wf.get("groups", []):
            for it in g.get("items", []):
                base = _norm(it.get("base", ""))
                derived = _norm(it.get("derived", ""))
                if not base or not derived:
                    continue
                k = _key(base)
                # Faqat HAQIQIY so'z oilasi: asos 3+ harf, hosila asos bilan
                # o'zakdosh (birinchi 3 harf bir xil). Aks holda olmosh
                # jadvallari, predlog juftlari kabi shovqin kiradi.
                if len(k) < 3 or " " in k:
                    continue
                forms = [x.strip() for x in re.split(r"[/,]| - ", derived) if x.strip()]
                stem = k[:3]
                forms = [
                    x for x in forms
                    if _key(x) != k and _key(x)[:3] == stem and " " not in _key(x)
                ]
                if not forms:
                    continue
                if k in seen_fam:
                    # mavjud oilaga yangi shakllar qo'shiladi
                    for fam in families:
                        if _key(fam["base"]) == k:
                            for x in forms:
                                if x not in fam["forms"]:
                                    fam["forms"].append(x)
                            if not fam["uz"] and it.get("baseUz"):
                                fam["uz"] = _norm(it["baseUz"])
                            break
                    continue
                seen_fam.add(k)
                families.append({
                    "id": f"wf-{len(families) + 1:04d}",
                    "base": base,
                    "uz": _norm(it.get("baseUz", "")),
                    "forms": forms,
                })

    # Bir bo'limda bir necha nazariya bo'lsa sarlavhalar takrorlanadi -
    # raqamlab ajratiladi ("Past Simple (2)").
    counts: dict[str, int] = {}
    for t in topics:
        counts[t["topic"]] = counts.get(t["topic"], 0) + 1
    seen: dict[str, int] = {}
    for t in topics:
        if counts[t["topic"]] > 1:
            seen[t["topic"]] = seen.get(t["topic"], 0) + 1
            t["topic"] = f'{t["topic"]} ({seen[t["topic"]]})'

    return topics, families


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="elementary", choices=sorted(LEVELS))
    a = ap.parse_args(argv)
    topics, families = collect(a.level)
    out = APP_CONTENT / LEVELS[a.level][1]
    out.mkdir(parents=True, exist_ok=True)
    # Beginner'da eski OCR quvuridan kelgan qisqa umumiy mavzular va
    # so'z oilalari bor edi — ular yo'qolmasin: oxiriga "Umumiy" deb
    # qo'shiladi (takror bo'lmasa).
    old_g = out / "grammar.json"
    if old_g.exists():
        seen = {_norm(t["rule_uz"]) for t in topics}
        for t in json.loads(old_g.read_text(encoding="utf-8")).get("topics", []):
            if t.get("source") and t.get("source") != "Umumiy qoida":
                continue  # allaqachon shu skript yozgan
            if _norm(t.get("rule_uz", "")) in seen:
                continue
            topics.append({
                "id": f"gr-{len(topics) + 1:03d}",
                "topic": t["topic"],
                "rule_uz": t.get("rule_uz", ""),
                "examples": t.get("examples", []),
                "module": t.get("module", ""),
                "unit": 0,
                "source": "Umumiy qoida",
            })
    old_w = out / "word_formation.json"
    if old_w.exists():
        have = {_key(f["base"]) for f in families}
        for f in json.loads(old_w.read_text(encoding="utf-8")).get("families", []):
            if _key(f.get("base", "")) in have or not f.get("forms"):
                continue
            have.add(_key(f["base"]))
            families.append({
                "id": f"wf-{len(families) + 1:04d}",
                "base": f["base"],
                "uz": f.get("uz", ""),
                "forms": list(f["forms"]),
            })
    (out / "grammar.json").write_text(
        json.dumps({"topics": topics}, ensure_ascii=False, indent=1), encoding="utf-8")
    (out / "word_formation.json").write_text(
        json.dumps({"families": families}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"[{a.level}] grammar.json: {len(topics)} mavzu; "
          f"word_formation.json: {len(families)} oila -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
