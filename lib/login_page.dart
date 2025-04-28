// File: lib/login_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/menu_page.dart';
import 'package:pamasuka/lupapage.dart';
import 'package:google_fonts/google_fonts.dart';

const String _apiBaseUrl = 'https://tunnel.jato.my.id/test%20api';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFFC0392B);

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _login() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Nama pengguna dan kata sandi harus diisi.', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() { _isLoading = true; });

    final url = Uri.parse('$_apiBaseUrl/login.php');

    try {
      final response = await http.post(
        url,
        body: {
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.toLowerCase().contains('application/json')) {
        if (response.statusCode == 200) {
          _showSnackBar('Respons server tidak dalam format JSON yang diharapkan.', isError: true);
          print("Server Response (Status 200, Not JSON): ${response.body}");
        } else {
          _showSnackBar('Kesalahan server: ${response.statusCode}. Format respons tidak dikenal.', isError: true);
          print("Server Error Response (${response.statusCode}, Not JSON): ${response.body}");
        }
        return;
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['success'] is bool && data['success'] == true) {
            final String responseUsername = data['username']?.toString() ?? 'Pengguna';
            final int userId = data['userId'] is int
                ? data['userId']
                : int.tryParse(data['userId']?.toString() ?? '') ?? 0;

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MenuPage(
                  username: responseUsername,
                  userId: userId,
                ),
              ),
            );
          } else {
            final String message = data['message']?.toString() ?? 'Login gagal. Periksa kembali kredensial Anda.';
            _showSnackBar(message, isError: true);
          }
        } on FormatException catch (e) {
          _showSnackBar('Format respons dari server tidak valid.', isError: true);
          print("JSON Decode Error: $e. Response body: ${response.body}");
        } catch (e) {
          _showSnackBar('Kesalahan saat memproses data login: ${e.toString()}', isError: true);
          print("Data processing error: $e");
        }
      } else {
        String errorMessage = 'Kesalahan server: ${response.statusCode}.';
        try {
          final errorData = json.decode(response.body);
          errorMessage += ' Pesan: ${errorData['message'] ?? 'Tidak ada pesan tambahan.'}';
        } catch (_) {
          errorMessage += ' Silakan coba lagi nanti.';
        }
        _showSnackBar(errorMessage, isError: true);
        print("Server error response (${response.statusCode}): ${response.body}");
      }
    } on TimeoutException {
      if (!mounted) return;
      _showSnackBar('Koneksi ke server time out. Periksa koneksi internet Anda.', isError: true);
    } on http.ClientException catch (e) {
      if (!mounted) return;
      _showSnackBar('Kesalahan koneksi: ${e.message}', isError: true);
      print("Network ClientException: $e");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan tak terduga: ${e.toString()}', isError: true);
      print("Login general error: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'images/Samalonian_app.png',
                  height: MediaQuery.of(context).size.height * 0.15,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading logo: $error");
                    return Icon(Icons.image_not_supported_rounded, size: 80, color: Colors.grey.shade400);
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Selamat Datang',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk melanjutkan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            enabled: !_isLoading,
                            style: GoogleFonts.poppins(),
                            decoration: _inputDecoration('Nama Pengguna', Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !_isLoading,
                            style: GoogleFonts.poppins(),
                            onSubmitted: (_) {
                              if (!_isLoading) _login();
                            },
                            decoration: _inputDecoration('Kata Sandi', Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Masuk'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LupaPasswordPage()),
                                  );
                                },
                          child: Text(
                            'Lupa Kata Sandi?',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _isLoading ? Colors.grey.shade400 : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.transparent, // Transparan karena warna diatur di Container
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}