// File: lib/lupapage.dart
import 'dart:convert';
import 'dart:async'; // For Timer/TimeoutException
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/login_page.dart'; // For navigation back to login

// Use the same base URL as defined in login_page.dart or define it globally
const String _apiBaseUrl = 'https://tunnel.jato.my.id/test%20api';

// Enum to manage the current step in the forgot password flow
enum ForgotPasswordStep { enterUsername, answerQuestion, resetPassword }

class LupaPasswordPage extends StatefulWidget {
  const LupaPasswordPage({Key? key}) : super(key: key);

  @override
  State<LupaPasswordPage> createState() => _LupaPasswordPageState();
}

class _LupaPasswordPageState extends State<LupaPasswordPage> {
  // --- Controllers ---
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _securityAnswerController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // --- State Variables ---
  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterUsername;
  String _username = ''; // Store username after step 1
  String _securityQuestion = ''; // Store fetched question
  bool _isLoading = false; // General loading indicator
  String _errorMessage = ''; // To display errors specific to a step

  final GlobalKey<FormState> _usernameFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _answerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _resetPasswordFormKey = GlobalKey<FormState>();

  final Color startColor = const Color(0xFFFFB6B6); // Match theme
  final Color endColor = const Color(0xFFFF8E8E);   // Match theme
  final Color primaryColor = const Color(0xFFC0392B); // Match theme accent

