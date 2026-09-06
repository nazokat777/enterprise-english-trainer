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

from ingest.export_pages import KNOWN_TYPES

TRAINER = Path(__file__).resolve().parent.parent
PAGES = TRAINER / "data" / "pages"
ASSETS = TRAINER.parent / "enterprise-app" / "assets" / "content" / "enterprise1"
APP_LIB = TRAINER.parent / "enterprise-app" / "lib"

# Bandlar shu maydonlarning birida bo'lishi mumkin.
ITEM_KEYS = (
    "items", "answers", "pairs", "lines", "profiles", "rows", "sentences",
    "words", "questions", "pictureLabels", "scenes", "modelSentences",
    "modelAnswers", "dialogues", "texts", "structure", "example",
    "sentenceEn", "table", "points",
)

UZ_IN_SPEECH = re.compile(
    r"(qator|to'ldir|tanlang|yozing|tuzing|qarang|Rasm |Matn |bo'yicha"
    r"|Namuna|toping|shakl|-bet|-o'rin)"
)


def count_answers(node) -> int:
    """Manba mashqidagi javobli bo'shliqlar soni.

    `given: true` belgilangan tugun butunlay o'tkazib yuboriladi — u kitobda
    tayyor namuna, o'quvchi uni bajarmaydi.
    """
    if isinstance(node, list):
        return sum(count_answers(x) for x in node)
    if not isinstance(node, dict):
        return 0
    if node.get("given"):
        return 0
    n = 0
    if node.get("answers"):
        n += len(node["answers"])
    elif node.get("answer"):
        n += 1
    for k, v in node.items():
        if k in ("answer", "answers"):
            continue
        n += count_answers(v)
    return n


