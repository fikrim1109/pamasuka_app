// File: lib/lupapage.dart
import 'dart:convert';
import 'dart:async'; // For Timer/TimeoutException
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/login_page.dart'; // For navigation back to login

// Use the same base URL as defined elsewhere or keep it here if needed
// Ensure consistency across files that use the API
const String _apiBaseUrl = 'https://tunnel.jato.my.id/test%20api'; // Kept as requested

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
  String _username = ''; // Store username after step 1 verification
  String _securityQuestion = ''; // Store fetched question
  bool _isLoading = false; // General loading indicator for the current step's action
  String _errorMessage = ''; // To display errors specific to the current step

  // Form Keys for each step to manage validation independently
  final GlobalKey<FormState> _usernameFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _answerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _resetPasswordFormKey = GlobalKey<FormState>();

  // Theme Colors (Consider defining these globally if used across many pages)
  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B);

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
        duration: Duration(seconds: isError ? 4 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // --- API Helper: Generic Request Handling ---
  // IMPROVEMENT: Extracted common API request logic to reduce repetition
  Future<Map<String, dynamic>?> _makeApiRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    required String loadingMessage,
    required String errorMessagePrefix,
    String method = 'POST', // Default to POST, allow GET
  }) async {
    if (!mounted) return null;
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous step error
    });

    final url = Uri.parse('$_apiBaseUrl/$endpoint');
    http.Response response;

    try {
      if (method.toUpperCase() == 'GET') {
        // For GET, append parameters to URL
        final queryString = Uri(queryParameters: body.map((key, value) => MapEntry(key, value.toString()))).query;
        final fullUrl = Uri.parse('$url?$queryString');
        response = await http.get(fullUrl).timeout(const Duration(seconds: 15));
      } else { // POST
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return null;

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data is Map<String, dynamic> && data['success'] == true) {
         return data; // Return successful data
      } else {
        // Handle API errors (success: false or non-200 status)
        final String message = data is Map<String, dynamic> ? (data['message'] ?? 'Unknown API error.') : 'Invalid response structure.';
        setState(() { _errorMessage = '$errorMessagePrefix: $message'; });
        return null; // Indicate failure
      }
    } on TimeoutException {
      setState(() { _errorMessage = '$errorMessagePrefix: Connection timed out.'; });
      return null;
    } on FormatException catch (e) {
      setState(() { _errorMessage = '$errorMessagePrefix: Invalid server response format.'; });
      print("API FormatException ($endpoint): $e");
      return null;
    } on http.ClientException catch (e) {
      setState(() { _errorMessage = '$errorMessagePrefix: Network error: ${e.message}'; });
      print("API ClientException ($endpoint): $e");
       return null;
    } catch (e) {
      setState(() { _errorMessage = '$errorMessagePrefix: An unexpected error occurred.'; });
      print("API General Exception ($endpoint): $e");
      return null;
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }


  // --- Step 1: Fetch Security Question ---
  Future<void> _fetchSecurityQuestion() async {
    // Validate the specific form for this step
    if (!_usernameFormKey.currentState!.validate()) return;

    final String currentUsername = _usernameController.text.trim();
    final data = await _makeApiRequest(
        endpoint: 'getsecurityquestion.php',
        // Use GET as per original code comment (php script likely checks $_GET)
        method: 'GET',
        // For GET, parameters are usually in the URL, so pass them as 'body' for helper
        body: {'username': currentUsername},
        loadingMessage: 'Fetching question...',
        errorMessagePrefix: 'Failed to fetch question',
    );

    if (data != null && data['question'] != null) {
      // Success: Update state and move to next step
      if (mounted) {
          setState(() {
              _username = currentUsername; // Store username only on success
              _securityQuestion = data['question'];
              _currentStep = ForgotPasswordStep.answerQuestion;
              _securityAnswerController.clear(); // Clear answer field for new step
          });
       }
    }
    // Error message is handled within _makeApiRequest
  }

  // --- Step 2: Verify Security Answer ---
  Future<void> _verifySecurityAnswer() async {
     // Validate the specific form for this step
    if (!_answerFormKey.currentState!.validate()) return;

    final data = await _makeApiRequest(
        endpoint: 'verifysecurityanswer.php',
        body: {
          'username': _username, // Use stored username
          'answer': _securityAnswerController.text.trim(),
        },
        loadingMessage: 'Verifying answer...',
        errorMessagePrefix: 'Failed to verify answer',
    );

     if (data != null && data['correct'] == true) {
       // Success: Move to reset password step
        if(mounted){
             setState(() {
                _currentStep = ForgotPasswordStep.resetPassword;
                _newPasswordController.clear(); // Clear password fields for new step
                _confirmPasswordController.clear();
             });
        }
    } else if (data != null && data['correct'] == false) {
        // API indicates answer was incorrect, keep user on this step
        if(mounted) {
            setState(() {
                 _errorMessage = data['message'] ?? 'Jawaban keamanan salah.';
            });
        }
    }
     // Other errors handled by _makeApiRequest
  }

  // --- Step 3: Reset Password ---
  Future<void> _resetPassword() async {
    // Validate the specific form for this step
    if (!_resetPasswordFormKey.currentState!.validate()) return;

    final data = await _makeApiRequest(
        endpoint: 'resetpassword.php',
        body: {
          'username': _username, // Use stored username
          'newPassword': _newPasswordController.text, // Send the new password
        },
        loadingMessage: 'Resetting password...',
        errorMessagePrefix: 'Failed to reset password',
    );

     if (data != null) {
       // Success: Show success message and navigate back to login
       _showSnackBar(data['message'] ?? 'Kata sandi berhasil direset.');
       if(mounted) {
         // Use pushAndRemoveUntil to clear stack and go to login
         Navigator.of(context).pushAndRemoveUntil(
           MaterialPageRoute(builder: (context) => const LoginPage()),
           (Route<dynamic> route) => false, // Remove all previous routes
         );
       }
     }
    // Errors handled by _makeApiRequest
  }

  // --- Build UI based on current step ---
  Widget _buildCurrentStepWidget() {
    // Key is essential for AnimatedSwitcher to detect changes correctly
    Widget stepWidget;
    switch (_currentStep) {
      case ForgotPasswordStep.enterUsername:
        stepWidget = _buildUsernameStep();
        break;
      case ForgotPasswordStep.answerQuestion:
        stepWidget = _buildAnswerStep();
        break;
      case ForgotPasswordStep.resetPassword:
        stepWidget = _buildResetPasswordStep();
        break;
    }
    return Container(
      key: ValueKey<ForgotPasswordStep>(_currentStep),
      child: stepWidget,
    );
  }

  // --- UI for Step 1: Enter Username ---
  Widget _buildUsernameStep() {
    return Form(
      key: _usernameFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Masukkan Nama Pengguna Anda',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
            textAlign: TextAlign.center,
           ),
          const SizedBox(height: 25),
          TextFormField(
            controller: _usernameController,
            decoration: _inputDecoration('Nama Pengguna', Icons.person_search_outlined),
            keyboardType: TextInputType.text,
             textInputAction: TextInputAction.done,
             enabled: !_isLoading, // Disable when loading
             autofocus: true,
             onFieldSubmitted: (_) => _isLoading ? null : _fetchSecurityQuestion(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama pengguna tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Show step-specific error message if any
          if (_errorMessage.isNotEmpty)
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
            child: _isLoading ? _loadingIndicator() : const Text('LANJUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Jawab Pertanyaan Keamanan Berikut',
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
             textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Display the security question
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
            decoration: _inputDecoration('Jawaban Anda', Icons.question_answer_outlined),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
             enabled: !_isLoading, // Disable when loading
            autofocus: true,
            onFieldSubmitted: (_) => _isLoading ? null : _verifySecurityAnswer(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Jawaban tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
           if (_errorMessage.isNotEmpty)
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
            child: _isLoading ? _loadingIndicator() : const Text('Verifikasi Jawaban', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          // Option to go back
           Center(
             child: TextButton(
              onPressed: _isLoading ? null : () {
                  setState(() {
                    _currentStep = ForgotPasswordStep.enterUsername;
                    _errorMessage = ''; // Clear error for the new step
                    _securityAnswerController.clear(); // Clear field from this step
                    // Keep username field populated
                  });
                },
              child: Text('<< Kembali ke Nama Pengguna', style: TextStyle(color: primaryColor.withOpacity(0.9))),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           const Text(
             'Masukkan Kata Sandi Baru Anda',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
           const SizedBox(height: 25),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: _inputDecoration('Kata Sandi Baru', Icons.lock_person_outlined),
            textInputAction: TextInputAction.next,
             enabled: !_isLoading, // Disable when loading
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Kata sandi baru tidak boleh kosong';
              }
              if (value.length < 6) {
                 return 'Kata sandi minimal 6 karakter';
              }
              // Potential improvement: Prevent using the same username as password, etc.
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
             decoration: _inputDecoration('Konfirmasi Kata Sandi Baru', Icons.lock_outline),
             textInputAction: TextInputAction.done,
              enabled: !_isLoading, // Disable when loading
             onFieldSubmitted: (_) => _isLoading ? null : _resetPassword(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Konfirmasi kata sandi tidak boleh kosong';
              }
              if (value != _newPasswordController.text) {
                return 'Kata sandi tidak cocok';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
           if (_errorMessage.isNotEmpty)
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
            child: _isLoading ? _loadingIndicator() : const Text('Simpan Kata Sandi Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          // No back button here, user should complete or cancel via AppBar back button
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
        title: const Text('Lupa Kata Sandi'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton( // Provide a consistent way back
          icon: const Icon(Icons.arrow_back),
          // Disable back button during network request to avoid interrupting flow
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
        child: Center(
          child: SingleChildScrollView( // Ensure scrolling if content overflows
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
            child: Card(
              elevation: 6,
              color: const Color(0xFFFFF5F5).withOpacity(0.97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: primaryColor.withOpacity(0.3))
              ),
              clipBehavior: Clip.antiAlias, // Helps with shape rendering
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0), // Adjusted padding
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300), // Slightly faster transition
                    switchInCurve: Curves.easeIn, // Standard curves
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // Fade transition (simple and effective)
                      return FadeTransition(opacity: animation, child: child);
                    },
                    // The child's key ensures AnimatedSwitcher detects the change
                    child: _buildCurrentStepWidget(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  InputDecoration _inputDecoration(String label, IconData icon) {
     return InputDecoration(
       labelText: label,
       labelStyle: TextStyle(color: primaryColor.withOpacity(0.9)), // Slightly more prominent label
       prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
       filled: true,
       fillColor: Colors.white.withOpacity(0.95), // Slightly more opaque fill
       border: OutlineInputBorder( // Define base border
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
       ),
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0), // Slightly darker enabled border
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor, width: 2.0), // Thicker focus
       ),
       errorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
       ),
       focusedErrorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 2.0), // Thicker error focus
       ),
       disabledBorder: OutlineInputBorder( // Style when disabled
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.7), width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
     );
   }

   ButtonStyle _buttonStyle() {
      return ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5), // Added letter spacing
        disabledBackgroundColor: primaryColor.withOpacity(0.5), // Visual feedback when disabled
        disabledForegroundColor: Colors.white.withOpacity(0.8),
      );
   }

   Widget _loadingIndicator() {
     return const SizedBox(
       height: 24,
       width: 24,
       child: CircularProgressIndicator(
         color: Colors.white,
         strokeWidth: 3,
        ),
     );
   }
}