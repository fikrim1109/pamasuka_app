# Samalonian App

## Gambaran Umum
Aplikasi ini adalah aplikasi survei stok/barang untuk wilayah Telkomsel Area PAMASUKA. Aplikasi ini dirancang sebagai alat survei untuk Telkomsel PAMASUKA, dengan berbagai fitur khusus untuk mendukung pengguna dalam melakukan survei stok dan pengelolaan data.

## Fitur
- **Halaman Utama (Home Page)**: Digunakan untuk survei oleh pengguna biasa.
- **Halaman Rumah (Rumah Page)**: Untuk survei oleh superuser atau non-PJP.
- **Halaman Akun (Akun Page)**: Untuk pengaturan pertanyaan keamanan dan pengubahan kata sandi.
- **Halaman Menu (Menu Page)**: Menampilkan menu dan tampilan shared.
- **Halaman Performa (Performa Page)**: Untuk melihat performa pengguna SF.
- **Tema Aplikasi (App Theme)**: Memudahkan perpindahan dari mode gelap ke mode terang.
- **Halaman Lihat Formulir (View Form)**: Untuk melihat formulir yang telah disubmit.
- **Halaman Edit Formulir (Edit Form)**: Untuk mengedit formulir, dengan akses harus melalui Performa Page terlebih dahulu.

## Prasyarat
Pastikan Anda memiliki hal berikut sebelum memulai:
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (versi 3.0 atau lebih tinggi disarankan)
- [Dart](https://dart.dev/get-dart) (termasuk bersama Flutter)
- Editor kode seperti [VS Code](https://code.visualstudio.com/) atau [Android Studio](https://developer.android.com/studio)
- Git untuk mengkloning repositori

## Instruksi Pengaturan
Ikuti langkah-langkah berikut untuk mengunduh dan menjalankan Samalonian App di komputer lokal Anda:

1. **Kloning Repositori**
   Buka terminal dan jalankan perintah berikut untuk mengkloning proyek:
   ```bash
   git clone <url-repositori>
   ```
   Ganti `<url-repositori>` dengan URL aktual repositori Samalonian App.

2. **Masuk ke Direktori Proyek**
   Pindah ke direktori proyek:
   ```bash
   cd samalonian_app
   ```

3. **Pasang Dependensi**
   Jalankan perintah berikut untuk memasang dependensi Flutter yang diperlukan:
   ```bash
   flutter pub get
   ```

4. **Jalankan Aplikasi**
   Hubungkan perangkat atau mulai emulator, lalu jalankan aplikasi dengan:
   ```bash
   flutter run
   ```
   Ini akan meluncurkan Samalonian App di perangkat atau emulator Anda.

## Struktur Proyek
Berikut adalah gambaran singkat file utama dalam proyek:
- `main.dart`: Titik masuk aplikasi.
- `app_theme.dart`: Mendefinisikan tema aplikasi untuk mode terang dan gelap.
- `theme_provider.dart`: Mengelola logika perubahan tema.
- `currency_input_formatter.dart`: Menangani pemformatan input mata uang.
- `login_page.dart`, `home_page.dart`, `editform_page.dart`, dll.: Halaman UI untuk berbagai fungsi aplikasi.

## Kontribusi
Silakan fork repositori dan ajukan pull request. Untuk perubahan besar, buka terlebih dahulu isu untuk mendiskusikan apa yang ingin Anda ubah.

## Lisensi
Proyek ini dilisensikan di bawah Lisensi MIT - lihat file [LICENSE](LICENSE) untuk detailnya.