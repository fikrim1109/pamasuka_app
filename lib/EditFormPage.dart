// File: lib/EditFormPage.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pamasuka/app_theme.dart';
import 'package:pamasuka/currency_input_formatter.dart';

// --- Helper Class for Price Entry Controllers ---
class HargaEntryControllers {
  final TextEditingController namaPaketController;
  final TextEditingController hargaController;
  final TextEditingController jumlahController;

  HargaEntryControllers({String nama = '', String harga = '', String jumlah = ''})
      : namaPaketController = TextEditingController(text: nama),
        hargaController = TextEditingController(text: harga),
        jumlahController = TextEditingController(text: jumlah);

  void dispose() {
    namaPaketController.dispose();
    hargaController.dispose();
    jumlahController.dispose();
  }

  Map<String, String> getData() {
    String hargaNumerikBersih = hargaController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
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
  final String outletName;
  final Map<String, dynamic> formData;

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

  // Controllers for display and simple fields
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _displayOutletNamaController = TextEditingController();
  final TextEditingController _displayTanggalController = TextEditingController();

  // State for 'Survei Branding'
  String? _existingEtalaseUrl;
  String? _existingDepanUrl;
  File? _newEtalaseFile;
  File? _newDepanFile;
  
  // 4 Kategori Lama
  List<String> _posterPromoOperators = [];
  List<String> _layarTokoOperators = [];
  List<String> _shopSignOperators = [];
  List<String> _papanHargaOperators = [];
  
  // 4 Kategori Baru (Sekarang Checklist)
  List<String> _wallBrandingOperators = [];
  List<String> _stikerEtalaseOperators = [];
  List<String> _kursiPlastikOperators = [];
  List<String> _akrilikProdukOperators = [];

  String? _fullBrandingOperator;
  final List<String> _brandingOperators = ["Telkomsel", "Indosat", "3", "Smartfren", "XL", "Axis"];

  // --- SLIDER KATEGORI OUTLET (OTOMATIS) ---
  double _kategoriOutletValue = 0; // 0: Tidak ada, 1: Mid, 2: Half, 3: Full
  final Map<int, String> _kategoriLabels = {
    0: "Tidak ada",
    1: "Mid branding",
    2: "Half branding",
    3: "Full branding"
  };

  // State for 'Survei Harga'
  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"];
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];
  final int _maxEntriesPerGroup = 10; 

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

