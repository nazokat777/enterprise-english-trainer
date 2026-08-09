"""Sahifa JSON'larini Flutter asset'lariga aylantiradi.

Sahifa fayllarida 43 xil mashq turi bor. Flutter tomonda ularning har biriga
alohida ekran qurish mumkin emas, shuning uchun bu skript hammasini
4 ta O'YIN TURIGA normalizatsiya qiladi:

    choice — variantdan birini tanlash
    text   — javobni harf/so'z plitkalaridan yig'ish
    match  — ikki ustunni juftlash
    study  — javobsiz: qoida, dialog, namuna (faqat o'qish/eshitish)

Noma'lum tur uchraса `study` ga tushadi — ya'ni kontent HECH QACHON
yo'qolmaydi, faqat interaktivligi kamayadi.

Ishlatish:
    python -m ingest.export_pages
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

TRAINER = Path(__file__).resolve().parent.parent
PAGES = TRAINER / "data" / "pages"
OUT = TRAINER.parent / "enterprise-app" / "assets" / "content" / "enterprise1"

# Eksportyor taniydigan mashq turlari. Bu ro'yxatda YO'Q tur uchrasa,
# mashqning bandlari eksportga chiqmaydi — shuning uchun ogohlantirish
# beriladi va check_content ham buni xato deb hisoblaydi.
KNOWN_TYPES = {
    "article_choice", "article_and_label", "true_false",
    "word_choice", "underline_correct", "choose_correct",
    "picture_choice", "picture_pronoun", "uz_to_en", "picture_guess_job",
    "fill_from_list", "nationality_dialogue", "map_fill",
    "match", "listen_match", "order_dialogue",
    "number_to_words", "write_number", "words_to_number",
    "word_order", "write_question", "fill_gap", "long_short_form",
    "dialogue_fill", "dialogue_gap_fill", "text_gap_fill",
    "complete_table", "prompt_to_dialogue", "picture_question_answer",
    "photo_age_sentence", "picture_fill_and_ask", "read_label_answer",
    "label_picture",
    "listen_fill_profile", "table_fill", "table_fill_from_list",
    "write_sentences", "guided_writing", "table_to_paragraph",
    "make_sentences_game", "speech_bubbles", "listen_repeat",
    "dialogue_drill", "listen_act_out", "guessing_game",
    "ask_answer_landmarks", "discuss_meaning", "explain_sentences", "explain",
}

# Bo'limlarni o'quv mantig'i bo'yicha tartiblash: o'rgan -> mashq qil -> qo'lla.
SECTION_ORDER = [
    "lead_in",
    "vocabulary",
    "reading",
    "grammar_theory",
    "grammar",
    "grammar_exercise",
    "pronunciation",
    "listening",
    "speaking",
    "communication",
    "game",
    "writing",
    "words_of_wisdom",
]
BOOK_ORDER = {"coursebook": 0, "grammar": 1, "workbook": 2}

SECTION_TITLE_UZ = {
    "lead_in": "Kirish",
    "vocabulary": "Lug'at",
    "reading": "O'qish",
    "grammar_theory": "Grammatika — qoida",
    "grammar": "Grammatika",
    "grammar_exercise": "Grammatika — mashq",
    "pronunciation": "Talaffuz",
    "listening": "Tinglash",
    "speaking": "Gapirish",
    "communication": "Muloqot",
    "game": "O'yin",
    "writing": "Yozish",
    "words_of_wisdom": "Hikmatli so'z",
}


# ─────────────────────────── yordamchilar ───────────────────────────
def task(prompt, answer, *, prompt_uz="", options=None, why="", alt=None,
         speak=None, visual=""):
    """Bitta savol-javob birligi.

    MUHIM — JAVOBNI OSHKOR QILMASLIK:
      * `prompt_uz` javobning o'zbekchasi BO'LMASLIGI kerak.
      * `speak` — javob berilgunga qadar ovoz chiqariladigan matn.
        Faqat SAVOL matni bo'lishi mumkin va u inglizcha bo'lsa.
        Berilmasa — avtomatik aniqlanadi (o'zbekcha bo'lsa, ovoz yo'q).
      * `visual` — emoji yoki asset yo'li (rasm o'rniga).
    """
    t = {"prompt": str(prompt), "answer": str(answer)}
    if prompt_uz:
        t["promptUz"] = prompt_uz
    if options:
        t["options"] = [str(o) for o in options]
    if why:
        t["whyUz"] = why
    if alt:
        t["alt"] = alt if isinstance(alt, list) else [str(alt)]
    if visual:
        t["visual"] = visual

    s = speak if speak is not None else _auto_speak(prompt)
    if s:
        t["speak"] = str(s)
    return t


# O'zbekcha yorliqlar — bularni inglizcha ovoz bilan o'qish ma'nosiz.
_UZ_MARKERS = ("Rasm ", "Matn ", "-o'rin", "-bet", " — ", "tuzing", "shakl",
               "Namuna", "bo'yicha", "yozing", "qarang", "to'ldiring",
               "qatorini", "tanlang", "Bo'shliq", "toping")


def _line_prompt(who, body):
    """Dialog qatorining savol matni. Matn bo'sh bo'lsa faqat 'A:' qolmasin."""
    body = (body or "").strip()
    who = (who or "").strip()
    if not body:
        return f"{who} qatorini to'ldiring" if who else "Bo'shliqni to'ldiring"
    return f"{who}: {body}" if who else body


def _auto_speak(prompt):
    """Savol matni inglizcha bo'lsa — o'qiladi, aks holda ovoz yo'q."""
    p = str(prompt).strip()
    if not p:
        return ""
    if any(m in p for m in _UZ_MARKERS):
        return ""
    # O'zbekcha o'ziga xos harflar yoki raqamdan iborat bo'lsa — o'qimaymiz.
    if any(ch in p for ch in "'‘’") and " " not in p:
        return ""
    letters = [c for c in p if c.isalpha()]
    if not letters:
        return ""  # faqat raqam (masalan "13")
    # "A:" kabi qisqa yorliqni o'qishning ma'nosi yo'q.
    if len(letters) < 3 or p.rstrip().endswith(":"):
        return ""
    return p


