// File: lib/EditFormPage.dart
import 'dart:convert';
import 'dart:io'; // For File handling
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:http/http.dart' as http; // For network requests
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:intl/intl.dart'; // For date/number formatting
import 'package:google_fonts/google_fonts.dart'; // For Poppins font

// --- Helper Class for Price Entry Controllers (Same as HomePage) ---
class HargaEntryControllers {
  final TextEditingController namaPaketController;
  final TextEditingController hargaController;
  final TextEditingController jumlahController;

  // Constructor initializes controllers with optional initial text
  HargaEntryControllers({String nama = '', String harga = '', String jumlah = ''})
      : namaPaketController = TextEditingController(text: nama),
        hargaController = TextEditingController(text: harga), // Keep original format for display
        jumlahController = TextEditingController(text: jumlah);

  void dispose() {
    namaPaketController.dispose();
    hargaController.dispose();
    jumlahController.dispose();
  }

  // Helper to get data from controllers, cleaning the price
  Map<String, String> getData() {
    // Clean numeric input for harga (remove dots) before getting data
    String hargaNumerikBersih = hargaController.text.trim().replaceAll('.', '');
    return {
      "nama_paket": namaPaketController.text.trim(),
      "harga": hargaNumerikBersih, // Send cleaned numeric string
      "jumlah": jumlahController.text.trim(),
    };
  }
}
// --- End Helper Class ---

class EditFormPage extends StatefulWidget {
  final int userId;
  final String outletName; // For display context
  final Map<String, dynamic> formData; // Data passed from ViewFormPage

  const EditFormPage({
    Key? key,
    required this.userId,
    required this.outletName,
    required this.formData,
  }) : super(key: key);

  @override
  State<EditFormPage> createState() => _EditFormPageState();
}

class _EditFormPageState extends State<EditFormPage> {
  final _formKey = GlobalKey<FormState>();
  final String _updateApiUrl = "https://tunnel.jato.my.id/test%20api/update_survey.php";

  // --- Style Colors ---
  final Color primaryColor = const Color(0xFFC0392B); // Red accent

  // --- State Variables ---
  late int _surveyId;
  late String _initialJenisSurvei;
  bool _isSubmitting = false;

  // --- Controllers ---
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _displayOutletNamaController = TextEditingController();
  final TextEditingController _displayTanggalController = TextEditingController();
  final TextEditingController _displayUsernameController = TextEditingController();

  // --- Branding State ---
  String? _existingEtalaseUrl;
  String? _existingDepanUrl;
  File? _newEtalaseFile;
  File? _newDepanFile;

  // --- Price Survey State ---
  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"];
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 15;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final data = widget.formData;

    _surveyId = data['id'] ?? 0;
    _initialJenisSurvei = data['jenis_survei'] ?? '';

    _keteranganController.text = data['keterangan_kunjungan'] ?? '';
    _displayOutletNamaController.text = data['outlet_nama'] ?? widget.outletName;
    _displayUsernameController.text = data['username'] ?? ''; // Make sure username exists or handle null

