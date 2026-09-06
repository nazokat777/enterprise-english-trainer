# Kitob betlari (bo'sh)

Bu papka **ataylab bo'sh**. Enterprise darsligi mualliflik huquqi bilan
himoyalangan, shuning uchun uning betlari ilova bilan birga tarqatilmaydi.

Agar o'zingiz sotib olgan kitobning betlarini shu yerga qo'ysangiz,
ilovada "Kitob betini ko'rish" tugmasi paydo bo'ladi.

Fayl nomi qoidasi:

    <kitob>_<bet>.jpg

Masalan:

    coursebook_6.jpg
    grammar_4.jpg
    workbook_5.jpg

Fayl bo'lmasa tugma ko'rsatilmaydi va mashqlar tavsiflar bilan
normal ishlayveradi.

## Siqish

Betlar JPEG **sifat 85** bilan saqlanadi (o'lchami o'zgarmaydi, ~1600x2080).
Bu asl skanlarga qaraganda ~45% kichik: 216 MB -> 118 MB. Mayda matn,
nuqtali chiziqlar va strelkalar 2x kattalashtirilganda ham asl nusxadan
farq qilmaydi — tekshirilgan.

Siqishdan OLDINGI nusxalar `assets/book_pages_original/` da turadi.
U papka `.gitignore` da va `pubspec.yaml` da yo'q — ya'ni na git'ga,
na build'ga chiqadi. Yangi betlar qo'shsangiz, o'sha yerga ham asl
nusxasini qo'ying.

Qayta siqish (kerak bo'lsa):

```python
from PIL import Image
im = Image.open(src).convert('RGB')
im.save(dst, 'JPEG', quality=85, optimize=True, progressive=True)
```