  @override
  void dispose() {
    _usernameController.dispose();
    _securityAnswerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Helper: Show Snackbar ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 3), // Show errors longer
      ),
    );
  }

  // --- Step 1: Fetch Security Question ---
  Future<void> _fetchSecurityQuestion() async {
    if (!_usernameFormKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous error
      _username = _usernameController.text.trim(); // Store username
    });

    // Use GET request as defined in getsecurityquestion.php
    final url = Uri.parse('$_apiBaseUrl/getsecurityquestion.php?username=${Uri.encodeComponent(_username)}'); // URL encode username

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _securityQuestion = data['question'];
          _currentStep = ForgotPasswordStep.answerQuestion; // Move to next step
        });
      } else {
        // Keep user on the same step but show error
        setState(() {
          _errorMessage = data['message'] ?? 'Gagal mengambil pertanyaan keamanan.'; // Indonesian
        });
      }
    } on TimeoutException {
      setState(() { _errorMessage = 'Koneksi time out. Silakan coba lagi.'; }); // Indonesian
    } on FormatException {
       setState(() { _errorMessage = 'Format respons server tidak valid.'; }); // Indonesian
    } catch (e) {
      setState(() { _errorMessage = 'Terjadi kesalahan jaringan. Periksa koneksi Anda.'; }); // Indonesian
      print("Fetch question error: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- Step 2: Verify Security Answer ---
  Future<void> _verifySecurityAnswer() async {
    if (!_answerFormKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous error
    });

    final url = Uri.parse('$_apiBaseUrl/verifysecurityanswer.php');
    final body = json.encode({
      'username': _username, // Use stored username
      'answer': _securityAnswerController.text.trim(),
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // PHP expects JSON
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true && data['correct'] == true) {
        // Answer is correct, move to next step
        setState(() {
          _currentStep = ForgotPasswordStep.resetPassword; // Move to final step
        });
      } else {
        // Handle incorrect answer or other errors from backend
        setState(() {
          _errorMessage = data['message'] ?? 'Gagal memverifikasi jawaban.'; // Indonesian
          // Don't clear the answer field immediately, let user retry
        });
      }
    } on TimeoutException {
       setState(() { _errorMessage = 'Koneksi time out. Silakan coba lagi.'; }); // Indonesian
    } on FormatException {
       setState(() { _errorMessage = 'Format respons server tidak valid.'; }); // Indonesian
    } catch (e) {
       setState(() { _errorMessage = 'Terjadi kesalahan jaringan. Periksa koneksi Anda.'; }); // Indonesian
       print("Verify answer error: $e");
    } finally {
       if (mounted) {
         setState(() { _isLoading = false; });
       }
    }
  }

  // --- Step 3: Reset Password ---
  Future<void> _resetPassword() async {
    if (!_resetPasswordFormKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous error
    });

    final url = Uri.parse('$_apiBaseUrl/resetpassword.php');
     final body = json.encode({
      'username': _username, // Use stored username
      'newPassword': _newPasswordController.text, // Send the new password
    });

    try {
       final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // PHP expects JSON
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = json.decode(response.body);

       if (response.statusCode == 200 && data['success'] == true) {
         // Show success message and navigate back to login
         _showSnackBar(data['message'] ?? 'Kata sandi berhasil direset.'); // Indonesian
         // Use pushAndRemoveUntil to clear stack and go to login
         // Ensure context is still valid before navigating
         if(mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const LoginPage()),
             (Route<dynamic> route) => false, // Remove all previous routes
           );
         }
       } else {
         // Stay on reset page but show error
         setState(() {
           _errorMessage = data['message'] ?? 'Gagal mereset kata sandi.'; // Indonesian
         });
       }
    } on TimeoutException {
       setState(() { _errorMessage = 'Koneksi time out. Silakan coba lagi.'; }); // Indonesian
    } on FormatException {
       setState(() { _errorMessage = 'Format respons server tidak valid.'; }); // Indonesian
    } catch (e) {
       setState(() { _errorMessage = 'Terjadi kesalahan jaringan. Periksa koneksi Anda.'; }); // Indonesian
       print("Reset password error: $e");
    } finally {
      // Only turn off loading if the widget is still in the tree
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- Build UI based on current step ---
  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case ForgotPasswordStep.enterUsername:
        return _buildUsernameStep();
      case ForgotPasswordStep.answerQuestion:
        return _buildAnswerStep();
      case ForgotPasswordStep.resetPassword:
        return _buildResetPasswordStep();
    }
  }

  // --- UI for Step 1: Enter Username ---
  Widget _buildUsernameStep() {
    return Form(
      key: _usernameFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Card wraps content
        crossAxisAlignment: CrossAxisAlignment.stretch, // Make button full width
        children: [
          const Text(
            'Masukkan Nama Pengguna Anda', // Indonesian
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
            textAlign: TextAlign.center,
           ),
          const SizedBox(height: 25),
          TextFormField(
            controller: _usernameController,
            decoration: _inputDecoration('Nama Pengguna', Icons.person_search_outlined), // Indonesian
            keyboardType: TextInputType.text,
             textInputAction: TextInputAction.done,
             autofocus: true, // Focus this field first
             onFieldSubmitted: (_) => _isLoading ? null : _fetchSecurityQuestion(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama pengguna tidak boleh kosong'; // Indonesian
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty) // Show error message if any
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchSecurityQuestion,
            style: _buttonStyle(),
            child: _isLoading
                ? _loadingIndicator()
                : const Text('CONFIRM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Indonesian
          ),
        ],
      ),
    );
  }

  // --- UI for Step 2: Answer Security Question ---
  Widget _buildAnswerStep() {
    return Form(
      key: _answerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, // Make button full width
        children: [
          const Text(
            'Jawab Pertanyaan Keamanan Berikut', // Indonesian
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
             textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Display the security question (read-only)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200]?.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[350] ?? Colors.grey)
            ),
            child: Text(
              _securityQuestion, // Display fetched question
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 25),
          TextFormField(
            controller: _securityAnswerController,
            decoration: _inputDecoration('Jawaban Anda', Icons.question_answer_outlined), // Indonesian
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            autofocus: true, // Focus field when step appears
            onFieldSubmitted: (_) => _isLoading ? null : _verifySecurityAnswer(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Jawaban tidak boleh kosong'; // Indonesian
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty) // Show error message if any
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifySecurityAnswer,
            style: _buttonStyle(),
            child: _isLoading
                ? _loadingIndicator()
                : const Text('Verifikasi Jawaban', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Indonesian
          ),
          const SizedBox(height: 10),
          // Option to go back to username entry
           Center(
             child: TextButton(
              onPressed: _isLoading ? null : () {
                  setState(() {
                    _currentStep = ForgotPasswordStep.enterUsername;
                    _errorMessage = ''; // Clear error
                    _securityAnswerController.clear(); // Clear previous answer
                    // _usernameController can keep its value or be cleared
                  });
                },
              child: Text('<< Kembali ke Nama Pengguna', style: TextStyle(color: primaryColor)), // Indonesian
             ),
           ),
        ],
      ),
    );
  }

  // --- UI for Step 3: Reset Password ---
  Widget _buildResetPasswordStep() {
    return Form(
      key: _resetPasswordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, // Make button full width
        children: [
           const Text(
             'Masukkan Kata Sandi Baru Anda', // Indonesian
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
           const SizedBox(height: 25),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: _inputDecoration('Kata Sandi Baru', Icons.lock_person_outlined), // Indonesian
            textInputAction: TextInputAction.next,
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Kata sandi baru tidak boleh kosong'; // Indonesian
              }
              if (value.length < 6) {
                 return 'Kata sandi minimal 6 karakter'; // Indonesian
              }
              // Optional: Check if it's the same as a known old password (if applicable)
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
             decoration: _inputDecoration('Konfirmasi Kata Sandi Baru', Icons.lock_outline), // Indonesian
             textInputAction: TextInputAction.done,
             onFieldSubmitted: (_) => _isLoading ? null : _resetPassword(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Konfirmasi kata sandi tidak boleh kosong'; // Indonesian
              }
              if (value != _newPasswordController.text) {
                return 'Kata sandi tidak cocok'; // Indonesian
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
           if (_errorMessage.isNotEmpty) // Show error message if any
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage,
                 style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: _buttonStyle(),
            child: _isLoading
                ? _loadingIndicator()
                : const Text('Simpan Kata Sandi Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Indonesian
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
        title: const Text('Lupa Kata Sandi'), // Indonesian
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton( // Add back button to always allow returning to login
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
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
        child: Center( // Center the card
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
            child: Card(
              elevation: 6,
              color: const Color(0xFFFFF5F5).withOpacity(0.97), // Slightly more opaque
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: primaryColor.withOpacity(0.3)) // Subtle border
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                // AnimatedSwitcher provides smooth transition between steps
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // Fade transition
                      return FadeTransition(opacity: animation, child: child);
                      // Optional: Slide transition (uncomment to use)
                      // final slideAnimation = Tween<Offset>(
                      //   begin: const Offset(0.5, 0.0), // Slide from right
                      //   end: Offset.zero,
                      // ).animate(animation);
                      // return ClipRect( // Important for slide transitions
                      //   child: SlideTransition(position: slideAnimation, child: child),
                      // );
                    },
                    child: Container(
                      // Key is important for AnimatedSwitcher to detect widget changes based on step
                      key: ValueKey<ForgotPasswordStep>(_currentStep),
                      child: _buildCurrentStepWidget(),
                    ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

    // Helper for input decoration (consistent style)
  InputDecoration _inputDecoration(String label, IconData icon) {
     return InputDecoration(
       labelText: label,
       prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
       filled: true,
       fillColor: Colors.white.withOpacity(0.9),
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide.none,
       ),
       enabledBorder: OutlineInputBorder( // Border when not focused
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
       ),
       focusedBorder: OutlineInputBorder( // Border when focused
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor, width: 1.8),
       ),
       errorBorder: OutlineInputBorder( // Style for error border
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
       ),
       focusedErrorBorder: OutlineInputBorder( // Style for error border when focused
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
       ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
     );
   }

    // Helper for button style (consistent style)
   ButtonStyle _buttonStyle() {
      return ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), // Adjusted padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
        textStyle: const TextStyle(fontWeight: FontWeight.bold) // Ensure text style is consistent
      );
   }

   // Helper for loading indicator (consistent style)
   Widget _loadingIndicator() {
     return const SizedBox(
       height: 24, // Match text line height roughly
       width: 24,
       child: CircularProgressIndicator(
         color: Colors.white,
         strokeWidth: 3,
        ),
     );
   }
}