# ─────────────────── Vizual (emoji) lug'ati ───────────────────
# Kitobdagi rasmlar mualliflik huquqi bilan himoyalangan, shuning uchun
# ularni ko'chirmaymiz. Ko'p mashqlarda rasm shunchaki buyumni bildiradi —
# emoji o'sha vazifani bajaradi: bepul, offline, tushunarli.
EMOJI = {
    # buyumlar
    "book": "📕", "armchair": "🪑", "house": "🏠", "orange": "🍊",
    "elephant": "🐘", "dog": "🐕", "tree": "🌳", "umbrella": "☂️",
    "envelope": "✉️", "watch": "⌚", "clock": "🕐", "hamburger": "🍔",
    "apple": "🍎", "pencil": "✏️", "bicycle": "🚲", "banana": "🍌",
    "hat": "🎩", "guitar": "🎸", "butterfly": "🦋", "lemon": "🍋",
    "television": "📺", "car": "🚗", "plane": "✈️", "tractor": "🚜",
    "palette": "🎨", "stethoscope": "🩺", "space shuttle": "🚀",
    "blackboard": "🧮", "letters": "📬", "kitten": "🐈", "cat": "🐈",
    "drum": "🥁", "piano": "🎹", "violin": "🎻", "map": "🗺️",
    # odamlar / kasblar
    "boy": "👦", "girl": "👧", "man": "👨", "woman": "👩",
    "doctor": "🧑‍⚕️", "pilot": "🧑‍✈️", "farmer": "🧑‍🌾", "teacher": "🧑‍🏫",
    "artist": "🧑‍🎨", "astronaut": "🧑‍🚀", "engineer": "👷", "waiter": "🧑‍🍳",
    "waitress": "🧑‍🍳", "musician": "🎼", "postman": "📮", "vet": "🐾",
    "dancer": "💃", "singer": "🎤", "policeman": "👮", "lawyer": "⚖️",
    "barman": "🍸", "actress": "🎭", "actor": "🎭", "student": "🎓",
    "taxi driver": "🚕", "footballer": "⚽", "guitarist": "🎸",
    "drummer": "🥁", "surgeons": "🧑‍⚕️", "two girls": "👧👧",
    # sport
    "golf": "⛳", "football": "⚽", "basketball": "🏀",
    "tennis": "🎾", "volleyball": "🏐",
    # mashhur joylar
    "the pyramids": "🔺", "the taj mahal": "🕌", "big ben": "🕰️",
    "the eiffel tower": "🗼", "the parthenon": "🏛️",
    "the white house": "🏛️", "st basil's cathedral": "⛪",
    "the sydney opera house": "🎭", "the statue of liberty": "🗽",
}

