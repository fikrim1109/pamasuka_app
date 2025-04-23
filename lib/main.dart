// lib/main.dart
import 'package:flutter/material.dart';
import 'package:pamasuka/login_page.dart'; // Pastikan path ini benar

// --- DEFINISIKAN RouteObserver DI SINI ---
// Buat instance RouteObserver yang bisa diakses secara global
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
// --- ---

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Champions', // Sesuaikan judul jika perlu
      theme: ThemeData(
        // Ganti primarySwatch jika Anda ingin warna tema lain
        primarySwatch: Colors.red, // Contoh: menggunakan merah seperti di halaman lain
        visualDensity: VisualDensity.adaptivePlatformDensity, // Tambahkan ini
      ),
      // --- DAFTARKAN RouteObserver DI SINI ---
      navigatorObservers: [routeObserver],
      // --- ---
      home: const LoginPage(), // Halaman awal Anda
      debugShowCheckedModeBanner: false, // Opsional: sembunyikan banner debug
    );
  }
}