"""OCR matnini tuzilgan JSON ga aylantirish (3-bosqich) — AI'siz, bepul.

OCR'dan kelgan matn shovqinli bo'ladi. Bu modul qoidalar asosida undan:
  * VOCABULARY      — haqiqiy inglizcha so'zlar (shovqin filtrlanadi) +
                      o'zbekcha tarjima + kitobdagi misol gap + so'z turkumi
  * WORD_FORMATION  — so'z oilalari (success -> successful, successfully, ...)
  * GRAMMAR         — grammatika kitobidagi mavzu sarlavhalari + qoida matni

ni ajratadi va `data/parsed/structured.json` ga saqlaydi.

Shovqinni filtrlash uchun `wordfreq` (so'z chastotasi) ishlatiladi:
haqiqiy so'zlar chastotaga ega, OCR shovqini esa 0.

Tarjimalar bepul Google Translate (deep-translator) orqali olinadi va
`data/parsed/_translations.json` da keshlanadi (qayta ishlatish uchun).

Ishga tushirish:
    python -m ingest.structure
    python -m ingest.structure --max-vocab 300   # lug'at sonini cheklash
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import TypedDict

from deep_translator import GoogleTranslator
from wordfreq import zipf_frequency

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config  # noqa: E402
from ingest.grammar_rules import GRAMMAR_RULES  # noqa: E402

# ---- Kitobning haqiqiy moduli tuzilishi (mundarijadan aniqlangan) ----
# Coursebook PDF sahifalari bo'yicha modul chegaralari (self-assessment
# sahifalari orqali aniqlangan). (boshi, oxiri, modul_nomi).
COURSEBOOK_MODULES: list[tuple[int, int, str]] = [
    (1, 34, "Module 1 (Units 1-4)"),
    (35, 64, "Module 2 (Units 5-8)"),
    (65, 96, "Module 3 (Units 9-12)"),
    (97, 123, "Module 4 (Units 13-15)"),
    (124, 999, "Qo'shimcha (lug'at/madaniyat)"),
]
# Workbook coursebook'ga parallel — 80 sahifa, 4 modulga teng taqsimlanadi.
WORKBOOK_BOUNDS: list[tuple[int, int, str]] = [
    (1, 20, "Module 1 (Units 1-4)"),
    (21, 40, "Module 2 (Units 5-8)"),
    (41, 60, "Module 3 (Units 9-12)"),
    (61, 999, "Module 4 (Units 13-15)"),
]


def page_to_module(book: str, page: int) -> str | None:
    """Kitob va sahifa raqamiga qarab haqiqiy modul nomini qaytaradi."""
    if "coursebook" in book:
        bounds = COURSEBOOK_MODULES
    elif "workbook" in book:
        bounds = WORKBOOK_BOUNDS
    else:
        return None  # grammatika kitobi modul tuzilishiga ega emas
    for start, end, name in bounds:
        if start <= page <= end:
            return name
    return None

# ---- Filtrlash sozlamalari ----
# Haqiqiy so'z deb hisoblanishi uchun minimal chastota (0 = OCR shovqini).
MIN_ZIPF = 2.3
# O'ta keng tarqalgan funksional so'zlar (the, is, a...) lug'atga kiritilmaydi.
MAX_ZIPF = 5.3
MIN_LEN = 3
MAX_LEN = 16

# O'rganishga arzimaydigan keng tarqalgan funksional so'zlar.
_FUNCTION = {
    "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
    "her", "was", "one", "our", "out", "his", "has", "had", "him", "how",
    "man", "new", "now", "old", "see", "two", "way", "who", "did", "get",
    "got", "let", "put", "say", "she", "too", "use", "your", "with", "are",
    "this", "that", "they", "them", "then", "than", "have", "from", "what",
    "when", "will", "into", "some", "more", "very", "also", "been", "here",
    "were", "their", "there", "these", "those", "which", "would", "could",
    "about", "after", "again", "being", "they", "the", "and", "for", "yes",
    "no", "not", "him", "she", "his", "its", "our", "are",
}
# Mashq KO'RSATMA so'zlari — kitobda ko'p uchraydi, lekin o'rganish so'zi emas.
_INSTRUCTION = {
    "fill", "read", "write", "complete", "correct", "answer", "answers",
    "question", "questions", "sentence", "sentences", "word", "words",
    "example", "examples", "dialogue", "dialogues", "table", "text", "texts",
    "look", "listen", "choose", "underline", "circle", "match", "tick",
    "box", "boxes", "form", "forms", "order", "verb", "verbs", "following",
    "correct", "missing", "given", "letter", "letters", "exercise", "page",
    "unit", "module", "below", "above", "use", "using", "make", "put",
    "act", "check", "find", "give", "name", "label", "picture", "pictures",
    "number", "numbers", "list", "note", "notes", "part", "section",
    "gap", "gaps", "pair", "pairs", "prompt", "prompts", "picture",
    "pictures", "blank", "blanks", "column", "columns", "row", "rows",
    "phrase", "phrases", "paragraph", "topic", "task", "tasks", "key",
}
# Qisqartma bo'laklari (apostrof OCR'da yo'qolib, "don't" -> "don" bo'lib qoladi).
_CONTRACTIONS = {
    "don", "isn", "didn", "doesn", "wasn", "weren", "won", "aren", "haven",
    "hasn", "hadn", "wouldn", "couldn", "shouldn", "mustn", "needn", "dont",
    "cant", "etc", "ll", "ve", "re", "youre", "theyre", "wont", "didnt",
}
# Coursebook'da uchraydigan keng tarqalgan ismlar (o'rganish so'zi emas).
_NAMES = {
    "tom", "ann", "anna", "paul", "bob", "david", "fergus", "john", "mary",
    "peter", "sam", "kate", "jane", "jack", "bill", "sue", "tim", "mike",
    "gill", "frank", "smith", "jones", "potter", "jackson", "rashid",
    "gillian", "mortimer", "helen", "george", "linda", "tony", "susan",
}
STOPWORDS: set[str] = _FUNCTION | _INSTRUCTION | _CONTRACTIONS | _NAMES


def looks_like_real(word: str) -> bool:
    """So'z OCR shovqini emasligini tekshiradi (unli+undosh, takror yo'q)."""
    if not re.fullmatch(r"[a-z]+", word):
        return False
    if not (set(word) & set("aeiou")):       # unlisiz -> shovqin
        return False
    if not (set(word) - set("aeiou")):        # undoshsiz -> shovqin (eee)
        return False
    if re.search(r"(.)\1\1", word):           # 3 marta takror harf -> shovqin
        return False
    return True

# So'z yasalishi uchun DERIVATSION qo'shimchalar (grammatik s/ed/ing emas).
SUFFIXES = ["ful", "less", "ness", "ment", "tion", "sion", "able", "ible",
            "ly", "er", "or", "ist", "ism", "ity", "ous", "ive", "al"]
PREFIXES = ["un", "in", "im", "dis", "re", "non", "mis", "over", "under"]


# ---------- Tiplar ----------
class VocabItem(TypedDict):
    id: str
    en: str
    uz: str
    example: str
    pos: str
    freq: float
    module: str


class WordFormItem(TypedDict):
    id: str
    base: str
    uz: str
    forms: list[str]
    module: str


class GrammarItem(TypedDict):
    id: str
    topic: str
    rule_text: str
    examples: list[str]
    module: str


# ---------- Tarjima keshi ----------
class TranslationCache:
    """Inglizcha->o'zbekcha tarjimalarni keshlovchi yordamchi.

    Tarjimalar diskda saqlanadi, shuning uchun jarayon to'xtab qolsa ham
    qayta ishga tushganda allaqachon tarjima qilinganlar qayta so'ralmaydi.
    """

    def __init__(self, path: Path) -> None:
        self.path = path
        self.data: dict[str, str] = {}
        if path.exists():
            self.data = json.loads(path.read_text(encoding="utf-8"))
        self._translator = GoogleTranslator(
            source=config.TRANSLATE_SOURCE, target=config.TRANSLATE_TARGET
        )

    def translate(self, word: str) -> str:
        """So'zni tarjima qiladi (keshdan yoki onlayn). Xato bo'lsa bo'sh."""
        key = word.lower().strip()
        if key in self.data:
            return self.data[key]
        try:
            result = self._translator.translate(key) or ""
        except Exception:
            result = ""
            time.sleep(1.0)  # tezlik chekloviga uchrasak, biroz kutamiz
        self.data[key] = result
        return result

    def save(self) -> None:
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8"
        )