# Mamlakat → bayroq. Millat mashqlarida javobni oshkor qilmasligi uchun
# faqat javob berilgandan keyin ko'rsatiladi (Dart tomonda hal qilinadi).
FLAG = {
    "brazil": "🇧🇷", "india": "🇮🇳", "spain": "🇪🇸", "scotland": "🏴󠁧󠁢󠁳󠁣󠁴󠁿",
    "egypt": "🇪🇬", "france": "🇫🇷", "italy": "🇮🇹", "poland": "🇵🇱",
    "hungary": "🇭🇺", "russia": "🇷🇺", "china": "🇨🇳", "japan": "🇯🇵",
    "germany": "🇩🇪", "turkey": "🇹🇷", "canada": "🇨🇦", "greece": "🇬🇷",
    "finland": "🇫🇮", "mexico": "🇲🇽", "argentina": "🇦🇷", "portugal": "🇵🇹",
    "switzerland": "🇨🇭", "the czech republic": "🇨🇿", "australia": "🇦🇺",
    "the usa": "🇺🇸", "america": "🇺🇸", "england": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "britain": "🇬🇧",
    "holland": "🇳🇱", "ireland": "🇮🇪", "wales": "🏴󠁧󠁢󠁷󠁬󠁳󠁿", "sweden": "🇸🇪",
    "denmark": "🇩🇰", "new zealand": "🇳🇿", "austria": "🇦🇹",
    "bulgaria": "🇧🇬", "new delhi": "🇮🇳",
}


def emoji_for(*candidates):
    """Berilgan so'zlardan biriga mos emoji topadi."""
    for c in candidates:
        if not c:
            continue
        k = str(c).strip().lower()
        if k in EMOJI:
            return EMOJI[k]
        # "a waiter" / "an artist" kabi artiklni tashlab ko'ramiz
        for art in ("a ", "an ", "the "):
            if k.startswith(art) and k[len(art):] in EMOJI:
                return EMOJI[k[len(art):]]
    return ""


def study(en, uz="", note=""):
    s = {"en": str(en)}
    if uz:
        s["uz"] = str(uz)
    if note:
        s["note"] = str(note)
    return s


def distractors(correct, pool, n=3):
    """Bir xil javobsiz, takrorsiz chalg'ituvchi variantlar."""
    out = []
    for x in pool:
        if len(out) >= n:
            break
        if str(x) != str(correct) and str(x) not in out:
            out.append(str(x))
    return out


# ─────────────────────────── normalizatorlar ───────────────────────────
def norm_exercise(ex, page):
    """Bitta mashqni normalizatsiya qiladi -> {kind, tasks, ...}."""
    t = ex.get("type", "")
    items = ex.get("items", [])
    base = {
        "ref": str(ex.get("ref", "")),
        "instructionEn": ex.get("instructionEn", ""),
        "instructionUz": ex.get("instructionUz", ""),
        "explanationUz": ex.get("explanationUz", ""),
        "audio": bool(ex.get("hasAudio")),
        "book": page["book"],
        "bookPage": page["bookPage"],
    }
    # Raqamlanmagan bet (modul muqovasi) — raqam o'rniga yorliq.
    if page.get("bookPageLabel"):
        base["pageLabel"] = page["bookPageLabel"]
    if ex.get("bookRef"):
        base["bookRef"] = ex["bookRef"]
    if ex.get("audioRequiredUz"):
        base["audioNoteUz"] = ex["audioRequiredUz"]

    kind, tasks = _dispatch(t, ex, items)
    base["kind"] = kind
    base["tasks"] = tasks
    return base


