// File: lib/EditFormPage.dart
import 'dart:convert';
import 'dart:io'; // For File handling
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:http/http.dart' as http; // For network requests
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:intl/intl.dart'; // For date/number formatting
import 'package:pamasuka/app_theme.dart'; // Import AppTheme

// --- Helper Class for Price Entry Controllers (Original Version from EditFormPage) ---
class HargaEntryControllers {
  final TextEditingController namaPaketController;
  final TextEditingController hargaController;
  final TextEditingController jumlahController;

  HargaEntryControllers({String nama = '', String harga = '', String jumlah = ''})
      : namaPaketController = TextEditingController(text: nama),
        hargaController = TextEditingController(text: harga), // Expects formatted harga for display
        jumlahController = TextEditingController(text: jumlah);

  void dispose() {
    namaPaketController.dispose();
    hargaController.dispose();
    jumlahController.dispose();
  }

  Map<String, String> getData() {
    // Remove dots for submission, keeps existing logic for Rupiah formatting
    String hargaNumerikBersih = hargaController.text.trim().replaceAll('.', '');
    return {
      "nama_paket": namaPaketController.text.trim(),
      "harga": hargaNumerikBersih,
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
  final String _updateApiUrl = "https://android.samalonian.my.id/test%20api/update_survey.php";

  late int _surveyId;
  late String _initialJenisSurvei;
  bool _isSubmitting = false;

  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _displayOutletNamaController = TextEditingController();
  final TextEditingController _displayTanggalController = TextEditingController();
  final TextEditingController _displayUsernameController = TextEditingController();

  String? _existingEtalaseUrl;
  String? _existingDepanUrl;
  File? _newEtalaseFile;
  File? _newDepanFile;

  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"];
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 100;

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
    _displayUsernameController.text = data['username'] ?? '';

    String formattedDate = 'Tanggal tidak tersedia';
    final rawDate = data['tanggal_survei']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        // Using 'id_ID' for Indonesian date formatting
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(rawDate));
      } catch (e) {
        formattedDate = 'Format Tanggal Salah: $rawDate';
      }
    }
    _displayTanggalController.text = formattedDate;

    if (_initialJenisSurvei == 'Survei branding') {
      _existingEtalaseUrl = data['foto_etalase_url']?.toString();
      _existingDepanUrl = data['foto_depan_url']?.toString();
    } else if (_initialJenisSurvei == 'Survei harga') {
      _initializeHargaSurveyFromData(data['data_harga']?.toString());
    }

    if (_surveyId == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStyledDialog(context, title: 'Data Tidak Lengkap', content: 'ID Survei tidak ditemukan. Tidak dapat mengedit.', isError: true);
      });
    }
  }

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
        decodedData = [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showStyledDialog(context, title: 'Data Harga Rusak', content: 'Gagal memuat data harga yang ada. Error: $e', isError: true);
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
        "entries": [], // Will be populated with formatted data
        "isHidden": false
      });
      if (entriesData.isNotEmpty) {
        for (int j = 0; j < entriesData.length; j++) {
          if (_totalHargaEntriesCount >= _maxHargaEntries) break;
          var entry = entriesData[j];
          String nama = entry['nama_paket']?.toString() ?? '';
          String hargaRaw = entry['harga']?.toString() ?? '';
          String displayHarga = hargaRaw; // Default to raw if formatting fails
          try {
            if (hargaRaw.isNotEmpty) {
              final priceNum = int.parse(hargaRaw.replaceAll('.', ''));
              displayHarga = NumberFormat('#,###', 'id_ID').format(priceNum);
            }
          } catch (e) { /* Keep original if parsing/formatting fails */ }
          String jumlah = entry['jumlah']?.toString() ?? '';
          
          // Store raw data for submission, but use displayHarga for controller
          _operatorSurveyGroups[i]["entries"].add({"nama_paket": nama, "harga": hargaRaw, "jumlah": jumlah});
          _hargaEntryControllersMap[i]![j] = HargaEntryControllers(nama: nama, harga: displayHarga, jumlah: jumlah);
          _totalHargaEntriesCount++;
        }
      } else {
        // Add a blank entry if no existing entries for this operator
        _operatorSurveyGroups[i]["entries"].add({"nama_paket": "", "harga": "", "jumlah": ""});
        _hargaEntryControllersMap[i]![0] = HargaEntryControllers();
        _totalHargaEntriesCount++;
      }
      // Hide group if no package type was selected (implies no data for this operator)
      if (selectedPaket == null || selectedPaket.isEmpty) {
        _operatorSurveyGroups[i]["isHidden"] = true;
      }
    }
    if (mounted) setState(() {});
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

  void _showStyledSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Theme.of(context).snackBarTheme.contentTextStyle),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
      ),
    );
  }

  void _showStyledDialog(BuildContext context, {required String title, required String content, bool isError = false, List<Widget>? actions}) {
    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: theme.dialogTheme.titleTextStyle),
        content: Text(content, style: theme.dialogTheme.contentTextStyle),
        actions: actions ?? <Widget>[
          TextButton(
            child: Text('OK', style: TextStyle(color: theme.colorScheme.primary)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        if (mounted) {
          setState(() { onImagePicked(File(pickedFile.path)); });
        }
      }
    } catch (e) {
      if (mounted) {
        _showStyledDialog(context, title: 'Gagal Ambil Gambar', content: 'Terjadi kesalahan: $e', isError: true);
      }
    }
  }

  void _addHargaEntry(int groupIndex) {
    if (_totalHargaEntriesCount >= _maxHargaEntries) {
      _showStyledSnackBar(context, 'Batas maksimal $_maxHargaEntries data paket tercapai', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""});
      _hargaEntryControllersMap[groupIndex] ??= {};
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
          // Re-index controllers after removal
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
        _showStyledSnackBar(context, 'Minimal harus ada satu data paket per operator', isError: true);
      }
    });
  }

  void _toggleGroupVisibility(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
    if (!mounted) return;
    setState(() { _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"]; });
  }

  Future<void> _updateForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showStyledSnackBar(context, 'Harap periksa kembali data yang belum terisi atau tidak valid', isError: true);
      return;
    }
    if (_surveyId <= 0) {
      _showStyledDialog(context, title: 'Error Internal', content: 'ID Survei tidak valid. Gagal melanjutkan.', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() { _isSubmitting = true; });

    var request = http.MultipartRequest('POST', Uri.parse(_updateApiUrl));
    request.fields['id'] = _surveyId.toString();
    request.fields['user_id'] = widget.userId.toString();
    request.fields['jenis_survei'] = _initialJenisSurvei; // Jenis survei tidak bisa diubah saat edit
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
          if (paketType != null && paketType.isNotEmpty) { // Only include groups with a selected package type
            List<Map<String, String>> currentEntriesData = [];
            if (_hargaEntryControllersMap.containsKey(i)) {
              _hargaEntryControllersMap[i]!.forEach((entryIndex, controllers) {
                var entryData = controllers.getData(); // This now returns harga without dots
                // Only add if at least one field in the entry has data
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
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        _showStyledDialog(context, title: 'Error Mempersiapkan Data', content: 'Gagal memproses data survei sebelum mengirim: $e', isError: true);
      }
      return;
    }

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 90)); // Increased timeout
      var response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;
      setState(() { _isSubmitting = false; });

      if (response.statusCode == 200) {
        try {
          var responseData = jsonDecode(response.body);
          if (responseData is Map && responseData['success'] == true) {
            _showStyledDialog(context, title: 'Sukses', content: responseData['message'] ?? 'Data survei berhasil diperbarui.', 
              actions: [
                TextButton(
                  child: Text('OK', style: TextStyle(color: Theme.of(context).colorScheme.primary)), 
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(true); // Pop EditFormPage with result true, indicating success
                  }
                )
              ]
            );
          } else {
            String errorMessage = responseData is Map && responseData.containsKey('message') ? responseData['message'] : 'Terjadi kesalahan yang tidak diketahui dari server.';
            _showStyledDialog(context, title: 'Gagal Memperbarui Data', content: errorMessage, isError: true);
          }
        } catch (e) {
          _showStyledDialog(context, title: 'Gagal Memproses Respons', content: 'Respons server tidak valid: $e. Isi Respons: ${response.body}', isError: true);
        }
      } else {
        String errorBody = response.body;
        try {
          var decodedError = jsonDecode(errorBody);
          if (decodedError is Map && decodedError.containsKey('message')) {
            errorBody = decodedError['message'];
          }
        } catch (e) { /* Use raw body if not JSON */ }
        _showStyledDialog(context, title: 'Gagal Memperbarui Data', content: 'Error ${response.statusCode}: $errorBody', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        _showStyledDialog(context, title: 'Kesalahan Jaringan', content: 'Gagal mengirim data: $e', isError: true);
      }
    }
  }

  // Helper to build text form fields with consistent styling
  Widget _buildReadOnlyTextField(String label, String value, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
          filled: true,
          fillColor: colorScheme.onSurface.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
      ),
    );
  }

  Widget _buildImagePickerSection(ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    Widget imageDisplay(String? url, File? file) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
        ),
        child: file != null
            ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.file(file, fit: BoxFit.cover))
            : (url != null && url.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.7)))))
                : Center(child: Icon(Icons.image_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.7)))),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Foto Etalase Branding", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            imageDisplay(_existingEtalaseUrl, _newEtalaseFile),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_newEtalaseFile == null && _existingEtalaseUrl == null ? "Ambil Gambar" : "Ganti Gambar"),
              onPressed: () => _pickImage(ImageSource.camera, (file) => setState(() => _newEtalaseFile = file)),
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary),
            ),
            const SizedBox(height: 24),
            Text("Foto Tampak Depan Toko", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            imageDisplay(_existingDepanUrl, _newDepanFile),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_newDepanFile == null && _existingDepanUrl == null ? "Ambil Gambar" : "Ganti Gambar"),
              onPressed: () => _pickImage(ImageSource.camera, (file) => setState(() => _newDepanFile = file)),
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorGroupCard(int groupIndex, ThemeData theme) {
    final group = _operatorSurveyGroups[groupIndex];
    final String operatorName = group["operator"];
    final bool isHidden = group["isHidden"] ?? false;
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(operatorName, style: textTheme.titleLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: colorScheme.secondary),
                  onPressed: () => _toggleGroupVisibility(groupIndex),
                ),
              ],
            ),
            if (!isHidden) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Jenis Paket",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                value: group["paket"],
                items: _paketOptions.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface)));
                }).toList(),
                onChanged: (String? newValue) {
                  if (mounted) setState(() { _operatorSurveyGroups[groupIndex]["paket"] = newValue; });
                },
                validator: (value) => value == null || value.isEmpty ? "Jenis paket harus dipilih" : null,
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (_operatorSurveyGroups[groupIndex]["entries"] as List).length,
                itemBuilder: (context, entryIndex) {
                  return _buildHargaEntryCard(groupIndex, entryIndex, theme);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Tambah Paket"),
                  onPressed: () => _addHargaEntry(groupIndex),
                  style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // MODIFIED: _buildHargaEntryCard to use vertical layout for EditFormPage.dart
  Widget _buildHargaEntryCard(int groupIndex, int entryIndex, ThemeData theme) {
    HargaEntryControllers? controllers = _hargaEntryControllersMap[groupIndex]?[entryIndex];
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;
    final priceFormatter = NumberFormat("#,###", "id_ID");

    InputDecoration hargaFieldDecoration(String label, {String? prefix}) {
        return InputDecoration(
            labelText: label,
            labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
            prefixText: prefix,
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Data Paket #${entryIndex + 1}", style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
              ),
              if ((_operatorSurveyGroups[groupIndex]["entries"] as List).length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error, size: 24),
                  onPressed: () => _removeHargaEntry(groupIndex, entryIndex),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers?.namaPaketController,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            decoration: hargaFieldDecoration("Nama Paket"),
            validator: (v) => v == null || v.trim().isEmpty ? "Nama Paket Wajib Diisi" : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers?.hargaController,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            decoration: hargaFieldDecoration("Harga", prefix: "Rp "),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                final numericValue = int.tryParse(newValue.text.replaceAll(".", ""));
                if (numericValue == null) return oldValue;
                final formattedText = priceFormatter.format(numericValue);
                return TextEditingValue(
                  text: formattedText,
                  selection: TextSelection.collapsed(offset: formattedText.length),
                );
              }),
            ],
            validator: (v) => v == null || v.trim().isEmpty ? "Harga Wajib Diisi" : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers?.jumlahController,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            decoration: hargaFieldDecoration("Jumlah Stok"),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => v == null || v.trim().isEmpty ? "Jumlah Wajib Diisi" : null,
          ),
          if (entryIndex < (_operatorSurveyGroups[groupIndex]["entries"] as List).length - 1)
            const Divider(height: 24, thickness: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Survei: ${widget.outletName}", style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary)),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Informasi Umum Survei", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildReadOnlyTextField("Nama Outlet", _displayOutletNamaController.text, theme),
                      _buildReadOnlyTextField("Tanggal Survei", _displayTanggalController.text, theme),
                      _buildReadOnlyTextField("Jenis Survei", _initialJenisSurvei, theme),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          controller: _keteranganController,
                          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: "Keterangan Kunjungan",
                            labelStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          validator: (value) => value == null || value.trim().isEmpty ? "Keterangan tidak boleh kosong" : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_initialJenisSurvei == 'Survei branding') ...[
                const SizedBox(height: 24),
                Text("Edit Gambar Branding", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildImagePickerSection(theme),
              ],
              if (_initialJenisSurvei == 'Survei harga') ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Edit Survei Harga", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    Text("Total Entri: $_totalHargaEntriesCount/$_maxHargaEntries", style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _operatorSurveyGroups.length,
                  itemBuilder: (context, groupIndex) {
                    return _buildOperatorGroupCard(groupIndex, theme);
                  },
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isSubmitting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary)) : const Icon(Icons.save_alt_outlined),
                label: Text(_isSubmitting ? "Menyimpan..." : "Simpan Perubahan"),
                onPressed: _isSubmitting ? null : _updateForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