    String formattedDate = 'Tanggal tidak tersedia';
    if (data['tanggal_survei'] != null) {
      try {
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(data['tanggal_survei']));
      } catch (e) { /* ignore */ }
    }
    _displayTanggalController.text = formattedDate;

    if (_initialJenisSurvei == 'Survei branding') {
      _existingEtalaseUrl = data['foto_etalase_url']?.toString();
      _existingDepanUrl = data['foto_depan_url']?.toString();

      // Helper untuk parse JSON List
      List<String> parseList(dynamic jsonStr) {
        if (jsonStr != null && jsonStr.toString().isNotEmpty && jsonStr.toString() != 'null') {
          try {
            return List<String>.from(json.decode(jsonStr.toString()));
          } catch (e) { return []; }
        }
        return [];
      }

      _posterPromoOperators = parseList(data['poster_promo_json']);
      _layarTokoOperators = parseList(data['layar_toko_json']);
      _shopSignOperators = parseList(data['shop_sign_json']);
      _papanHargaOperators = parseList(data['papan_harga_json']);
      
      // Parse 4 Kategori Baru
      _wallBrandingOperators = parseList(data['wall_branding']);
      _stikerEtalaseOperators = parseList(data['stiker_etalase']);
      _kursiPlastikOperators = parseList(data['kursi_plastik']);
      _akrilikProdukOperators = parseList(data['akrilik_produk']);

      _fullBrandingOperator = data['full_branding_operator'] as String?;
      if (_fullBrandingOperator != null && _fullBrandingOperator!.isEmpty) {
        _fullBrandingOperator = null;
      }

      // Hitung kategori outlet berdasarkan data yang sudah diload
      _calculateBrandingCategory();

    } else if (_initialJenisSurvei == 'Survei harga') {
      _initializeHargaSurveyFromData(data['data_harga_json']?.toString());
    }

    if (_surveyId == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStyledDialog(title: 'Data Tidak Lengkap', content: 'ID Survei tidak ditemukan. Tidak dapat mengedit.', isError: true);
      });
    }
  }

  // --- LOGIKA OTOMATISASI SLIDER (Sama dengan HomePage) ---
  void _calculateBrandingCategory() {
    int telkomselCount = 0;
    
    if (_posterPromoOperators.contains("Telkomsel")) telkomselCount++;
    if (_layarTokoOperators.contains("Telkomsel")) telkomselCount++;
    if (_shopSignOperators.contains("Telkomsel")) telkomselCount++;
    if (_papanHargaOperators.contains("Telkomsel")) telkomselCount++;
    if (_wallBrandingOperators.contains("Telkomsel")) telkomselCount++;
    if (_stikerEtalaseOperators.contains("Telkomsel")) telkomselCount++;
    if (_kursiPlastikOperators.contains("Telkomsel")) telkomselCount++;
    if (_akrilikProdukOperators.contains("Telkomsel")) telkomselCount++;

    setState(() {
      if (telkomselCount >= 7) {
        _kategoriOutletValue = 3; // Full
      } else if (telkomselCount >= 4) {
        _kategoriOutletValue = 2; // Half
      } else if (telkomselCount >= 1) {
        _kategoriOutletValue = 1; // Mid
      } else {
        _kategoriOutletValue = 0; // None
      }
    });
  }

  void _initializeHargaSurveyFromData(String? jsonDataString) {
    _operatorSurveyGroups = [];
    _hargaEntryControllersMap = {};

    List<dynamic> savedData = [];
    if (jsonDataString != null && jsonDataString.isNotEmpty) {
      try {
        savedData = json.decode(jsonDataString);
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showStyledDialog(title: 'Data Harga Rusak', content: 'Gagal memuat data harga yang ada. Error: $e', isError: true);
        });
      }
    }

    Map<String, List<dynamic>> existingEntriesMap = {};
    for (var item in savedData) {
      if (item is Map<String, dynamic> && item['operator'] != null && item['paket'] != null) {
        String key = "${item['operator']}-${item['paket']}";
        existingEntriesMap[key] = (item['entries'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      }
    }

    int groupIndex = 0;
    for (String operatorName in _fixedOperators) {
      for (String paketType in _paketOptions) {
        String key = "$operatorName-$paketType";
        List<dynamic> entriesData = existingEntriesMap[key] ?? [];

        _hargaEntryControllersMap[groupIndex] = {};
        _operatorSurveyGroups.add({
          "operator": operatorName,
          "paket": paketType,
          "entries": [], 
          "isHidden": entriesData.isEmpty,
        });

        if (entriesData.isNotEmpty) {
          for (int j = 0; j < entriesData.length; j++) {
            var entry = entriesData[j];
            String nama = entry['nama_paket']?.toString() ?? '';
            String hargaRaw = entry['harga']?.toString() ?? '';
            String displayHarga = hargaRaw;
            try {
              if (hargaRaw.isNotEmpty) {
                displayHarga = NumberFormat('#,###', 'id_ID').format(int.parse(hargaRaw.replaceAll('.', '')));
              }
            } catch (e) { /* ignore */ }
            String jumlah = entry['jumlah']?.toString() ?? '';
            
            (_operatorSurveyGroups[groupIndex]["entries"] as List).add({"nama_paket": nama, "harga": hargaRaw, "jumlah": jumlah});
            _hargaEntryControllersMap[groupIndex]![j] = HargaEntryControllers(nama: nama, harga: displayHarga, jumlah: jumlah);
          }
        } else {
          (_operatorSurveyGroups[groupIndex]["entries"] as List).add({"nama_paket": "", "harga": "", "jumlah": ""});
          _hargaEntryControllersMap[groupIndex]![0] = HargaEntryControllers();
        }
        groupIndex++;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _displayOutletNamaController.dispose();
    _displayTanggalController.dispose();
    _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose()));
    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
      ),
    );
  }

  void _showStyledDialog({required String title, required String content, bool isError = false, List<Widget>? actions}) {
    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context)),
            const SizedBox(width: 10),
            Text(title, style: theme.dialogTheme.titleTextStyle),
          ],
        ),
        content: Text(content, style: theme.dialogTheme.contentTextStyle),
        actions: actions ?? [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 75, maxHeight: 1280, maxWidth: 1280);
      if (pickedFile != null && mounted) setState(() => onImagePicked(File(pickedFile.path)));
    } catch (e) {
      if (mounted) _showStyledDialog(title: 'Gagal Ambil Gambar', content: 'Terjadi kesalahan: $e', isError: true);
    }
  }

  Future<void> _updateForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showStyledSnackBar('Harap periksa kembali data yang tidak valid.', isError: true);
      return;
    }
    if (_surveyId <= 0) {
      _showStyledDialog(title: 'Error Internal', content: 'ID Survei tidak valid.', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = true);

    var request = http.MultipartRequest('POST', Uri.parse(_updateApiUrl));
    request.fields['id'] = _surveyId.toString();
    request.fields['user_id'] = widget.userId.toString();
    request.fields['jenis_survei'] = _initialJenisSurvei;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();

    try {
      if (_initialJenisSurvei == 'Survei branding') {
        if (_newEtalaseFile != null) request.files.add(await http.MultipartFile.fromPath('foto_etalase', _newEtalaseFile!.path));
        if (_newDepanFile != null) request.files.add(await http.MultipartFile.fromPath('foto_depan', _newDepanFile!.path));

        // Kirim Checklist Lama sebagai JSON
        request.fields['poster_promo'] = json.encode(_posterPromoOperators);
        request.fields['layar_toko'] = json.encode(_layarTokoOperators);
        request.fields['shop_sign'] = json.encode(_shopSignOperators);
        request.fields['papan_harga'] = json.encode(_papanHargaOperators);
        
        // Kirim Checklist Baru sebagai JSON
        request.fields['wall_branding'] = json.encode(_wallBrandingOperators);
        request.fields['stiker_etalase'] = json.encode(_stikerEtalaseOperators);
        request.fields['kursi_plastik'] = json.encode(_kursiPlastikOperators);
        request.fields['akrilik_produk'] = json.encode(_akrilikProdukOperators);

        request.fields['full_branding'] = _fullBrandingOperator ?? '';
        request.fields['kategori_outlet'] = _kategoriLabels[_kategoriOutletValue.toInt()] ?? "Tidak ada";

      } else if (_initialJenisSurvei == 'Survei harga') {
        List<Map<String, dynamic>> finalHargaData = [];
        for (int i = 0; i < _operatorSurveyGroups.length; i++) {
          var group = _operatorSurveyGroups[i];
          List<Map<String, String>> currentEntriesData = [];
          
          _hargaEntryControllersMap[i]?.forEach((_, controllers) {
            var entryData = controllers.getData();
            if (entryData['nama_paket']!.isNotEmpty || entryData['harga']!.isNotEmpty || entryData['jumlah']!.isNotEmpty) {
              currentEntriesData.add(entryData);
            }
          });
          
          if (currentEntriesData.isNotEmpty) {
            finalHargaData.add({
              "operator": group["operator"], 
              "paket": group["paket"], 
              "entries": currentEntriesData
            });
          }
        }
        request.fields['data_harga_json'] = jsonEncode(finalHargaData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showStyledDialog(title: 'Error Mempersiapkan Data', content: 'Gagal memproses data: $e', isError: true);
      }
      return;
    }

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      var response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      var responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        _showStyledDialog(
          title: 'Sukses',
          content: responseData['message'] ?? 'Data survei berhasil diperbarui.',
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.of(context).pop(true); 
              },
              child: const Text('OK'),
            )
          ],
        );
      } else {
        _showStyledDialog(title: 'Gagal Memperbarui', content: responseData['message'] ?? 'Terjadi kesalahan.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showStyledDialog(title: 'Kesalahan Jaringan', content: 'Gagal mengirim data: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Survei: ${widget.outletName}"),
      ),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Informasi Umum Survei", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildReadOnlyTextField("Nama Outlet", _displayOutletNamaController.text, theme),
                        _buildReadOnlyTextField("Tanggal Survei", _displayTanggalController.text, theme),
                        _buildReadOnlyTextField("Jenis Survei", _initialJenisSurvei, theme),
                        TextFormField(
                          controller: _keteranganController,
                          decoration: const InputDecoration(labelText: "Keterangan Kunjungan"),
                          keyboardType: TextInputType.multiline,
                          maxLines: 4,
                          validator: (value) => (value == null || value.trim().isEmpty) ? "Keterangan tidak boleh kosong" : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_initialJenisSurvei == 'Survei branding') ...[
                  const SizedBox(height: 24),
                  Text("Edit Detail Branding", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildBrandingEditorSection(theme),
                  const SizedBox(height: 24),
                  Text("Edit Gambar Branding", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildImagePickerSection(theme),
                ],
                if (_initialJenisSurvei == 'Survei harga') ...[
                  const SizedBox(height: 24),
                  Text("Edit Survei Harga", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _operatorSurveyGroups.length,
                    itemBuilder: (context, groupIndex) => _buildOperatorGroupCard(groupIndex, theme),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_outlined),
                  label: Text(_isSubmitting ? "Menyimpan..." : "Simpan Perubahan"),
                  onPressed: _isSubmitting ? null : _updateForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDER HELPERS ---
  Widget _buildReadOnlyTextField(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.colorScheme.onSurface.withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _buildBrandingEditorSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCheckboxSection("1. Poster Promo", _posterPromoOperators, _brandingOperators, theme),
            _buildCheckboxSection("2. Layar Toko", _layarTokoOperators, _brandingOperators, theme),
            _buildCheckboxSection("3. Shop Sign", _shopSignOperators, _brandingOperators, theme),
            _buildCheckboxSection("4. Papan Harga", _papanHargaOperators, _brandingOperators, theme),
            
            const Divider(height: 30),
            Text("Fasilitas Tambahan", style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor)),
            const SizedBox(height: 10),

            // 4 Poin Baru (Checklist)
            _buildCheckboxSection("5. Wall Branding", _wallBrandingOperators, _brandingOperators, theme),
            _buildCheckboxSection("6. Stiker Etalase", _stikerEtalaseOperators, _brandingOperators, theme),
            _buildCheckboxSection("7. Kursi Plastik", _kursiPlastikOperators, _brandingOperators, theme),
            _buildCheckboxSection("8. Akrilik Produk", _akrilikProdukOperators, _brandingOperators, theme),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _fullBrandingOperator,
              hint: const Text("Pilih operator jika full branding"),
              items: _brandingOperators.map((op) => DropdownMenuItem<String>(value: op, child: Text(op))).toList(),
              onChanged: (value) => setState(() => _fullBrandingOperator = value),
              decoration: const InputDecoration(labelText: 'Outlet Full Branding? (Opsional)'),
            ),
            const SizedBox(height: 24),
            
            // --- SLIDER KATEGORI OUTLET (OTOMATIS) ---
            Text("Kategori Outlet (Otomatis)", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text("Dihitung dari jumlah checklist Telkomsel.", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: Column(
                children: [
                   SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: Colors.grey, 
                      activeTrackColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                    child: Slider(
                      value: _kategoriOutletValue,
                      min: 0,
                      max: 3,
                      divisions: 3,
                      label: _kategoriLabels[_kategoriOutletValue.toInt()],
                      onChanged: null, // Disable
                    ),
                   ),
                  Text(
                    "Status: ${_kategoriLabels[_kategoriOutletValue.toInt()]}",
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxSection(String title, List<String> selected, List<String> options, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ...options.map((op) => CheckboxListTile(
          title: Text(op),
          value: selected.contains(op),
          onChanged: (bool? val) {
            setState(() {
              if (val == true) {
                selected.add(op);
              } else {
                selected.remove(op);
              }
              // Panggil kalkulasi ulang setiap ada perubahan
              _calculateBrandingCategory();
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        )),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildImagePickerSection(ThemeData theme) {
    Widget imageDisplay(String? url, File? file, String placeholder) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: file != null
              ? Image.file(file, fit: BoxFit.cover)
              : (url != null && url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(placeholder)))
                  : Center(child: Text(placeholder))),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            imageDisplay(_existingEtalaseUrl, _newEtalaseFile, 'Foto Etalase'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_newEtalaseFile == null ? "Ganti Foto Etalase" : "Foto Etalase Baru"),
              onPressed: () => _pickImage(ImageSource.camera, (file) => setState(() => _newEtalaseFile = file)),
            ),
            const SizedBox(height: 20),
            imageDisplay(_existingDepanUrl, _newDepanFile, 'Foto Tampak Depan'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_newDepanFile == null ? "Ganti Foto Depan" : "Foto Depan Baru"),
              onPressed: () => _pickImage(ImageSource.camera, (file) => setState(() => _newDepanFile = file)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorGroupCard(int groupIndex, ThemeData theme) {
    final group = _operatorSurveyGroups[groupIndex];
    final String cardTitle = "${group["operator"]} (${group["paket"]})";
    final bool isHidden = group["isHidden"] ?? false;
    final List entries = group["entries"] as List;
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cardTitle,
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: colorScheme.secondary),
                  onPressed: () => _toggleGroupVisibility(groupIndex),
                ),
              ],
            ),
            if (!isHidden) ...[
              const Divider(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, entryIndex) => _buildHargaEntryCard(groupIndex, entryIndex, theme),
              ),
              const SizedBox(height: 8),
              if (entries.length < _maxEntriesPerGroup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Tambah Paket"),
                    onPressed: () => _addHargaEntry(groupIndex),
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
  
  void _addHargaEntry(int groupIndex) {
    final entries = _operatorSurveyGroups[groupIndex]["entries"] as List;
    if (entries.length >= _maxEntriesPerGroup) {
      _showStyledSnackBar('Batas maksimal $_maxEntriesPerGroup data paket untuk grup ini tercapai', isError: true);
      return;
    }
    setState(() {
      int newEntryIndex = entries.length;
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""});
      _hargaEntryControllersMap[groupIndex] ??= {};
      _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();
    });
  }

  void _removeHargaEntry(int groupIndex, int entryIndex) {
    setState(() {
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      if (entries.length > 1) {
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
      } else {
        _showStyledSnackBar('Minimal harus ada satu data paket', isError: true);
      }
    });
  }

  void _toggleGroupVisibility(int groupIndex) {
    setState(() { _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"]; });
  }

  Widget _buildHargaEntryCard(int groupIndex, int entryIndex, ThemeData theme) {
    HargaEntryControllers? controllers = _hargaEntryControllersMap[groupIndex]?[entryIndex];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8)
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Paket #${entryIndex + 1}"),
                if ((_operatorSurveyGroups[groupIndex]["entries"] as List).length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error, size: 24),
                    onPressed: () => _removeHargaEntry(groupIndex, entryIndex),
                  ),
              ],
            ),
            TextFormField(
              controller: controllers?.namaPaketController,
              decoration: const InputDecoration(labelText: "Nama Paket"),
            ),
            TextFormField(
              controller: controllers?.hargaController,
              decoration: const InputDecoration(labelText: "Harga"),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
            ),
            TextFormField(
              controller: controllers?.jumlahController,
              decoration: const InputDecoration(labelText: "Jumlah"),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
      ),
    );
  }
}