def _dispatch(t, ex, items):
    # ---------- TANLASH ----------
    if t == "article_choice":
        return "choice", [
            task(i["word"], i["answer"], prompt_uz=i.get("wordUz", ""),
                 options=["a", "an"], why=i.get("whyUz", ""),
                 visual=emoji_for(i["word"]))
            for i in items
        ]

    if t == "article_and_label":
        out = [
            task(a["word"], a["article"], prompt_uz=a.get("uz", ""),
                 options=["a", "an"], why=a.get("whyUz", ""))
            for a in ex.get("articleAnswers", [])
        ]
        # DIQQAT: answerUz — javobning o'zbekchasi, ko'rsatib bo'lmaydi.
        names = [i["answer"] for i in items]
        out += [
            task(f"{i['name']} ({i['age']})", i["answer"],
                 prompt_uz="Rasmdagi kasbni tanlang",
                 options=[i["answer"]] + distractors(i["answer"], names),
                 why=i.get("noteUz", ""), speak="")
            for i in items if not i.get("given")
        ]
        return "choice", out

    if t == "true_false":
        return "choice", [
            task(i["sentence"], i["answer"], options=["T", "F"], why=i.get("whyUz", ""))
            for i in items
        ]

    if t in ("word_choice", "underline_correct", "choose_correct"):
        # "To'g'ri so'zni tanlang" — Enterprise'da eng ko'p uchraydigan tur.
        # Savol matnida bo'shliq turadi, javob variantlar ichida.
        # Ovoz yo'q: gap javobni o'z ichiga olsa, o'qish javobni oshkor qiladi.
        return "choice", [
            task(i["textEn"], i["answer"],
                 prompt_uz=i.get("uz", "To'g'ri so'zni tanlang"),
                 options=i.get("options", []),
                 why=i.get("whyUz", ""), speak="")
            for i in items if not i.get("given")
        ]

    if t in ("picture_choice",):
        # DIQQAT: mamlakatning o'zbekcha nomi JAVOB hisoblanadi — uni
        # savolda ko'rsatib bo'lmaydi. O'rniga rasm tavsifi beriladi.
        return "choice", [
            task(a.get("descEn") or f"Rasm {a['picture']}", a["country"],
                 prompt_uz=a.get("descUz", "Kiyim va buyumlarga qarab toping"),
                 options=ex.get("options", []),
                 speak=a.get("descEn", ""),
                 visual=a.get("image", ""))
            for a in ex.get("answers", [])
        ]

    if t == "picture_pronoun":
        return "choice", [
            task(i.get("pictureEn", i.get("picture", "")), i["answer"],
                 prompt_uz=i.get("picture", ""), options=["he", "she", "it", "they"],
                 why=i.get("whyUz", ""),
                 speak=i.get("pictureEn", ""),
                 visual=emoji_for(i.get("pictureEn"), i.get("picture")))
            for i in items
        ]

    if t == "uz_to_en":
        # O'zbekcha so'z -> inglizcha javob. Savol JAVOBNI bermaydi,
        # shuning uchun ovoz ham chiqarilmaydi (speak="").
        wl = ex.get("wordList", [])
        return "choice", [
            task(i["promptUz"], i["answer"],
                 prompt_uz="Inglizchasini tanlang",
                 options=[i["answer"]] + distractors(i["answer"], wl),
                 why=i.get("whyUz", ""), speak="",
                 visual=emoji_for(i["answer"]))
            for i in items
        ]

    if t == "picture_guess_job":
        pool = [i["answer"] for i in items]
        return "choice", [
            task(i.get("objectEn", ""), i["answer"], prompt_uz=i.get("object", ""),
                 options=[i["answer"]] + distractors(i["answer"], pool),
                 why=i.get("commonMistake", {}).get("whyUz", ""),
                 speak=i.get("objectEn", ""),
                 visual=emoji_for(i.get("objectEn"), i.get("object")))
            for i in items
        ]

    if t in ("fill_from_list", "nationality_dialogue"):
        wl = ex.get("wordList", [])
        if t == "fill_from_list":
            return "choice", [
                task(i["sentence"], i["answer"], prompt_uz=i.get("uz", ""),
                     options=[i["answer"]] + distractors(i["answer"], wl),
                     why=i.get("commonMistake", {}).get("whyUz", ""))
                for i in items
            ]
        return "choice", [
            task(i["question"], i["word"], prompt_uz=f"({i.get('countryUz','')})",
                 options=[i["word"]] + distractors(i["word"], wl),
                 why=i.get("commonMistake", {}).get("whyUz", ""))
            for i in items
        ]

    if t == "map_fill":
        # DIQQAT: countryUz javob — savolda faqat poytaxt nomi beriladi.
        wl = ex.get("wordList", [])
        return "choice", [
            task(f"{i['capital']} is in ___", i["country"],
                 prompt_uz=i.get("capitalUz", ""),
                 options=[i["country"]] + distractors(i["country"], wl),
                 why=i.get("noteUz", ""), speak=i["capital"])
            for i in items
        ]

    # ---------- MOSLASH ----------
    if t == "match":
        pairs = ex.get("pairs", [])
        if pairs and "left" in pairs[0]:
            return "match", [{"left": p["left"], "right": p["right"]} for p in pairs]
        return "match", [{"left": p["cardinal"], "right": p["ordinal"]} for p in pairs]

    if t == "listen_match":
        # Yorliqda NIMA borligi yozilishi shart — "Rasm A" o'zi hech nima
        # anglatmaydi, o'quvchi kitobsiz mashqni tushunmaydi.
        return "match", [
            {
                "left": f"Rasm {a['letter']}"
                        + (f" — {a['pictureDescUz']}" if a.get("pictureDescUz") else ""),
                "right": f"Matn {a['number']}"
                         + (f" — {a['textDescUz']}" if a.get("textDescUz") else ""),
                "note": a.get("why", ""),
            }
            for a in ex.get("answers", [])
        ]

    if t == "order_dialogue":
        return "match", [
            {"left": f"{i['correctOrder']}-o'rin", "right": f"{i['who']}: {i['en']}",
             "note": i.get("uz", "")}
            for i in sorted(items, key=lambda x: x["correctOrder"])
        ]

    # ---------- YIG'ISH (text) ----------
    if t in ("number_to_words", "write_number", "words_to_number"):
        out = []
        for i in items:
            if "number" in i and isinstance(i.get("answer"), str):
                out.append(task(str(i["number"]), i["answer"], why=i.get("whyUz", "")))
            elif "word" in i and isinstance(i.get("answer"), int):
                out.append(task(i["word"], str(i["answer"]), why=i.get("whyUz", "")))
            elif "word" in i:
                out.append(task(i["word"], str(i["answer"]), why=i.get("whyUz", "")))
        return "text", out

    if t == "word_order":
        return "text", [
            task(" / ".join(i["words"]), i["answer"],
                 why=i.get("whyUz", "") or i.get("commonMistake", {}).get("whyUz", ""),
                 alt=i.get("alt"))
            for i in items
        ]

    if t == "write_question":
        out = [
            task(i["answer"], i["question"], prompt_uz="Shu javobga savol tuzing",
                 why=i.get("whyUz", ""))
            for i in items if not i.get("given")
        ]
        # Dialog ko'rinishidagi variant: savol o'rni `gap` bilan belgilangan,
        # javob esa keyingi qatorda turadi.
        lines = ex.get("lines", [])
        for idx, ln in enumerate(lines):
            if not ln.get("gap") or not ln.get("answer"):
                continue
            reply = next((lines[k].get("en", "") for k in range(idx + 1, len(lines))
                          if lines[k].get("en")), "")
            out.append(task(
                reply or "Shu javobga savol tuzing", ln["answer"],
                prompt_uz=ln.get("answerUz", "Savolni tiklang"),
                why=ln.get("commonMistake", {}).get("whyUz", ""),
                speak=reply,
            ))
        return "text", out

    if t in ("fill_gap", "long_short_form"):
        out = []
        for i in items:
            if i.get("given"):
                continue
            if t == "long_short_form":
                out.append(task(i["textEn"], i["long"], prompt_uz="To'liq shakl",
                                why=i.get("whyUz", "")))
                out.append(task(i["textEn"], i["short"], prompt_uz="Qisqa shakl",
                                why=i.get("whyUz", "")))
            else:
                # Bitta qatorda bir NECHA bo'shliq bo'lishi mumkin ->
                # `answers` ro'yxati. Aks holda bittasi yo'qolib ketardi.
                answers = i.get("answers") or (
                    [i["answer"]] if i.get("answer") else [])
                hint = i.get("hintUz") or i.get("promptUz", "")
                for k, a in enumerate(answers):
                    prompt = i["textEn"] if len(answers) == 1 else \
                        f"{i['textEn']}  [{k + 1}-bo'shliq]"
                    out.append(task(prompt, a, prompt_uz=hint,
                                    why=i.get("whyUz", "")))
        return "text", out

    if t in ("dialogue_fill", "dialogue_gap_fill", "text_gap_fill"):
        out = []

        # (a) Ba'zi mashqlarda qatorlar MASHQ darajasida turadi (items emas).
        #     Matn `textEn` yoki `en` maydonida bo'lishi mumkin.
        #     Bir qatorda BIR NECHTA bo'shliq bo'lsa — `answers` ro'yxati.
        for ln in ex.get("lines", []):
            if ln.get("given"):
                continue
            answers = ln.get("answers") or (
                [ln["answer"]] if ln.get("answer") else []
            )
            if not answers:
                continue
            body = ln.get("textEn") or ln.get("en") or ""
            base_prompt = _line_prompt(ln.get("who"), body)
            # `hintUz` — javobni oshkor qilmaydigan yordam. Bo'lmasa `uz`.
            # DIQQAT: `uz` — qatorning to'liq tarjimasi. Javob BUTUN gap bo'lsa
            # (masalan tushib qolgan savol), tarjima javobni beradi —
            # bunday holda sahifa faylida `hintUz` yozilishi shart.
            hint = ln.get("hintUz") or ln.get("uz", "")
            for k, a in enumerate(answers):
                prompt = base_prompt if len(answers) == 1 else \
                    f"{base_prompt}  [{k + 1}-bo'shliq]"
                out.append(task(prompt, a, prompt_uz=hint,
                                why=ln.get("whyUz", "")))

        # (b) Ba'zilarida bir nechta dialog bo'ladi.
        for dlg in ex.get("dialogues", []):
            for ln in dlg.get("lines", []):
                if ln.get("given") or not ln.get("answer"):
                    continue
                body = ln.get("textEn") or ln.get("en") or ""
                out.append(task(_line_prompt(ln.get("who"), body), ln["answer"],
                                prompt_uz=ln.get("answerUz", "")))

        for i in items:
            if i.get("given") and "lines" not in i:
                continue
            for ln in i.get("lines", []):
                if ln.get("given"):
                    continue
                ans = ln.get("answers") or ([ln["answer"]] if ln.get("answer") else [])
                for a in ans:
                    out.append(task(f"{ln.get('who','')}: {ln['textEn']}", a,
                                    why=i.get("whyUz", "")))
            if "lines" not in i and i.get("answer"):
                out.append(task(f"{i.get('who','')}: {i['textEn']}", i["answer"],
                                why=i.get("whyUz", "") or
                                    i.get("commonMistake", {}).get("whyUz", "")))
        return "text", out

    if t == "complete_table":
        out = []
        for i in items:
            if i.get("fullBlank"):
                out.append(task(f"{i['subject']} — to'liq shakl", i["full"]))
            if i.get("shortBlank"):
                out.append(task(f"{i['subject']} — qisqa shakl", i["short"]))
        return "text", out

    if t == "prompt_to_dialogue":
        out = []
        for i in items:
            if i.get("given"):
                continue
            out.append(task(i["prompt"], i["question"], prompt_uz="Savol tuzing",
                            why=i.get("whyUz", "")))
            out.append(task(i["prompt"], i["answer"], prompt_uz="Javob tuzing",
                            why=i.get("whyUz", "")))
        return "text", out

    if t == "picture_question_answer":
        out = []
        for i in items:
            if i.get("given"):
                continue
            out.append(task(i.get("pictureEn", i.get("picture", "")), i["question"],
                            prompt_uz="Savol tuzing", why=i.get("whyUz", "")))
            out.append(task(i.get("pictureEn", i.get("picture", "")), i["answer"],
                            prompt_uz="Javob tuzing", why=i.get("whyUz", "")))
        return "text", out

    if t == "photo_age_sentence":
        return "text", [
            task(f"{i['gender']}, {i['age']}", i["answer"],
                 why=i.get("commonMistake", {}).get("whyUz", "") or i.get("noteUz", ""))
            for i in items if not i.get("given")
        ]

    if t == "picture_fill_and_ask":
        return "text", [
            task(i["country"], i["capital"], prompt_uz=i.get("countryUz", ""),
                 why=f"{i.get('landmark','')}", speak=i["country"],
                 visual=i.get("image", ""))
            for i in items if not i.get("given")
        ]

    if t == "label_picture":
        # Rasmdagi strelkalarni so'zlar ro'yxatidan belgilash.
        # Savol — strelka raqami va u ko'rsatgan joyning o'zbekcha izohi;
        # javob — tana qismi (yoki boshqa) nomi. Variantlar ro'yxatdan olinadi.
        pool = [str(w) for w in ex.get("wordList", [])] or \
               [str(i["answer"]) for i in items]
        return "choice", [
            task(f"{i['number']}-strelka", i["answer"],
                 prompt_uz=i.get("hintUz", "Rasmdagi qismni tanlang"),
                 options=[str(i["answer"])] + distractors(i["answer"], pool),
                 why=i.get("whyUz", ""), speak="")
            for i in items if not i.get("given")
        ]

    if t == "read_label_answer":
        out = [
            task(f"{p['prompt']} ({p['picture']})", p["answer"],
                 prompt_uz=p.get("answerUz", ""))
            for p in ex.get("pictureLabels", [])
        ]
        out += [
            task(q["en"], q["answerEn"], prompt_uz=q.get("uz", ""))
            for q in ex.get("questions", [])
        ]
        return "text", out

    if t == "listen_fill_profile":
        return "text", [
            task(p["name"], p["modelSentence"], prompt_uz="Profil bo'yicha gap tuzing")
            for p in ex.get("profiles", [])
            if p.get("modelSentence") and not p.get("ageFromAudio")
        ]

    if t in ("table_fill", "table_fill_from_list"):
        rows = ex.get("rows", [])
        out = []
        for r in rows:
            if r.get("given"):
                continue
            blank = r.get("blank")
            if blank and r.get(blank):
                out.append(task(f"{r.get('name','')} — {blank}", r[blank]))
            elif r.get("cells") and any(r["cells"]):
                cols = ex.get("columns", [])
                for c, v in zip(cols, r["cells"]):
                    if v:
                        out.append(task(f"{r['name']} — {c}", v))
        return "text", out

    if t in ("write_sentences", "guided_writing", "table_to_paragraph"):
        out = []
        # (a) Tuzilishi berilgan bo'lsa — har bir qadamning sarlavhasi savol bo'ladi.
        for s in ex.get("structure", []):
            if s.get("modelEn"):
                out.append(task(s.get("headingUz") or "Namuna bo'yicha yozing",
                                s["modelEn"], why=s.get("noteUz", "")))
        # (b) Tayyor namuna gaplar.
        models = ex.get("modelAnswers") or (
            [ex["modelAnswer"]] if ex.get("modelAnswer") else []
        )
        out += [task("Namuna bo'yicha yozing", m) for m in models if m]
        return "text", out

    if t == "make_sentences_game":
        return "text", [
            task(m["word"], m["sentence"], prompt_uz=m.get("uz", ""))
            for m in ex.get("modelSentences", [])
        ]

    if t == "speech_bubbles":
        out = []
        for sc in ex.get("scenes", []):
            for b in sc.get("bubbles", []):
                if b.get("given"):
                    continue
                out.append(task(f"{sc['picture']} — {b['position']}", b["answer"],
                                prompt_uz=b.get("uz", "")))
        return "text", out

    # ---------- O'RGANISH (study) ----------
    if t == "listen_repeat":
        src = ex.get("sentences") or ex.get("words") or []
        return "study", [
            study(x.get("en", ""), x.get("uz", ""), x.get("hintUz", "")) for x in src
        ]

    if t in ("dialogue_drill", "listen_act_out", "guessing_game"):
        # Dialog qatorlari `example` yoki `lines` da, gapiruvchi esa
        # `speaker` yoki `who` da bo'lishi mumkin — ikkalasini ham qabul
        # qilamiz, aks holda mashq jimgina bo'sh chiqadi.
        src = ex.get("example") or ex.get("lines") or []
        return "study", [
            study(f"{l.get('speaker') or l.get('who', '')}: {l['en']}",
                  l.get("uz", ""))
            for l in src if l.get("en")
        ]

    if t == "ask_answer_landmarks":
        # Rasm + "shu mamlakatdami?" -> Ha/Yo'q. Kitobdagi og'zaki mashqning
        # interaktiv varianti: birlik/ko'plik farqi ham shu yerda mashq bo'ladi.
        out = []
        for i in items:
            q = "Are" if i.get("plural") else "Is"
            out.append(task(
                f"{q} {i['landmark']} in {i['asked']}?",
                "Ha" if i.get("correct") else "Yo'q",
                prompt_uz=i.get("landmarkUz", ""),
                options=["Ha", "Yo'q"],
                why=f"{i.get('answerEn','')} "
                    f"({i.get('realCity','')}, {i.get('realCountry','')})",
                speak=f"{q} {i['landmark']} in {i['asked']}?",
                visual=i.get("image", ""),
            ))
        return "choice", out

    if t == "discuss_meaning":
        return "study", [study(ex.get("sentenceEn", ""), ex.get("sentenceUz", ""))]

    if t == "explain_sentences":
        return "study", [
            study(x.get("en", ""), x.get("uz", ""), x.get("noteUz", ""))
            for x in ex.get("sentences", [])
        ]

    if t == "explain":
        return "study", [study(ex.get("instructionEn", ""), ex.get("instructionUz", ""))]

    # ---------- fallback: hech narsa yo'qolmaydi ----------
    # DIQQAT: bu yerga tushish — odatda XATO. Mashq turi tanilmasa, uning
    # bandlari eksportga chiqmaydi va o'quvchi kontentni ko'rmaydi.
    # Shuning uchun ogohlantirish chiqaramiz (check_content ham tekshiradi).
    if t not in KNOWN_TYPES:
        print(f"  OGOHLANTIRISH: noma'lum mashq turi '{t}' — bandlar chiqmadi",
              file=sys.stderr)
    return "study", [study(ex.get("instructionEn", ""), ex.get("instructionUz", ""))]


