"""Jarayonni SQLite'da saqlash (4-bosqich).

Kartalar (Card) holatini va har bir javob tarixini SQLite bazasida saqlaydi.
Shuningdek, zaif nuqtalarni diagnostika qilish uchun ma'lumot beradi:
  * har element bo'yicha xatolar (lapses)
  * har kategoriya bo'yicha aniqlik foizi (vocabulary / grammar / word_formation)

`srs.py` sof hisob-kitobni bajaradi; bu modul esa uni diskka bog'laydi.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

from sqlalchemy import (
    DateTime, Float, ForeignKey, Integer, String, create_engine, func, select,
)
from sqlalchemy.orm import (
    DeclarativeBase, Mapped, Session, mapped_column, relationship,
)

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config  # noqa: E402
from core.srs import Card, Grade  # noqa: E402


class Base(DeclarativeBase):
    pass


class CardRow(Base):
    """Bitta o'rganish elementining doimiy holati."""

    __tablename__ = "cards"

    item_id: Mapped[str] = mapped_column(String, primary_key=True)
    category: Mapped[str] = mapped_column(String, index=True)
    module: Mapped[str] = mapped_column(String, index=True)
    mastery: Mapped[int] = mapped_column(Integer, default=0)
    ease: Mapped[float] = mapped_column(Float, default=1.0)
    reps: Mapped[int] = mapped_column(Integer, default=0)
    lapses: Mapped[int] = mapped_column(Integer, default=0)
    due: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_reviewed: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    reviews: Mapped[list["ReviewRow"]] = relationship(
        back_populates="card", cascade="all, delete-orphan"
    )

    def to_card(self) -> Card:
        """SQL qatorini SRS Card obyektiga aylantiradi."""
        return Card(
            item_id=self.item_id,
            category=self.category,
            module=self.module,
            mastery=self.mastery,
            ease=self.ease,
            reps=self.reps,
            lapses=self.lapses,
            due=self.due,
            last_reviewed=self.last_reviewed,
        )

    def update_from(self, card: Card) -> None:
        """SRS Card holatini SQL qatoriga ko'chiradi."""
        self.mastery = card.mastery
        self.ease = card.ease
        self.reps = card.reps
        self.lapses = card.lapses
        self.due = card.due
        self.last_reviewed = card.last_reviewed


class ReviewRow(Base):
    """Bitta javob tarixi yozuvi (diagnostika uchun)."""

    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    item_id: Mapped[str] = mapped_column(ForeignKey("cards.item_id"), index=True)
    category: Mapped[str] = mapped_column(String, index=True)
    grade: Mapped[int] = mapped_column(Integer)
    correct: Mapped[int] = mapped_column(Integer)  # 1 = to'g'ri, 0 = xato
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)

    card: Mapped[CardRow] = relationship(back_populates="reviews")


class ProgressStore:
    """SQLite bazasi bilan ishlash uchun yuqori darajadagi interfeys."""

    def __init__(self, db_path: Path | None = None) -> None:
        path = db_path or config.PROGRESS_DB
        self.engine = create_engine(f"sqlite:///{path}", future=True)
        Base.metadata.create_all(self.engine)

    # ---- Boshlang'ich yuklash ----
    def seed_from_structured(self, structured_path: Path | None = None) -> int:
        """structured.json dagi elementlardan kartalar yaratadi (yo'qlarini).

        Returns:
            Yangi qo'shilgan kartalar soni.
        """
        path = structured_path or config.STRUCTURED_JSON
        data = json.loads(Path(path).read_text(encoding="utf-8"))

        items: list[tuple[str, str, str]] = []  # (item_id, category, module)
        for v in data.get("vocabulary", []):
            items.append((v["id"], "vocabulary", v["module"]))
        for w in data.get("word_formation", []):
            items.append((w["id"], "word_formation", w["module"]))
        for g in data.get("grammar", []):
            items.append((g["id"], "grammar", g["module"]))

        added = 0
        with Session(self.engine) as s:
            existing = {row[0] for row in s.execute(select(CardRow.item_id))}
            for item_id, category, module in items:
                if item_id in existing:
                    continue
                s.add(CardRow(item_id=item_id, category=category, module=module))
                added += 1
            s.commit()
        return added

    # ---- Kartalarni o'qish ----
    def all_cards(self) -> list[Card]:
        """Barcha kartalarni SRS Card ko'rinishida qaytaradi."""
        with Session(self.engine) as s:
            rows = s.execute(select(CardRow)).scalars().all()
            return [r.to_card() for r in rows]

    def get_card(self, item_id: str) -> Card | None:
        """Bitta kartani qaytaradi."""
        with Session(self.engine) as s:
            row = s.get(CardRow, item_id)
            return row.to_card() if row else None

    # ---- Javobni saqlash ----
    def save_review(self, card: Card, grade: Grade) -> None:
        """Yangilangan karta holatini va javob tarixini saqlaydi."""
        with Session(self.engine) as s:
            row = s.get(CardRow, card.item_id)
            if row is None:
                raise KeyError(f"Karta topilmadi: {card.item_id}")
            row.update_from(card)
            s.add(ReviewRow(
                item_id=card.item_id,
                category=card.category,
                grade=int(grade),
                correct=1 if grade != Grade.AGAIN else 0,
                created_at=card.last_reviewed or datetime.now(),
            ))
            s.commit()

    # ---- Diagnostika ----
    def category_accuracy(self) -> dict[str, float]:
        """Har kategoriya bo'yicha aniqlik foizini hisoblaydi."""
        result: dict[str, float] = {}
        with Session(self.engine) as s:
            rows = s.execute(
                select(
                    ReviewRow.category,
                    func.avg(ReviewRow.correct),
                    func.count(ReviewRow.id),
                ).group_by(ReviewRow.category)
            ).all()
            for category, avg_correct, _count in rows:
                result[category] = round((avg_correct or 0.0) * 100, 1)
        return result

    def weakest_items(self, limit: int = 10) -> list[dict]:
        """Eng ko'p xato qilingan / mahorati past elementlarni qaytaradi."""
        with Session(self.engine) as s:
            rows = s.execute(
                select(CardRow)
                .where(CardRow.reps > 0)
                .order_by(CardRow.mastery.asc(), CardRow.lapses.desc())
                .limit(limit)
            ).scalars().all()
            return [
                {
                    "item_id": r.item_id,
                    "category": r.category,
                    "module": r.module,
                    "mastery": r.mastery,
                    "lapses": r.lapses,
                }
                for r in rows
            ]