# ---------- Yordamchi funksiyalar ----------
def load_pages(book: str) -> list[dict]:
    """Bitta kitobning ajratilgan sahifalarini yuklaydi."""
    path = config.PARSED_DIR / f"{book}.json"
    return json.loads(path.read_text(encoding="utf-8"))["pages"]


def all_books() -> list[str]:
    """data/parsed/ ichidagi barcha kitob nomlarini qaytaradi."""
    return sorted(p.stem for p in config.PARSED_DIR.glob("*.json")
                  if not p.stem.startswith("_") and p.stem != "structured")


def tokenize(text: str) -> list[str]:
    """Matndan faqat harfli so'zlarni ajratadi (kichik harfda)."""
    return re.findall(r"[a-zA-Z]+", text.lower())


def is_real_word(word: str) -> bool:
    """So'z haqiqiy (OCR shovqini emas) va o'rganishga arzigulimi?"""
    if not (MIN_LEN <= len(word) <= MAX_LEN):
        return False
    if word in STOPWORDS:
        return False
    if not looks_like_real(word):
        return False
    z = zipf_frequency(word, "en")
    return MIN_ZIPF <= z <= MAX_ZIPF


def guess_pos(word: str) -> str:
    """Qo'shimchaga qarab so'z turkumini taxmin qiladi (o'zbekcha)."""
    if word.endswith("ly"):
        return "ravish"          # adverb
    if word.endswith(("tion", "sion", "ment", "ness", "ity", "ism", "ist")):
        return "ot"              # noun
    if word.endswith(("ous", "ful", "less", "able", "ible", "ive", "al")):
        return "sifat"           # adjective
    if word.endswith(("ize", "ise", "ate", "ify")):
        return "fe'l"            # verb
    return "—"


