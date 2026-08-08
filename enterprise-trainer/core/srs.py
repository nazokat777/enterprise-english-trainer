"""Adaptiv interval takrorlash mexanizmi (4-bosqich).

Har bir o'rganish elementi (so'z, qoida, so'z oilasi) uchun 0..100 oralig'ida
MAHORAT (mastery) bali yuritiladi. Mantiq SM-2 algoritmiga asoslangan, lekin
quyidagi qat'iy talablarga moslangan:

  * Noto'g'ri javob mahoratni KESKIN tushiradi va elementni ~1 daqiqada
    qayta rejalashtiradi.
  * Element faqat mahorat 100% bo'lgandagina "o'rganilgan" (mastered) hisoblanadi.
  * Modul faqat BARCHA elementlari o'rganilgandagina tugallangan bo'ladi.
  * Tizim doim eng ZAIF (mahorati past, muddati kelgan) elementni oldinga chiqaradi.

Bu modul vaqtni `now` parametri orqali oladi (sof, test qilish oson). Diskka
yozish `progress.py` ning vazifasi — bu yerda faqat hisob-kitob mantig'i.
"""
from __future__ import annotations

import enum
from dataclasses import dataclass, field
from datetime import datetime, timedelta


class Grade(enum.IntEnum):
    """Foydalanuvchi javobining bahosi."""

    AGAIN = 0   # Noto'g'ri / umuman bilmadim
    HARD = 1    # To'g'ri, lekin qiynaldim
    GOOD = 2    # To'g'ri
    EASY = 3    # To'g'ri va oson


# Har bir baho mahoratni qanday o'zgartiradi (delta, 0..100 shkalasida).
_MASTERY_DELTA: dict[Grade, int] = {
    Grade.AGAIN: -40,   # keskin tushadi
    Grade.HARD: +8,
    Grade.GOOD: +20,
    Grade.EASY: +34,
}

# Noto'g'ri javobdan keyin qayta ko'rsatish oralig'i (~1 daqiqa).
_LAPSE_INTERVAL = timedelta(minutes=1)

# Mahorat darajasiga qarab keyingi takrorlashgacha oraliq (daqiqalarda).
# Mahorat oshgani sari oraliq uzayadi (interval takrorlash printsipi).
def _interval_for(mastery: int, ease: float) -> timedelta:
    """Mahorat bali va yengillik koeffitsiyentiga qarab keyingi oraliq."""
    if mastery >= 100:
        base_minutes = 60 * 24 * 4        # ~4 kun (mustahkamlash uchun)
    elif mastery >= 80:
        base_minutes = 60 * 24            # ~1 kun
    elif mastery >= 60:
        base_minutes = 60 * 4             # ~4 soat
    elif mastery >= 40:
        base_minutes = 30                 # 30 daqiqa
    elif mastery >= 20:
        base_minutes = 10                 # 10 daqiqa
    else:
        base_minutes = 2                  # 2 daqiqa
    return timedelta(minutes=base_minutes * ease)


@dataclass
class Card:
    """Bitta o'rganish elementining takrorlash holati.

    Attributes:
        item_id: Element identifikatori (masalan "vocab-0007").
        category: "vocabulary" | "grammar" | "word_formation".
        module: Tegishli modul nomi (dashboard uchun).
        mastery: 0..100 mahorat bali.
        ease: Yengillik koeffitsiyenti (oraliqni cho'zadi/qisqartiradi).
        reps: Umumiy takrorlashlar soni.
        lapses: Xato (AGAIN) javoblar soni.
        due: Keyingi takrorlash vaqti.
        last_reviewed: Oxirgi takrorlash vaqti (None = hali ko'rilmagan).
    """

    item_id: str
    category: str
    module: str
    mastery: int = 0
    ease: float = 1.0
    reps: int = 0
    lapses: int = 0
    due: datetime | None = None
    last_reviewed: datetime | None = None

    def is_mastered(self) -> bool:
        """Element 100% o'rganilganmi?"""
        return self.mastery >= 100

    def is_due(self, now: datetime) -> bool:
        """Hozir takrorlash muddati kelganmi?"""
        return self.due is None or self.due <= now


