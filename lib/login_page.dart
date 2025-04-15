// File: lib/login_page.dart
import 'dart:async'; // Import for Timer/TimeoutException
import 'dart:convert'; // Import for jsonDecode, jsonEncode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/menu_page.dart'; // Ensure this import path is correct for your project
import 'package:pamasuka/lupapage.dart'; // Ensure this import path is correct for your project

// --- Base URL for API calls ---
// ** IMPORTANT: Keeping URL as requested. Consider using a name without spaces like 'test_api' on the server if possible in the future. **
const String _apiBaseUrl = 'https://tunnel.jato.my.id/test%20api'; // Kept as requested
// ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Define colors consistently
  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B);

  // --- Helper Function to Show Snack Bar ---
  void _showSnackBar(String message, {bool isError = false}) {
    // Check if the widget is still in the tree before showing Snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Added shape
        margin: const EdgeInsets.all(10), // Added margin
      ),
    );
  }

  // --- Login Function ---
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
        // Sending as form data (matches PHP checking $_POST)
        body: {
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 20)); // Increased timeout slightly

      if (!mounted) return; // Check again after await

      // FIX: Added Content-Type check before attempting JSON decode
      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.toLowerCase().contains('application/json')) {
         // Handle cases where server responds with 200 OK but non-JSON body (e.g., HTML error)
         if (response.statusCode == 200) {
             _showSnackBar('Respons server tidak dalam format JSON yang diharapkan.', isError: true);
             print("Server Response (Status 200, Not JSON): ${response.body}");
         } else {
             // Handle non-200 error responses (likely HTML or plain text)
             _showSnackBar('Kesalahan server: ${response.statusCode}. Format respons tidak dikenal.', isError: true);
             print("Server Error Response (${response.statusCode}, Not JSON): ${response.body}");
         }
         return; // Exit processing
      }

      // Process response only if it's likely JSON
      if (response.statusCode == 200) {
        // FIX: Added specific try-catch for JSON decoding and processing
        try {
          final data = json.decode(response.body);

          // Ensure 'success' key exists and is a boolean
          if (data['success'] is bool && data['success'] == true) {
            // FIX: Added .toString() for extra safety before null check/fallback
            final String responseUsername = data['username']?.toString() ?? 'Pengguna';
            // Safer userId parsing (already good)
            final int userId = data['userId'] is int
                ? data['userId']
                : int.tryParse(data['userId']?.toString() ?? '') ?? 0;

            if (!mounted) return; // Check before navigation

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
            // Handle cases where 'success' is false or missing/not boolean
            final String message = data['message']?.toString() ?? 'Login gagal. Periksa kembali kredensial Anda.';
            _showSnackBar(message, isError: true);
          }
        } on FormatException catch (e) {
          _showSnackBar('Format respons dari server tidak valid.', isError: true);
          print("JSON Decode Error: $e. Response body: ${response.body}");
        } catch (e) {
          // Catch other potential errors during data processing (e.g., accessing missing keys unexpectedly)
          _showSnackBar('Kesalahan saat memproses data login: ${e.toString()}', isError: true);
          print("Data processing error: $e");
        }
      } else {
        // Handle non-200 status codes more gracefully, attempting to decode JSON error message if possible
        String errorMessage = 'Kesalahan server: ${response.statusCode}.';
        try {
            final errorData = json.decode(response.body);
            errorMessage += ' Pesan: ${errorData['message'] ?? 'Tidak ada pesan tambahan.'}';
        } catch (_) {
            // If response body is not JSON, just show the status code
             errorMessage += ' Silakan coba lagi nanti.';
        }
         _showSnackBar(errorMessage, isError: true);
         print("Server error response (${response.statusCode}): ${response.body}");
      }
    } on TimeoutException {
        if (!mounted) return;
        _showSnackBar('Koneksi ke server time out. Periksa koneksi internet Anda.', isError: true);
    } on http.ClientException catch (e) { // Catch specific network errors
        if (!mounted) return;
        _showSnackBar('Kesalahan koneksi: ${e.message}', isError: true);
        print("Network ClientException: $e");
    } catch (e) {
      // Catch other unexpected errors (e.g., socket exceptions, general errors)
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan tak terduga: ${e.toString()}', isError: true);
      print("Login general error: $e");
    } finally {
      // Ensure loading state is turned off only if the widget is still mounted
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
      body: Container(
         width: double.infinity,
         height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20), // Added vertical padding
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // IMPROVEMENT: Added comment recommending asset constants
                  // Consider managing asset paths in a separate constants file (e.g., lib/constants/app_assets.dart)
                  // for better maintainability. Example: Image.asset(AppAssets.logo, ...)
                  Image.asset(
                    'images/Samalonian_app.png', // Ensure path is correct and in pubspec.yaml
                    height: MediaQuery.of(context).size.height * 0.18, // Adjusted height slightly
                    errorBuilder: (context, error, stackTrace) {
                       print("Error loading logo: $error");
                       return Icon(Icons.image_not_supported_rounded, size: 100, color: Colors.grey.shade700);
                    }
                  ),
                  const SizedBox(height: 28), // Adjusted spacing
                  Card(
                    elevation: 6,
                    color: const Color(0xFFFFF5F5).withOpacity(0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: startColor.withOpacity(0.6), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Center(
                            child: Text('Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor))),
                          const SizedBox(height: 24), // Adjusted spacing
                          TextField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            // FIX: Disable field when loading
                            enabled: !_isLoading,
                            decoration: _inputDecoration('Nama Pengguna', Icons.person_outline),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            // FIX: Disable field when loading
                            enabled: !_isLoading,
                            onSubmitted: (_) {
                              if (!_isLoading) _login(); // Allow login via keyboard action
                            },
                            decoration: _inputDecoration('Kata Sandi', Icons.lock_outline),
                          ),
                          const SizedBox(height: 28), // Adjusted spacing
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login, // Correctly disables button
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 3,
                                // Provide visual feedback when disabled
                                disabledBackgroundColor: primaryColor.withOpacity(0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24, width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                  : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            // Disable button while loading to prevent accidental taps
                            onPressed: _isLoading ? null : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LupaPasswordPage()),
                              );
                            },
                            child: Text(
                              'Lupa Kata Sandi?',
                              style: TextStyle(
                                color: _isLoading ? Colors.grey : primaryColor, // Dim color when disabled
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                   const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for input decoration
  InputDecoration _inputDecoration(String label, IconData icon) {
     return InputDecoration(
       labelText: label,
       labelStyle: TextStyle(color: primaryColor.withOpacity(0.8)), // Softer label color
       prefixIcon: Icon(icon, color: primaryColor),
       filled: true,
       fillColor: Colors.white.withOpacity(0.9),
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide.none,
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor, width: 2.0), // Thicker focus border
       ),
       // Added border for when the field is enabled but not focused
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.0),
       ),
       // Added border for when the field is disabled
       disabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1.0),
       ),
     );
   }
}