# ─────────────────────────── qurish ───────────────────────────
# Kitobda unitlardan tashqari QO'SHIMCHA bo'limlar bor:
#   * hikoya epizodlari  ("Episode 1: The Accident")
#   * modul testlari     ("Module Self-Assessment 1")
# Ular unit raqamiga ega emas, lekin unitlar ORASIDA turadi.
# Sahifa faylida shu maydonlar beriladi:
#   unit         — fayl nomi uchun sun'iy raqam (901+, 951+)
#   unitLabelUz  — ekranda ko'rinadigan yorliq ("1-modul testi")
#   unitBadge    — ro'yxatdagi qisqa belgi ("M1")
#   afterUnit    — qaysi unitdan keyin turishi
#   episode      — epizodlar uchun raqam (yorliq avtomatik yasaladi)
def unit_label(page):
    """Ekranda ko'rinadigan yorliq: "3-unit", "1-epizod", "1-modul testi"."""
    if page.get("unitLabelUz"):
        return page["unitLabelUz"]
    ep = page.get("episode")
    return f"{ep}-epizod" if ep else f"{page['unit']}-unit"


def unit_badge(page):
    """Ro'yxatdagi dumaloq belgi: "3", "E1", "M1"."""
    if page.get("unitBadge"):
        return page["unitBadge"]
    ep = page.get("episode")
    return f"E{ep}" if ep else str(page["unit"])


