// Mr. Vaysaqi uchun SERVER PROKSI (Vercel funksiyasi).
//
// Gemini kaliti FAQAT Vercel muhit o'zgaruvchisida (GEMINI_API_KEY) turadi -
// brauzerga, repoga va ilova kodiga tushmaydi. Ilova bu manzilga murojaat
// qiladi, funksiya kalitni qo'shib Google'ga uzatadi.
//
//   GET  /api/tutor  -> {ok: true|false}  (kalit sozlanganmi)
//   POST /api/tutor  -> Gemini generateContent javobi (o'zgarishsiz)

const MODELS = new Set([
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-2.0-flash',
  'gemini-2.0-flash-lite',
]);
const MAX_BODY = 40000; // belgi: suhbat tarixi + tizim ko'rsatmasi uchun yetarli
const MAX_OUT_TOKENS = 600;

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  const key = process.env.GEMINI_API_KEY;

  if (req.method === 'GET') {
    return res.status(200).json({ ok: Boolean(key) });
  }
  if (req.method !== 'POST') return res.status(405).json({ error: 'method' });
  if (!key) return res.status(503).json({ error: { message: 'AI kaliti serverda sozlanmagan' } });

  // Boshqa saytlar kvotani sarflamasin (to'liq himoya emas, lekin oddiy suiiste'molni to'sadi).
  const host = req.headers.host || '';
  const origin = req.headers.origin || '';
  if (origin && !origin.includes(host)) return res.status(403).json({ error: 'origin' });

  let body = req.body;
  try {
    if (typeof body === 'string') body = JSON.parse(body);
  } catch (_) {
    return res.status(400).json({ error: 'json' });
  }
  if (!body || typeof body !== 'object') return res.status(400).json({ error: 'body' });
  if (JSON.stringify(body).length > MAX_BODY) return res.status(413).json({ error: 'size' });

  const model = MODELS.has(body.model) ? body.model : 'gemini-2.5-flash';
  const payload = {
    system_instruction: body.system_instruction,
    contents: body.contents,
    generationConfig: {
      ...(body.generationConfig || {}),
      maxOutputTokens: Math.min(
        Number((body.generationConfig || {}).maxOutputTokens) || 400,
        MAX_OUT_TOKENS,
      ),
    },
  };

  try {
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify(payload),
      },
    );
    const text = await r.text();
    res.status(r.status).setHeader('content-type', 'application/json');
    return res.send(text);
  } catch (e) {
    return res.status(502).json({ error: { message: 'Google AI ga ulanib bo\'lmadi' } });
  }
};
