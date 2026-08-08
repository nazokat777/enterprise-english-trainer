"""core/generator.py uchun unit testlar."""
from __future__ import annotations

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from core.generator import Generator, grade_answer  # noqa: E402
from core.retriever import Retriever  # noqa: E402


def make_gen() -> Generator:
    return Generator(retriever=Retriever(), rng=random.Random(1))


def test_vocab_exercise_has_required_fields():
    ex = make_gen().generate("vocab-0001")
    for key in ("prompt_uz", "question", "expected_answer", "hint_uz",
                "mnemonic_uz", "type"):
        assert ex[key], f"{key} bo'sh bo'lmasligi kerak"


def test_grammar_exercise_generates():
    ex = make_gen().generate("gr-001")
    assert ex["type"].startswith("grammar")
    assert ex["expected_answer"]


def test_grade_exact_match():
    fb = grade_answer("yemoq", "yemoq")
    assert fb["correct"] and fb["similarity"] == 1.0


def test_grade_tolerates_typo():
    assert grade_answer("yemok", "yemoq")["correct"]      # 1 xato
    assert grade_answer("kitb", "kitob")["correct"]       # 1 tushib qolgan


def test_grade_rejects_wrong():
    assert not grade_answer("mashina", "yemoq")["correct"]


def test_grade_accepts_one_of_variants():
    assert grade_answer("opa", "opa, singil")["correct"]
    assert grade_answer("singil", "opa, singil")["correct"]


def test_grade_empty_is_wrong():
    fb = grade_answer("", "yemoq")
    assert not fb["correct"]


def test_grade_case_insensitive():
    assert grade_answer("YEMOQ", "yemoq")["correct"]