def review(card: Card, grade: Grade, now: datetime | None = None) -> Card:
    """Javob bahosiga qarab kartani yangilaydi (mahorat + keyingi muddat).

    Args:
        card: Yangilanayotgan karta (joyida o'zgartiriladi va qaytariladi).
        grade: Foydalanuvchi javobining bahosi.
        now: Joriy vaqt (test uchun beriladi; standart — hozir).

    Returns:
        Yangilangan karta.
    """
    if now is None:
        now = datetime.now()

    card.reps += 1
    card.last_reviewed = now

    # Mahoratni 0..100 oralig'ida yangilash.
    delta = _MASTERY_DELTA[grade]
    card.mastery = max(0, min(100, card.mastery + delta))

    if grade == Grade.AGAIN:
        # Xato: yengillikni kamaytirib, ~1 daqiqada qayta ko'rsatamiz.
        card.lapses += 1
        card.ease = max(0.6, card.ease - 0.2)
        card.due = now + _LAPSE_INTERVAL
    else:
        # To'g'ri: yengillikni biroz moslab, mahoratga mos oraliq beramiz.
        if grade == Grade.EASY:
            card.ease = min(2.5, card.ease + 0.15)
        elif grade == Grade.HARD:
            card.ease = max(0.6, card.ease - 0.05)
        card.due = now + _interval_for(card.mastery, card.ease)

    return card


def get_due_cards(cards: list[Card], now: datetime | None = None) -> list[Card]:
    """Muddati kelgan kartalarni eng ZAIFidan boshlab qaytaradi.

    Tartiblash: avval o'rganilmaganlar, so'ng mahorat past bo'lganlar,
    keyin muddati eng oldin kelganlar.

    Args:
        cards: Barcha kartalar.
        now: Joriy vaqt.

    Returns:
        Takrorlashga tayyor kartalar (eng zaifi birinchi).
    """
    if now is None:
        now = datetime.now()
    due = [c for c in cards if not c.is_mastered() and c.is_due(now)]
    due.sort(key=lambda c: (c.mastery, c.due or now, c.lapses * -1))
    return due


def next_card(cards: list[Card], now: datetime | None = None) -> Card | None:
    """Keyingi mashq qilinishi kerak bo'lgan eng zaif kartani qaytaradi.

    Muddati kelgan karta bo'lmasa, o'rganilmaganlar ichidan eng zaifini
    (muddati hali kelmagan bo'lsa ham) qaytaradi — shunda foydalanuvchi
    har doim mashq qila oladi.
    """
    if now is None:
        now = datetime.now()
    due = get_due_cards(cards, now)
    if due:
        return due[0]
    # Muddati kelgan yo'q — o'rganilmaganlar ichidan eng zaifini beramiz.
    pending = [c for c in cards if not c.is_mastered()]
    if not pending:
        return None
    pending.sort(key=lambda c: (c.mastery, c.due or now))
    return pending[0]


@dataclass
class ModuleProgress:
    """Modul bo'yicha jarayon ma'lumoti."""

    module: str
    total: int
    mastered: int
    avg_mastery: float = field(default=0.0)

    @property
    def percent(self) -> int:
        """Modul tugallanish foizi (o'rganilgan elementlar / jami)."""
        if self.total == 0:
            return 0
        return round(self.mastered / self.total * 100)

    @property
    def is_complete(self) -> bool:
        """Modul to'liq tugallanganmi (barcha elementlar 100%)?"""
        return self.total > 0 and self.mastered == self.total


def module_progress(cards: list[Card]) -> list[ModuleProgress]:
    """Har bir modul bo'yicha jarayonni hisoblaydi.

    Returns:
        Modul nomlari bo'yicha tartiblangan ModuleProgress ro'yxati.
    """
    groups: dict[str, list[Card]] = {}
    for c in cards:
        groups.setdefault(c.module, []).append(c)

    result: list[ModuleProgress] = []
    for module, items in groups.items():
        mastered = sum(1 for c in items if c.is_mastered())
        avg = sum(c.mastery for c in items) / len(items) if items else 0.0
        result.append(ModuleProgress(
            module=module,
            total=len(items),
            mastered=mastered,
            avg_mastery=round(avg, 1),
        ))
    result.sort(key=lambda m: m.module)
    return result