def is_clean_sentence(line: str, word: str) -> bool:
    """Gap "toza" (OCR shovqini emas) va o'rganishga yaroqlimi?

    Mezonlar: mos uzunlik, asosan harf/tinish, va so'zlarning ko'pi haqiqiy
    (lug'atda bor) bo'lishi kerak.
    """
    line = line.strip()
    if not (12 <= len(line) <= 110):
        return False
    # Asosan harf, bo'sh joy va oddiy tinish belgilaridan iborat bo'lsin.
    good = sum(c.isalpha() or c.isspace() or c in ".,!?'’-" for c in line)
    if good / len(line) < 0.9:
        return False
    tokens = re.findall(r"[a-zA-Z]+", line.lower())
    if len(tokens) < 3:
        return False
    # So'z gapda bo'lsin.
    if word.lower() not in tokens:
        return False
    # Tokenlarning kamida 75% i haqiqiy inglizcha so'z bo'lsin (shovqin emas).
    real = sum(1 for t in tokens if zipf_frequency(t, "en") > 2.0 or len(t) <= 3)
    return real / len(tokens) >= 0.75


def find_clean_example(word: str, lines_by_word: dict[str, list[str]]) -> str:
    """So'z uchun kitobdagi eng toza misol gapni qaytaradi (bo'lmasa bo'sh)."""
    for line in lines_by_word.get(word, []):
        if is_clean_sentence(line, word):
            return re.sub(r"\s+", " ", line).strip()
    return ""