def unit_extra(page):
    """Unit emas (epizod yoki modul testi) — ro'yxatda boshqacha ko'rinadi."""
    return bool(page.get("episode")) or bool(page.get("unitLabelUz"))


def unit_order(page):
    """Ro'yxatdagi tartib. Qo'shimcha bo'lim o'z unitidan KEYIN turadi.

    Modul testi epizoddan ham keyin tursin — shuning uchun 0.5 emas 0.7.
    Aniq tartib kerak bo'lsa sahifa faylida `order` berilishi mumkin
    (masalan modul muqovasi testdan ham keyin, keyingi unitdan oldin).
    """
    if page.get("order") is not None:
        return float(page["order"])
    if unit_extra(page):
        step = 0.5 if page.get("episode") else 0.7
        return page.get("afterUnit", 0) + step
    return float(page["unit"])



def build_unit(pages):
    """Bir unitning uchala kitobdagi sahifalarini bitta unitga yig'adi.

    Kitobda unitlar orasida HIKOYA betlari ham bor ("Episode 1: The
    Accident"). Ular unit emas — shuning uchun sahifa faylida `episode`
    va `afterUnit` maydonlari beriladi. Ular `unit` sifatida 900+N
    raqamini oladi (fayl nomi uchun), lekin ekranda "1-epizod" deb
    ko'rsatiladi va ro'yxatda o'z joyida (afterUnit dan keyin) turadi.
    """
    first = pages[0]
    sections, wf, sp, voc = [], [], [], []
    seen_voc = set()

    ordered = sorted(
        pages, key=lambda p: (BOOK_ORDER.get(p["book"], 9), p["bookPage"])
    )
    for p in ordered:
        for s in p["sections"]:
            exercises = [norm_exercise(e, p) for e in s.get("exercises", [])]
            sec = {
                "id": f"u{p['unit']}-{p['book']}-{p['bookPage']}-{len(sections)}",
                "kind": s["kind"],
                "title": s.get("title", ""),
                "titleUz": s.get("titleUz") or SECTION_TITLE_UZ.get(s["kind"], ""),
                "book": p["book"],
                "bookPage": p["bookPage"],
                "exercises": exercises,
            }
            if p.get("bookPageLabel"):
                sec["pageLabel"] = p["bookPageLabel"]
            if s.get("rule"):
                sec["rule"] = s["rule"]
            sections.append(sec)

        for g in p.get("wordFormation", {}).get("groups", []):
            wf.append({
                "ruleUz": g["ruleUz"],
                "explanationUz": g.get("explanationUz", ""),
                "items": g["items"],
                "book": p["book"],
                "bookPage": p["bookPage"],
            })
        for pat in p.get("sentencePatterns", {}).get("patterns", []):
            sp.append({**pat, "book": p["book"], "bookPage": p["bookPage"]})
        for v in p.get("vocabularyOnPage", []):
            key = v["en"].lower()
            if key not in seen_voc:
                seen_voc.add(key)
                voc.append(v)

    sections.sort(key=lambda s: (
        SECTION_ORDER.index(s["kind"]) if s["kind"] in SECTION_ORDER else 99,
        BOOK_ORDER.get(s["book"], 9),
        s["bookPage"],
    ))

    return {
        "unit": first["unit"],
        "label": unit_label(first),
        "badge": unit_badge(first),
        "isExtra": unit_extra(first),
        "order": unit_order(first),
        "title": first.get("unitTitle", ""),
        "module": first.get("module", 0),
        "sections": sections,
        "wordFormation": wf,
        "sentencePatterns": sp,
        "vocabulary": voc,
    }


