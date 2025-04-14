// File: lib/akunpage.dart
import 'dart:convert';
import 'dart:async'; // For Timer/TimeoutException
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Use the same base URL as defined in login_page.dart or define it globally
const String _apiBaseUrl = 'http://10.0.2.2/test%20api'; // Adjust if needed

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
  String? _selectedSecurityQuestion; // Holds the *currently selected/saved* question string
  final List<String> _securityQuestions = const [
    "nama panggilan",
    "nama hewan",
    "kota asal",
    "makanan favorit",
    "artis/idola"
  ];

  bool _isLoadingPassword = false;
  bool _isLoadingSecurity = false;
  bool _isFetchingData = true; // Combined initial fetch state
  bool _hasSecurityQuestionSet = false; // Determined after fetching

  // Separate Form Keys for each section
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _securityFormKey = GlobalKey<FormState>();

  // Theme Colors
  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _fetchSecurityData(); // Fetch initial data on load
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
      ),
    );
  }

  // --- Fetch Current Security Question Status ---
  Future<void> _fetchSecurityData() async {
    if (!mounted) return;
    setState(() { _isFetchingData = true; }); // Show loading indicator

    final url = Uri.parse('$_apiBaseUrl/securityquestion.php?userId=${widget.userId}');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      String? fetchedQuestion;
      bool hasQuestion = false;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['question'] != null) {
            // Check if the fetched question is valid
            if (_securityQuestions.contains(data['question'])) {
               fetchedQuestion = data['question'];
               hasQuestion = true;
            } else {
               print("Warning: Fetched security question '${data['question']}' is not in the allowed list.");
            }
        }
      } else {
         print("Server error fetching security data: ${response.statusCode}");
         // Optionally show error, but allow page to load
         // _showSnackBar('Gagal memuat status keamanan.', isError: true);
      }

      // Update state after fetch attempt
      setState(() {
        _selectedSecurityQuestion = fetchedQuestion; // Will be null if no valid question found
        _hasSecurityQuestionSet = hasQuestion;
        _isFetchingData = false; // Hide loading indicator
      });

    } catch (e) {
       print("Fetch security data exception: $e");
       // Update state even on error to hide loading
       if (mounted) {
         setState(() {
           _selectedSecurityQuestion = null;
           _hasSecurityQuestionSet = false;
           _isFetchingData = false;
           // _showSnackBar('Terjadi kesalahan saat memuat data.', isError: true);
         });
       }
    }
  }

  // --- Change Password Function ---
  Future<void> _changePassword() async {
    // Double check if allowed (should be disabled in UI anyway)
    if (!_hasSecurityQuestionSet) {
      _showSnackBar('Harap atur pertanyaan keamanan terlebih dahulu.', isError: true);
      return;
    }

    if (!_passwordFormKey.currentState!.validate()) {
      return; // Basic form validation failed
    }

    if (!mounted) return;
    setState(() { _isLoadingPassword = true; });

    final url = Uri.parse('$_apiBaseUrl/changepassword.php');
    final body = json.encode({
      'userId': widget.userId,
      'currentPassword': _currentPasswordController.text,
      'newPassword': _newPasswordController.text,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar(data['message'] ?? 'Kata sandi berhasil diubah.', isError: false);
        _passwordFormKey.currentState!.reset(); // Clear fields on success
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _showSnackBar(data['message'] ?? 'Gagal mengubah kata sandi.', isError: true);
      }
    } on TimeoutException {
      _showSnackBar('Koneksi time out. Gagal mengubah kata sandi.', isError: true);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan: ${e.toString()}', isError: true);
      print("Change password error: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoadingPassword = false; });
      }
    }
  }

  // --- Save/Update Security Question Function ---
  Future<void> _saveSecurityQuestion() async {
    if (!_securityFormKey.currentState!.validate()) {
      return; // Basic form validation failed
    }

    // Get the currently selected value from the dropdown in the form
    // Note: _selectedSecurityQuestion state variable might hold the *initial* value.
    // It's better to rely on the form's current state if possible, or ensure
    // the state variable is updated `onChanged`. We'll use the state variable
    // as it's updated by `onChanged`.
    final String? questionToSave = _selectedSecurityQuestion;
    final String answerToSave = _securityAnswerController.text.trim();

    if (questionToSave == null || questionToSave.isEmpty) {
      _showSnackBar('Kesalahan: Pertanyaan tidak terpilih.', isError: true);
      return;
    }
     if (answerToSave.isEmpty) {
       _showSnackBar('Kesalahan: Jawaban tidak boleh kosong.', isError: true);
       return;
    }


    if (!mounted) return;
    setState(() { _isLoadingSecurity = true; });

    final url = Uri.parse('$_apiBaseUrl/securityquestion.php'); // POST to save/update
    final body = json.encode({
      'userId': widget.userId,
      'question': questionToSave,
      'answer': answerToSave,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
         // Success! Update the state to reflect the change
         if (mounted) {
           setState(() {
             _hasSecurityQuestionSet = true; // Mark as set
             // _selectedSecurityQuestion is already updated via onChanged
             // Clear the answer field for next time
              _securityAnswerController.clear();
           });
         }
        _showSnackBar(data['message'] ?? 'Pertanyaan & jawaban keamanan berhasil disimpan/diperbarui.', isError: false);

        // Optional: Automatically focus the current password field if enabled?
        // FocusScope.of(context).requestFocus(_currentPasswordFocusNode);

      } else {
        _showSnackBar(data['message'] ?? 'Gagal menyimpan pertanyaan/jawaban keamanan.', isError: true);
      }
    } on TimeoutException {
      _showSnackBar('Koneksi time out. Gagal menyimpan.', isError: true);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan: ${e.toString()}', isError: true);
      print("Save security question error: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoadingSecurity = false; });
      }
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
        child: _isFetchingData
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _buildFormContent(), // Build content after fetching
      ),
    );
  }

  // Widget builder for the main content area
  Widget _buildFormContent() {
      // Determine if password change should be enabled
      bool canChangePassword = _hasSecurityQuestionSet;

      return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // --- Change Password Section ---
              Card(
                 elevation: 4,
                 color: const Color(0xFFFFF5F5).withOpacity(0.95),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(15),
                   side: BorderSide(color: primaryColor.withOpacity(0.3))
                 ),
                 clipBehavior: Clip.antiAlias,
                 child: Padding(
                   padding: const EdgeInsets.all(20.0),
                   child: IgnorePointer( // Disable interaction if needed
                     ignoring: !canChangePassword,
                     child: Opacity( // Make it visually distinct if disabled
                       opacity: canChangePassword ? 1.0 : 0.5,
                       child: Form(
                         key: _passwordFormKey,
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                           children: [
                             Text(
                               'Ubah Kata Sandi',
                               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                               textAlign: TextAlign.center,
                             ),
                             const SizedBox(height: 15),

                             // Explanatory message if disabled
                             if (!canChangePassword)
                               Padding(
                                 padding: const EdgeInsets.only(bottom: 15.0),
                                 child: Text(
                                   'Harap atur Pertanyaan Keamanan di bawah ini terlebih dahulu untuk mengaktifkan fitur ini.',
                                   textAlign: TextAlign.center,
                                   style: TextStyle(color: Colors.red.shade700, fontStyle: FontStyle.italic),
                                 ),
                               ),

                             TextFormField(
                               controller: _currentPasswordController,
                               obscureText: true,
                               enabled: canChangePassword, // Explicitly enable/disable
                               decoration: _inputDecoration('Kata Sandi Saat Ini', Icons.lock_clock_outlined),
                               validator: (value) {
                                  // Required only if actually changing password
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
                               validator: (value) {
                                 if (!canChangePassword) return null; // Don't validate if disabled
                                  if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                                    return 'Kata sandi baru diperlukan';
                                  }
                                 if (value != null && value.isNotEmpty && value.length < 6) {
                                   return 'Kata sandi minimal 6 karakter';
                                 }
                                  if (value != null && value.isNotEmpty && value == _currentPasswordController.text) {
                                    return 'Kata sandi baru harus berbeda';
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
                               validator: (value) {
                                  if (!canChangePassword) return null;
                                   if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                                     return 'Konfirmasi kata sandi diperlukan';
                                   }
                                 if (value != _newPasswordController.text) {
                                   return 'Kata sandi tidak cocok';
                                 }
                                 return null;
                               },
                             ),
                             const SizedBox(height: 24),
                             ElevatedButton(
                               // Enable button only if conditions met AND not loading
                               onPressed: canChangePassword && !_isLoadingPassword ? _changePassword : null,
                               style: _buttonStyle(),
                               child: _isLoadingPassword
                                   ? _loadingIndicator()
                                   : const Text('Ubah Kata Sandi', style: TextStyle(fontSize: 16)),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),
              ),

              const SizedBox(height: 30), // Spacer between cards

              // --- Security Question Section ---
               Card(
                 elevation: 4,
                 color: const Color(0xFFFFF5F5).withOpacity(0.95),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(15),
                   side: BorderSide(color: primaryColor.withOpacity(0.3))
                 ),
                 clipBehavior: Clip.antiAlias,
                 child: Padding(
                   padding: const EdgeInsets.all(20.0),
                   child: Form(
                     key: _securityFormKey,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                          Text(
                           // Dynamic title based on whether question is already set
                           _hasSecurityQuestionSet ? 'Ubah Pertanyaan Keamanan' : 'Atur Pertanyaan Keamanan',
                           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                           textAlign: TextAlign.center,
                         ),
                         const SizedBox(height: 15),

                         DropdownButtonFormField<String>(
                           value: _selectedSecurityQuestion, // Shows current value if set
                           hint: const Text('Pilih Pertanyaan Keamanan'),
                           isExpanded: true,
                           decoration: _inputDecoration('Pertanyaan', Icons.shield_outlined).copyWith(
                             contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                           ),
                           items: _securityQuestions.map((String question) {
                             return DropdownMenuItem<String>(
                               value: question,
                               child: Text(question, overflow: TextOverflow.ellipsis),
                             );
                           }).toList(),
                           onChanged: (String? newValue) {
                              // Update the state variable when user makes a selection
                              setState(() {
                                _selectedSecurityQuestion = newValue;
                              });
                           },
                           validator: (value) {
                              // Question is required if the answer field has text
                              if (_securityAnswerController.text.isNotEmpty && value == null) {
                                return 'Silakan pilih pertanyaan';
                              }
                              // Also required if user hasn't set one before and tries to save
                              if (!_hasSecurityQuestionSet && value == null){
                                  return 'Pertanyaan keamanan wajib diisi';
                              }
                             return null;
                           },
                         ),
                         const SizedBox(height: 16),
                         TextFormField(
                           controller: _securityAnswerController,
                           decoration: _inputDecoration('Jawaban Anda', Icons.question_answer_outlined),
                            // Answer field should start empty
                           validator: (value) {
                              // Answer required if a question is selected
                              if (_selectedSecurityQuestion != null && (value == null || value.trim().isEmpty)) {
                                return 'Jawaban tidak boleh kosong';
                              }
                             return null;
                           },
                         ),
                         const SizedBox(height: 24),
                         ElevatedButton(
                           onPressed: _isLoadingSecurity ? null : _saveSecurityQuestion,
                           style: _buttonStyle(),
                           child: _isLoadingSecurity
                               ? _loadingIndicator()
                               : Text(
                                 // Dynamic button text
                                 _hasSecurityQuestionSet ? 'Update Keamanan' : 'Simpan Keamanan',
                                 style: const TextStyle(fontSize: 16)
                               ),
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
            ],
          ),
      );
  }

  // Helper for input decoration
  InputDecoration _inputDecoration(String label, IconData icon) {
     // Style is kept consistent from previous versions
     return InputDecoration(
       labelText: label,
       prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
       filled: true,
       fillColor: Colors.white.withOpacity(0.9),
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide.none,
       ),
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: primaryColor, width: 1.8),
       ),
       errorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
       ),
       focusedErrorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
       ),
       disabledBorder: OutlineInputBorder( // Style when disabled
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
       ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
     );
   }

   // Helper for button style
   ButtonStyle _buttonStyle() {
      return ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
        textStyle: const TextStyle(fontWeight: FontWeight.bold)
      );
   }

   // Helper for loading indicator
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