"""Sifatli TALAFFUZ: neural ovoz (Microsoft Edge TTS, bepul) bilan
so'zlar va namunaviy gaplarni oldindan MP3 qilib yozadi.

Brauzerning o'z TTS'i (flutter_tts) qurilmaga qarab juda sun'iy yoki
o'zbek/rus talaffuzi bilan o'qiydi. Bu skript:
  * ikkala darajaning unit lug'ati (`vocabulary[].en`), lug'at misol
    gaplari, gap qoliplari (`sentencePatterns[].exampleEn`) uchun
  * `en-GB-SoniaNeural` (darslik Britan inglizchasida) ovozida
  * `enterprise-app/web/tts/<fnv1a64>.mp3` fayllarini yozadi (oddiy web
    fayl — asset emas, aks holda build/test juda sekinlashadi),
  * `assets/tts/index.json` — mavjud kalitlar ro'yxati (asset).

Ilova (`lib/services/tts.dart`) matn kalitini xuddi shu FNV-1a bilan
hisoblaydi: fayl bo'lsa MP3, bo'lmasa brauzer TTS.

Ishga tushirish (uzoq, ~1 soat; qayta ishga tushirilsa bor fayllarni
o'tkazib yuboradi):
  python -m ingest.gen_audio
  python -m ingest.gen_audio --only-missing --concurrency 6
"""
from __future__ import annotations

import argparse
import asyncio
import glob
import json
import re
import subprocess
import shutil
from pathlib import Path

import edge_tts

HERE = Path(__file__).resolve().parent
APP = HERE.parent.parent / "enterprise-app"
CONTENT = APP / "assets" / "content"
OUT = APP / "web" / "tts"  # oddiy web fayllar (asset emas)
INDEX = APP / "assets" / "tts" / "index.json"
VOICE = "en-GB-SoniaNeural"
RATE = "-12%"  # o'rganuvchi uchun sal sekinroq
LEVELS = ["enterprise1", "enterprise2"]


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def key_of(text: str) -> str:
    """FNV-1a 64 — Dart tomonida ham xuddi shunday (tts.dart)."""
    h = 0xCBF29CE484222325
    for b in norm(text).lower().encode("utf-8"):
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def collect() -> dict[str, str]:
    texts: dict[str, str] = {}

    def add(s: str | None):
        if not s:
            return
        s = norm(s)
        if not re.search(r"[A-Za-z]", s) or len(s) > 160:
            return
        texts.setdefault(key_of(s), s)

    # Ilovadagi doimiy matnlar (sozlamalardagi sinov tugmasi va h.k.)
    for extra in ["Hello! How are you?"]:
        add(extra)
    for lvl in LEVELS:
        for f in glob.glob(str(CONTENT / lvl / "unit_*.json")):
            d = json.loads(Path(f).read_text(encoding="utf-8"))
            for v in d.get("vocabulary", []):
                add(v.get("en"))
                add(v.get("example"))
            for sp in d.get("sentencePatterns", []):
                # Bir necha gap bo'lsa — birinchi ikkitasi
                for part in re.split(r"(?<=[.!?])\s+", sp.get("exampleEn", ""))[:2]:
                    add(part)
    return texts


async def synth(sem: asyncio.Semaphore, key: str, text: str, tmp: Path, ffmpeg: str | None):
    async with sem:
        dst = OUT / f"{key}.mp3"
        if dst.exists() and dst.stat().st_size > 200:
            return "skip"
        raw = tmp / f"{key}.raw.mp3"
        for attempt in range(3):
            try:
                com = edge_tts.Communicate(text, VOICE, rate=RATE)
                await com.save(str(raw))
                break
            except Exception as e:  # noqa: BLE001
                if attempt == 2:
                    print(f"XATO {key}: {text[:40]} -> {e}")
                    return "fail"
                await asyncio.sleep(1.5 * (attempt + 1))
        if not raw.exists():
            return "fail"
        if ffmpeg:
            # 32 kbps mono — so'z/gap uchun yetarli, hajm 2 barobar kam.
            r = subprocess.run(
                [ffmpeg, "-y", "-loglevel", "error", "-i", str(raw), "-ac", "1",
                 "-ar", "24000", "-b:a", "32k",
                 # Boshidagi sukunatni kesish — tugma bosilishi bilan eshitilsin.
                 "-af", "silenceremove=start_periods=1:start_threshold=-45dB",
                 str(dst)],
                capture_output=True,
            )
            try:
                if r.returncode != 0 or not dst.exists():
                    shutil.move(str(raw), str(dst))
                else:
                    raw.unlink(missing_ok=True)
            except OSError as e:
                print(f"XATO (fayl) {key}: {e}")
                return "fail"
        else:
            try:
                shutil.move(str(raw), str(dst))
            except OSError as e:
                print(f"XATO (fayl) {key}: {e}")
                return "fail"
        return "ok"


async def main_async(a) -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = OUT / "_tmp"
    tmp.mkdir(exist_ok=True)
    texts = collect()
    print(f"{len(texts)} ta matn; ovoz {VOICE}")
    ffmpeg = shutil.which("ffmpeg")
    sem = asyncio.Semaphore(a.concurrency)
    items = list(texts.items())
    if a.limit:
        items = items[: a.limit]
    done = 0
    stats = {"ok": 0, "skip": 0, "fail": 0}
    # Partiyalar bilan — progress ko'rinsin, index vaqti-vaqti bilan yozilsin.
    for i in range(0, len(items), 200):
        batch = items[i:i + 200]
        res = await asyncio.gather(*(synth(sem, k, t, tmp, ffmpeg) for k, t in batch))
        for r in res:
            stats[r] += 1
        done += len(batch)
        write_index()
        print(f"  {done}/{len(items)}  ok={stats['ok']} skip={stats['skip']} fail={stats['fail']}", flush=True)
    shutil.rmtree(tmp, ignore_errors=True)
    write_index()
    print("tayyor:", stats)
    return 0


def write_index():
    keys = sorted(p.stem for p in OUT.glob("*.mp3") if p.stat().st_size > 200)
    INDEX.parent.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps(keys), encoding="utf-8")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--concurrency", type=int, default=6)
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args(argv)
    return asyncio.run(main_async(a))


if __name__ == "__main__":
    raise SystemExit(main())
