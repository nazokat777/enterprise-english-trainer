# -*- coding: utf-8 -*-
"""Javobni OVOZ bilan o'qish qoidalari.

Ilova javob berilgandan keyin javobni ovoz chiqarib o'qiydi. Javoblarning
bir qismi o'zbekcha (moslash o'yinida o'ng tomon ko'pincha tarjima,
tanlashda "Yo'q"/"Ha"), ularni ingliz ovozi bilan o'qish noto'g'ri
eshitiladi. Ayni paytda `isn't`, `Who's`, `I'm` kabi inglizcha
qisqartmalar — bu grammatika mashqlarining ASOSIY javoblari — albatta
o'qilishi kerak.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ingest.export_pages import (  # noqa: E402
    _add_answer_speech,
    _auto_speak,
    _strip_gloss,
    collect_uz_glosses,
)


def test_ingliz_qisqartmalari_oqiladi():
    """Apostrof o'zi o'zbekcha degani emas."""
    for w in ("isn't", "aren't", "Who's", "they're", "I've", "we'll",
              "I'm", "I'd", "o'clock"):
        assert _auto_speak(w), w


def test_ozbekcha_sozlar_jim_qoladi():
    """O'zbekchada apostrof `o`/`g` dan keyin, so'z ichida turadi."""
    for w in ("Yo'q", "bo'sh", "to'g'ri", "do'st", "a'zo", "cho'tka"):
        assert _auto_speak(w) == "", w


def test_yorliq_va_raqam_oqilmaydi():
    for w in ("13", "A:", "F", "T"):
        assert _auto_speak(w) == "", w


def test_qavsdagi_izoh_ovozdan_chiqariladi():
    assert _strip_gloss("T (to'g'ri)") == "T"
    assert _strip_gloss("'ll (will)") == "'ll"
    assert _strip_gloss("E (England)") == "E"
    # Butun matn qavs ichida bo'lsa — o'zi qoladi.
    assert _strip_gloss("(hech narsa)") == "(hech narsa)"


def test_moslashda_ong_tomon_olinadi():
    # O'zbekcha tarjimalar loyihaning O'Z lug'atidan aniqlanadi.
    collect_uz_glosses([{"vocabularyOnPage": [{"en": "farmer", "uz": "dehqon"}]}])
    tasks = [{"left": "farmer", "right": "dehqon"},
             {"left": "one", "right": "first"}]
    _add_answer_speech("match", tasks)
    assert "speakAnswer" not in tasks[0]      # o'zbekcha — jim
    assert tasks[1]["speakAnswer"] == "first"  # inglizcha — o'qiladi


def test_qisqa_ingliz_javoblari_oqiladi():
    """Grammatika mashqlarining javoblari aynan qisqa so'zlar."""
    for w in ("in", "on", "is", "an", "am", "to", "of", "it"):
        assert _auto_speak(w, min_letters=2), w
    # Bitta harf — yorliq, o'qilmaydi.
    for w in ("T", "F", "C", "B"):
        assert _auto_speak(w, min_letters=2) == "", w


def test_tanlashda_javob_olinadi():
    collect_uz_glosses([{"vocabularyOnPage": [{"en": "no", "uz": "Yo'q"}]}])
    tasks = [{"prompt": "orange", "answer": "an"},
             {"prompt": "Bormi?", "answer": "Yo'q"}]
    _add_answer_speech("choice", tasks)
    assert tasks[0]["speakAnswer"] == "an"
    assert "speakAnswer" not in tasks[1]


if __name__ == "__main__":
    # pytest o'rnatilmagan bo'lsa ham ishlasin.
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
