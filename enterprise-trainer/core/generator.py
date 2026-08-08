"""Mashq yaratish va javobni baholash (6-bosqich) — bepul, AI'siz.

Har bir muddati kelgan element uchun shablon asosida YANGI mashq yasaladi.
Mashq turlari:
  * vocabulary     -> javobni yozish (UZ->EN va EN->UZ) + o'zbekcha mnemonika
  * word_formation -> gapdagi bo'sh joyni to'g'ri hosila so'z bilan to'ldirish
  * grammar        -> (a) qoidani eslash, (b) cloze/transformatsiya mashqi

Baholash fuzzy (imlo xatosi va sinonimlarga tolerant) va o'zbekcha izoh beradi.

Mashq JSON tuzilishi:
  {prompt_uz, question, expected_answer, hint_uz, mnemonic_uz, type}
"""
from __future__ import annotations

import random
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path
from typing import TypedDict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from core.retriever import Retriever  # noqa: E402


class Exercise(TypedDict):
    item_id: str
    type: str            # mashq turi (quyida)
    prompt_uz: str       # o'zbekcha ko'rsatma
    question: str        # savol / topshiriq matni
    expected_answer: str # kutilgan javob (baholash uchun)
    hint_uz: str         # o'zbekcha maslahat
    mnemonic_uz: str     # o'zbekcha yodlash assotsiatsiyasi


# ---------- Mnemonika (oddiy, AI'siz) ----------
def make_mnemonic(en: str, uz: str) -> str:
    """So'zni yodlash uchun oddiy o'zbekcha assotsiatsiya yaratadi.

    Inglizcha so'z tovushini o'zbekcha ma'no bilan bog'lashga undaydi.
    """
    return (
        f"Yodlash uchun: \"{en}\" so'zini ovoz chiqarib ayting va uni "
        f"\"{uz}\" ma'nosi bilan bog'lang. Ko'z oldingizga \"{uz}\" ni "
        f"keltiring va \"{en}\" deb takrorlang."
    )


# ---------- Mashq generatori ----------
class Generator:
    """Element konteksti asosida mashq yasaydi va javobni baholaydi."""

    def __init__(self, retriever: Retriever | None = None,
                 rng: random.Random | None = None) -> None:
        self.retriever = retriever or Retriever()
        self.rng = rng or random.Random()

    def generate(self, item_id: str) -> Exercise:
        """Element uchun yangi mashq yaratadi (har safar tasodifiy tur)."""
        ctx = self.retriever.context(item_id)
        category = ctx["category"]
        if category == "vocabulary":
            return self._vocab_exercise(item_id, ctx)
        if category == "word_formation":
            return self._wordform_exercise(item_id, ctx)
        return self._grammar_exercise(item_id, ctx)

    # ---- Lug'at ----
    def _vocab_exercise(self, item_id: str, ctx: dict) -> Exercise:
        en, uz, example = ctx["en"], ctx["uz"], ctx.get("example", "")
        mnemonic = make_mnemonic(en, uz)
        direction = self.rng.choice(["uz2en", "en2uz"])

        if direction == "uz2en":
            question = f"\"{uz}\" so'zining inglizchasini yozing."
            expected = en
            prompt = "O'zbekchadan inglizchaga tarjima qiling."
            hint = f"Birinchi harfi: \"{en[0]}\"."
        else:
            question = f"\"{en}\" so'zining o'zbekchasini yozing."
            expected = uz
            prompt = "Inglizchadan o'zbekchaga tarjima qiling."
            hint = f"Misol: {example}" if example else "Ma'nosini eslang."

        return Exercise(
            item_id=item_id, type=f"vocab_{direction}", prompt_uz=prompt,
            question=question, expected_answer=expected, hint_uz=hint,
            mnemonic_uz=mnemonic,
        )

    # ---- So'z yasalishi ----
    def _wordform_exercise(self, item_id: str, ctx: dict) -> Exercise:
        base = ctx["base"]
        forms = ctx.get("forms", [])
        uz = ctx.get("uz", "")
        if not forms:
            # Hosila bo'lmasa, oddiy eslash mashqi.
            return Exercise(
                item_id=item_id, type="wordform_recall",
                prompt_uz="So'z oilasini eslang.",
                question=f"\"{base}\" ({uz}) so'zidan hosila so'z yasang.",
                expected_answer=base, hint_uz="Qo'shimcha qo'shing (-er, -ful, ...).",
                mnemonic_uz=make_mnemonic(base, uz),
            )
        target = self.rng.choice(forms)
        return Exercise(
            item_id=item_id, type="wordform_fill",
            prompt_uz="Asos so'zdan to'g'ri hosila shaklni yozing.",
            question=(f"Asos so'z: \"{base}\". Bu so'zdan yasalган shakllardan "
                      f"birini yozing (masalan, qo'shimcha bilan)."),
            expected_answer=target,
            hint_uz=f"Shakllardan biri \"{target[:2]}...\" bilan boshlanadi.",
            mnemonic_uz=f"\"{base}\" oilasi: {', '.join(forms)}",
        )

    # ---- Grammatika ----
    def _grammar_exercise(self, item_id: str, ctx: dict) -> Exercise:
        topic = ctx["topic"]
        rule = ctx.get("rule_text", "")
        examples = ctx.get("examples", [])
        mode = self.rng.choice(["recall", "cloze"]) if examples else "recall"

        if mode == "recall":
            return Exercise(
                item_id=item_id, type="grammar_recall",
                prompt_uz="Grammatika qoidasini eslang.",
                question=f"\"{topic}\" mavzusi qoidasini o'z so'zingiz bilan ayting.",
                expected_answer=rule,
                hint_uz=rule[:60] + "..." if rule else "Qoidani eslang.",
                mnemonic_uz=f"Mavzu: {topic}",
            )
        # cloze: misoldan bitta so'zni yashiramiz.
        sentence = self.rng.choice(examples)
        words = sentence.split()
        # Yashirishga arzigulik so'z (uzunroq) tanlaymiz.
        candidates = [w for w in words if len(re.sub(r"[^a-zA-Z']", "", w)) >= 3]
        target_word = self.rng.choice(candidates) if candidates else words[0]
        clean_target = re.sub(r"[^a-zA-Z']", "", target_word)
        blanked = sentence.replace(target_word, "_____", 1)
        return Exercise(
            item_id=item_id, type="grammar_cloze",
            prompt_uz=f"\"{topic}\" — bo'sh joyni to'ldiring.",
            question=blanked,
            expected_answer=clean_target,
            hint_uz=f"Birinchi harfi: \"{clean_target[0]}\". {rule[:50]}",
            mnemonic_uz=f"Qoida: {rule[:80]}",
        )


