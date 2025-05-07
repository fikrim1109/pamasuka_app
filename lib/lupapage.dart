// File: lib/lupapage.dart
import "dart:convert";
import "dart:async"; // For Timer/TimeoutException
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
// import "package:google_fonts/google_fonts.dart"; // Replaced by Theme
import "package:pamasuka/login_page.dart"; // For navigation back to login
import "package:pamasuka/app_theme.dart"; // Import AppTheme

const String _apiBaseUrl = "https://tunnel.jato.my.id/test%20api";

enum ForgotPasswordStep { enterUsername, answerQuestion, resetPassword }

class LupaPasswordPage extends StatefulWidget {
  const LupaPasswordPage({Key? key}) : super(key: key);

  @override
  State<LupaPasswordPage> createState() => _LupaPasswordPageState();
}

class _LupaPasswordPageState extends State<LupaPasswordPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _securityAnswerController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterUsername;
  String _username = "";
  String _securityQuestion = "";
  bool _isLoading = false;
  String _errorMessage = "";

  final GlobalKey<FormState> _usernameFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _answerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _resetPasswordFormKey = GlobalKey<FormState>();

  // Removed: final Color primaryColor = const Color(0xFFC0392B);

  @override
  void dispose() {
    _usernameController.dispose();
    _securityAnswerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: theme.snackBarTheme.contentTextStyle ?? TextStyle(color: isError ? theme.colorScheme.onError : theme.colorScheme.onInverseSurface)),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
      ),
    );
  }

  Future<Map<String, dynamic>?> _makeApiRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    required String errorMessagePrefix,
    String method = "POST",
  }) async {
    if (!mounted) return null;
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final url = Uri.parse("$_apiBaseUrl/$endpoint");
    http.Response response;

    try {
      if (method.toUpperCase() == "GET") {
        final queryString = Uri(queryParameters: body.map((key, value) => MapEntry(key, value.toString()))).query;
        final fullUrl = Uri.parse("$url?$queryString");
        response = await http.get(fullUrl).timeout(const Duration(seconds: 15));
      } else {
        response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: json.encode(body),
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return null;
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data is Map<String, dynamic> && data["success"] == true) {
        return data;
      } else {
        final String message = data is Map<String, dynamic> ? (data["message"] ?? "Unknown API error.") : "Invalid response structure.";
        setState(() { _errorMessage = "$errorMessagePrefix: $message"; });
        return null;
      }
    } on TimeoutException {
      setState(() { _errorMessage = "$errorMessagePrefix: Connection timed out."; });
      return null;
    } on FormatException {
      setState(() { _errorMessage = "$errorMessagePrefix: Invalid server response format."; });
      return null;
    } on http.ClientException catch (e) {
      setState(() { _errorMessage = "$errorMessagePrefix: Network error: ${e.message}"; });
      return null;
    } catch (e) {
      setState(() { _errorMessage = "$errorMessagePrefix: An unexpected error occurred."; });
      return null;
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _fetchSecurityQuestion() async {
    if (!_usernameFormKey.currentState!.validate()) return;
    final String currentUsername = _usernameController.text.trim();
    final data = await _makeApiRequest(
      endpoint: "getsecurityquestion.php",
      method: "GET",
      body: {"username": currentUsername},
      errorMessagePrefix: "Gagal mengambil pertanyaan",
    );
    if (data != null && data["question"] != null) {
      if (mounted) {
        setState(() {
          _username = currentUsername;
          _securityQuestion = data["question"];
          _currentStep = ForgotPasswordStep.answerQuestion;
          _securityAnswerController.clear();
        });
      }
    }
  }

  Future<void> _verifySecurityAnswer() async {
    if (!_answerFormKey.currentState!.validate()) return;
    final data = await _makeApiRequest(
      endpoint: "verifysecurityanswer.php",
      body: {"username": _username, "answer": _securityAnswerController.text.trim()},
      errorMessagePrefix: "Gagal verifikasi jawaban",
    );
    if (data != null && data["correct"] == true) {
      if (mounted) {
        setState(() {
          _currentStep = ForgotPasswordStep.resetPassword;
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } else if (data != null && data["correct"] == false) {
      if (mounted) {
        setState(() { _errorMessage = data["message"] ?? "Jawaban keamanan salah."; });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetPasswordFormKey.currentState!.validate()) return;
    final data = await _makeApiRequest(
      endpoint: "resetpassword.php",
      body: {"username": _username, "newPassword": _newPasswordController.text},
      errorMessagePrefix: "Gagal reset kata sandi",
    );
    if (data != null) {
      _showSnackBar(context, data["message"] ?? "Kata sandi berhasil direset.");
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Widget _buildCurrentStepWidget(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    Widget stepWidget;
    switch (_currentStep) {
      case ForgotPasswordStep.enterUsername:
        stepWidget = _buildUsernameStep(theme, colorScheme, textTheme);
        break;
      case ForgotPasswordStep.answerQuestion:
        stepWidget = _buildAnswerStep(theme, colorScheme, textTheme);
        break;
      case ForgotPasswordStep.resetPassword:
        stepWidget = _buildResetPasswordStep(theme, colorScheme, textTheme);
        break;
    }
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
        },
        child: Container(key: ValueKey<ForgotPasswordStep>(_currentStep), child: stepWidget),
    );
  }

  Widget _buildUsernameStep(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Form(
      key: _usernameFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Masukkan Nama Pengguna Anda", style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 25),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: "Nama Pengguna", prefixIcon: Icon(Icons.person_search_outlined, color: colorScheme.primary)),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            autofocus: true,
            style: textTheme.bodyLarge,
            onFieldSubmitted: (_) => _isLoading ? null : _fetchSecurityQuestion(),
            validator: (value) => (value == null || value.trim().isEmpty) ? "Nama pengguna tidak boleh kosong" : null,
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(_errorMessage, style: textTheme.bodySmall?.copyWith(color: AppSemanticColors.danger(context)), textAlign: TextAlign.center),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchSecurityQuestion,
            child: _isLoading ? _loadingIndicator(colorScheme) : Text("Lanjut", style: TextStyle(color: colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerStep(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Form(
      key: _answerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Jawab Pertanyaan Keamanan Berikut", style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Text(_securityQuestion, style: textTheme.bodyLarge, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 25),
          TextFormField(
            controller: _securityAnswerController,
            decoration: InputDecoration(labelText: "Jawaban Anda", prefixIcon: Icon(Icons.question_answer_outlined, color: colorScheme.primary)),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            autofocus: true,
            style: textTheme.bodyLarge,
            onFieldSubmitted: (_) => _isLoading ? null : _verifySecurityAnswer(),
            validator: (value) => (value == null || value.trim().isEmpty) ? "Jawaban tidak boleh kosong" : null,
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(_errorMessage, style: textTheme.bodySmall?.copyWith(color: AppSemanticColors.danger(context)), textAlign: TextAlign.center),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifySecurityAnswer,
            child: _isLoading ? _loadingIndicator(colorScheme) : Text("Verifikasi Jawaban", style: TextStyle(color: colorScheme.onPrimary)),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _currentStep = ForgotPasswordStep.enterUsername;
                  _errorMessage = "";
                  _securityAnswerController.clear();
                });
              },
              child: Text("<< Kembali ke Nama Pengguna", style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordStep(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Form(
      key: _resetPasswordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Masukkan Kata Sandi Baru Anda", style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 25),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: "Kata Sandi Baru", prefixIcon: Icon(Icons.lock_person_outlined, color: colorScheme.primary)),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            autofocus: true,
            style: textTheme.bodyLarge,
            validator: (value) {
              if (value == null || value.isEmpty) return "Kata sandi baru tidak boleh kosong";
              if (value.length < 6) return "Kata sandi minimal 6 karakter";
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: "Konfirmasi Kata Sandi Baru", prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary)),
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            style: textTheme.bodyLarge,
            onFieldSubmitted: (_) => _isLoading ? null : _resetPassword(),
            validator: (value) {
              if (value == null || value.isEmpty) return "Konfirmasi kata sandi tidak boleh kosong";
              if (value != _newPasswordController.text) return "Kata sandi tidak cocok";
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(_errorMessage, style: textTheme.bodySmall?.copyWith(color: AppSemanticColors.danger(context)), textAlign: TextAlign.center),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            child: _isLoading ? _loadingIndicator(colorScheme) : Text("Reset Kata Sandi", style: TextStyle(color: colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _loadingIndicator(ColorScheme colorScheme) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lupa Kata Sandi", style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 5, // Keep some elevation for card distinction
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildCurrentStepWidget(theme, colorScheme, textTheme),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

