"""Grammatika mavzulari uchun TOZA qoidalar (o'zbekcha) va misollar.

OCR grammatika kitobidagi qoida matnini buzib o'qiydi. Shuning uchun bu yerda
har bir mavzu uchun toza, qo'lda yozilgan o'zbekcha tushuntirish va to'g'ri
inglizcha misollar saqlanadi. Bu — standart boshlang'ich grammatika bilimi
(kitobdan ko'chirilmagan), shuning uchun "qoidalar buzilmaydi".

structure.py shu qoidalarni structured.json ga qo'shadi.
"""
from __future__ import annotations

# Mavzu nomi -> {"rule_uz": ..., "examples": [...]}
GRAMMAR_RULES: dict[str, dict] = {
    "Subject Pronouns": {
        "rule_uz": (
            "Subject pronouns (kishilik olmoshlari) gap egasi o'rnida keladi: "
            "I (men), you (sen/siz), he (u – erkak), she (u – ayol), "
            "it (u – jonsiz/hayvon), we (biz), they (ular)."
        ),
        "examples": ["I am a student.", "She is my sister.", "They are at home."],
    },
    "Object Pronouns": {
        "rule_uz": (
            "Object pronouns (to'ldiruvchi olmoshlar) fe'l yoki predlogdan keyin "
            "keladi: me (meni), you (seni), him (uni – erkak), her (uni – ayol), "
            "it (uni), us (bizni), them (ularni)."
        ),
        "examples": ["Call me later.", "I know him.", "She likes them."],
    },
    "The Verb 'to be'": {
        "rule_uz": (
            "'To be' fe'li (am/is/are) shaxsga qarab o'zgaradi: I am, he/she/it is, "
            "you/we/they are. Inkor: am not / isn't / aren't. "
            "So'roq: Am I...? / Is he...? / Are they...?"
        ),
        "examples": ["I am happy.", "He is a teacher.", "Are you ready?"],
    },
    "Articles: a / an": {
        "rule_uz": (
            "'A' va 'an' — noaniq artikllar, birlikdagi sanaladigan otlar oldida. "
            "Undosh tovush oldida 'a' (a book), unli tovush oldida 'an' (an apple) "
            "ishlatiladi."
        ),
        "examples": ["a car", "an orange", "She is a doctor."],
    },
    "Have got": {
        "rule_uz": (
            "'Have got' egalik bildiradi (… bor). I/you/we/they have got, "
            "he/she/it has got. Inkor: haven't got / hasn't got. "
            "So'roq: Have you got...? / Has she got...?"
        ),
        "examples": [
            "I have got a brother.",
            "She has got brown eyes.",
            "Have you got a pen?",
        ],
    },
    "Can (ability)": {
        "rule_uz": (
            "'Can' qobiliyat yoki ruxsat bildiradi (… ola olmoq). Hamma shaxs uchun "
            "bir xil: I/you/he/she/we/they can. Undan keyin fe'l asosiy shaklda keladi. "
            "Inkor: can't (cannot). So'roq: Can you...?"
        ),
        "examples": ["I can swim.", "She can't drive.", "Can you help me?"],
    },
    "Prepositions": {
        "rule_uz": (
            "Joy predloglari narsaning qayerdaligini bildiradi: in (ichida), "
            "on (ustida), under (tagida), next to (yonida), behind (orqasida), "
            "in front of (oldida), between (orasida)."
        ),
        "examples": [
            "The book is on the table.",
            "The cat is under the chair.",
            "She is next to me.",
        ],
    },
    "Plurals": {
        "rule_uz": (
            "Ko'plik odatda '-s' qo'shiladi (book → books). '-s, -ss, -sh, -ch, -x' "
            "bilan tugasa '-es' (box → boxes). Undosh+y bo'lsa, y→i+es (baby → babies). "
            "Ba'zilar tartibsiz: man → men, child → children, foot → feet."
        ),
        "examples": ["one book, two books", "a box, three boxes", "a man, two men"],
    },
    "Present Continuous": {
        "rule_uz": (
            "Present Continuous hozir sodir bo'layotgan ishni bildiradi. "
            "Tuzilishi: am/is/are + fe'l-ing. Inkor: am/is/are + not + -ing. "
            "So'roq: Am/Is/Are + ega + -ing?"
        ),
        "examples": [
            "I am reading a book.",
            "She is sleeping now.",
            "What are you doing?",
        ],
    },
    "Past Simple": {
        "rule_uz": (
            "Past Simple o'tgan zamonda tugagan ishni bildiradi. To'g'ri fe'llarga "
            "'-ed' qo'shiladi (play → played). Tartibsiz fe'llar o'zgaradi "
            "(go → went, have → had). Inkor: didn't + fe'l. So'roq: Did + ega + fe'l?"
        ),
        "examples": [
            "I played football yesterday.",
            "She went to school.",
            "Did you see him?",
        ],
    },
    "Present Perfect": {
        "rule_uz": (
            "Present Perfect o'tmishda bo'lib, hozir bilan bog'liq ishni bildiradi. "
            "Tuzilishi: have/has + fe'lning 3-shakli (V3). Inkor: haven't/hasn't + V3. "
            "So'roq: Have/Has + ega + V3?"
        ),
        "examples": [
            "I have finished my homework.",
            "She has visited London.",
            "Have you eaten?",
        ],
    },
    "Possessives (Possessive Case)": {
        "rule_uz": (
            "Egalikni ko'rsatish uchun otga 's qo'shiladi (Tom's book — Tomning kitobi). "
            "Ko'plik -s bilan tugasa, faqat apostrof qo'yiladi (the boys' room). "
            "Possessive adjectives: my, your, his, her, its, our, their."
        ),
        "examples": ["This is Ann's bag.", "my father's car", "Their house is big."],
    },
    "Demonstratives: this/that/these/those": {
        "rule_uz": (
            "This (bu – yaqin, birlik), that (u – uzoq, birlik), "
            "these (bular – yaqin, ko'plik), those (ular – uzoq, ko'plik)."
        ),
        "examples": ["This is my pen.", "That is her house.", "These are my books."],
    },
    "There is / There are": {
        "rule_uz": (
            "'There is' birlik uchun (… bor), 'There are' ko'plik uchun. "
            "Inkor: there isn't / there aren't. So'roq: Is there...? / Are there...?"
        ),
        "examples": [
            "There is a book on the desk.",
            "There are five students.",
            "Is there a bank near here?",
        ],
    },
    "Countable & Uncountable Nouns": {
        "rule_uz": (
            "Sanaladigan otlar (countable) ko'plikka ega (one apple, two apples). "
            "Sanalmaydigan otlar (uncountable) ko'plikka ega emas (water, milk, rice) "
            "va ular bilan a/an ishlatilmaydi."
        ),
        "examples": ["two apples", "some water", "a lot of rice"],
    },
    "some / any": {
        "rule_uz": (
            "'Some' tasdiq gaplarda (ba'zi, biroz), 'any' inkor va so'roq gaplarda "
            "ishlatiladi."
        ),
        "examples": [
            "I have some money.",
            "There isn't any milk.",
            "Have you got any questions?",
        ],
    },
    "much / many": {
        "rule_uz": (
            "'Many' sanaladigan otlar bilan (many books), 'much' sanalmaydigan otlar "
            "bilan (much water) ishlatiladi. 'A lot of' ikkalasi bilan ham keladi."
        ),
        "examples": ["How many books?", "How much water?", "a lot of friends"],
    },
    "Comparatives & Superlatives": {
        "rule_uz": (
            "Qiyosiy daraja: qisqa sifatga -er + than (taller than). Orttirma daraja: "
            "the + sifat-est (the tallest). Uzun sifatlar: more/most "
            "(more beautiful, the most beautiful)."
        ),
        "examples": [
            "She is taller than me.",
            "This is the biggest room.",
            "It is more expensive.",
        ],
    },
    "Imperative": {
        "rule_uz": (
            "Buyruq mayli buyruq yoki ko'rsatma beradi. Fe'l asosiy shaklda, egasiz "
            "ishlatiladi. Inkor: Don't + fe'l."
        ),
        "examples": ["Open the door.", "Sit down, please.", "Don't be late."],
    },
    "Future: be going to": {
        "rule_uz": (
            "'Be going to' reja yoki niyatni bildiradi. Tuzilishi: am/is/are + going to "
            "+ fe'l."
        ),
        "examples": [
            "I am going to study tonight.",
            "She is going to travel.",
            "Are you going to help?",
        ],
    },
    "Future: will": {
        "rule_uz": (
            "'Will' kelajak, va'da yoki qaror bildiradi. Hamma shaxs uchun bir xil: "
            "will + fe'l. Inkor: won't. So'roq: Will + ega + fe'l?"
        ),
        "examples": ["I will call you.", "It will rain.", "Will you come?"],
    },
    "Modal Verbs": {
        "rule_uz": (
            "Modal fe'llar (can, must, should, may) imkon, majburiyat yoki maslahat "
            "bildiradi. Undan keyin fe'l asosiy shaklda keladi va shaxsga qarab "
            "o'zgarmaydi."
        ),
        "examples": ["You must stop.", "You should rest.", "May I come in?"],
    },
    "Question Words": {
        "rule_uz": (
            "So'roq so'zlari: what (nima), who (kim), where (qayer), when (qachon), "
            "why (nega), how (qanday), which (qaysi), whose (kimniki)."
        ),
        "examples": ["What is this?", "Where do you live?", "How are you?"],
    },
}
