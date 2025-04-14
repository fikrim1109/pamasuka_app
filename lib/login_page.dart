// File: lib/login_page.dart
import 'dart:async'; // Import for Timer/TimeoutException
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/menu_page.dart'; // Ensure this import path is correct for your project
import 'package:pamasuka/lupapage.dart'; // <-- ADDED IMPORT for Forgot Password

// --- Base URL for API calls ---
// ** IMPORTANT: Replace with your actual server address/domain and path **
const String _apiBaseUrl = 'http://10.0.2.2/test%20api'; // 10.0.2.2 for Android emulator -> host localhost
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

  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B); // Define primary color

  // --- Helper Function to Show Snack Bar ---
  void _showSnackBar(String message, {bool isError = false}) {
    // Check if the widget is still in the tree before showing Snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating, // Optional: Make it float above bottom nav bar if any
      ),
    );
  }

  // --- Login Function ---
  Future<void> _login() async {
    // Trim username input, password usually shouldn't be trimmed
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    // Client-side validation
    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Nama pengguna dan kata sandi harus diisi.', isError: true); // Indonesian message
      return;
    }

    // Set loading state only if mounted
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final url = Uri.parse('$_apiBaseUrl/login.php'); // Use the base URL constant

    try {
      // Send request with timeout
      final response = await http.post(
        url,
        // Sending as form data implicitly by http package when body is Map<String, String>
        // If your updated PHP expects JSON, change headers and body:
        // headers: {'Content-Type': 'application/json'},
        // body: json.encode({
        //   'username': username,
        //   'password': password,
        // }),
        body: { // Keep as form data to match updated PHP which checks both JSON and POST
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 15)); // Add a reasonable timeout

      // Check if the widget is still mounted after the async call
      if (!mounted) return;

      // Process response
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Ensure userId is correctly parsed as int
           final int userId = data['userId'] is int ? data['userId'] : int.tryParse(data['userId'].toString()) ?? 0; // Safer parsing
           final String responseUsername = data['username'] ?? 'Pengguna'; // Default username if missing

          // Navigate to MenuPage on successful login
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
          // Show error message from API response or a default one
          _showSnackBar(data['message'] ?? 'Login gagal. Periksa kembali kredensial Anda.', isError: true); // Indonesian message
        }
      } else {
        // Handle non-200 status codes (e.g., 404, 500)
         _showSnackBar('Kesalahan server: ${response.statusCode}. Silakan coba lagi nanti.', isError: true); // Indonesian message
         print("Server error response: ${response.body}"); // Log server response body
      }
    } on TimeoutException {
        _showSnackBar('Koneksi ke server time out. Periksa koneksi internet Anda.', isError: true); // Indonesian message
    } on FormatException {
         _showSnackBar('Format respons dari server tidak valid.', isError: true); // Indonesian message
    } catch (e) {
      // Handle other errors (network issues, etc.)
      _showSnackBar('Terjadi kesalahan jaringan: ${e.toString()}', isError: true); // Indonesian message
      print("Login error: $e"); // Log detailed error for debugging
    } finally {
      // Ensure loading state is turned off only if the widget is still mounted
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
         width: double.infinity, // Ensure gradient covers full screen width
         height: double.infinity, // Ensure gradient covers full screen height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView( // Allows scrolling on smaller screens
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo (Ensure asset path is correct and declared in pubspec.yaml)
                  Image.asset(
                    'images/Samalonian APP.png',
                    height: MediaQuery.of(context).size.height * 0.20, // Adjusted height slightly
                    errorBuilder: (context, error, stackTrace) {
                       // Show a placeholder if the image fails to load
                       print("Error loading logo: $error"); // Log error
                       return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
                    }
                  ),
                  const SizedBox(height: 32),
                  // Login Card
                  Card(
                    elevation: 6, // Slightly more elevation
                    color: const Color(0xFFFFF5F5).withOpacity(0.95), // Slightly more opaque card
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // More rounded corners
                      side: BorderSide(color: startColor.withOpacity(0.6), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Card size wraps content
                        children: [
                          // Title
                           Center(
                            child: Text('Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor))),
                          const SizedBox(height: 20),
                          // Username Field
                          TextField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next, // Focus next field on enter/next
                            decoration: _inputDecoration('Nama Pengguna', Icons.person_outline), // Indonesian & Outline icon
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done, // Submit action on enter/done
                            onSubmitted: (_) { // Allow login by pressing done/enter on keyboard
                              if (!_isLoading) _login();
                            },
                            decoration: _inputDecoration('Kata Sandi', Icons.lock_outline), // Indonesian & Outline icon
                          ),
                          const SizedBox(height: 24),
                          // Login Button
                          SizedBox( // Wrap button for consistent width
                            width: double.infinity,
                            child: ElevatedButton(
                              // Disable button while loading
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 3,
                              ),
                              child: _isLoading
                                  ? const SizedBox( // Constrain indicator size
                                      height: 24, width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                  : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16), // Add space before forgot password
                          // --- FORGOT PASSWORD LINK (MODIFIED) ---
                          TextButton(
                            onPressed: () {
                              // Navigate to Forgot Password Page
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LupaPasswordPage()), // Navigate to LupaPasswordPage
                              );
                            },
                            child: Text(
                              'Lupa Kata Sandi?', // Indonesian
                              style: TextStyle(
                                color: primaryColor, // Match theme color
                                // decoration: TextDecoration.underline, // Optional underline
                              ),
                            ),
                          ),
                          // --- END OF MODIFICATION ---
                        ],
                      ),
                    ),
                  ),
                   const SizedBox(height: 20), // Add some padding at the bottom
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for input decoration to keep code DRY
  InputDecoration _inputDecoration(String label, IconData icon) {
     return InputDecoration(
       labelText: label,
       prefixIcon: Icon(icon, color: primaryColor),
       filled: true,
       fillColor: Colors.white.withOpacity(0.9), // Slightly transparent
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide.none, // Hide border side when filled
       ),
       focusedBorder: OutlineInputBorder( // Add a border highlight when focused
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor, width: 1.5),
       ),
       // Add hint style, error style etc. if needed
     );
   }
}