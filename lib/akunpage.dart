// File: lib/akunpage.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

const String _apiBaseUrl = 'https://tunnel.jato.my.id/test%20api';

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
  // --- Controllers ---
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _securityAnswerController = TextEditingController();

  // --- State Variables ---
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

  final Color primaryColor = const Color(0xFFC0392B);

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

  // --- Helper: Show Snackbar ---
  void _showSnackBar(String message, {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --- API Helper: Generic Request Handling ---
  Future<Map<String, dynamic>?> _makeApiRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    required String errorMessagePrefix,
    String method = 'POST',
    bool setLoadingState = true,
    Function(bool)? setLoading
  }) async {
    if (!mounted) return null;

    if (setLoadingState) {
      if (setLoading != null) {
        setLoading(true);
      }
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

      final data = json.decode(response!.body);

      if (response.statusCode == 200 && data is Map<String, dynamic> && data['success'] == true) {
        return data;
      } else {
        final String message = data is Map<String, dynamic> ? (data['message'] ?? 'Kesalahan API tidak diketahui.') : 'Struktur respons tidak valid.';
        _showSnackBar('$errorMessagePrefix: $message', isError: true, duration: const Duration(seconds: 5));
        return null;
      }
    } on TimeoutException {
      _showSnackBar('$errorMessagePrefix: Koneksi waktu habis.', isError: true);
      return null;
    } on FormatException catch (e) {
      _showSnackBar('$errorMessagePrefix: Format respons server tidak valid.', isError: true);
      print("API FormatException ($endpoint): $e. Response Body: $responseBodyForErrorLogging");
      return null;
    } on http.ClientException catch (e) {
      _showSnackBar('$errorMessagePrefix: Kesalahan jaringan: ${e.message}', isError: true);
      print("API ClientException ($endpoint): $e");
      return null;
    } catch (e) {
      _showSnackBar('$errorMessagePrefix: Terjadi kesalahan tak terduga: ${e.runtimeType}', isError: true);
      print("API General Exception ($endpoint): $e");
      return null;
    } finally {
      if (mounted && setLoadingState) {
        if (setLoading != null) {
          setLoading(false);
        }
      }
    }
  }

  // --- Fetch Current Security Question Status ---
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

  // --- Change Password Function ---
  Future<void> _changePassword() async {
    if (!_hasSecurityQuestionSet) {
      _showSnackBar('Harap atur pertanyaan keamanan terlebih dahulu untuk mengubah kata sandi.', isError: true);
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
      _showSnackBar(data['message'] ?? 'Kata sandi berhasil diubah.');
      _passwordFormKey.currentState?.reset();
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  // --- Save/Update Security Question Function ---
  Future<void> _saveSecurityQuestion() async {
    if (!_securityFormKey.currentState!.validate()) {
      return;
    }

    final String? questionToSave = _dropdownSelectedQuestion;
    final String answerToSave = _securityAnswerController.text.trim();

    if (questionToSave == null || questionToSave.isEmpty) {
      _showSnackBar('Silakan pilih pertanyaan keamanan.', isError: true);
      return;
    }
    if (answerToSave.isEmpty) {
      _showSnackBar('Jawaban keamanan tidak boleh kosong.', isError: true);
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
      _showSnackBar(data['message'] ?? 'Pertanyaan & jawaban keamanan berhasil disimpan/diperbarui.');
    }
  }

  // --- Input Decoration Helper ---
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.transparent,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Pengaturan Akun', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFFF5F5),
        foregroundColor: primaryColor,
        elevation: 4,
        shadowColor: Colors.black26,
        centerTitle: true,
      ),
      body: _isFetchingInitialData
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _buildFormContent(),
    );
  }

  // Widget builder for the main content area after initial data fetch
  Widget _buildFormContent() {
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
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.7)),
              ),
            ),

            // --- Change Password Section ---
            _buildCard(
              title: 'Ubah Kata Sandi',
              formKey: _passwordFormKey,
              enabled: canChangePassword,
              disabledMessage: 'Harap atur Pertanyaan Keamanan di bawah ini terlebih dahulu untuk mengaktifkan fitur ini.',
              isLoading: _isLoadingPassword,
              onSave: _changePassword,
              saveButtonText: 'Ubah Kata Sandi',
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
                    child: TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      enabled: canChangePassword,
                      style: GoogleFonts.poppins(),
                      decoration: _inputDecoration('Kata Sandi Saat Ini'),
                      validator: (value) {
                        if (canChangePassword && _newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Kata sandi saat ini diperlukan';
                        }
                        return null;
                      },
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
                    child: TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      enabled: canChangePassword,
                      style: GoogleFonts.poppins(),
                      decoration: _inputDecoration('Kata Sandi Baru (min. 6 karakter)'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (!canChangePassword) return null;
                        if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Kata sandi baru diperlukan';
                        }
                        if (value != null && value.isNotEmpty) {
                          if (value.length < 6) {
                            return 'Kata sandi minimal 6 karakter';
                          }
                          if (value == _currentPasswordController.text) {
                            return 'Kata sandi baru harus berbeda';
                          }
                        }
                        return null;
                      },
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
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      enabled: canChangePassword,
                      style: GoogleFonts.poppins(),
                      decoration: _inputDecoration('Konfirmasi Kata Sandi Baru'),
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
                          return 'Kata sandi tidak cocok';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- Security Question Section ---
            _buildCard(
              title: _hasSecurityQuestionSet ? 'Ubah Pertanyaan Keamanan' : 'Atur Pertanyaan Keamanan',
              formKey: _securityFormKey,
              enabled: true,
              isLoading: _isLoadingSecurity,
              onSave: _saveSecurityQuestion,
              saveButtonText: _hasSecurityQuestionSet ? 'Perbarui Keamanan' : 'Simpan Keamanan',
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
                    child: DropdownButtonFormField<String>(
                      value: _dropdownSelectedQuestion,
                      hint: Text('Pilih Pertanyaan Keamanan', style: GoogleFonts.poppins()),
                      isExpanded: true,
                      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                      decoration: _inputDecoration('Pertanyaan').copyWith(
                        contentPadding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 16.0),
                      ),
                      items: _securityQuestions
                          .map((String question) => DropdownMenuItem<String>(
                                value: question,
                                child: Text(question, style: GoogleFonts.poppins(), overflow: TextOverflow.ellipsis, maxLines: 1),
                              ))
                          .toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _dropdownSelectedQuestion = newValue;
                        });
                      },
                      validator: (value) {
                        if ((_securityAnswerController.text.isNotEmpty || !_hasSecurityQuestionSet) && value == null) {
                          return 'Silakan pilih pertanyaan';
                        }
                        return null;
                      },
                      dropdownColor: Colors.white,
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
                    child: TextFormField(
                      controller: _securityAnswerController,
                      style: GoogleFonts.poppins(),
                      decoration: _inputDecoration('Jawaban Anda'),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoadingSecurity) _saveSecurityQuestion();
                      },
                      validator: (value) {
                        if (_dropdownSelectedQuestion != null && (value == null || value.trim().isEmpty)) {
                          return 'Jawaban tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Reusable Card Widget Builder ---
  Widget _buildCard({
    required String title,
    required Widget child,
    required GlobalKey<FormState> formKey,
    required bool enabled,
    required bool isLoading,
    required VoidCallback onSave,
    required String saveButtonText,
    String? disabledMessage,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: enabled ? primaryColor : primaryColor.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),

                  if (!enabled && disabledMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Text(
                        disabledMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.red.shade700.withOpacity(0.9), fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),

                  child,

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: enabled && !isLoading ? onSave : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white70,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Text(
                            saveButtonText,
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}