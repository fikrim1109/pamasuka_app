import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pamasuka/app_theme.dart'; // Pastikan path import ini benar
import 'package:pamasuka/currency_input_formatter.dart'; // Pastikan path import ini benar

class HomePage extends StatefulWidget {
  final String username;
  final int userId;
  const HomePage({Key? key, required this.username, required this.userId}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
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

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();

  // GANTI DENGAN URL API ANDA YANG BENAR
  final String _submitApiUrl = "https://android.samalonian.my.id/test%20api/submit_survey.php";
  final String _outletApiUrl = "https://android.samalonian.my.id/test%20api/getAreas.php";

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

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
    _namaController.text = widget.username;
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
        content: Text(message),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
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

      _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _namaController.text = widget.username;
    });
    _fetchOutlets();
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
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length || 
        _hargaEntryControllersMap[groupIndex] == null || entryIndex < 0) return;
    
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
          sortedKeys?.forEach((oldIndexKey) {
            if (_hargaEntryControllersMap[groupIndex]![oldIndexKey] != null) {
              updatedControllers[currentNewIndex] = _hargaEntryControllersMap[groupIndex]![oldIndexKey]!;
              currentNewIndex++;
            }
          });
          _hargaEntryControllersMap[groupIndex] = updatedControllers;
          _totalHargaEntriesCount--;
        }
      } else {
        _showStyledSnackBar('Minimal harus ada satu data paket per operator.', isError: true);
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
      var response = await http.get(url).timeout(const Duration(seconds: 25));

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
      final pickedFile = await picker.pickImage(source: source, imageQuality: 75, maxHeight: 1280, maxWidth: 1280);
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
      _showStyledSnackBar('Harap periksa kembali data yang belum terisi atau tidak valid.', isError: true);
      return;
    }
    if (_selectedOutlet == null) {
      _showStyledSnackBar('Outlet belum terpilih atau data outlet gagal dimuat.', isError: true);
      return;
    }
    if (_selectedBrandinganOption == null) {
      _showStyledSnackBar('Silakan pilih jenis survei.', isError: true);
      return;
    }

    List<Map<String, dynamic>> finalHargaData = [];

    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        _showStyledSnackBar('Silakan ambil kedua gambar branding (etalase dan tampak depan).', isError: true);
        return;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      bool isHargaDataValid = true;
      bool hasAnyFilledEntryForAnyOperator = false;
      
      for (int i = 0; i < _operatorSurveyGroups.length; i++) {
        var group = _operatorSurveyGroups[i];
        String operatorName = group["operator"];
        String? paketType = group["paket"];
        List<Map<String, String>> currentEntriesData = [];
        List groupEntriesSource = group["entries"];
        bool operatorHasAtLeastOneFilledEntry = false;

        for (int j = 0; j < groupEntriesSource.length; j++) {
          HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
          String namaPaket = controllers?.namaPaketController.text.trim() ?? "";
          String hargaInput = controllers?.hargaController.text.trim() ?? "";
          String jumlahInput = controllers?.jumlahController.text.trim() ?? "";

          if (namaPaket.isNotEmpty || hargaInput.isNotEmpty || jumlahInput.isNotEmpty) {
            operatorHasAtLeastOneFilledEntry = true;
            hasAnyFilledEntryForAnyOperator = true;

            if (namaPaket.isEmpty || hargaInput.isEmpty || jumlahInput.isEmpty) {
              _showStyledSnackBar('Data paket untuk operator $operatorName (entri ke-${j + 1}) tidak lengkap. Harap isi semua kolom (Nama Paket, Harga, Jumlah) atau kosongkan semua.', isError: true);
              isHargaDataValid = false;
              break;
            }
            String hargaNumerikBersih = hargaInput.replaceAll(RegExp(r'[^0-9]'), '');
            currentEntriesData.add({ "nama_paket": namaPaket, "harga": hargaNumerikBersih, "jumlah": jumlahInput });
          }
        }

        if (!isHargaDataValid) break;

        if (operatorHasAtLeastOneFilledEntry) {
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

      if (hasAnyFilledEntryForAnyOperator && finalHargaData.isEmpty) {
          _showStyledSnackBar('Tidak ada data harga yang valid untuk dikirim. Harap periksa kembali kelengkapan jenis paket dan entri harga.', isError: true);
          return;
      }
    }

    if (mounted) setState(() { _isSubmitting = true; });

    var request = http.MultipartRequest('POST', Uri.parse(_submitApiUrl));
    request.fields['user_id'] = widget.userId.toString();
    request.fields['username'] = widget.username;
    
    if (_namaController.text.trim().isNotEmpty) {
        request.fields['nama_surveyor'] = _namaController.text.trim();
    }

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
          String etalaseFileName = 'etalase_${DateTime.now().millisecondsSinceEpoch}.${_brandingImageEtalase!.path.split('.').last}';
          request.files.add(await http.MultipartFile.fromPath('foto_etalase', _brandingImageEtalase!.path, filename: etalaseFileName));
        }
        if (_brandingImageTampakDepan != null) {
          String depanFileName = 'depan_${DateTime.now().millisecondsSinceEpoch}.${_brandingImageTampakDepan!.path.split('.').last}';
          request.files.add(await http.MultipartFile.fromPath('foto_depan', _brandingImageTampakDepan!.path, filename: depanFileName));
        }
      } else if (_selectedBrandinganOption == "Survei harga") {
        if (finalHargaData.isNotEmpty) {
          request.fields['data_harga'] = jsonEncode(finalHargaData);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        _showErrorDialog('Error Mempersiapkan Data', 'Gagal memproses data survei sebelum mengirim: $e');
      }
      return;
    }

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      var response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        setState(() { _isSubmitting = false; });
        final Map<String, dynamic> data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          _showErrorDialog('Error Parsing Respons Server', 'Format respons dari server tidak valid (bukan JSON).\nIsi Respons:\n${response.body}');
          return;
        }
        
        if (response.statusCode == 200 && data.containsKey('success')) {
            if (data['success'] == true) {
                if (data.containsKey('status') && data['status'] == 'duplicate_found') {
                    _showDuplicateConfirmationDialog(data['message'] ?? 'Data survei untuk outlet ini pada tanggal yang sama sudah ada. Yakin ingin mengirim data baru?');
                } else {
                    _showSuccessDialog(data['message'] ?? 'Data survei berhasil dikirim.');
                    _resetForm();
                }
            } else {
                String errorMessage = data['message'] ?? 'Terjadi kesalahan yang tidak diketahui dari server.';
                _showErrorDialog('Gagal Mengirim Data', errorMessage);
            }
        } else {
            String errorMessage = data.containsKey('message') ? data['message'] : 'Respon server tidak berhasil (Status: ${response.statusCode}).';
            _showErrorDialog('Gagal Mengirim Data', '$errorMessage\nIsi Respons:\n${response.body.substring(0, (response.body.length > 200 ? 200 : response.body.length))}...');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        _showErrorDialog('Error Jaringan atau Timeout', 'Tidak dapat terhubung ke server atau waktu tunggu habis. Periksa koneksi internet Anda.\nDetail: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.error_outline, color: AppSemanticColors.danger(context)),
          const SizedBox(width: 10),
          Text(title, style: theme.dialogTheme.titleTextStyle?.copyWith(color: AppSemanticColors.danger(context)))
        ]),
        content: SingleChildScrollView(child: Text(message, style: theme.dialogTheme.contentTextStyle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Oke', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle_outline, color: AppSemanticColors.success(context)),
          const SizedBox(width: 10),
          Text('Berhasil', style: theme.dialogTheme.titleTextStyle?.copyWith(color: AppSemanticColors.success(context)))
        ]),
        content: Text(message, style: theme.dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Oke', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showDuplicateConfirmationDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppSemanticColors.warning(context)),
          const SizedBox(width: 10),
          Text('Konfirmasi Duplikasi', style: theme.dialogTheme.titleTextStyle?.copyWith(color: AppSemanticColors.warning(context)))
        ]),
        content: Text(message, style: theme.dialogTheme.contentTextStyle),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: <Widget>[
          TextButton(
            child: const Text('Batal'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          ElevatedButton(
            child: const Text('Kirim (Tetap)'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitForm(confirmDuplicate: true);
            },
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        style: theme.textTheme.bodyLarge?.copyWith(
            color: readOnly ? theme.colorScheme.onSurface.withOpacity(0.6) : theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          fillColor: readOnly 
              ? (theme.brightness == Brightness.light 
                  ? Colors.grey.shade200.withOpacity(0.7)
                  : Colors.grey.shade800.withOpacity(0.5))
              : null,
          hintText: hint,
          prefixText: prefixText,
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
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: (image == null && !disabled) ? onPick : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.8)),
              borderRadius: BorderRadius.circular(12),
              color: disabled 
                  ? theme.colorScheme.onSurface.withOpacity(0.05) 
                  : theme.colorScheme.surfaceContainer,
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
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withOpacity(0.65),
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            onTap: disabled ? null : onRetake,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(7.0),
                              child: Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 48, color: disabled ? theme.colorScheme.onSurface.withOpacity(0.4) : theme.colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(
                          "Ketuk untuk mengambil foto",
                          style: theme.textTheme.bodyMedium?.copyWith(color: disabled ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5) : theme.colorScheme.onSurfaceVariant),
                        )
                      ],
                    ),
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
        title: const Text('Formulir Survei'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16,16,16,80),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    _isLoadingOutlets && _outlets.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  const SizedBox(height: 20),
                                  Text("Memuat data outlet...", style: theme.textTheme.titleMedium),
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
                                Text("Informasi Outlet", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
                                Divider(height: 24, thickness: theme.dividerTheme.thickness),
                                _buildTextField(controller: _regionController, label: 'Wilayah', readOnly: true),
                                _buildTextField(controller: _branchController, label: 'Cabang', readOnly: true),
                                _buildTextField(controller: _clusterController, label: 'Klaster', readOnly: true),
                                _buildTextField(controller: _hariController, label: 'Hari Kunjungan (Outlet)', readOnly: true),
                                
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: DropdownSearch<Map<String, dynamic>>(
                                    popupProps: PopupProps.menu(
                                      showSearchBox: true,
                                      searchFieldProps: TextFieldProps(
                                        decoration: InputDecoration( 
                                          hintText: "Cari nama atau ID outlet...",
                                          prefixIcon: Icon(Icons.search_rounded),
                                        ),
                                      ),
                                      menuProps: MenuProps(
                                        backgroundColor: theme.colorScheme.surfaceContainerLowest,
                                        elevation: 4, 
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                      ),
                                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                                      fit: FlexFit.loose,
                                      itemBuilder: (context, item, isSelected) {
                                        return ListTile(
                                          title: Text(item['nama_outlet']?.toString() ?? 'N/A', style: theme.textTheme.bodyLarge),
                                          subtitle: Text("ID: ${item['id_outlet']?.toString() ?? 'N/A'}", style: theme.textTheme.bodySmall),
                                          selected: isSelected,
                                          selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                                          dense: true,
                                        );
                                      },
                                      emptyBuilder: (context, searchEntry) => Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text("Outlet tidak ditemukan", style: theme.textTheme.bodyMedium))),
                                      errorBuilder: (context, searchEntry, exception) => Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text("Gagal memuat outlet", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)))),
                                      loadingBuilder: (context, searchEntry) => Center(child: Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator())),
                                    ),
                                    items: _outlets,
                                    itemAsString: (outlet) => "${outlet['nama_outlet']?.toString() ?? ''} (ID: ${outlet['id_outlet']?.toString() ?? ''})",
                                    selectedItem: _selectedOutlet,
                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                      dropdownSearchDecoration: InputDecoration( 
                                        labelText: "Pilih Outlet *",
                                        hintText: _outlets.isEmpty && !_isLoadingOutlets ? "Tidak ada data outlet" : "Pilih outlet dari daftar",
                                        prefixIcon: Icon(Icons.storefront_outlined),
                                      ),
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
                                        }
                                      });
                                    },
                                    validator: (value) => value == null ? 'Silakan pilih outlet' : null,
                                    enabled: !_isLoadingOutlets && _outlets.isNotEmpty && !_isSubmitting,
                                    compareFn: (item1, item2) => item1?['id_outlet'] == item2?['id_outlet'],
                                  ),
                                ),
                                _buildTextField(controller: _idOutletController, label: 'ID Outlet (Otomatis)', readOnly: true),
                                _buildTextField(controller: _tokoController, label: 'Tanggal Survei (Otomatis)', readOnly: true),
                                const SizedBox(height: 16),

                                Text("Detail Survei", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
                                Divider(height: 24, thickness: theme.dividerTheme.thickness),

                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedBrandinganOption,
                                    hint: Text("Pilih Jenis Survei", style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)),
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      labelText: 'Jenis Survei *',
                                      prefixIcon: Icon(Icons.assessment_outlined),
                                    ),
                                    items: _brandinganOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
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
                                    dropdownColor: theme.colorScheme.surfaceContainerLowest,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                if (_selectedBrandinganOption == "Survei branding") ...[
                                  _buildImagePicker(label: "Foto Etalase *", image: _brandingImageEtalase, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => setState(() => _brandingImageEtalase = file)), onRetake: () => _pickImage(ImageSource.camera, (file) => setState(() => _brandingImageEtalase = file))),
                                  const SizedBox(height: 20),
                                  _buildImagePicker(label: "Foto Tampak Depan *", image: _brandingImageTampakDepan, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => setState(() => _brandingImageTampakDepan = file)), onRetake: () => _pickImage(ImageSource.camera, (file) => setState(() => _brandingImageTampakDepan = file))),
                                  const SizedBox(height: 16),
                                ],

                                if (_selectedBrandinganOption == "Survei harga") ...[
                                  Text("Input Data Harga per Operator", style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
                                  const SizedBox(height: 8),
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
                                          margin: const EdgeInsets.symmetric(vertical: 10.0),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(14,10,14,14),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(operatorName, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                                                    TextButton.icon(
                                                      icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                                      label: Text(isHidden ? 'Tampilkan' : 'Sembunyikan', style: theme.textTheme.labelSmall),
                                                      onPressed: _isSubmitting ? null : () => _toggleGroupVisibility(groupIndex),
                                                    ),
                                                  ],
                                                ),
                                                if (!isHidden) ...[
                                                  Divider(thickness: theme.dividerTheme.thickness, height: 16),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                    child: DropdownButtonFormField<String>(
                                                      validator: null,
                                                      value: group["paket"],
                                                      hint: Text("Pilih Jenis Paket", style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                                                      style: theme.textTheme.bodyMedium,
                                                      decoration: InputDecoration(
                                                        labelText: 'Jenis Paket ',
                                                      ),
                                                      items: _paketOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
                                                      onChanged: _isSubmitting ? null : (value) => setState(() => group["paket"] = value),
                                                      dropdownColor: theme.colorScheme.surfaceContainerLowest,
                                                    ),
                                                  ),
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
                                                            _buildTextField(controller: controllers!.namaPaketController, label: 'Nama Paket', hint: 'Cth: HotRod 2GB / SP DATA 2GB', validator: null, inputFormatters: [LengthLimitingTextInputFormatter(50)], readOnly: _isSubmitting),
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
                                                            _buildTextField(controller: controllers.jumlahController, label: 'Jumlah (pcs)', hint: 'Cth: 10', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], validator: null, readOnly: _isSubmitting),
                                                            if (entries.length > 1)
                                                              Align(
                                                                alignment: Alignment.centerRight,
                                                                child: IconButton(icon: Icon(Icons.remove_circle_outline_rounded, color: AppSemanticColors.danger(context), size: 28), onPressed: _isSubmitting ? null : () => _removeHargaEntry(groupIndex, entryIndex), tooltip: 'Hapus Entri Paket Ini'),
                                                              )
                                                            else
                                                              const SizedBox(height: 48),
                                                            if (entryIndex < entries.length -1) Divider(height: 20, thickness: theme.dividerTheme.thickness, indent: 20, endIndent: 20),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  if (canAddMoreHarga) Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: TextButton.icon(
                                                      icon: Icon(Icons.add_circle_outline_rounded), 
                                                      label: Text('Tambah Data Paket', style: TextStyle(fontWeight: FontWeight.w500)), 
                                                      onPressed: _isSubmitting ? null : () => _addHargaEntry(groupIndex)
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
                                  if (!canAddMoreHarga) Padding(padding: const EdgeInsets.only(top: 10.0, bottom: 10.0), child: Row(children: [Icon(Icons.info_outline_rounded, color: AppSemanticColors.warning(context), size: 18), const SizedBox(width: 8), Expanded(child: Text("Batas maksimal $_maxHargaEntries data paket telah tercapai untuk semua operator.", style: theme.textTheme.bodySmall?.copyWith(color: AppSemanticColors.warning(context), fontStyle: FontStyle.italic)))])),
                                  const SizedBox(height: 16),
                                ],

                                _buildTextField(controller: _keteranganController, label: 'Keterangan Kunjungan *', hint: 'Masukkan detail atau catatan penting lainnya...', maxLines: 5, readOnly: _isSubmitting, validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Keterangan kunjungan wajib diisi';
                                  if (value.trim().length < 10) return 'Keterangan terlalu pendek (minimal 10 karakter)';
                                  return null;
                                }),
                                const SizedBox(height: 30),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: _isSubmitting ? Container() : Icon(Icons.send_rounded),
                                    label: _isSubmitting
                                        ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary)))
                                        : Text('Kirim Data Survei', style: theme.textTheme.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.bold)),
                                    onPressed: _isSubmitting ? null : () => _submitForm(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    if (_isSubmitting) 
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.scrim.withOpacity(0.7), 
                            borderRadius: (theme.cardTheme.shape is RoundedRectangleBorder && (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius != null)
                                ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context))
                                : BorderRadius.circular(12.0), // Default jika tidak ada atau bukan RoundedRectangleBorder
                          ), 
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min, 
                              children: [
                                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary)), 
                                const SizedBox(height: 18), 
                                Text(
                                  "Mengirim data...", 
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onPrimary, 
                                    fontWeight: FontWeight.bold
                                  )
                                )
                              ]
                            )
                          )
                        )
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