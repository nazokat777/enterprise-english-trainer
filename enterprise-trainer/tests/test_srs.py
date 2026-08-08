"""core/srs.py uchun unit testlar."""
from __future__ import annotations

import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from core.srs import (  # noqa: E402
    Card, Grade, get_due_cards, module_progress, next_card, review,
)

NOW = datetime(2026, 1, 1, 12, 0, 0)


def make_card(item_id: str = "vocab-0001", module: str = "Lug'at 1",
              mastery: int = 0) -> Card:
    return Card(item_id=item_id, category="vocabulary", module=module,
                mastery=mastery)


def test_correct_answer_raises_mastery():
    card = make_card(mastery=0)
    review(card, Grade.GOOD, now=NOW)
    assert card.mastery == 20
    assert card.reps == 1
    assert card.lapses == 0


def test_wrong_answer_drops_mastery_sharply():
    card = make_card(mastery=50)
    review(card, Grade.AGAIN, now=NOW)
    assert card.mastery == 10  # 50 - 40
    assert card.lapses == 1


def test_wrong_answer_reschedules_within_one_minute():
    card = make_card(mastery=50)
    review(card, Grade.AGAIN, now=NOW)
    assert card.due == NOW + timedelta(minutes=1)


def test_mastery_never_below_zero_or_above_100():
    low = make_card(mastery=10)
    review(low, Grade.AGAIN, now=NOW)
    assert low.mastery == 0

    high = make_card(mastery=90)
    review(high, Grade.EASY, now=NOW)
    assert high.mastery == 100


def test_is_mastered_only_at_100():
    card = make_card(mastery=99)
    assert not card.is_mastered()
    card.mastery = 100
    assert card.is_mastered()


def test_higher_mastery_gives_longer_interval():
    low = make_card(mastery=20)
    review(low, Grade.GOOD, now=NOW)  # -> 40
    high = make_card(mastery=80)
    review(high, Grade.GOOD, now=NOW)  # -> 100
    assert high.due - NOW > low.due - NOW


def test_get_due_cards_weakest_first():
    strong = make_card("a", mastery=80)
    weak = make_card("b", mastery=20)
    medium = make_card("c", mastery=50)
    # Hammasining muddati kelgan (due=None).
    due = get_due_cards([strong, weak, medium], now=NOW)
    assert [c.item_id for c in due] == ["b", "c", "a"]


def test_mastered_cards_excluded_from_due():
    done = make_card("a", mastery=100)
    pending = make_card("b", mastery=30)
    due = get_due_cards([done, pending], now=NOW)
    assert [c.item_id for c in due] == ["b"]


def test_next_card_returns_weakest():
    cards = [make_card("a", mastery=70), make_card("b", mastery=10)]
    assert next_card(cards, now=NOW).item_id == "b"


def test_next_card_none_when_all_mastered():
    cards = [make_card("a", mastery=100), make_card("b", mastery=100)]
    assert next_card(cards, now=NOW) is None


def test_not_due_card_excluded_but_next_card_still_returns_it():
    card = make_card("a", mastery=30)
    card.due = NOW + timedelta(days=1)  # muddati kelmagan
    assert get_due_cards([card], now=NOW) == []
    # next_card baribir mashq uchun beradi.
    assert next_card([card], now=NOW).item_id == "a"


def test_module_progress_counts_mastered():
    cards = [
        make_card("a", module="Lug'at 1", mastery=100),
        make_card("b", module="Lug'at 1", mastery=50),
        make_card("c", module="Grammatika", mastery=100),
    ]
    progress = {p.module: p for p in module_progress(cards)}
    assert progress["Lug'at 1"].total == 2
    assert progress["Lug'at 1"].mastered == 1
    assert progress["Lug'at 1"].percent == 50
    assert not progress["Lug'at 1"].is_complete
    assert progress["Grammatika"].is_complete


def test_full_mastery_journey():
    """0% dan 100% gacha to'g'ri javoblar bilan yetib borish."""
    card = make_card(mastery=0)
    t = NOW
    for _ in range(10):
        if card.is_mastered():
            break
        review(card, Grade.GOOD, now=t)
        t = card.due
    assert card.is_mastered()
