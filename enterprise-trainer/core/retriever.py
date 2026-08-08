"""Element uchun kontekst olish (5-bosqich) — bepul, oddiy.

AI/ChromaDB ishlatilmaydi: barcha kontekst (tarjima, misol, qoida, so'z
oilasi) allaqachon `structured.json` da tayyor. Bu modul element identifikatori
bo'yicha o'sha kontekstni tez topib beradi (xotirada indekslangan).

`generator.py` shu kontekstdan mashq yasaydi.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config  # noqa: E402


class Retriever:
    """structured.json ni yuklab, element bo'yicha kontekst qaytaradi."""

    def __init__(self, structured_path: Path | None = None) -> None:
        path = structured_path or config.STRUCTURED_JSON
        self.data = json.loads(Path(path).read_text(encoding="utf-8"))
        # item_id -> element (tez qidirish uchun indeks).
        self._index: dict[str, dict] = {}
        self._category: dict[str, str] = {}
        for cat in ("vocabulary", "word_formation", "grammar"):
            for item in self.data.get(cat, []):
                self._index[item["id"]] = item
                self._category[item["id"]] = cat

    def get(self, item_id: str) -> dict | None:
        """Element ma'lumotini (kontekst bilan) qaytaradi."""
        return self._index.get(item_id)

    def category_of(self, item_id: str) -> str | None:
        """Element kategoriyasini qaytaradi."""
        return self._category.get(item_id)

    def context(self, item_id: str) -> dict:
        """Mashq yaratish uchun zarur kontekstni tayyorlaydi.

        Har kategoriya uchun mos maydonlarni qaytaradi:
          * vocabulary     -> en, uz, example, pos
          * word_formation -> base, uz, forms
          * grammar        -> topic, rule_text, examples
        """
        item = self._index.get(item_id)
        if item is None:
            raise KeyError(f"Element topilmadi: {item_id}")
        category = self._category[item_id]

        if category == "vocabulary":
            return {
                "category": category,
                "en": item["en"],
                "uz": item["uz"],
                "example": item.get("example", ""),
                "pos": item.get("pos", ""),
            }
        if category == "word_formation":
            return {
                "category": category,
                "base": item["base"],
                "uz": item.get("uz", ""),
                "forms": item.get("forms", []),
            }
        # grammar
        return {
            "category": category,
            "topic": item["topic"],
            "rule_text": item.get("rule_text", ""),
            "examples": item.get("examples", []),
        }

    def all_ids(self) -> list[str]:
        """Barcha element identifikatorlari."""
        return list(self._index.keys())
