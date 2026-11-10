# Grammatika maktabi - kontent shartnomasi

Fayl: `assets/content/<level>/grammar_school.json` (level = beginner | elementary).
UTF-8, to'g'ri JSON (izoh yo'q). Barcha tushuntirishlar O'ZBEKCHA (lotin), misollar inglizcha + o'zbekcha tarjima.

```json
{
  "level": "beginner",
  "units": [
    {
      "unit": 3,
      "rules": [
        {
          "id": "b3-some-any",
          "title": "Some va Any",
          "summary": "1-2 gap: bu qoida nima uchun kerak.",
          "sections": [
            {"h": "Qachon ishlatiladi?", "body": "Oddiy tushuntirish, kerak bo'lsa ro'yxat (• bilan) va jadval-qolip (qatorlar \\n bilan)."}
          ],
          "examples": [{"en": "There are some apples.", "uz": "Bir nechta olma bor."}],
          "mistakes": [{"wrong": "I have any books.", "right": "I have some books.", "why": "Tasdiq gapda any emas, some."}],
          "tip": "Yodda saqlash uchun qisqa ilgak/qoida.",
          "quiz": [{"q": "There aren't ___ chairs.", "options": ["some", "any", "a"], "answer": 1, "why": "Inkor gapda any."}]
        }
      ]
    }
  ]
}
```

## Talablar
- `units`: 1..15 (kitobdagi unit raqami). Har unit uchun shu unitda KITOBDA o'tiladigan grammatika qoidalarini
  alohida-alohida `rules` qilib yoz (odatda 3-7 ta). Qaysi qoida qaysi unitda ekanini
  `assets/content/<level>/grammar.json` (maydonlar: unit, topic, rule_uz) va
  `assets/content/<bookdir>/` dan (beginner->enterprise1, elementary->enterprise2) aniqla.
  Bir xil qoida bir necha mashqda takrorlansa - BIR qoida bo'lsin (dublikat yo'q).
- `id` noyob: beginner `b<unit>-<slug>`, elementary `e<unit>-<slug>`.
- Har qoida: `summary`, kamida 3 ta `sections` (masalan: Qachon ishlatiladi / Shakli (tasdiq-so'roq-inkor) /
  O'zbekcha bilan solishtirish / Alohida holatlar), 5-8 ta `examples`, 2-4 ta `mistakes` (o'zbek
  o'quvchilar tipik xatolari), bitta `tip`, 3 ta `quiz` (3 variantli, `answer` = to'g'ri variant indeksi 0..2).
- Til: sodda, do'stona, ingliz tilini endi o'rganayotgan o'zbek o'quvchiga mo'ljallangan. Atamani
  birinchi uchraganda qavsda tushuntir (masalan "ega (kim?)"). Ingliz atamalar saqlansin (Present Simple).
- Aniqlik: faqat to'g'ri ingliz grammatikasi; shubhali narsani yozma. Kitob matnini ko'chirma - o'z
  so'zing bilan tushuntir, misollarni o'zing tuz.
- Apostrof: faqat oddiy ' (U+0027) ishlat; JSON'da to'g'ri escape. Faylni yozgach
  `python -c "import json;json.load(open(r'FAYL',encoding='utf-8'))"` bilan tekshir.
- Tipik mavzular: Beginner - pronouns, to be, a/an/the, have got, can, some/any, there is/are, this/that,
  prepositions (place/time/movement), possessives, Present Simple, adverbs of frequency, Present Continuous,
  countable/uncountable, much/many, was/were, Past Simple, adjectives/adverbs, comparisons, will/going to,
  must/mustn't, Present Perfect. Elementary - tenses (Present/Past Simple & Continuous, Perfect), used to,
  passive, conditionals 0/1/2, relative pronouns, location, infinitive/-ing, reported speech, question tags,
  modals (should, might, could, have to), some/any/no compounds - lekin AYNAN kitobdagi unit tarkibiga tayan.
