# [Uchar](https://github.com/uchar-org/cross) loyihasini Windows'da build qilish
Flutter'da qurilgan loyihalarni Windows'da build qilishda yaxshigina muammolarga duch keldim. Shu tufayli tutorialni ham yozib o'tmoqdaman. Barcha kerakli dependency'larni maqolaning so'nggida havolalari bilan birga topishingiz mumkin.

## Dependency'larni o'rnatish
Har bir dasturni ishga tushirish, ayniqsa ishlab chiqish jarayonida kerakli dependency'larni o'rnatish kerak bo'ladi. Hozir shuni ko'rib chiqamiz

### 1. VCRedist All In One
Windows uchun fundamental C++ library. Buni o'rnatish har qanday holatda qat'iy. Quyidagi link orqali VCRedist'ni yuklab olamiz va u .zip formatda bo'ladi. So'ng uni alohida papkaga extract qilvolamiz va `install_all.bat` script'ini ishga tushirish orqali o'rnatamiz. [VCRedist AIO](https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/)

### 2. Windows Development Dependencies
Bu orqali biz Windows'ga dasturlar qurishimiz mumkin. Hozirda Visual Studio 2026 aktual, lekin bizga eski versiyadagi dependency'lar kerak. Shu tufayli norasmiy manbadan 2022-yilgi versiyani olamiz. [Visual Studio 2022](https://aka.ms/vs/17/release/vs_community.exe)

### 3. NuGet
Windows Development uchun .NET ham keng qo'llangani sababli uning package manager'i NuGet'ga ham ishimiz tushadi. Uni ham quyidagi link'dan olishingiz mumkin. [NuGet](https://www.nuget.org/downloads)

### 4. NASM
Bizga keyinchalik OpenSSL kerak bo'ladi. Uni compile qilish uchun kerakli library. [NASM](https://www.nasm.us/pub/nasm/releasebuilds/3.01/win64/nasm-3.01-installer-x64.exe)

### 5. OpenSSL
Uchar ma'lumotlar almashinishi uchun Matrix protocol'ini ishlatadi, shifrlash uchun esa Vodozemak. Shunday ekan, Vodozemakka shifrlash uchun kriptografik library kerak, ya'ni OpenSSL. Uni ham quyidagi link orqali olishingiz mumkin. [OpenSSL](https://slproweb.com/download/Win64OpenSSL-3_6_1.msi) 

### 6. Rustup
Nega Rust (rustc) emas? Chunki bizga [external crates](https://crates.io) (tashqi paketlar) ham kerak bo'ladi. Xususan, [Matrix SDK](https://github.com/matrix-org/matrix-rust-sdk) to'laqonli Rustda yozilgan. [Rustup](https://rustup.rs)

## Flutter
"Flutterni qanday o'rnataman? 😰" deb bosh qotirishingiz mumkin. Muammo yo'q, mana bu yerdan o'rganib keling - [Flutter'ni Windowsga o'rnatish](https://docs.flutter.dev/install/quick)

## Ucharni build qilish
[Uchar-org](https://github.com/uchar-org)'dan [cross](https://github.com/uchar-org/cross) reposini olib, `uchar/app/latest` branchini aktiv qilib olamiz. So'ng quyidagi commands'ni ketma-ket yozib boramiz.

```bash
$ flutter run -d windows
# <app is running>
```

### Nega buncha qisqa?
Chunki bu command'ning o'zi barcha kerakli ishlarni qiladi. Masalan, paketlarni o'rnatish, yuklash, build, ishga tushirish va hokazo.

## Havolalar
Bu yerda siz barcha ishlatilgan havolalarni ko'rishingiz mumkin
- [VCRedist AIO](https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/)
- [Visual Studio Installer 2022](https://aka.ms/vs/17/release/vs_community.exe)
- [NuGet](https://www.nuget.org/downloads)
- [OpenSSL](https://slproweb.com/download/Win64OpenSSL-3_6_1.msi)
- [NASM](https://www.nasm.us/pub/nasm/releasebuilds/3.01/win64/nasm-3.01-installer-x64.exe)
- [Rustup](https://rustup.rs)
