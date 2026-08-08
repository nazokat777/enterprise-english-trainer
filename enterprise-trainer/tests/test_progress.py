"""core/progress.py uchun unit testlar (vaqtinchalik SQLite bilan)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from core.progress import ProgressStore  # noqa: E402
from core.srs import Grade, review  # noqa: E402


@pytest.fixture()
def structured_file(tmp_path: Path) -> Path:
    data = {
        "vocabulary": [
            {"id": "vocab-0001", "en": "book", "uz": "kitob", "module": "Lug'at 1"},
            {"id": "vocab-0002", "en": "eat", "uz": "yemoq", "module": "Lug'at 1"},
        ],
        "word_formation": [
            {"id": "wf-0001", "base": "care", "module": "So'z yasalishi"},
        ],
        "grammar": [
            {"id": "gr-001", "topic": "Present Simple", "module": "Grammatika"},
        ],
    }
    p = tmp_path / "structured.json"
    p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return p


@pytest.fixture()
def store(tmp_path: Path) -> ProgressStore:
    return ProgressStore(db_path=tmp_path / "test.db")


def test_seed_creates_cards(store: ProgressStore, structured_file: Path):
    added = store.seed_from_structured(structured_file)
    assert added == 4
    cards = store.all_cards()
    assert len(cards) == 4
    assert {c.category for c in cards} == {"vocabulary", "word_formation", "grammar"}


def test_seed_is_idempotent(store: ProgressStore, structured_file: Path):
    store.seed_from_structured(structured_file)
    added_again = store.seed_from_structured(structured_file)
    assert added_again == 0
    assert len(store.all_cards()) == 4


def test_save_review_persists_state(store: ProgressStore, structured_file: Path):
    store.seed_from_structured(structured_file)
    card = store.get_card("vocab-0001")
    review(card, Grade.GOOD)
    store.save_review(card, Grade.GOOD)

    reloaded = store.get_card("vocab-0001")
    assert reloaded.mastery == 20
    assert reloaded.reps == 1


def test_category_accuracy(store: ProgressStore, structured_file: Path):
    store.seed_from_structured(structured_file)
    # vocab-0001: to'g'ri, vocab-0002: xato
    c1 = store.get_card("vocab-0001")
    review(c1, Grade.GOOD)
    store.save_review(c1, Grade.GOOD)
    c2 = store.get_card("vocab-0002")
    review(c2, Grade.AGAIN)
    store.save_review(c2, Grade.AGAIN)

    acc = store.category_accuracy()
    assert acc["vocabulary"] == 50.0  # 1 to'g'ri, 1 xato


def test_weakest_items(store: ProgressStore, structured_file: Path):
    store.seed_from_structured(structured_file)
    c = store.get_card("vocab-0002")
    review(c, Grade.AGAIN)
    store.save_review(c, Grade.AGAIN)

    weak = store.weakest_items()
    assert weak[0]["item_id"] == "vocab-0002"
    assert weak[0]["lapses"] == 1
