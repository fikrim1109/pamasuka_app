// File: lib/akunpage.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/app_theme.dart'; // Import AppTheme

const String _apiBaseUrl = 'https://android.samalonian.my.id/test%20api';

class AkunPage extends StatefulWidget {
  final int userId;
  final String username;

  const AkunPage({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<AkunPage> createState() => _AkunPageState();
}

class _AkunPageState extends State<AkunPage> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _securityAnswerController = TextEditingController();

  String? _dropdownSelectedQuestion;
  String? _savedSecurityQuestion;

  final List<String> _securityQuestions = const [
    "Nama panggilan masa kecil?",
    "Nama hewan peliharaan pertama?",
    "Kota kelahiran Anda?",
    "Makanan favorit Anda?",
    "Nama idola/artis favorit?"
  ];

  bool _isLoadingPassword = false;
  bool _isLoadingSecurity = false;
  bool _isFetchingInitialData = true;

  bool get _hasSecurityQuestionSet => _savedSecurityQuestion != null && _savedSecurityQuestion!.isNotEmpty;

  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _securityFormKey = GlobalKey<FormState>();

  // Removed: final Color primaryColor = const Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _fetchSecurityData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Theme.of(context).snackBarTheme.contentTextStyle),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
        duration: duration,
        // behavior, shape, margin are now part of SnackBarThemeData in AppTheme
      ),
    );
  }

  Future<Map<String, dynamic>?> _makeApiRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    required String errorMessagePrefix,
    String method = 'POST',
    bool setLoadingState = true,
    Function(bool)? setLoading
  }) async {
    if (!mounted) return null;

    if (setLoadingState && setLoading != null) {
      setLoading(true);
    }

    final url = Uri.parse('$_apiBaseUrl/$endpoint');
    http.Response? response;
    Map<String, String> headers = {'Content-Type': 'application/json'};
    String? responseBodyForErrorLogging;

    try {
      if (method.toUpperCase() == 'GET') {
        final queryParams = body.map((key, value) => MapEntry(key, value.toString()));
        final fullUrl = url.replace(queryParameters: queryParams);
        response = await http.get(fullUrl, headers: headers).timeout(const Duration(seconds: 15));
      } else {
        response = await http.post(
          url,
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return null;
      responseBodyForErrorLogging = response.body;
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data is Map<String, dynamic> && data['success'] == true) {
        return data;
      } else {
        final String message = data is Map<String, dynamic> ? (data['message'] ?? 'Kesalahan API tidak diketahui.') : 'Struktur respons tidak valid.';
        _showStyledSnackBar('$errorMessagePrefix: $message', isError: true, duration: const Duration(seconds: 5));
        return null;
      }
    } on TimeoutException {
      _showStyledSnackBar('$errorMessagePrefix: Koneksi waktu habis.', isError: true);
      return null;
    } on FormatException catch (e) {
      _showStyledSnackBar('$errorMessagePrefix: Format respons server tidak valid.', isError: true);
      print("API FormatException ($endpoint): $e. Response Body: $responseBodyForErrorLogging");
      return null;
    } on http.ClientException catch (e) {
      _showStyledSnackBar('$errorMessagePrefix: Kesalahan jaringan: ${e.message}', isError: true);
      print("API ClientException ($endpoint): $e");
      return null;
    } catch (e) {
      _showStyledSnackBar('$errorMessagePrefix: Terjadi kesalahan tak terduga: ${e.runtimeType}', isError: true);
      print("API General Exception ($endpoint): $e");
      return null;
    } finally {
      if (mounted && setLoadingState && setLoading != null) {
        setLoading(false);
      }
    }
  }

  Future<void> _fetchSecurityData() async {
    if (!mounted) return;
    setState(() { _isFetchingInitialData = true; });

    final data = await _makeApiRequest(
      endpoint: 'securityquestion.php',
      method: 'GET',
      body: {'userId': widget.userId},
      errorMessagePrefix: 'Gagal memuat data keamanan',
      setLoadingState: false,
    );

    String? fetchedQuestion;
    if (data != null && data['question'] != null) {
      String potentialQuestion = data['question'];
      if (_securityQuestions.contains(potentialQuestion)) {
        fetchedQuestion = potentialQuestion;
      } else {
        print("Peringatan: Pertanyaan keamanan yang diambil '$potentialQuestion' tidak ada dalam daftar yang ditentukan. Diabaikan.");
      }
    }

    if (mounted) {
      setState(() {
        _savedSecurityQuestion = fetchedQuestion;
        _dropdownSelectedQuestion = fetchedQuestion;
        _isFetchingInitialData = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (!_hasSecurityQuestionSet) {
      _showStyledSnackBar('Harap atur pertanyaan keamanan terlebih dahulu untuk mengubah kata sandi.', isError: true);
      return;
    }
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final data = await _makeApiRequest(
      endpoint: 'changepassword.php',
      body: {
        'userId': widget.userId,
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
      },
      errorMessagePrefix: 'Gagal mengubah kata sandi',
      setLoading: (loading) => setState(() => _isLoadingPassword = loading),
    );

    if (data != null && mounted) {
      _showStyledSnackBar(data['message'] ?? 'Kata sandi berhasil diubah.');
      _passwordFormKey.currentState?.reset();
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _saveSecurityQuestion() async {
    if (!_securityFormKey.currentState!.validate()) {
      return;
    }

    final String? questionToSave = _dropdownSelectedQuestion;
    final String answerToSave = _securityAnswerController.text.trim();

    if (questionToSave == null || questionToSave.isEmpty) {
      _showStyledSnackBar('Silakan pilih pertanyaan keamanan.', isError: true);
      return;
    }
    if (answerToSave.isEmpty) {
      _showStyledSnackBar('Jawaban keamanan tidak boleh kosong.', isError: true);
      return;
    }

    final data = await _makeApiRequest(
      endpoint: 'securityquestion.php',
      body: {
        'userId': widget.userId,
        'question': questionToSave,
        'answer': answerToSave,
      },
      errorMessagePrefix: 'Gagal menyimpan informasi keamanan',
      setLoading: (loading) => setState(() => _isLoadingSecurity = loading),
    );

    if (data != null && mounted) {
      setState(() {
        _savedSecurityQuestion = questionToSave;
        _securityAnswerController.clear();
      });
      FocusScope.of(context).unfocus();
      _showStyledSnackBar(data['message'] ?? 'Pertanyaan & jawaban keamanan berhasil disimpan/diperbarui.');
    }
  }

  // Removed _inputDecoration, will use theme's InputDecorationTheme

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      // backgroundColor from theme.scaffoldBackgroundColor
      appBar: AppBar(
        // Style from theme.appBarTheme
        title: const Text('Pengaturan Akun'),
        centerTitle: true,
      ),
      body: _isFetchingInitialData
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _buildFormContent(theme, colorScheme, textTheme),
    );
  }

  Widget _buildFormContent(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    bool canChangePassword = _hasSecurityQuestionSet;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                'Akun: ${widget.username}',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
            ),
            _buildCard(
              theme: theme,
              title: 'Ubah Kata Sandi',
              formKey: _passwordFormKey,
              enabled: canChangePassword,
              disabledMessage: 'Harap atur Pertanyaan Keamanan di bawah ini terlebih dahulu untuk mengaktifkan fitur ini.',
              isLoading: _isLoadingPassword,
              onSave: _changePassword,
              saveButtonText: 'Ubah Kata Sandi',
              child: Column(
                children: [
                  _buildTextFormField(
                    theme: theme,
                    controller: _currentPasswordController,
                    labelText: 'Kata Sandi Saat Ini',
                    obscureText: true,
                    enabled: canChangePassword,
                    validator: (value) {
                      if (canChangePassword && _newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                        return 'Kata sandi saat ini diperlukan';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    theme: theme,
                    controller: _newPasswordController,
                    labelText: 'Kata Sandi Baru (min. 6 karakter)',
                    obscureText: true,
                    enabled: canChangePassword,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (!canChangePassword) return null;
                      if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                        return 'Kata sandi baru diperlukan';
                      }
                      if (value != null && value.isNotEmpty) {
                        if (value.length < 6) return 'Kata sandi minimal 6 karakter';
                        if (value == _currentPasswordController.text) return 'Kata sandi baru harus berbeda';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    theme: theme,
                    controller: _confirmPasswordController,
                    labelText: 'Konfirmasi Kata Sandi Baru',
                    obscureText: true,
                    enabled: canChangePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (canChangePassword && !_isLoadingPassword) _changePassword();
                    },
                    validator: (value) {
                      if (!canChangePassword) return null;
                      if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                        return 'Konfirmasi kata sandi diperlukan';
                      }
                      if (value != null && value.isNotEmpty && value != _newPasswordController.text) {
                        return 'Konfirmasi kata sandi tidak cocok';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildCard(
              theme: theme,
              title: _hasSecurityQuestionSet ? 'Perbarui Pertanyaan Keamanan' : 'Atur Pertanyaan Keamanan',
              formKey: _securityFormKey,
              isLoading: _isLoadingSecurity,
              onSave: _saveSecurityQuestion,
              saveButtonText: _hasSecurityQuestionSet ? 'Perbarui Keamanan' : 'Simpan Keamanan',
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _dropdownSelectedQuestion,
                      items: _securityQuestions.map((String question) {
                        return DropdownMenuItem<String>(
                          value: question,
                          child: Text(question, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() { _dropdownSelectedQuestion = newValue; });
                      },
                      decoration: InputDecoration(
                        labelText: 'Pilih Pertanyaan Keamanan',
                        labelStyle: theme.inputDecorationTheme.labelStyle,
                        border: InputBorder.none, // Remove internal border, rely on container
                        filled: false, // Fill is handled by container
                      ),
                      style: textTheme.bodyLarge,
                      dropdownColor: theme.cardTheme.color, // Use card color for dropdown menu background
                      isExpanded: true,
                      validator: (value) => value == null ? 'Pertanyaan harus dipilih' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    theme: theme,
                    controller: _securityAnswerController,
                    labelText: 'Jawaban Keamanan Anda',
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoadingSecurity) _saveSecurityQuestion();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Jawaban tidak boleh kosong';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required ThemeData theme,
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    bool enabled = true,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    Function(String)? onFieldSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        enabled: enabled,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: labelText,
          // Uses InputDecorationTheme from AppTheme for other properties (border, labelStyle, etc.)
          // fillColor is handled by the container, so set TextField's fillColor to transparent or null
          filled: false, 
        ),
        textInputAction: textInputAction,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required String title,
    required Widget child,
    required GlobalKey<FormState> formKey,
    bool enabled = true,
    String? disabledMessage,
    required bool isLoading,
    required Future<void> Function() onSave,
    required String saveButtonText,
  }) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      // Styles from theme.cardTheme
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!enabled && disabledMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.error.withOpacity(0.7))
                    ),
                    child: Text(
                      disabledMessage,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              AbsorbPointer(
                absorbing: !enabled,
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.5,
                  child: child,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                // Style from theme.elevatedButtonTheme
                onPressed: enabled && !isLoading ? onSave : null,
                child: isLoading
                    ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                      )
                    : Text(saveButtonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

