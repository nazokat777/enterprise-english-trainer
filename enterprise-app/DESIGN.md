# Enterprise English Trainer — dizayn tizimi

Manba kodi: `lib/theme.dart`, `lib/widgets/hover_lift.dart`, `lib/widgets/geo_bg.dart`.
Har yangi ekran shu tokenlardan foydalanadi — "raw" rang/radius yozilmaydi.

## Ranglar
| Token | Qiymat | Qayerda |
|---|---|---|
| `AppColors.brandPurple / brandIndigo / brandCyan` | 7C3AED / 4F46E5 / 06B6D4 | brend |
| `AppColors.brandGradient` | binafsha → indigo → moviy | hero, faol menyu, nishonlar, ovoz tugmasi |
| `AppColors.goldGradient` | sariq → olov → pushti | rekord, imtihon o'tdi, benuqson |
| `AppColors.successGradient` | yashil → teal | tugallangan, trening |
| `AppColors.success / danger / coin / homework` | funksional | to'g'ri / xato / tanga / olov |
| `AppColors.surface(ctx) / surface2 / border(ctx) / muted(ctx)` | rejimga qarab | kartalar, chegara, ikkilamchi matn |
| Dark: `darkBg` 0F1117, `darkSurface` 1A1D27 | chuqur ko'k-qora | tungi rejim |

## Tipografika
- Sarlavhalar: **Manrope** 800 (`textTheme.headline*`, `AppTheme.heading/display`), letter-spacing manfiy.
- Matn: **Inter** (body), 16px / 1.5.
- Katta so'z (tanishuv kartasi): `displaySmall` 38px, `GradientText`.

## Shakl va chuqurlik
- Radius: `AppRadius.sm 10 · md 14 · lg 20 · xl 28 · pill`.
- Soya: `AppShadow.card(ctx)` (ambient + key), rangli nur `AppShadow.glow(color)`.
- Karta: `SurfaceCard` = yuza + chegara + soya; bosiladigan bo'lsa `HoverLift` avtomatik.
- Fon: `GeoBackground` — aurora mesh (statik, 4 xira bulut).

## Komponentlar
- `GradientBadge` — ikonka/raqam nishoni (unit, sidebar logotipi).
- `BentoTile` (book_screens.dart) — gradient plitka + progress halqa (So'zlar / Trening).
- `OptionTile` (drill_screen.dart) — javob varianti: raqam, katta matn, right/wrong/dim holatlari.
- `Pressable3D` — 3D tugma: hover'da 1px ko'tariladi, rangli soya; neytral rangda kulrang soya.
- `DrillCard` — savol kartasi (xl radius, chegara, soya).
- Natija kartalari (dars/Blitz/imtihon): gradient (gold/success/olov) + `elasticOut` nishon; benuqson → `ConfettiBurst`.

## Harakat
- Kirish: `EntranceFade` (460 ms, stagger 40–60 ms).
- Hover: 160 ms `easeOutCubic`, scale 1.015; bosish 0.98.
- Karta almashish: `AnimatedSwitcher` 260 ms fade + 6% slide.
- Halqalar: `TweenAnimationBuilder` 900–1100 ms `easeOutCubic`.
- Testlar uchun cheksiz `repeat()` YO'Q — `repeat(count:)`.

## Atamalar (xalqaro)
Avatar (Spark → Star → Nova → Comet → Orbit → Aurora → Nebula → Cosmos), Bonus box / Mega bonus,
Power Hour, Lucky Spin, missiyalar, Blitz, Imtihon. "Tuxum", "uchqun", "sandiq", "g'ildirak" ishlatilmaydi.