# ---------- Javobni baholash ----------
def _edit_distance(a: str, b: str) -> int:
    """Ikki satr orasidagi tahrir masofasi (Levenshtein)."""
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1,
                           prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def _normalize(text: str) -> str:
    """Taqqoslash uchun matnni soddalashtiradi (kichik harf, tinishsiz)."""
    text = text.lower().strip()
    text = re.sub(r"[^\w\s']", "", text)
    text = re.sub(r"\s+", " ", text)
    return text


class Feedback(TypedDict):
    correct: bool
    similarity: float
    message_uz: str
    expected: str


def grade_answer(user_answer: str, expected: str,
                 threshold: float = 0.82) -> Feedback:
    """Foydalanuvchi javobini baholaydi (imlo/sinonimga tolerant).

    Kutilgan javob vergul bilan ajratilgan bir nechta variant bo'lishi mumkin
    (tarjimalar ko'p ma'noli bo'lganda). Har biriga moslik tekshiriladi.

    Args:
        user_answer: Foydalanuvchi kiritgan javob.
        expected: To'g'ri javob (yoki "a, b, c" ko'rinishidagi variantlar).
        threshold: To'g'ri deb hisoblash uchun minimal o'xshashlik (0..1).

    Returns:
        Baholash natijasi va o'zbekcha izoh.
    """
    user_norm = _normalize(user_answer)
    if not user_norm:
        return Feedback(correct=False, similarity=0.0, expected=expected,
                        message_uz="Javob bo'sh. Iltimos, javob yozing.")

    # Kutilgan javob variantlari (vergul yoki "/" bilan).
    variants = [_normalize(v) for v in re.split(r"[,/;]", expected) if v.strip()]
    best = 0.0
    for v in variants:
        if not v:
            continue
        if user_norm == v:
            best = 1.0
            break
        ratio = SequenceMatcher(None, user_norm, v).ratio()
        # Kichik imlo xatosiga tolerantlik: 1 ta xato (qisqa so'z) yoki
        # uzunroq so'zda 2 ta xatogacha to'g'ri hisoblanadi.
        dist = _edit_distance(user_norm, v)
        allowed = 1 if len(v) <= 6 else 2
        if dist <= allowed:
            ratio = max(ratio, 0.95)
        # Foydalanuvchi javobi to'g'ri javobni o'z ichiga olsa (izoh bilan).
        if v in user_norm.split() or user_norm in v:
            ratio = max(ratio, 0.9)
        best = max(best, ratio)

    correct = best >= threshold
    if correct and best >= 0.999:
        msg = "✅ To'g'ri! Ajoyib."
    elif correct:
        msg = f"✅ To'g'ri (kichik imlo xatosi bilan). To'g'ri shakli: \"{expected}\"."
    else:
        msg = f"❌ Noto'g'ri. To'g'ri javob: \"{expected}\". Yana mashq qilamiz."
    return Feedback(correct=correct, similarity=round(best, 2),
                    expected=expected, message_uz=msg)
