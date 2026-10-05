"""O'QILIShI: kitob so'zlarining o'zbek harflaridagi talaffuzi.

Ilgari ilova so'z imlosidan "taxmin" qilardi (`approxSound`) - inglizcha
imlo talaffuzni bildirmaydi, natija ko'pincha xato edi ("married" ->
"marrid"). Endi CMU talaffuz lug'atidan (126 000 so'z, ochiq litsenziya)
haqiqiy fonemalar olinadi va o'zbek harflariga o'giriladi:

  * urg'uli unli ustiga belgi (´): "kettle" -> "kétl" emas, "kétal";
  * darslik va ovoz BRITAN inglizchasida - unlidan keyingi R
    aytilmaydi ("car" -> "ká");
  * lug'atda bo'lmagan so'z uchun yozilmaydi (noto'g'ri ko'rsatgandan
    ko'ra ko'rsatmagan yaxshi - ovoz tugmasi baribir bor).

Natija: enterprise-app/assets/tts/pron.json  {kichik_harf_matn: "o'qilishi"}

  python -m ingest.gen_pron
"""
from __future__ import annotations

import glob
import json
import re
from pathlib import Path

import cmudict

HERE = Path(__file__).resolve().parent
APP = HERE.parent.parent / "enterprise-app"
CONTENT = APP / "assets" / "content"
OUT = APP / "assets" / "tts" / "pron.json"
LEVELS = ["enterprise1", "enterprise2"]

VOWELS = {
    "AA": "a", "AE": "e", "AH": "a", "AO": "o", "AW": "au", "AY": "ay",
    "EH": "e", "ER": "ö", "EY": "ey", "IH": "i", "IY": "i", "OW": "ou",
    "OY": "oy", "UH": "u", "UW": "u",
}
CONS = {
    "B": "b", "CH": "ch", "D": "d", "DH": "z", "F": "f", "G": "g", "HH": "h",
    "JH": "j", "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ng", "P": "p",
    "R": "r", "S": "s", "SH": "sh", "T": "t", "TH": "s", "V": "v", "W": "w",
    "Y": "y", "Z": "z", "ZH": "j",
}
# Gap ichidagi kuchsiz shakllar (lug'atning to'liq shakli emas).
WEAK = {"a": "a", "an": "an", "the": "za", "of": "av", "to": "tu",
        "and": "end", "for": "fo", "at": "et", "from": "from"}
ACUTE = {"a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú"}


def norm_key(s: str) -> str:
    """Kalit: kichik harf, faqat harf/apostrof/bo'shliq (Dart bilan bir xil)."""
    s = re.sub(r"[^a-z' ]", " ", s.lower())
    return re.sub(r"\s+", " ", s).strip()


def phones_to_uz(phones: list[str]) -> str:
    out: list[str] = []
    n = len(phones)
    # Bir nechta asosiy urg'u bo'lsa - oxirgisi qoladi ("engineer").
    prim = [i for i, p in enumerate(phones) if p.endswith("1")]
    keep = prim[-1] if prim else -1
    for i, p in enumerate(phones):
        base = re.sub(r"\d", "", p)
        stress = p[-1] if p[-1].isdigit() else ""
        if base in VOWELS:
            v = VOWELS[base]
            # Urg'usiz ER - britancha "ə": "teacher" -> "tíchə" ~ "tícha".
            if base == "ER" and stress != "1":
                nxt = re.sub(r"\d", "", phones[i + 1]) if i + 1 < n else ""
                v = "ar" if nxt in VOWELS else "a"
            if stress == "1" and i == keep and v[0] in ACUTE:
                v = ACUTE[v[0]] + v[1:]
            out.append(v)
        elif base == "R":
            # Britancha: R faqat keyin unli kelsa aytiladi.
            nxt = re.sub(r"\d", "", phones[i + 1]) if i + 1 < n else ""
            if nxt in VOWELS:
                out.append("r")
            else:
                # pair -> "pea", here -> "hia", tour -> "tua" (britancha).
                prv = re.sub(r"\d", "", phones[i - 1]) if i > 0 else ""
                if prv in ("EH", "IH", "IY", "UH", "UW"):
                    out.append("a")
        elif base in CONS:
            out.append(CONS[base])
    s = "".join(out)
    # Bir bo'g'inli so'zda urg'u belgisi kerak emas.
    if sum(1 for p in phones if re.sub(r"\d", "", p) in VOWELS) <= 1:
        for k, v in ACUTE.items():
            s = s.replace(v, k)
    return s


def main() -> int:
    d = cmudict.dict()
    words: set[str] = set()
    for lvl in LEVELS:
        for f in glob.glob(str(CONTENT / lvl / "unit_*.json")):
            j = json.loads(Path(f).read_text(encoding="utf-8"))
            for v in j.get("vocabulary", []):
                en = re.sub(r"\s+", " ", (v.get("en") or "").strip())
                if en:
                    words.add(en)
    out: dict[str, str] = {}
    miss = 0
    for en in sorted(words):
        parts = re.findall(r"[A-Za-z']+", en)
        if not parts or len(parts) > 6:
            continue
        res = []
        for w in parts:
            if w.lower() in WEAK:
                res.append(WEAK[w.lower()])
                continue
            prons = d.get(w.lower())
            if not prons:
                res = None
                break
            res.append(phones_to_uz(prons[0]))
        if res is None:
            miss += 1
            continue
        out[norm_key(en)] = " ".join(res)
    OUT.write_text(json.dumps(out, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    print(f"{len(out)} ta so'z o'qilishi; lug'atda yo'q: {miss}")
    for k in ["thank you", "kettle", "married", "car", "teacher", "beautiful", "engineer", "ice cream", "bird", "thank you"]:
        print(f"  {k}: {out.get(k)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