class ExampleCache:
    """Tatoeba'dan toza misol gaplarni olib keshlovchi yordamchi."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.data: dict[str, str] = {}
        if path.exists():
            self.data = json.loads(path.read_text(encoding="utf-8"))

    def fetch(self, word: str) -> str:
        """Tatoeba'dan so'zga mos toza inglizcha gap (keshdan yoki onlayn)."""
        key = word.lower()
        if key in self.data:
            return self.data[key]
        sentence = ""
        try:
            q = urllib.parse.quote(word)
            url = (f"https://tatoeba.org/en/api_v0/search?from=eng"
                   f"&query={q}&sort=relevance")
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            data = json.load(urllib.request.urlopen(req, timeout=15))
            for r in data.get("results", []):
                text = r.get("text", "").strip()
                if is_clean_sentence(text, word) and len(text) <= 90:
                    sentence = text
                    break
        except Exception:
            time.sleep(0.5)
        self.data[key] = sentence
        return sentence

    def save(self) -> None:
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8"
        )


# ---------- Asosiy ajratuvchilar ----------
def extract_vocabulary(
    books: list[str], cache: TranslationCache, examples: ExampleCache,
    max_vocab: int,
) -> list[VocabItem]:
    """Barcha kitoblardan haqiqiy so'zlarni ajratib, lug'at tuzadi.

    Har bir so'z uchun: kitobdagi birinchi uchragan sahifa (modulni aniqlash),
    misol gaplar va uchrash soni saqlanadi.
    """
    counts: dict[str, int] = {}
    first_loc: dict[str, tuple[str, int]] = {}     # so'z -> (kitob, sahifa)
    lines_by_word: dict[str, list[str]] = {}       # so'z -> misol uchun qatorlar

    for book in books:
        for page in load_pages(book):
            for tok in set(tokenize(page["text"])):
                if not is_real_word(tok):
                    continue
                counts[tok] = counts.get(tok, 0) + 1
                # Birinchi uchragan joyni (coursebook ustun) eslab qolamiz.
                if tok not in first_loc or (
                    "coursebook" in book and "coursebook" not in first_loc[tok][0]
                ):
                    first_loc[tok] = (book, page["page"])
            # Misol gaplar uchun qatorlarni yig'amiz.
            for line in page["text"].splitlines():
                for tok in set(tokenize(line)):
                    if tok in counts or is_real_word(tok):
                        lines_by_word.setdefault(tok, [])
                        if len(lines_by_word[tok]) < 8:
                            lines_by_word[tok].append(line)

    # Kitobda ko'p uchragan + o'rtacha qiyinlikdagi so'zlarni oldinga qo'yamiz.
    ranked = sorted(
        counts.keys(),
        key=lambda w: (counts[w], -zipf_frequency(w, "en")),
        reverse=True,
    )
    selected = ranked[:max_vocab]

    items: list[VocabItem] = []
    for i, word in enumerate(selected, start=1):
        uz = cache.translate(word)
        book, page = first_loc.get(word, (books[0], 1))
        module = page_to_module(book, page) or "Qo'shimcha (lug'at/madaniyat)"

        # Misol: avval kitobdagi TOZA gap, bo'lmasa Tatoeba zaxirasi.
        example = find_clean_example(word, lines_by_word)
        if not example:
            example = examples.fetch(word)

        items.append(VocabItem(
            id=f"vocab-{i:04d}",
            en=word,
            uz=uz,
            example=example,
            pos=guess_pos(word),
            freq=round(zipf_frequency(word, "en"), 2),
            module=module,
        ))
        if i % 20 == 0:
            print(f"    lug'at: {i}/{len(selected)} ...", end="\r")
            cache.save()
            examples.save()
    print()
    examples.save()
    return items


def extract_word_formation(
    vocab: list[VocabItem], cache: TranslationCache, limit: int = 150
) -> list[WordFormItem]:
    """Lug'atdan so'z oilalarini (base + hosilalar) aniqlaydi."""
    vocab_words = {v["en"] for v in vocab}
    families: list[WordFormItem] = []
    seen_bases: set[str] = set()

    for word in sorted(vocab_words):
        base = word
        if base in seen_bases:
            continue
        # Asos so'z ishonchli bo'lishi kerak: yetarlicha keng tarqalgan va
        # o'zi hosila/grammatik shakl bo'lmasligi (‑ing, ‑ed, ‑s bilan tugamasligi).
        if zipf_frequency(base, "en") < 3.0:
            continue
        if base.endswith(("ing", "ed", "ly", "tion", " ")):
            continue
        forms = generate_forms(base)
        # Faqat haqiqiy va yetarlicha tanilgan hosila shakllarni qoldiramiz.
        real_forms = [f for f in forms
                      if f != base and zipf_frequency(f, "en") > 2.5]
        if len(real_forms) >= 2:
            seen_bases.add(base)
            families.append(WordFormItem(
                id=f"wf-{len(families) + 1:04d}",
                base=base,
                uz=cache.translate(base),
                forms=real_forms[:6],
                module="So'z yasalishi",
            ))
        if len(families) >= limit:
            break
    return families


def generate_forms(base: str) -> list[str]:
    """Asos so'zdan mumkin bo'lgan hosila shakllarni hosil qiladi."""
    forms: set[str] = set()
    for suf in SUFFIXES:
        forms.add(base + suf)
        if base.endswith("e"):
            forms.add(base[:-1] + suf)  # make -> making
        if base.endswith("y"):
            forms.add(base[:-1] + "i" + suf)  # happy -> happiness
    for pre in PREFIXES:
        forms.add(pre + base)
    return list(forms)


# Grammatika kalit so'zlari -> kanonik (toza) mavzu nomi.
# OCR sarlavhasida kalit topilsa, toza nom ishlatiladi (takrorlar birlashadi).
GRAMMAR_TOPICS: list[tuple[str, str]] = [
    ("subject pronoun", "Subject Pronouns"),
    ("object pronoun", "Object Pronouns"),
    ("possessive", "Possessives (Possessive Case)"),
    ("verb to be", "The Verb 'to be'"),
    ("have got", "Have got"),
    ("present perfect", "Present Perfect"),
    ("present continuous", "Present Continuous"),
    ("present simple", "Present Simple"),
    ("past continuous", "Past Continuous"),
    ("past simple", "Past Simple"),
    ("going to", "Future: be going to"),
    ("will", "Future: will"),
    ("comparative", "Comparatives & Superlatives"),
    ("superlative", "Comparatives & Superlatives"),
    ("indefinite article", "Articles: a / an"),
    ("a/an", "Articles: a / an"),
    ("demonstrative", "Demonstratives: this/that/these/those"),
    ("plural", "Plurals"),
    ("preposition", "Prepositions"),
    ("there is", "There is / There are"),
    ("there are", "There is / There are"),
    ("imperative", "Imperative"),
    ("countable", "Countable & Uncountable Nouns"),
    ("uncountable", "Countable & Uncountable Nouns"),
    ("some any", "some / any"),
    ("much many", "much / many"),
    ("modal", "Modal Verbs"),
    ("question word", "Question Words"),
    ("can", "Can (ability)"),
]


# Grammatika mavzusi -> haqiqiy modul (mundarijaga ko'ra).
_M1, _M2, _M3, _M4 = (
    "Module 1 (Units 1-4)", "Module 2 (Units 5-8)",
    "Module 3 (Units 9-12)", "Module 4 (Units 13-15)",
)
GRAMMAR_MODULE: dict[str, str] = {
    "Subject Pronouns": _M1, "Object Pronouns": _M1,
    "The Verb 'to be'": _M1, "Articles: a / an": _M1, "Have got": _M1,
    "Can (ability)": _M1, "There is / There are": _M1,
    "Demonstratives: this/that/these/those": _M1, "Plurals": _M1,
    "Prepositions": _M1, "Possessives (Possessive Case)": _M1,
    "Present Simple": _M1,
    "Present Continuous": _M2, "Countable & Uncountable Nouns": _M2,
    "some / any": _M2, "much / many": _M2, "Imperative": _M2,
    "Past Simple": _M3, "Past Continuous": _M3,
    "Comparatives & Superlatives": _M3,
    "Future: be going to": _M4, "Future: will": _M4,
    "Modal Verbs": _M4, "Question Words": _M4,
}


def extract_grammar(book: str = "Enterprise_1_grammar") -> list[GrammarItem]:
    """Grammatika kitobidagi mavzu sarlavhalari va qoida matnini ajratadi."""
    try:
        pages = load_pages(book)
    except FileNotFoundError:
        return []

    items: list[GrammarItem] = []
    seen: set[str] = set()
    for page in pages:
        lines = [ln.strip() for ln in page["text"].splitlines() if ln.strip()]
        if not lines:
            continue
        # Sarlavha odatda dastlabki 2 qatorda bo'ladi.
        header = " ".join(lines[:2]).lower()
        canonical = None
        for kw, name in GRAMMAR_TOPICS:
            if kw in header:
                canonical = name
                break
        if not canonical or canonical in seen:
            continue
        seen.add(canonical)
        # Qoida va misollarni TOZA (qo'lda yozilgan) manbadan olamiz —
        # OCR shovqinli bo'lgani uchun. Topilmasa, mavzu o'tkazib yuboriladi.
        rule = GRAMMAR_RULES.get(canonical)
        if not rule:
            continue
        items.append(GrammarItem(
            id=f"gr-{len(items) + 1:03d}",
            topic=canonical,
            rule_text=rule["rule_uz"],
            examples=rule["examples"],
            module=GRAMMAR_MODULE.get(canonical, "Module 1 (Units 1-4)"),
        ))
    return items


# ---------- Yig'ish va saqlash ----------
def build_structured(max_vocab: int) -> dict:
    """Hamma narsani yig'ib, structured.json uchun lug'at qaytaradi."""
    config.ensure_dirs()
    books = all_books()
    if not books:
        raise FileNotFoundError(
            "data/parsed/ da kitob topilmadi. Avval `python -m ingest.pdf_extract` ni ishga tushiring."
        )
    print(f"[+] Kitoblar: {', '.join(books)}")

    cache = TranslationCache(config.PARSED_DIR / "_translations.json")
    examples = ExampleCache(config.PARSED_DIR / "_examples.json")

    print("[1/3] Lug'at ajratilmoqda, tarjima va misollar tayyorlanmoqda ...")
    vocabulary = extract_vocabulary(books, cache, examples, max_vocab)
    cache.save()
    examples.save()

    print("[2/3] So'z yasalishi (so'z oilalari) aniqlanmoqda ...")
    word_formation = extract_word_formation(vocabulary, cache)
    cache.save()

    print("[3/3] Grammatika mavzulari ajratilmoqda ...")
    grammar = extract_grammar()

    # Modullar ro'yxati (dashboard uchun guruhlash).
    module_names: list[str] = []
    for coll in (vocabulary, word_formation, grammar):
        for it in coll:
            if it["module"] not in module_names:
                module_names.append(it["module"])

    return {
        "source_books": books,
        "counts": {
            "vocabulary": len(vocabulary),
            "word_formation": len(word_formation),
            "grammar": len(grammar),
        },
        "modules": module_names,
        "vocabulary": vocabulary,
        "word_formation": word_formation,
        "grammar": grammar,
    }


def validate(structured: dict) -> None:
    """Saqlashdan oldin JSON tuzilishini tekshiradi."""
    assert structured["vocabulary"], "Lug'at bo'sh — OCR yoki filtr muammosi"
    for v in structured["vocabulary"]:
        assert v["en"] and v["id"], "Lug'at elementi to'liq emas"
    # JSON seriyalashtirilishini tekshiramiz.
    json.dumps(structured, ensure_ascii=False)


def main() -> None:
    ap = argparse.ArgumentParser(description="OCR matnini tuzilgan JSON ga aylantirish")
    ap.add_argument("--max-vocab", type=int, default=400,
                    help="Maksimal lug'at so'zlari soni (standart 400)")
    args = ap.parse_args()

    structured = build_structured(args.max_vocab)
    validate(structured)
    config.STRUCTURED_JSON.write_text(
        json.dumps(structured, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    c = structured["counts"]
    print("\n=== Yakun ===")
    print(f"  Lug'at:         {c['vocabulary']}")
    print(f"  So'z yasalishi: {c['word_formation']}")
    print(f"  Grammatika:     {c['grammar']}")
    print(f"  Saqlandi -> {config.STRUCTURED_JSON}")


if __name__ == "__main__":
    main()