    String formattedDate = 'Tanggal tidak tersedia';
    final rawDate = data['tanggal_survei']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(rawDate));
      } catch (e) {
        formattedDate = 'Format Tanggal Salah: $rawDate';
        print("Error parsing date in EditForm init: $e");
      }
    }
    _displayTanggalController.text = formattedDate;

    if (_initialJenisSurvei == 'Survei branding') {
      _existingEtalaseUrl = data['foto_etalase_url']?.toString();
      _existingDepanUrl = data['foto_depan_url']?.toString();
      print("Init Edit Branding: Etalase URL=$_existingEtalaseUrl, Depan URL=$_existingDepanUrl");
    } else if (_initialJenisSurvei == 'Survei harga') {
      _initializeHargaSurveyFromData(data['data_harga']?.toString());
    }

    if (_surveyId == 0) {
      print("Error: Survey ID is missing or invalid in formData!");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog('Data Tidak Lengkap', 'ID Survei tidak ditemukan. Tidak dapat mengedit.');
      });
    }
  }

  // --- Pre-fill Logic for Price Survey ---
  void _initializeHargaSurveyFromData(String? jsonDataString) {
    _operatorSurveyGroups = [];
    _hargaEntryControllersMap = {};
    _totalHargaEntriesCount = 0;

    List<dynamic> decodedData = [];
    if (jsonDataString != null && jsonDataString.isNotEmpty && jsonDataString != '[]') {
      try {
        decodedData = json.decode(jsonDataString);
        if (decodedData is! List) decodedData = [];
      } catch (e) {
        print("Error decoding existing price data JSON: $e");
        decodedData = [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorDialog('Data Harga Rusak', 'Gagal memuat data harga yang ada. Error: $e');
        });
      }
    }

    Map<String, Map<String, dynamic>> existingOperatorData = {};
    for (var item in decodedData) {
      if (item is Map<String, dynamic> && item['operator'] != null) {
        existingOperatorData[item['operator']] = item;
      }
    }

    for (int i = 0; i < _fixedOperators.length; i++) {
      String operatorName = _fixedOperators[i];
      Map<String, dynamic>? currentData = existingOperatorData[operatorName];

      String? selectedPaket = currentData?['paket'] as String?;
      List<dynamic> entriesRaw = currentData?['entries'] ?? [];
      List<Map<String, dynamic>> entriesData = entriesRaw.whereType<Map<String, dynamic>>().toList();

      _hargaEntryControllersMap[i] = {};
      _operatorSurveyGroups.add({
        "operator": operatorName,
        "paket": selectedPaket,
        "entries": [],
        "isHidden": false
      });

      if (entriesData.isNotEmpty) {
        for (int j = 0; j < entriesData.length; j++) {
          if (_totalHargaEntriesCount >= _maxHargaEntries) break;
          var entry = entriesData[j];
          String nama = entry['nama_paket']?.toString() ?? '';
          String harga = entry['harga']?.toString() ?? '';
          // Format price with dots for display in controller if it's numeric
          String displayHarga = harga;
          try {
            if (harga.isNotEmpty) {
              final priceNum = int.parse(harga.replaceAll('.', '')); // Remove dots for parsing
              displayHarga = NumberFormat('#,###', 'id_ID').format(priceNum); // Format with dots
            }
          } catch (e) { /* Keep original if formatting fails */ }

          String jumlah = entry['jumlah']?.toString() ?? '';

          _operatorSurveyGroups[i]["entries"].add({"nama_paket": nama, "harga": harga, "jumlah": jumlah});
          _hargaEntryControllersMap[i]![j] = HargaEntryControllers(nama: nama, harga: displayHarga, jumlah: jumlah); // Use formatted price for display
          _totalHargaEntriesCount++;
        }
      } else {
        _operatorSurveyGroups[i]["entries"].add({"nama_paket": "", "harga": "", "jumlah": ""});
        _hargaEntryControllersMap[i]![0] = HargaEntryControllers();
        _totalHargaEntriesCount++;
      }

      if (selectedPaket == null || selectedPaket.isEmpty) {
        _operatorSurveyGroups[i]["isHidden"] = true;
      }
    }
    if (mounted) setState(() {});
    print("Initialized Price Survey Groups: ${_operatorSurveyGroups.length}, Total Entries: $_totalHargaEntriesCount");
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _displayOutletNamaController.dispose();
    _displayTanggalController.dispose();
    _displayUsernameController.dispose();
    _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose()));
    super.dispose();
  }

  // --- Image Picking Logic ---
  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            onImagePicked(File(pickedFile.path));
          });
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        _showErrorDialog('Gagal Ambil Gambar', 'Terjadi kesalahan: $e');
      }
    }
  }

  // --- Add/Remove Price Entry Logic ---
  void _addHargaEntry(int groupIndex) {
    if (_totalHargaEntriesCount >= _maxHargaEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batas maksimal $_maxHargaEntries data paket tercapai', style: GoogleFonts.poppins())),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""});
      if (_hargaEntryControllersMap[groupIndex] == null) _hargaEntryControllersMap[groupIndex] = {};
      _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();
      _totalHargaEntriesCount++;
    });
  }

  void _removeHargaEntry(int groupIndex, int entryIndex) {
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length || _hargaEntryControllersMap[groupIndex] == null || entryIndex < 0) return;
    if (!mounted) return;
    setState(() {
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      if (entries.length > 1) {
        if (entryIndex < entries.length) {
          _hargaEntryControllersMap[groupIndex]?[entryIndex]?.dispose();
          _hargaEntryControllersMap[groupIndex]?.remove(entryIndex);
          entries.removeAt(entryIndex);
          Map<int, HargaEntryControllers> updatedControllers = {};
          int currentNewIndex = 0;
          var sortedKeys = _hargaEntryControllersMap[groupIndex]?.keys.toList()?..sort();
          sortedKeys?.forEach((oldIndex) {
            if (_hargaEntryControllersMap[groupIndex]![oldIndex] != null) {
              updatedControllers[currentNewIndex] = _hargaEntryControllersMap[groupIndex]![oldIndex]!;
              currentNewIndex++;
            }
          });
          _hargaEntryControllersMap[groupIndex] = updatedControllers;
          _totalHargaEntriesCount--;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Minimal harus ada satu data paket per operator', style: GoogleFonts.poppins())),
        );
      }
    });
  }

  // --- Toggle Group Visibility ---
  void _toggleGroupVisibility(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
    if (!mounted) return;
    setState(() {
      _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"];
    });
  }

  // --- Update Form Submission Logic ---
  Future<void> _updateForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Harap periksa kembali data yang belum terisi atau tidak valid', style: GoogleFonts.poppins())),
      );
      return;
    }
    if (_surveyId <= 0) {
      _showErrorDialog('Error Internal', 'ID Survei tidak valid. Gagal melanjutkan.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    var request = http.MultipartRequest('POST', Uri.parse(_updateApiUrl));
    request.fields['id'] = _surveyId.toString();
    request.fields['user_id'] = widget.userId.toString();
    request.fields['jenis_survei'] = _initialJenisSurvei;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();

    try {
      if (_initialJenisSurvei == 'Survei branding') {
        if (_newEtalaseFile != null) request.files.add(await http.MultipartFile.fromPath('foto_etalase', _newEtalaseFile!.path));
        if (_newDepanFile != null) request.files.add(await http.MultipartFile.fromPath('foto_depan', _newDepanFile!.path));
      } else if (_initialJenisSurvei == 'Survei harga') {
        List<Map<String, dynamic>> finalHargaData = [];
        for (int i = 0; i < _operatorSurveyGroups.length; i++) {
          var group = _operatorSurveyGroups[i];
          String? paketType = group["paket"];
          if (paketType != null && paketType.isNotEmpty) {
            List<Map<String, String>> currentEntriesData = [];
            // Ensure the map exists before iterating
            if (_hargaEntryControllersMap.containsKey(i)) {
              _hargaEntryControllersMap[i]!.forEach((entryIndex, controllers) {
                // Basic validation within entry before adding
                var entryData = controllers.getData();
                if (entryData['nama_paket']!.isNotEmpty || entryData['harga']!.isNotEmpty || entryData['jumlah']!.isNotEmpty) {
                  currentEntriesData.add(entryData);
                }
              });
            }
            if (currentEntriesData.isNotEmpty) {
              finalHargaData.add({"operator": group["operator"], "paket": paketType, "entries": currentEntriesData});
            }
          }
        }
        request.fields['data_harga'] = jsonEncode(finalHargaData);
        print("Adding price data JSON: ${request.fields['data_harga']}");
      }
    } catch (e) {
      print("Error preparing request data (file/json): $e");
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showErrorDialog('Error Mempersiapkan Data', 'Gagal memproses data survei sebelum mengirim: $e');
      }
      return;
    }

    try {
      print("--- Sending Update Request ---");
      print("URL: $_updateApiUrl");
      print("Fields: ${request.fields}");
      print("Files attached: ${request.files.length}");

      var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      var response = await http.Response.fromStream(streamedResponse);

      print("Update Response Status: ${response.statusCode}");
      print("Update Response Body: ${response.body}");

      if (!mounted) return; // Check mounted again after await

      setState(() {
        _isSubmitting = false;
      }); // Stop loading indicator

      if (response.statusCode == 200) {
        try {
          var responseData = jsonDecode(response.body);
          if (responseData is Map && responseData['success'] == true) {
            _showSuccessDialog(responseData['message'] ?? 'Data survei berhasil diperbarui.');
          } else {
            String errorMessage = responseData is Map && responseData.containsKey('message')
                ? responseData['message']
                : 'Terjadi kesalahan yang tidak diketahui dari server.';
            _showErrorDialog('Gagal Memperbarui Data', errorMessage);
          }
        } catch (e) {
          print("Error decoding update response JSON: $e");
          _showErrorDialog('Gagal Memproses Respon', 'Respon dari server tidak valid.');
        }
      } else {
        _showErrorDialog('Error Server', 'Gagal terhubung ke server (Kode: ${response.statusCode}).\n${response.reasonPhrase ?? ''}');
      }
    } catch (e, stacktrace) {
      print("Error sending update form: $e\n$stacktrace");
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showErrorDialog('Error Jaringan', 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.\nError: $e');
      }
    }
  }

  // --- Dialog Helpers ---
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(child: Text(message, style: GoogleFonts.poppins())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins(color: primaryColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Berhasil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Pop Edit page, return true
            },
            child: Text('OK', style: GoogleFonts.poppins(color: primaryColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Input Decoration Helper ---
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? prefixText,
    IconData? prefixIcon,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade600) : null,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
      prefixStyle: GoogleFonts.poppins(color: Colors.black54),
      filled: true,
      fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade100,
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

  // --- Widget Builders ---

  // Build TextField for display fields
  Widget _buildDisplayTextField({required TextEditingController controller, required String label}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: _inputDecoration(label: label, isReadOnly: true),
      style: GoogleFonts.poppins(color: Colors.grey.shade800),
      enableInteractiveSelection: false,
      focusNode: FocusNode(canRequestFocus: false),
    );
  }

  // Build TextField for editable fields
  Widget _buildEditableTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        prefixText: prefixText,
        isReadOnly: readOnly,
      ),
      style: GoogleFonts.poppins(color: readOnly ? Colors.grey.shade700 : Colors.black87),
    );
  }

  // Build Image Picker
  Widget _buildImagePicker({
    required String label,
    required String? existingImageUrl,
    required File? newImageFile,
    required VoidCallback onPick,
    bool disabled = false,
  }) {
    Widget imageWidget;
    bool hasExisting = existingImageUrl != null && existingImageUrl.isNotEmpty;
    bool hasNew = newImageFile != null;

    if (hasNew) {
      imageWidget = Image.file(newImageFile!, fit: BoxFit.cover);
    } else if (hasExisting) {
      Uri? uri = Uri.tryParse(existingImageUrl!);
      bool isValidUrl = uri != null && uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
      if (isValidUrl) {
        imageWidget = Image.network(
          existingImageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                color: primaryColor,
                strokeWidth: 2.5,
              ),
            );
          },
          errorBuilder: (context, error, stack) => Center(child: Icon(Icons.broken_image_outlined, color: Colors.redAccent.shade100, size: 40)),
        );
      } else {
        imageWidget = Center(child: Icon(Icons.broken_image_outlined, color: Colors.redAccent.shade100, size: 40));
      }
    } else {
      imageWidget = Center(child: Icon(Icons.image_not_supported_outlined, size: 40, color: disabled ? Colors.grey.shade500 : Colors.grey.shade600));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: disabled ? Colors.grey.shade200 : Colors.grey.shade50,
          ),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11.0),
                child: imageWidget,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    tooltip: hasNew || hasExisting ? "Ambil Ulang Foto" : "Ambil Foto",
                    onPressed: disabled ? null : onPick,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    bool canAddMoreHarga = _totalHargaEntriesCount < _maxHargaEntries;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit Survei: ${widget.outletName}', style: GoogleFonts.poppins()),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF5F5),
        foregroundColor: primaryColor,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: primaryColor),
            tooltip: 'Simpan Perubahan',
            onPressed: _isSubmitting ? null : _updateForm,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Headers
                          Text(
                            "Informasi Survei (Tidak Dapat Diubah)",
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Divider(color: Colors.grey.shade300),
                          const SizedBox(height: 10),

                          // Read Only Fields
                          _buildDisplayTextField(controller: _displayOutletNamaController, label: 'Nama Outlet'),
                          const SizedBox(height: 16),
                          _buildDisplayTextField(controller: _displayTanggalController, label: 'Tanggal Survei Asli'),
                          const SizedBox(height: 16),

                          // Display Jenis Survei
                          InputDecorator(
                            decoration: _inputDecoration(label: 'Jenis Survei', isReadOnly: true),
                            child: Text(_initialJenisSurvei, style: GoogleFonts.poppins(color: Colors.grey.shade800, fontSize: 14)),
                          ),
                          const SizedBox(height: 24),

                          // Section Header
                          Text(
                            "Data Yang Dapat Diedit",
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Divider(color: Colors.grey.shade300),
                          const SizedBox(height: 10),

                          // Editable Keterangan
                          _buildEditableTextField(
                            controller: _keteranganController,
                            label: 'Keterangan Kunjungan *',
                            hint: 'Update detail atau catatan penting...',
                            maxLines: 5,
                            readOnly: _isSubmitting,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Keterangan tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Conditional Edit Sections
                          // === BRANDING EDIT ===
                          if (_initialJenisSurvei == "Survei branding") ...[
                            _buildImagePicker(
                              label: "Foto Etalase (Klik ikon untuk ganti)",
                              existingImageUrl: _existingEtalaseUrl,
                              newImageFile: _newEtalaseFile,
                              disabled: _isSubmitting,
                              onPick: () => _pickImage(ImageSource.camera, (file) => _newEtalaseFile = file),
                            ),
                            const SizedBox(height: 16),
                            _buildImagePicker(
                              label: "Foto Tampak Depan (Klik ikon untuk ganti)",
                              existingImageUrl: _existingDepanUrl,
                              newImageFile: _newDepanFile,
                              disabled: _isSubmitting,
                              onPick: () => _pickImage(ImageSource.camera, (file) => _newDepanFile = file),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // === HARGA EDIT ===
                          if (_initialJenisSurvei == "Survei harga") ...[
                            AbsorbPointer(
                              absorbing: _isSubmitting,
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _operatorSurveyGroups.length,
                                itemBuilder: (context, groupIndex) {
                                  final group = _operatorSurveyGroups[groupIndex];
                                  bool isHidden = group["isHidden"];
                                  List entries = group["entries"];
                                  String operatorName = group["operator"];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header Grup
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  operatorName,
                                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              TextButton.icon(
                                                icon: Icon(
                                                  isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                  size: 20,
                                                  color: Colors.grey.shade600,
                                                ),
                                                label: Text(
                                                  isHidden ? 'Tampilkan' : 'Sembunyikan',
                                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                                onPressed: _isSubmitting ? null : () => _toggleGroupVisibility(groupIndex),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  minimumSize: const Size(0, 30),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!isHidden) ...[
                                            Divider(color: Colors.grey.shade300, height: 20),
                                            // Dropdown Paket
                                            Container(
                                              decoration: BoxDecoration(
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: DropdownButtonFormField<String>(
                                                value: group["paket"],
                                                isExpanded: true,
                                                decoration: _inputDecoration(
                                                  label: 'Paket',
                                                  hint: 'Pilih Paket',
                                                  prefixIcon: Icons.category,
                                                ),
                                                items: _paketOptions
                                                    .map((option) => DropdownMenuItem<String>(
                                                          value: option,
                                                          child: Text(option, style: GoogleFonts.poppins()),
                                                        ))
                                                    .toList(),
                                                onChanged: _isSubmitting
                                                    ? null
                                                    : (value) {
                                                        setState(() {
                                                          _operatorSurveyGroups[groupIndex]["paket"] = value;
                                                        });
                                                      },
                                                validator: (value) {
                                                  if (!isHidden && (value == null || value.isEmpty)) {
                                                    return 'Pilih jenis paket';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            // List Entri Harga
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: entries.length,
                                              itemBuilder: (context, entryIndex) {
                                                if (_hargaEntryControllersMap[groupIndex] == null ||
                                                    _hargaEntryControllersMap[groupIndex]![entryIndex] == null) {
                                                  return const SizedBox.shrink();
                                                }
                                                HargaEntryControllers controllers = _hargaEntryControllersMap[groupIndex]![entryIndex]!;
                                                return Container(
                                                  padding: const EdgeInsets.all(10).copyWith(bottom: 0),
                                                  margin: const EdgeInsets.only(bottom: 10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.grey.shade200),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Data Paket Ke-${entryIndex + 1}",
                                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // TextFields using the builder
                                                      _buildEditableTextField(
                                                        controller: controllers.namaPaketController,
                                                        label: 'Nama Paket *',
                                                        hint: 'Contoh: Xtra Combo Lite L 3.5GB',
                                                        readOnly: _isSubmitting,
                                                        validator: (value) {
                                                          if (group["paket"] != null && group["paket"].isNotEmpty) {
                                                            if (value == null || value.trim().isEmpty) {
                                                              return 'Masukkan nama paket';
                                                            }
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                      const SizedBox(height: 16),
                                                      _buildEditableTextField(
                                                        controller: controllers.hargaController,
                                                        label: 'Harga Satuan *',
                                                        prefixText: 'Rp ',
                                                        hint: 'Contoh: 10000',
                                                        readOnly: _isSubmitting,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                                        validator: (value) {
                                                          if (group["paket"] != null && group["paket"].isNotEmpty) {
                                                            if (value == null || value.trim().isEmpty) {
                                                              return 'Masukkan harga';
                                                            }
                                                            final numericString = value.replaceAll('.', '').replaceAll(',', '');
                                                            if (numericString.isEmpty || double.tryParse(numericString) == null) {
                                                              return 'Format angka tidak valid';
                                                            }
                                                            if (double.parse(numericString) <= 0) {
                                                              return 'Harga harus > 0';
                                                            }
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                      const SizedBox(height: 16),
                                                      _buildEditableTextField(
                                                        controller: controllers.jumlahController,
                                                        label: 'Jumlah *',
                                                        hint: 'Jumlah barang/stok',
                                                        readOnly: _isSubmitting,
                                                        keyboardType: TextInputType.number,
                                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                        validator: (value) {
                                                          if (group["paket"] != null && group["paket"].isNotEmpty) {
                                                            if (value == null || value.trim().isEmpty) {
                                                              return 'Masukkan jumlah';
                                                            }
                                                            final numValue = int.tryParse(value);
                                                            if (numValue == null || numValue < 0) {
                                                              return 'Jumlah harus angka >= 0';
                                                            }
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                      const SizedBox(height: 0),
                                                      // Remove Button
                                                      Align(
                                                        alignment: Alignment.centerRight,
                                                        child: (entries.length > 1)
                                                            ? TextButton.icon(
                                                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                                                label: Text(
                                                                  "Hapus",
                                                                  style: GoogleFonts.poppins(color: Colors.red.shade600, fontSize: 12),
                                                                ),
                                                                onPressed: _isSubmitting ? null : () => _removeHargaEntry(groupIndex, entryIndex),
                                                                style: TextButton.styleFrom(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                  minimumSize: const Size(0, 30),
                                                                ),
                                                              )
                                                            : const SizedBox(height: 25),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            // Add Button
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                icon: Icon(Icons.add_circle_outline, size: 20, color: _isSubmitting || !canAddMoreHarga ? Colors.grey : primaryColor),
                                                label: Text(
                                                  "Tambah Data Paket",
                                                  style: GoogleFonts.poppins(
                                                    color: _isSubmitting || !canAddMoreHarga ? Colors.grey : primaryColor,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: _isSubmitting || !canAddMoreHarga ? null : () => _addHargaEntry(groupIndex),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  minimumSize: const Size(0, 30),
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              child: Text(
                                                'Data operator ini disembunyikan',
                                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!canAddMoreHarga)
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  'Batas maksimal data paket tercapai',
                                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ], // End Survei Harga Edit

                          // --- Submit Button ---
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.save, color: Colors.white),
                              label: Text(
                                _isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                              ),
                              onPressed: _isSubmitting ? null : _updateForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                disabledBackgroundColor: Colors.grey.shade400,
                                disabledForegroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),

                    // --- Loading Overlay ---
                    if (_isSubmitting)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: primaryColor),
                                SizedBox(height: 15),
                                Text(
                                  "Menyimpan perubahan...",
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}