def check_losses() -> list[tuple[str, str]]:
    """Manbadagi javoblar eksportga TO'LIQ chiqqanini tekshiradi.

    Bu tekshiruv 15c-mashqda 12 ta predlog bandi jimgina yo'qolganini
    topgan: eksportyor bir qatordagi bir nechta bo'shliqni bilmagan edi.
    """
    out = []
    exported: dict[tuple, int] = {}
    for f in sorted(ASSETS.glob("unit_*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d["sections"]:
            for e in s["exercises"]:
                key = (e["book"], e["bookPage"], str(e["ref"]))
                n = len(e["tasks"])
                # Javobi kitobda YO'Q bandlar o'yindan chiqarilib, mashq
                # izohiga ro'yxat qilib ko'chiriladi. Ular yo'qolgan emas —
                # shuning uchun hisobga qo'shiladi.
                n += (e.get("explanationUz") or "").count(chr(10) + "  * ")
                exported[key] = exported.get(key, 0) + n

    for f in sorted(PAGES.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d.get("sections", []):
            for e in s.get("exercises", []):
                want = count_answers(e)
                if not want:
                    continue
                key = (d["book"], d["bookPage"], str(e.get("ref", "")))
                got = exported.get(key, 0)
                if got < want:
                    out.append((
                        f"{d['book']} {d['bookPage']}-bet Ex.{e.get('ref')}",
                        f"manbada {want} javob, eksportda {got} — "
                        f"{want - got} tasi YO'QOLDI",
                    ))
    return out


def check_pages() -> list[tuple[str, str]]:
    """Bet raqamlarini tekshiradi: takror va raqamsiz betlar.

    Kitobda RAQAMLANMAGAN betlar bor (modul muqovasi). Ular
    `bookPage: 0` va `bookPageLabel` bilan belgilanadi. Raqamli bet
    ikki marta uchrasa — bu xato (bir bet ikki faylga yozilgan).
    """
    out = []
    seen: dict[tuple, str] = {}
    for f in sorted(PAGES.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        book, bp = d.get("book"), d.get("bookPage")
        if not bp:
            if not d.get("bookPageLabel"):
                out.append((f.name, "bet raqami yo'q, lekin bookPageLabel "
                                    "ham berilmagan"))
            continue
        key = (book, bp)
        if key in seen:
            out.append((f.name, f"{book} {bp}-bet allaqachon "
                                f"{seen[key]} da bor"))
        seen[key] = f.name
    return out


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
                # Eksportyor tanimaydigan tur = bandlar jimgina yo'qoladi.
                if e.get("type") and e["type"] not in KNOWN_TYPES:
                    out.append((tag, f"Ex.{ref}: eksportyor '{e['type']}' "
                                     f"turini bilmaydi — bandlar yo'qoladi"))

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

                # Moslash o'yinida bir xil O'NG tomon ikki marta uchrasa,
                # o'yin yechib bo'lmaydi: o'quvchi ikkita bir xil yozuvdan
                # qaysinisini bosishni bilolmaydi. Eksportyor bunday mashqni
                # "choice" ga aylantirishi kerak — bu yerga yetib kelsa, xato.
                if e["kind"] == "match":
                    rights = [t.get("right") for t in e["tasks"]]
                    dup = {r for r in rights if r and rights.count(r) > 1}
                    for r in sorted(dup):
                        out.append(
                            (loc, f"moslashda '{r}' ikki marta — o'yin yechilmaydi")
                        )
                # Moslashda chap va o'ng bir xil bo'lsa, o'quvchi
                # o'ylamasdan bosadi — mashq hech nima o'rgatmaydi.
                if e["kind"] == "match" and len(e["tasks"]) < 2:
                    out.append((loc, "moslashda bitta juft — tanlov yo'q"))

                seen_tasks: dict[tuple[str, str], int] = {}
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
                    # Manbada bo'sh (null) maydon savolga aylanib qolmasin:
                    # ekranda "None" so'zi chiqadi va ovoz uni o'qib beradi.
                    for name, val in (("savol", prompt), ("javob", t.get("answer") or ""),
                                      ("ovoz", speak)):
                        if val.strip() in ("None", "null"):
                            out.append((loc, f"b{i}: {name} — bo'sh maydon ('{val}')"))
                    if speak and UZ_IN_SPEECH.search(speak):
                        out.append((loc, f"b{i}: o'zbekcha matn ovozga berilyapti"))
                    if e["kind"] in ("choice", "text") and not prompt:
                        out.append((loc, f"b{i}: savol matni bo'sh"))
                    # Dialog qatorida gapiruvchi bo'sh bo'lsa, savol
                    # ": No, he ___ ." ko'rinishida chiqib qolardi.
                    if prompt.startswith(":") or prompt.startswith(" :"):
                        out.append((loc, f"b{i}: savol ':' bilan boshlanyapti"))
                    # O'qish bandi bo'sh bo'lsa — ekranda hech nima
                    # ko'rinmaydi. Bu jimgina kontent yo'qotish demak.
                    if e["kind"] == "study" and not (t.get("en") or "").strip():
                        out.append((loc, f"b{i}: o'qish matni bo'sh"))
                    # O'qish kartochkasi boshlang'ich darajadagi o'zbek
                    # o'quvchisiga MO'LJALLANGAN. Faqat inglizcha gap
                    # ko'rsatilsa, u tushunarsiz qoladi — bu jimgina
                    # kontent yo'qotish (441 band shunday bo'lgan edi).
                    # Istisno: matnning O'ZI o'zbekcha — ⚠ bilan
                    # boshlanadigan ogohlantirishlar (javob faqat audioda).
                    en_txt = (t.get("en") or "").strip()
                    if (e["kind"] == "study" and en_txt
                            and not en_txt.startswith("⚠")
                            and not (t.get("uz") or "").strip()
                            and not UZ_IN_SPEECH.search(en_txt)):
                        out.append((loc, f"b{i}: o'qish matni o'zbekcha tarjimasiz"))
                    # `answerUz` javobning o'zbekchasi — o'yin rejimida
                    # ko'rinsa, javobni oshkor qiladi.
                    if t.get("answerUz"):
                        out.append((loc, f"b{i}: answerUz o'yinga sizib chiqqan"))

                    # Javob savol matnining ICHIDA turgan bo'lsa, mashq
                    # soxta: o'quvchi javobni o'ylamasdan ko'chiradi.
                    if ans and len(ans) > 2 and e["kind"] in ("choice", "text"):
                        if re.search(rf"{re.escape(ans)}", prompt, re.I):
                            out.append((loc, f"b{i}: javob savolda ko'rinib turibdi"))

                    # Moslashda chap = o'ng: juftlik o'z-o'zidan ravshan.
                    #
                    # Kitob oxiridagi LUG'AT ro'yxatlari (unit >= 900)
                    # bundan mustasno: u yerda "park", "bank", "opera"
                    # kabi o'zlashma so'zlar bor va ularning o'zbekchasi
                    # ROSTDAN ham inglizchasi bilan bir xil. Buni
                    # o'zgartirish kitobni buzish bo'lardi.
                    if e["kind"] == "match" and d["unit"] < 900:
                        lf = (t.get("left") or "").strip().lower()
                        rt = (t.get("right") or "").strip().lower()
                        if lf and lf == rt:
                            out.append((loc, f"b{i}: moslashda chap = o'ng"))

                    # Bir xil savol+javob ikki marta — vaqtni oladi,
                    # yangi narsa o'rgatmaydi.
                    if prompt:
                        key = (prompt.lower(), ans)
                        if key in seen_tasks:
                            out.append(
                                (loc, f"b{i}: b{seen_tasks[key]} bilan bir xil")
                            )
                        else:
                            seen_tasks[key] = i
    return out


# Manbada kontent saqlanadigan ro'yxat maydonlari. Eksportyor bir mashqning
# faqat BIR xil yozilishini bilsa, boshqa yozilishdagi kontent jimgina
# yo'qoladi — "Words of Wisdom" mashqlarida shunday bo'lgan: uch betdagi
# 10 ta maqol ilovaga umuman chiqmagan va hech qanday tekshiruv buni
# ko'rmagan, chunki ular `answer` maydonida emas edi.
CONTENT_LISTS = (
    "items", "points", "pairs", "lines", "sentences", "profiles", "scenes",
    "answers", "questions", "people", "modelSentences", "structure",
    "groups", "patterns", "rows", "words",
)


def check_content_units() -> list[tuple[str, str]]:
    """Manbada bir necha band bor, eksportda esa deyarli hech nima."""
    out = []
    exported: dict[tuple, int] = {}
    for f in sorted(ASSETS.glob("unit_*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d["sections"]:
            for e in s["exercises"]:
                key = (e["book"], e["bookPage"], str(e["ref"]))
                exported[key] = exported.get(key, 0) + len(e["tasks"])

    for f in sorted(PAGES.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d.get("sections", []):
            for e in s.get("exercises", []):
                n = 0
                for k in CONTENT_LISTS:
                    v = e.get(k)
                    if isinstance(v, list):
                        n += sum(
                            1 for x in v
                            if not (isinstance(x, dict) and x.get("given"))
                        )
                if n < 2:
                    continue
                key = (d["book"], d["bookPage"], str(e.get("ref", "")))
                if exported.get(key, 0) <= 1:
                    out.append((
                        f"{d['book']} {d['bookPage']}-bet Ex.{e.get('ref')}",
                        f"manbada {n} ta band, eksportda "
                        f"{exported.get(key, 0)} — kontent yo'qolgan",
                    ))
    return out


# Ilovada HECH QAYERDA o'qilmaydigan maydonlar — ular eksportda bor,
# lekin o'quvchi ularni KO'RMAYDI. Aynan shu sabab bilan `scanNote`,
# `negLong`, `examplesUz`, `noteEn` va `listEn` jimgina yo'qolgan edi.
#
# Ataylab tashlanadigan texnik maydonlar (ilova ularni o'qishi shart emas):
IGNORED_KEYS = {
    "book", "bookPage", "bookRef", "ref", "id", "order", "isExtra",
    "module", "unit", "label", "badge", "audio",
}


def check_unused_keys() -> list[tuple[str, str]]:
    """Eksportdagi har bir maydon Flutter kodida o'qiladimi."""
    src = ""
    for f in sorted(APP_LIB.rglob("*.dart")):
        src += f.read_text(encoding="utf-8")

    keys: set[str] = set()

    def walk(o) -> None:
        if isinstance(o, dict):
            for k, v in o.items():
                keys.add(k)
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    for f in sorted(ASSETS.glob("*.json")):
        walk(json.loads(f.read_text(encoding="utf-8")))

    out = []
    for k in sorted(keys - IGNORED_KEYS):
        if f"'{k}'" not in src and f'"{k}"' not in src:
            out.append((k, "eksportda bor, ilovada O'QILMAYDI — ko'rinmaydi"))
    return out


def audio_open_items() -> list[tuple[str, int]]:
    """Audio bo'lmagani uchun OChIQ qolgan bandlarni sanaydi.

    Bu son `enterprise-app/assets/audio/README.md` dagi jadval bilan mos
    bo'lishi kerak. Ilgari README eskirib qolgan edi: unda 33 band deb
    yozilgan, aslida 15 ta edi. Endi son har eksportda qayta sanaladi.
    """
    marker = "⚠"
    out: list[tuple[str, int]] = []
    for f in sorted(ASSETS.glob("unit_*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d["sections"]:
            for e in s["exercises"]:
                n = 0
                for line in (e.get("explanationUz") or "").splitlines():
                    if line.startswith("  * ") and marker in line:
                        n += 1
                for t in e["tasks"]:
                    for fld in ("answer", "en", "right"):
                        v = t.get(fld)
                        if (isinstance(v, str) and v.strip().startswith(marker)
                                and "AUDIO" in v.upper()):
                            n += 1
                if n:
                    out.append((f"{e['book']} {e['bookPage']}b Ex.{e['ref']}", n))
    return out


def main() -> int:
    src = check_sources()
    exp = check_export()
    lost = check_losses() + check_content_units()
    unused = check_unused_keys()
    pages = check_pages()

    print("=== MANBA SAHIFALARI ===")
    for tag, msg in src:
        print(f"  {tag:24s} {msg}")
    print("  muammo yo'q" if not src else f"  jami: {len(src)}")

    print("\n=== BET RAQAMLARI ===")
    for tag, msg in pages:
        print(f"  {tag:24s} {msg}")
    print("  muammo yo'q" if not pages else f"  jami: {len(pages)}")

    print("\n=== YO'QOLGAN KONTENT (manba -> eksport) ===")
    for tag, msg in lost:
        print(f"  {tag:30s} {msg}")
    print("  muammo yo'q" if not lost else f"  jami: {len(lost)}")

    print("\n=== EKSPORT (o'quvchi ko'radigan) ===")
    for loc, msg in exp:
        print(f"  {loc:30s} {msg}")
    print("  muammo yo'q" if not exp else f"  jami: {len(exp)}")

    print("\n=== ILOVADA O'QILMAYDIGAN MAYDONLAR ===")
    for k, msg in unused:
        print(f"  {k:24s} {msg}")
    print("  muammo yo'q" if not unused else f"  jami: {len(unused)}")

    audio = audio_open_items()
    print("\n=== AUDIO KUTAYOTGAN OCHIQ BANDLAR (xato emas) ===")
    for loc, n in audio:
        print(f"  {loc:30s} {n} band")
    print(f"  jami: {sum(n for _, n in audio)} band, {len(audio)} mashqda")

    total = len(src) + len(exp) + len(lost) + len(pages) + len(unused)
    print(f"\n{'TOZA' if total == 0 else f'JAMI MUAMMO: {total}'}")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