def main():
    by_unit = defaultdict(list)
    for f in sorted(PAGES.glob("*/p*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        if d.get("unit"):
            by_unit[d["unit"]].append(d)

    if not by_unit:
        print("Sahifa fayllari topilmadi.")
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    built = []
    for unit, pages in by_unit.items():
        built.append((unit, build_unit(pages)))
    # Ro'yxat tartibi: unit raqami bo'yicha, epizodlar o'z unitidan keyin.
    built.sort(key=lambda x: x[1]["order"])

    index = []
    for unit, u in built:
        (OUT / f"unit_{unit}.json").write_text(
            json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        kinds = defaultdict(int)
        tasks = 0
        for s in u["sections"]:
            for e in s["exercises"]:
                kinds[e["kind"]] += 1
                tasks += len(e["tasks"])
        index.append({
            "unit": unit,
            "label": u["label"],
            "badge": u["badge"],
            "isExtra": u["isExtra"],
            "order": u["order"],
            "title": u["title"],
            "module": u["module"],
            "sections": len(u["sections"]),
            "exercises": sum(len(s["exercises"]) for s in u["sections"]),
            "tasks": tasks,
        })
        print(f"{u['label']} ({u['title']}): {len(u['sections'])} bo'lim, "
              f"{sum(len(s['exercises']) for s in u['sections'])} mashq, {tasks} band")
        print(f"    turlari: {dict(kinds)}")

    (OUT / "index.json").write_text(
        json.dumps({"units": index}, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(f"\nSaqlandi -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
