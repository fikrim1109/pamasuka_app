import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import untuk SystemUiOverlayStyle jika diperlukan
import 'package:pamasuka/rumah_page.dart'; // Pastikan path import benar
import 'home_page.dart'; // Pastikan path import benar
import 'login_page.dart'; // Pastikan path import benar

class MenuPage extends StatelessWidget {
  final String username;
  final int userId;
  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar disesuaikan dengan HomePage
      appBar: AppBar(
        title: const Text(
          'Samalonian APP',
          style: TextStyle(
            color: Colors.white, // Warna teks AppBar jadi putih
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent, // Warna background AppBar disamakan
        elevation: 2, // Anda bisa sesuaikan elevasinya
        // Optional: Atur warna ikon status bar jika perlu
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
           statusBarColor: Colors.transparent, // Transparan agar menyatu dengan AppBar
           statusBarIconBrightness: Brightness.light, // Ikon status bar (wifi, baterai) jadi putih
        ),
        // Optional: Jika ada ikon lain di AppBar (misal back button otomatis), atur warnanya
         iconTheme: const IconThemeData(
           color: Colors.white, // Warna ikon di AppBar jadi putih
         ),
      ),
      // Body dengan gradient background (sudah sesuai)
      body: Container(
        width: double.infinity, // Pastikan gradient memenuhi layar
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFB6B6), // Warna gradient atas (sama dengan HomePage)
              Color(0xFFFF8E8E), // Warna gradient bawah (sama dengan HomePage)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Pusatkan konten secara vertikal
            crossAxisAlignment: CrossAxisAlignment.center, // Pusatkan konten secara horizontal
            children: [
              // App logo/image (Akan terpusat karena Column diatur center)
              Image.asset(
                'images/Samalonian APP.png', // Pastikan path gambar benar
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              // Welcome message (textAlign sudah center, dan widgetnya akan center)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0), // Padding agar teks tidak mepet
                child: Text(
                  'Selamat datang,\n$username!', // \n untuk baris baru jika nama panjang
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B3A3A), // Warna abu tua
                    letterSpacing: 0.5,
                    shadows: [ // Shadow tipis agar lebih menonjol
                      Shadow(
                        blurRadius: 6.0,
                        color: Colors.black38,
                        offset: Offset(1.5, 1.5),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center, // Ini penting untuk teks multi-baris
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle (textAlign sudah center, dan widgetnya akan center)
              const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 20.0),
                 child: Text(
                  'Pilih menu di bawah untuk melanjutkan',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF3B3A3A), // Warna abu tua
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center, // Ini penting untuk teks multi-baris
                             ),
               ),
               // const Spacer(), // <-- SPACER DIHAPUS DARI SINI AGAR BENAR-BENAR CENTER
            ],
          ),
        ),
      ),
      // Bottom navigation bar
      bottomNavigationBar: Material(
        elevation: 10,
        color: Colors.white, // Pastikan background putih
        child: BottomNavBar(username: username, userId: userId),
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;

  const BottomNavBar({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Tidak perlu color lagi karena sudah di Material parent-nya
      padding: const EdgeInsets.symmetric(vertical: 8), // Padding vertikal
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribusi merata
        children: [
          _NavBarItem(
            icon: Icons.store_mall_directory_outlined, // Contoh ikon lain
            label: 'Outlet PJP',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(username: username, userId: userId),
                ),
              );
            },
          ),
          _NavBarItem(
            icon: Icons.home_work_outlined, // Contoh ikon lain
            label: 'Outlet Non PJP',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RumahPage(username: username, userId: userId),
                ),
              );
            },
          ),
          _NavBarItem(
            icon: Icons.logout, // Ikon logout
            label: 'Logout',
            onTap: () {
              // Tambahkan dialog konfirmasi sebelum logout (Best Practice)
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), // Tutup dialog
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                         Navigator.pop(context); // Tutup dialog
                         Navigator.pushAndRemoveUntil( // Lakukan logout
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false, // Hapus semua route sebelumnya
                        );
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavBarItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded( // Pastikan item mengisi ruang yang sama
      child: InkWell( // Efek ripple saat disentuh
        onTap: onTap,
        splashColor: Colors.red.withOpacity(0.1), // Warna splash disesuaikan
        highlightColor: Colors.red.withOpacity(0.05), // Warna highlight disesuaikan
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10), // Padding dalam item
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ukuran kolom secukupnya
            children: [
              Icon(
                icon,
                color: Colors.redAccent, // Warna ikon disamakan dengan AppBar
                size: 28, // Ukuran ikon
              ),
              const SizedBox(height: 6), // Jarak ikon ke teks
              Text(
                label,
                textAlign: TextAlign.center, // Teks di tengah
                style: const TextStyle(
                  fontSize: 13, // Sedikit lebih kecil agar rapi
                  color: Colors.black87, // Warna teks standar
                  fontWeight: FontWeight.w500, // Sedikit tebal
                ),
                maxLines: 1, // Pastikan label 1 baris
                overflow: TextOverflow.ellipsis, // Jika terlalu panjang, beri elipsis
              ),
            ],
          ),
        ),
      ),
    );
  }
}