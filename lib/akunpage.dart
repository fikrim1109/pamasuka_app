// File: lib/akunpage.dart
import 'dart:convert';
import 'dart:async'; // For Timer/TimeoutException
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Use the same base URL or ensure it's consistent
const String _apiBaseUrl = 'https://tunnel.jato.my.id/test%20api'; // Kept as requested

class AkunPage extends StatefulWidget {
  final int userId;
  final String username; // Username might be useful for display

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
    "Kota kelahiran ibu?",
    "Makanan favorit Anda?",
    "Nama idola/artis favorit?"
  ];

  bool _isLoadingPassword = false;
  bool _isLoadingSecurity = false;
  bool _isFetchingInitialData = true;

  bool get _hasSecurityQuestionSet => _savedSecurityQuestion != null && _savedSecurityQuestion!.isNotEmpty;

  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _securityFormKey = GlobalKey<FormState>();

  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
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
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
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
        if(setLoading != null) {
            setLoading(true);
        } else {
             setState(() { /* Update general loading state if needed */ });
        }
    }

    final url = Uri.parse('$_apiBaseUrl/$endpoint');
    // FIX: Declare response as nullable to satisfy the analyzer
    http.Response? response;
    Map<String, String> headers = {'Content-Type': 'application/json'};
    String? responseBodyForErrorLogging; // To safely log body in case of FormatException

    try {
      if (method.toUpperCase() == 'GET') {
        final queryParams = body.map((key, value) => MapEntry(key, value.toString()));
        final fullUrl = url.replace(queryParameters: queryParams);
        response = await http.get(fullUrl, headers: headers).timeout(const Duration(seconds: 15));
      } else { // POST
        response = await http.post(
          url,
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return null;
      
      // Store body for potential error logging before attempting decode
      responseBodyForErrorLogging = response.body; 

      // Use null assertion `!` because if we reach here without exceptions, response *must* be assigned.
      final data = json.decode(response!.body);

      if (response.statusCode == 200 && data is Map<String, dynamic> && data['success'] == true) {
         return data; // Success
      } else {
        final String message = data is Map<String, dynamic> ? (data['message'] ?? 'Unknown API error.') : 'Invalid response structure.';
        _showSnackBar('$errorMessagePrefix: $message', isError: true, duration: const Duration(seconds: 5));
        return null; // Indicate failure
      }
    } on TimeoutException {
        _showSnackBar('$errorMessagePrefix: Connection timed out.', isError: true);
        return null;
    } on FormatException catch (e) {
        _showSnackBar('$errorMessagePrefix: Invalid server response format.', isError: true);
        // Safely log the response body captured before the decode attempt
        print("API FormatException ($endpoint): $e. Response Body: $responseBodyForErrorLogging");
        return null;
    } on http.ClientException catch (e) {
       _showSnackBar('$errorMessagePrefix: Network error: ${e.message}', isError: true);
        print("API ClientException ($endpoint): $e");
        return null;
    } catch (e) {
        _showSnackBar('$errorMessagePrefix: An unexpected error occurred: ${e.runtimeType}', isError: true);
        print("API General Exception ($endpoint): $e");
        return null;
    } finally {
       if (mounted) {
           if (setLoadingState) {
               if(setLoading != null) {
                   setLoading(false);
               } else {
                   setState(() { /* Update general loading state */ });
               }
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
      errorMessagePrefix: 'Failed to load security data',
      setLoadingState: false,
    );

     String? fetchedQuestion;
     if (data != null && data['question'] != null) {
       String potentialQuestion = data['question'];
       if (_securityQuestions.contains(potentialQuestion)) {
         fetchedQuestion = potentialQuestion;
       } else {
          print("Warning: Fetched security question '$potentialQuestion' is not in the predefined list. Ignoring.");
       }
     }

    if (mounted) {
      setState(() {
        _savedSecurityQuestion = fetchedQuestion;
        _dropdownSelectedQuestion = fetchedQuestion;
        _isFetchingInitialData = false;
      });
    } else {
       // If widget unmounted during fetch, ensure loading state is off if possible
       // This case is unlikely here but good practice in complex scenarios.
       _isFetchingInitialData = false;
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
      errorMessagePrefix: 'Failed to change password',
      setLoading: (loading) => setState(() => _isLoadingPassword = loading)
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
      errorMessagePrefix: 'Failed to save security info',
       setLoading: (loading) => setState(() => _isLoadingSecurity = loading)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Akun'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
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
        child: _isFetchingInitialData
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _buildFormContent(),
      ),
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
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.7)),
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
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        enabled: canChangePassword,
                        decoration: _inputDecoration('Kata Sandi Saat Ini', Icons.lock_clock_outlined),
                        validator: (value) {
                           if (canChangePassword && _newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                             return 'Kata sandi saat ini diperlukan';
                           }
                           return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        enabled: canChangePassword,
                        decoration: _inputDecoration('Kata Sandi Baru (min. 6 karakter)', Icons.lock_outline),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        enabled: canChangePassword,
                        decoration: _inputDecoration('Konfirmasi Kata Sandi Baru', Icons.lock_person_outlined),
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
                    ],
                  ),
                ),

                const SizedBox(height: 30), // Spacer between cards

                // --- Security Question Section ---
                _buildCard(
                  title: _hasSecurityQuestionSet ? 'Ubah Pertanyaan Keamanan' : 'Atur Pertanyaan Keamanan',
                  formKey: _securityFormKey,
                  enabled: true,
                  isLoading: _isLoadingSecurity,
                  onSave: _saveSecurityQuestion,
                  saveButtonText: _hasSecurityQuestionSet ? 'Update Keamanan' : 'Simpan Keamanan',
                  child: Column(
                     children: [
                        DropdownButtonFormField<String>(
                           value: _dropdownSelectedQuestion,
                           hint: const Text('Pilih Pertanyaan Keamanan'),
                           isExpanded: true,
                           focusColor: Colors.white.withOpacity(0.1),
                           decoration: _inputDecoration('Pertanyaan', Icons.shield_outlined).copyWith(
                              contentPadding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 16.0),
                           ),
                           items: _securityQuestions.map((String question) {
                             return DropdownMenuItem<String>(
                               value: question,
                               child: Text(question, overflow: TextOverflow.ellipsis, maxLines: 1,),
                             );
                           }).toList(),
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
                           dropdownColor: Colors.pink.shade50,
                           style: TextStyle(color: Colors.black87, fontSize: 16),
                         ),
                         const SizedBox(height: 16),
                         TextFormField(
                           controller: _securityAnswerController,
                           decoration: _inputDecoration('Jawaban Anda', Icons.question_answer_outlined),
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
       elevation: 4,
       color: const Color(0xFFFFF5F5).withOpacity(0.96),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(15),
         side: BorderSide(color: primaryColor.withOpacity(enabled ? 0.3 : 0.15))
       ),
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
                     style: TextStyle(
                         fontSize: 20,
                         fontWeight: FontWeight.bold,
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
                         style: TextStyle(color: Colors.red.shade700.withOpacity(0.9), fontStyle: FontStyle.italic, fontSize: 13),
                       ),
                     ),

                   child, // The actual form fields

                   const SizedBox(height: 24),
                   ElevatedButton(
                     onPressed: enabled && !isLoading ? onSave : null,
                     style: _buttonStyle(),
                     child: isLoading
                         ? _loadingIndicator()
                         : Text(saveButtonText, style: const TextStyle(fontSize: 16)),
                   ),
                 ],
               ),
             ),
           ),
         ),
       ),
    );
  }

  // --- Helper Widgets (Input Decoration, Button Style, Loading Indicator) ---

  InputDecoration _inputDecoration(String label, IconData icon) {
     return InputDecoration(
       labelText: label,
        labelStyle: TextStyle(color: primaryColor.withOpacity(0.9)),
       prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
       filled: true,
       fillColor: Colors.white.withOpacity(0.95),
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
       ),
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor, width: 2.0),
       ),
       errorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
       ),
       focusedErrorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
       ),
       disabledBorder: OutlineInputBorder(
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        disabledBackgroundColor: primaryColor.withOpacity(0.5),
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