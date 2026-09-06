# -*- coding: utf-8 -*-
"""Lug'at paketlarining tarjimasi kitobnikiga mos kelishi.

Pack'lardagi tarjimalar mashina tarjimasi keshidan kelardi. U kontekstni
bilmaydi va shu sababli XATO o'rgatardi — masalan `quite` = "juda",
holbuki kitob aynan farqni o'rgatadi (very = juda, quite = ancha).
Kitob lug'ati esa 316 betning hammasi skan bilan solishtirib
tekshirilgan, shuning uchun u ASOSIY manba.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ingest.export_assets import (  # noqa: E402
    _is_verb_form,
    _norm_en,
    pick_gloss,
)


def test_kitob_manosi_olinadi():
    """Bir ma'noli so'zda kitob tarjimasi mashina tarjimasini almashtiradi."""
    assert pick_gloss("juda", ["ancha"], "quite") == "ancha"
    assert pick_gloss("tekis", ["kvartira"], "flat") == "kvartira"
    assert pick_gloss("qalam", ["ruchka"], "pen") == "ruchka"
    assert pick_gloss("oyna", ["deraza"], "window") == "deraza"


def test_soz_turkumi_saqlanadi():
    """Bir necha ma'noda mashina tarjimasining SHAKLI yo'l ko'rsatadi."""
    # `kiyinish` — harakat oti -> fe'l ma'nosi olinadi.
    assert pick_gloss("kiyinish", ["ko'ylak", "kiyinmoq"], "dress") == "kiyinmoq"
    # `telefon` — ot; kitobda faqat fe'l bor -> tegilmaydi.
    assert pick_gloss("telefon", ["qo'ng'iroq qilmoq"], "phone") == "telefon"


def test_buyruq_va_otgan_zamon_ham_fel_deb_qabul_qilinadi():
    for w in ("tushuntiring", "sog'indim", "qo'rqib ketdi", "kiyinish",
              "o'rganmoq"):
        assert _is_verb_form(w), w
    # "ajoyib" — sifat, `-ib` bilan tugasa ham fe'l EMAS.
    assert not _is_verb_form("ajoyib")
    assert not _is_verb_form("telefon")


def test_kontekst_royxati_majburan_kitobga_otkazadi():
    """Shakl mos kelsa ham ma'nosi noto'g'ri bo'lgan so'zlar."""
    assert pick_gloss("krem", ["qaymoq, smetana"], "cream") == "qaymoq, smetana"
    assert pick_gloss("ozuqa", ["boqmoq", "ovqatlantirmoq"], "feed") == "boqmoq"


def test_artikl_hisobga_olinmaydi():
    assert _norm_en("a dog") == "dog"
    assert _norm_en("to run") == "run"
    assert _norm_en("The Sun") == "sun"


def test_kitobda_yoq_soz_tegilmaydi():
    assert pick_gloss("kompyuter", [], "computer") == "kompyuter"


if __name__ == "__main__":
    fails = 0
    for name, fn in sorted(list(globals().items())):
        if not name.startswith("test_") or not callable(fn):
            continue
        try:
            fn()
            print("OK  ", name)
        except AssertionError as e:
            fails += 1
            print("XATO", name, e)
    print("TOZA" if not fails else f"XATOLAR: {fails}")
    raise SystemExit(1 if fails else 0)
