import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pamasuka/app_theme.dart'; // Import AppTheme
import 'package:pamasuka/currency_input_formatter.dart'; // Import CurrencyInputFormatter

class RumahPage extends StatefulWidget {
  final String username; // Username from login
  final int userId;
  const RumahPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  State<RumahPage> createState() => _RumahPageState();
}

class HargaEntryControllers {
  final TextEditingController namaPaketController;
  final TextEditingController hargaController;
  final TextEditingController jumlahController;

  HargaEntryControllers()
      : namaPaketController = TextEditingController(),
        hargaController = TextEditingController(),
        jumlahController = TextEditingController();

  void dispose() {
    namaPaketController.dispose();
    hargaController.dispose();
    jumlahController.dispose();
  }
}

class _RumahPageState extends State<RumahPage> {
  final _formKey = GlobalKey<FormState>();

  final String _submitApiUrl = "https://tunnel.jato.my.id/test%20api/submit_survey.php";
  final String _outletApiUrl = "https://tunnel.jato.my.id/test%20api/getAreas.php";

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController();
  final TextEditingController _namaController = TextEditingController(); // Editable Surveyor Name
  final TextEditingController _tokoController = TextEditingController(); // Survey Date
  final TextEditingController _keteranganController = TextEditingController(); // Keterangan Kunjungan

  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoadingOutlets = false;
  bool _isSubmitting = false;

  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"];

  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 15; 
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];

  @override
  void initState() {
    super.initState();
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fetchOutlets();
  }

  @override
  void dispose() {
    _regionController.dispose();
    _branchController.dispose();
    _clusterController.dispose();
    _namaController.dispose();
    _tokoController.dispose();
    _idOutletController.dispose();
    _hariController.dispose();
    _keteranganController.dispose();
    _hargaEntryControllersMap.values.forEach((entryMap) {
      entryMap.values.forEach((controllers) {
        controllers.dispose();
      });
    });
    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Theme.of(context).snackBarTheme.contentTextStyle ?? TextStyle(color: Theme.of(context).colorScheme.onInverseSurface)),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _namaController.clear(); 
      _keteranganController.clear();
      _selectedBrandinganOption = null;
      _brandingImageEtalase = null;
      _brandingImageTampakDepan = null;
      _operatorSurveyGroups.clear();
      _hargaEntryControllersMap.values.forEach((entryMap) {
        entryMap.values.forEach((controllers) => controllers.dispose());
      });
      _hargaEntryControllersMap.clear();
      _totalHargaEntriesCount = 0;

      if (_selectedOutlet != null) {
        // Fields related to outlet are auto-filled
      } else {
        _idOutletController.clear();
        _regionController.clear();
        _branchController.clear();
        _clusterController.clear();
        _hariController.clear();
      }
      _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    });
  }

  void _initializeFixedSurveyHarga() {
    setState(() {
      _operatorSurveyGroups.clear();
      _hargaEntryControllersMap.values.forEach((entryMap) {
        entryMap.values.forEach((controllers) => controllers.dispose());
      });
      _hargaEntryControllersMap.clear();
      _totalHargaEntriesCount = 0;

      for (int i = 0; i < _fixedOperators.length; i++) {
        String operatorName = _fixedOperators[i];
        _operatorSurveyGroups.add({
          "operator": operatorName,
          "paket": null,
          "entries": [{"nama_paket": "", "harga": "", "jumlah": ""}],
          "isHidden": false
        });
        _hargaEntryControllersMap[i] = { 0: HargaEntryControllers() };
        _totalHargaEntriesCount++;
      }
    });
  }

  void _addHargaEntry(int groupIndex) {
    if (_totalHargaEntriesCount >= _maxHargaEntries) {
      _showStyledSnackBar('Batas maksimal $_maxHargaEntries data paket tercapai', isError: true);
      return;
    }
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
        _showStyledSnackBar('Minimal harus ada satu data paket per operator', isError: true);
      }
    });
  }

  void _toggleGroupVisibility(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
    setState(() { _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"]; });
  }

  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoadingOutlets = true;
      _outlets = [];
      _selectedOutlet = null;
      _idOutletController.clear();
      _regionController.clear();
      _branchController.clear();
      _clusterController.clear();
      _hariController.clear();
    });
    try {
      var url = Uri.parse('$_outletApiUrl?user_id=${widget.userId}');
      var response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data is Map && data.containsKey('success') && data['success'] == true && data['outlets'] is List) {
          final List<Map<String, dynamic>> fetchedOutlets = List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
          Map<String, dynamic>? initialOutlet;
          String initialId = '', initialRegion = '', initialBranch = '', initialCluster = '', initialHari = '';

          if (fetchedOutlets.isNotEmpty) {
            initialOutlet = fetchedOutlets[0];
            initialId = initialOutlet['id_outlet']?.toString() ?? '';
            initialRegion = initialOutlet['region'] ?? '';
            initialBranch = initialOutlet['branch'] ?? '';
            initialCluster = initialOutlet['cluster'] ?? initialOutlet['area'] ?? '';
            initialHari = initialOutlet['hari'] ?? '';
          }

          if (mounted) {
            setState(() {
              _outlets = fetchedOutlets;
              _selectedOutlet = initialOutlet;
              _idOutletController.text = initialId;
              _regionController.text = initialRegion;
              _branchController.text = initialBranch;
              _clusterController.text = initialCluster;
              _hariController.text = initialHari;
            });
          }
        } else {
          String errorMessage = data is Map && data.containsKey('message') ? data['message'] : 'Gagal mengambil data outlet: Format data tidak sesuai.';
          if (mounted) _showStyledSnackBar(errorMessage, isError: true);
        }
      } else {
        if (mounted) _showStyledSnackBar('Gagal mengambil data outlet (Error Server: ${response.statusCode})', isError: true);
      }
    } catch (e) {
      if (mounted) _showStyledSnackBar('Terjadi kesalahan jaringan saat mengambil outlet: $e', isError: true);
    } finally {
      if (mounted) { setState(() { _isLoadingOutlets = false; }); }
    }
  }

  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        if (mounted) { setState(() { onImagePicked(File(pickedFile.path)); }); }
      }
    } catch (e) {
      if (mounted) _showStyledSnackBar('Gagal mengambil gambar: $e', isError: true);
    }
  }

  Future<void> _submitForm({bool confirmDuplicate = false}) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showStyledSnackBar('Harap periksa kembali data yang belum terisi atau tidak valid', isError: true);
      return;
    }
    if (_selectedOutlet == null) {
      _showStyledSnackBar('Outlet belum terpilih atau data outlet gagal dimuat', isError: true);
      return;
    }
    if (_selectedBrandinganOption == null) {
      _showStyledSnackBar('Silakan pilih jenis survei', isError: true);
      return;
    }
    if (_namaController.text.trim().isEmpty) {
        _showStyledSnackBar('Nama Surveyor tidak boleh kosong.', isError: true);
        return;
    }

    List<Map<String, dynamic>> finalHargaData = [];

    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        _showStyledSnackBar('Silakan ambil kedua gambar branding', isError: true);
        return;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      bool isHargaDataValid = true;
      for (int i = 0; i < _operatorSurveyGroups.length; i++) {
        var group = _operatorSurveyGroups[i];
        String operatorName = group["operator"];
        String? paketType = group["paket"];
        List<Map<String, String>> currentEntriesData = [];
        List groupEntriesSource = group["entries"];
        bool operatorHasFilledEntries = false;

        for (int j = 0; j < groupEntriesSource.length; j++) {
          HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
          String namaPaket = controllers?.namaPaketController.text.trim() ?? "";
          String hargaInput = controllers?.hargaController.text.trim() ?? "";
          String jumlahInput = controllers?.jumlahController.text.trim() ?? "";

          if (namaPaket.isNotEmpty || hargaInput.isNotEmpty || jumlahInput.isNotEmpty) {
            operatorHasFilledEntries = true;
            if (namaPaket.isEmpty || hargaInput.isEmpty || jumlahInput.isEmpty) {
              _showStyledSnackBar('Data paket untuk operator $operatorName (entri ke-${j + 1}) tidak lengkap. Harap isi semua kolom atau kosongkan semua.', isError: true);
              isHargaDataValid = false;
              break;
            }
            String hargaNumerikBersih = hargaInput.replaceAll(RegExp(r'[^0-9]'), '');
            currentEntriesData.add({ "nama_paket": namaPaket, "harga": hargaNumerikBersih, "jumlah": jumlahInput });
          }
        }

        if (!isHargaDataValid) break;

        if (operatorHasFilledEntries) {
          if (paketType == null || paketType.isEmpty) {
            _showStyledSnackBar('Jenis paket untuk operator $operatorName belum dipilih.', isError: true);
            isHargaDataValid = false;
            break;
          }
          if (currentEntriesData.isNotEmpty) {
             finalHargaData.add({ "operator": operatorName, "paket": paketType, "entries": currentEntriesData });
          }
        }
      }
      if (!isHargaDataValid) return;
      bool anyEntryFilledAcrossOperators = _operatorSurveyGroups.any((group) => 
          (group["entries"] as List).any((entry) => 
              (_hargaEntryControllersMap[ _operatorSurveyGroups.indexOf(group)]?[ (group["entries"] as List).indexOf(entry)]?.namaPaketController.text.trim().isNotEmpty ?? false) ||
              (_hargaEntryControllersMap[ _operatorSurveyGroups.indexOf(group)]?[ (group["entries"] as List).indexOf(entry)]?.hargaController.text.trim().isNotEmpty ?? false) ||
              (_hargaEntryControllersMap[ _operatorSurveyGroups.indexOf(group)]?[ (group["entries"] as List).indexOf(entry)]?.jumlahController.text.trim().isNotEmpty ?? false)
          )
      );
      if (finalHargaData.isEmpty && anyEntryFilledAcrossOperators) {
          _showStyledSnackBar('Tidak ada data harga yang valid untuk dikirim. Harap periksa kembali entri Anda.', isError: true);
          return;
      }
    }

    if (mounted) setState(() { _isSubmitting = true; });

    var request = http.MultipartRequest('POST', Uri.parse(_submitApiUrl));
    request.fields['user_id'] = widget.userId.toString();
    request.fields['username'] = widget.username; 
    request.fields['nama_surveyor'] = _namaController.text.trim(); 
    request.fields['outlet_id'] = _idOutletController.text;
    request.fields['outlet_nama'] = _selectedOutlet?['nama_outlet']?.toString() ?? 'N/A';
    request.fields['region'] = _regionController.text;
    request.fields['branch'] = _branchController.text;
    request.fields['cluster'] = _clusterController.text;
    request.fields['hari'] = _hariController.text;
    request.fields['tanggal_survei'] = _tokoController.text;
    request.fields['jenis_survei'] = _selectedBrandinganOption!;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();
    if (confirmDuplicate) {
      request.fields['confirm_duplicate'] = 'true';
    }

    try {
      if (_selectedBrandinganOption == "Survei branding") {
        if (_brandingImageEtalase != null) {
          request.files.add(await http.MultipartFile.fromPath('foto_etalase', _brandingImageEtalase!.path));
        }
        if (_brandingImageTampakDepan != null) {
          request.files.add(await http.MultipartFile.fromPath('foto_depan', _brandingImageTampakDepan!.path));
        }
      } else if (_selectedBrandinganOption == "Survei harga") {
        request.fields['data_harga'] = jsonEncode(finalHargaData);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        _showErrorDialog('Error Mempersiapkan Data', 'Gagal memproses data survei sebelum mengirim: $e');
      }
      return;
    }

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        setState(() { _isSubmitting = false; });
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data is Map && data.containsKey('success') && data['success'] == true) {
           _showSuccessDialog(data['message'] ?? 'Data survei berhasil dikirim.');
           _resetForm();
        } else if (data is Map && data.containsKey('status') && data['status'] == 'duplicate_found') {
          _showDuplicateConfirmationDialog(data['message'] ?? 'Data duplikat ditemukan. Yakin ingin melanjutkan?');
        } else {
          String errorMessage = data is Map && data.containsKey('message') ? data['message'] : 'Terjadi kesalahan yang tidak diketahui dari server.';
          _showErrorDialog('Gagal Mengirim Data', errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        _showErrorDialog('Error Jaringan', 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.\nError: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.error, color: AppSemanticColors.danger(context)),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(ctx).dialogTheme.titleTextStyle)
        ]),
        content: SingleChildScrollView(child: Text(message, style: Theme.of(ctx).dialogTheme.contentTextStyle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Oke', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
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
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: AppSemanticColors.success(context)),
          const SizedBox(width: 10),
          Text('Berhasil', style: Theme.of(ctx).dialogTheme.titleTextStyle)
        ]),
        content: Text(message, style: Theme.of(ctx).dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Oke', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDuplicateConfirmationDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppSemanticColors.warning(context)),
          const SizedBox(width: 10),
          Text('Konfirmasi', style: Theme.of(ctx).dialogTheme.titleTextStyle)
        ]),
        content: Text(message, style: Theme.of(ctx).dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitForm(confirmDuplicate: true);
            },
            child: Text('Lanjutkan', style: TextStyle(color: AppSemanticColors.danger(context))),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    int maxLines = 1,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), 
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        style: theme.textTheme.bodyLarge?.copyWith(color: readOnly ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          hintText: hint,
        ),
        enableInteractiveSelection: !readOnly,
        focusNode: readOnly ? FocusNode(canRequestFocus: false) : null,
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    File? image,
    required VoidCallback onPick,
    required VoidCallback onRetake,
    bool disabled = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
            color: disabled ? theme.colorScheme.onSurface.withOpacity(0.05) : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: image != null
              ? Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11.0),
                      child: Image.file(image, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                          tooltip: "Ambil Ulang Foto",
                          onPressed: disabled ? null : onRetake,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, size: 40, color: disabled ? theme.colorScheme.onSurface.withOpacity(0.4) : theme.colorScheme.primary),
                    tooltip: "Ambil Foto",
                    onPressed: disabled ? null : onPick,
                  ),
                ),
        ),
      ],
    );
  }

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool canAddMoreHarga = _totalHargaEntriesCount < _maxHargaEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text('Form Survei Rumah', style: TextStyle(color: theme.colorScheme.onPrimary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    _isLoadingOutlets && _outlets.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 50.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: theme.colorScheme.primary),
                                  const SizedBox(height: 15),
                                  Text("Memuat data outlet...", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                                ],
                              ),
                            ),
                          )
                        : Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _namaController, 
                                  label: 'Nama Surveyor *', 
                                  hint: 'Masukkan nama surveyor',
                                  readOnly: _isSubmitting,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Nama surveyor wajib diisi';
                                    return null;
                                  }
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _regionController, label: 'Wilayah', readOnly: true),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _branchController, label: 'Cabang', readOnly: true),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _clusterController, label: 'Klaster', readOnly: true),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _hariController, label: 'Hari Kunjungan (Outlet)', readOnly: true),
                                const SizedBox(height: 16),

                                DropdownSearch<Map<String, dynamic>>(
                                  popupProps: PopupProps.menu(
                                    showSearchBox: true,
                                    searchFieldProps: TextFieldProps(
                                      style: theme.textTheme.bodyLarge,
                                      decoration: InputDecoration(
                                        hintText: "Cari nama outlet...",
                                        prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                                      ),
                                    ),
                                    menuProps: MenuProps(backgroundColor: theme.cardColor, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                                    emptyBuilder: (context, searchEntry) => Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Outlet tidak ditemukan", style: theme.textTheme.bodyMedium))),
                                    errorBuilder: (context, searchEntry, exception) => Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Gagal memuat outlet", style: theme.textTheme.bodyMedium))),
                                    loadingBuilder: (context, searchEntry) => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 2)),
                                  ),
                                  items: _outlets,
                                  itemAsString: (outlet) => outlet['nama_outlet']?.toString() ?? 'Outlet Tidak Dikenal',
                                  selectedItem: _selectedOutlet,
                                  dropdownDecoratorProps: DropDownDecoratorProps(
                                    dropdownSearchDecoration: InputDecoration(
                                      labelText: "Pilih Outlet *",
                                      hintText: _outlets.isEmpty && !_isLoadingOutlets ? "Tidak ada data outlet" : "Pilih outlet lainnya...",
                                      prefixIcon: Icon(Icons.store, color: theme.colorScheme.primary),
                                    ),
                                    baseStyle: theme.textTheme.bodyLarge,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedOutlet = value;
                                      if (value != null) {
                                        _idOutletController.text = value['id_outlet']?.toString() ?? '';
                                        _regionController.text = value['region'] ?? '';
                                        _branchController.text = value['branch'] ?? '';
                                        _clusterController.text = value['cluster'] ?? value['area'] ?? '';
                                        _hariController.text = value['hari'] ?? '';
                                      } else {
                                        _idOutletController.clear();
                                        _regionController.clear();
                                        _branchController.clear();
                                        _clusterController.clear();
                                        _hariController.clear();
                                      }
                                    });
                                  },
                                  validator: (value) => value == null ? 'Silakan pilih outlet' : null,
                                  enabled: !_isLoadingOutlets && _outlets.isNotEmpty && !_isSubmitting,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _idOutletController, label: 'ID Outlet', readOnly: true),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _tokoController, label: 'Tanggal Survei', readOnly: true),
                                const SizedBox(height: 16),

                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedBrandinganOption,
                                  hint: Text("Pilih Jenis Survei", style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)),
                                  style: theme.textTheme.bodyLarge,
                                  decoration: InputDecoration(
                                    labelText: 'Jenis Survei *',
                                    prefixIcon: Icon(Icons.assessment, color: theme.colorScheme.primary),
                                  ),
                                  items: _brandinganOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option, style: theme.textTheme.bodyLarge))).toList(),
                                  onChanged: _isSubmitting ? null : (value) {
                                    setState(() {
                                      _selectedBrandinganOption = value;
                                      _brandingImageEtalase = null;
                                      _brandingImageTampakDepan = null;
                                      if (value == "Survei harga") {
                                        _initializeFixedSurveyHarga();
                                      } else {
                                        _operatorSurveyGroups.clear();
                                        _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose()));
                                        _hargaEntryControllersMap.clear();
                                        _totalHargaEntriesCount = 0;
                                      }
                                    });
                                  },
                                  validator: (value) => (value == null || value.isEmpty) ? 'Silakan pilih jenis survei' : null,
                                  dropdownColor: theme.cardColor,
                                ),
                                const SizedBox(height: 20),

                                if (_selectedBrandinganOption == "Survei branding") ...[
                                  _buildImagePicker(label: "Foto Etalase *", image: _brandingImageEtalase, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file)),
                                  const SizedBox(height: 16),
                                  _buildImagePicker(label: "Foto Tampak Depan *", image: _brandingImageTampakDepan, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file)),
                                  const SizedBox(height: 16),
                                ],

                                if (_selectedBrandinganOption == "Survei harga") ...[
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
                                                Row(
                                                  children: [
                                                    Expanded(child: Text(operatorName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                                                    TextButton.icon(
                                                      icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                                                      label: Text(isHidden ? 'Tampilkan' : 'Sembunyikan', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                                                      onPressed: _isSubmitting ? null : () => _toggleGroupVisibility(groupIndex),
                                                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap, minimumSize: const Size(0, 30)),
                                                    ),
                                                  ],
                                                ),
                                                if (!isHidden) ...[
                                                  const Divider(thickness: 1, height: 20),
                                                  DropdownButtonFormField<String>(
                                                    validator: null, 
                                                    value: group["paket"],
                                                    hint: Text("Pilih Jenis Paket", style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                                                    style: theme.textTheme.bodyMedium,
                                                    decoration: InputDecoration(
                                                      labelText: 'Jenis Paket *',
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.7))),
                                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.7))),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      labelStyle: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                                    ),
                                                    items: _paketOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option, style: theme.textTheme.bodyMedium))).toList(),
                                                    onChanged: _isSubmitting ? null : (value) => setState(() => group["paket"] = value),
                                                    dropdownColor: theme.cardColor,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: entries.length,
                                                    itemBuilder: (context, entryIndex) {
                                                      HargaEntryControllers? controllers = _hargaEntryControllersMap[groupIndex]?[entryIndex];
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                                        child: Column( 
                                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                                          children: [
                                                            _buildTextField(controller: controllers!.namaPaketController, label: 'Nama Paket', hint: 'Cth: HotRod 2GB', validator: null, inputFormatters: [LengthLimitingTextInputFormatter(50)], readOnly: _isSubmitting),
                                                            const SizedBox(height: 8), 
                                                            _buildTextField(
                                                              controller: controllers.hargaController, 
                                                              label: 'Harga (Rp)', 
                                                              hint: 'Cth: 25000',
                                                              keyboardType: TextInputType.number,
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter.digitsOnly, 
                                                                CurrencyInputFormatter(), 
                                                                LengthLimitingTextInputFormatter(12), 
                                                              ],
                                                              validator: null, 
                                                              readOnly: _isSubmitting
                                                            ),
                                                            const SizedBox(height: 8), 
                                                            _buildTextField(controller: controllers.jumlahController, label: 'Jumlah', hint: 'Cth: 10', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], validator: null, readOnly: _isSubmitting),
                                                            if (entries.length > 1) 
                                                              Align(
                                                                alignment: Alignment.centerRight,
                                                                child: IconButton(icon: Icon(Icons.remove_circle_outline, color: AppSemanticColors.danger(context)), onPressed: _isSubmitting ? null : () => _removeHargaEntry(groupIndex, entryIndex), tooltip: 'Hapus Entri'),
                                                              ) 
                                                            else 
                                                              const SizedBox(height: 48), 
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  if (canAddMoreHarga) TextButton.icon(icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary), label: Text('Tambah Data Paket', style: TextStyle(color: theme.colorScheme.primary)), onPressed: _isSubmitting ? null : () => _addHargaEntry(groupIndex)),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (!canAddMoreHarga) Padding(padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), child: Row(children: [Icon(Icons.info_outline, color: AppSemanticColors.warning(context), size: 16), const SizedBox(width: 8), Expanded(child: Text("Batas maksimal $_maxHargaEntries data paket telah tercapai.", style: theme.textTheme.bodySmall?.copyWith(color: AppSemanticColors.warning(context), fontStyle: FontStyle.italic)))])),
                                  const SizedBox(height: 16),
                                ],

                                _buildTextField(controller: _keteranganController, label: 'Keterangan Kunjungan *', hint: 'Masukkan detail atau catatan penting...', maxLines: 5, readOnly: _isSubmitting, validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Keterangan kunjungan wajib diisi';
                                  if (value.trim().length < 10) return 'Keterangan terlalu pendek (min. 10 karakter)';
                                  return null;
                                }),
                                const SizedBox(height: 24),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : () => _submitForm(),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: theme.colorScheme.primary,
                                      disabledBackgroundColor: theme.disabledColor,
                                    ),
                                    child: _isSubmitting
                                        ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary)))
                                        : Text('Kirim Data Survei', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    if (_isSubmitting) Positioned.fill(child: Container(decoration: BoxDecoration(color: theme.colorScheme.scrim.withOpacity(0.5), borderRadius: BorderRadius.circular(16)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary)), const SizedBox(height: 15), Text("Mengirim data...", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold))])))),
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

