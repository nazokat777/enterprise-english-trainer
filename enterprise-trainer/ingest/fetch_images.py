"""Wikimedia Commons'dan ERKIN LITSENZIYALI rasmlarni yuklaydi.

Nega kerak: kitobdagi rasmlar mualliflik huquqi bilan himoyalangan va
ularni ko'chirib bo'lmaydi. Lekin ba'zi mashqlar rasmsiz ma'nosiz
("Bu odamlar qaysi mamlakatdan?"). Yechim — Commons'dagi erkin rasmlar.

MUHIM: faqat quyidagi litsenziyalar qabul qilinadi. Wikipedia'dagi
"fair use" fayllari (wikipedia/en/ yo'lidagilar) OLINMAYDI.

Ishlatish:
    python -m ingest.fetch_images
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

TRAINER = Path(__file__).resolve().parent.parent
OUT = TRAINER.parent / "enterprise-app" / "assets" / "images" / "unit1"
CREDITS = TRAINER.parent / "enterprise-app" / "assets" / "images" / "CREDITS.json"

UA = "EnterpriseEnglishTrainer/1.0 (educational, non-commercial)"
API = "https://commons.wikimedia.org/w/api.php"

# Qabul qilinadigan litsenziyalar (erkin foydalanish).
OK_LICENCE = re.compile(
    r"(public domain|cc0|cc[ -]by([ -]sa)?([ -][0-9.]+)?)", re.I
)

# id -> Commons qidiruv so'rovi.
# id sahifa JSON'laridagi `image` maydoniga mos keladi.
WANTED = {
    # Unit 1, Ex.1 — kiyim/madaniyat bo'yicha mamlakatni topish
    "u1-people-brazil": "agricultura familiar Brasil trabalhador rural",
    "u1-people-india": "Rajasthani woman traditional dress India",
    "u1-people-spain": "flamenco dress traditional Spain dancer",
    "u1-people-scotland": "Scottish bagpiper kilt piper",
    # Unit 1, Ex.9 — poytaxtlar (rasm mamlakatga ishora)
    "u1-cap-egypt": "Great Sphinx of Giza",
    "u1-cap-france": "Arc de Triomphe Paris",
    "u1-cap-italy": "Colosseum Rome",
    "u1-cap-poland": "Warsaw Old Town market square",
    "u1-cap-hungary": "Hungarian Parliament Building Budapest",
    "u1-cap-russia": "Moscow Kremlin",
    "u1-cap-china": "Forbidden City Beijing",
    # Unit 1, Ex.14 — mashhur joylar
    "u1-lm-pyramids": "Pyramids of Giza",
    "u1-lm-tajmahal": "Taj Mahal",
    "u1-lm-bigben": "Big Ben Elizabeth Tower London",
    "u1-lm-eiffel": "Tour Eiffel Wikimedia Commons",
    "u1-lm-parthenon": "Parthenon Athens Acropolis",
    "u1-lm-whitehouse": "White House Washington north facade",
    "u1-lm-stbasil": "Saint Basil's Cathedral Moscow",
    "u1-lm-sydney": "Sydney Opera House",
    "u1-lm-liberty": "Statue of Liberty New York",
}


def _get(url: str, tries: int = 4) -> bytes:
    """Commons tezlik chekloviga (429) uchrasa, kutib qayta uriniladi."""
    delay = 3.0
    last = None
    for _ in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=45) as r:
                return r.read()
        except urllib.error.HTTPError as e:  # noqa: PERF203
            last = e
            if e.code != 429:
                raise
            time.sleep(delay)
            delay *= 2
    raise last if last else RuntimeError("yuklab bo'lmadi")


def _strip(html: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html or "")).strip()


def search(query: str, width: int = 800):
    """Commons'dan erkin litsenziyali birinchi mos rasmni topadi."""
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": f"filetype:bitmap {query}",
        "gsrlimit": "8",
        "gsrnamespace": "6",
        "prop": "imageinfo",
        "iiprop": "url|extmetadata|size",
        "iiurlwidth": str(width),
        "format": "json",
    }
    data = json.loads(_get(f"{API}?{urllib.parse.urlencode(params)}"))
    pages = (data.get("query") or {}).get("pages") or {}
    # Qidiruv tartibini saqlaymiz.
    ordered = sorted(pages.values(), key=lambda p: p.get("index", 99))
    for p in ordered:
        info = (p.get("imageinfo") or [{}])[0]
        md = info.get("extmetadata") or {}
        licence = (md.get("LicenseShortName") or {}).get("value", "")
        if not OK_LICENCE.search(licence):
            continue
        url = info.get("thumburl") or info.get("url")
        if not url or "/wikipedia/commons/" not in url:
            continue  # Commons'da bo'lmagan (fair-use) fayllar rad etiladi
        return {
            "file": p.get("title", ""),
            "url": url,
            "licence": licence,
            "author": _strip((md.get("Artist") or {}).get("value", ""))[:120],
            "descriptionUrl": info.get("descriptionurl", ""),
        }
    return None


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    credits = {}
    if CREDITS.exists():
        credits = json.loads(CREDITS.read_text(encoding="utf-8"))

    ok = skipped = failed = 0
    for key, query in WANTED.items():
        dest = OUT / f"{key}.jpg"
        if dest.exists() and key in credits:
            skipped += 1
            continue
        try:
            hit = search(query)
            if not hit:
                print(f"  [-] {key}: erkin litsenziyali rasm topilmadi")
                failed += 1
                continue
            dest.write_bytes(_get(hit["url"]))
            credits[key] = {
                "asset": f"assets/images/unit1/{key}.jpg",
                "query": query,
                **hit,
            }
            size_kb = dest.stat().st_size // 1024
            print(f"  [+] {key}: {size_kb} KB | {hit['licence']} | {hit['author'][:34]}")
            ok += 1
            time.sleep(1.6)  # Commons tezlik chekloviga hurmat
        except Exception as e:  # noqa: BLE001
            print(f"  [!] {key}: {type(e).__name__}: {e}")
            failed += 1

    CREDITS.parent.mkdir(parents=True, exist_ok=True)
    CREDITS.write_text(
        json.dumps(credits, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(f"\nYuklandi: {ok} | o'tkazildi: {skipped} | xato: {failed}")
    print(f"Mualliflik ma'lumoti -> {CREDITS}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
