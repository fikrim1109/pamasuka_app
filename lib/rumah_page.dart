// File: lib/rumah_page.dart
import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:http/http.dart" as http;
import "package:dropdown_search/dropdown_search.dart";
import "package:pamasuka/app_theme.dart"; // Import AppTheme

class RumahPage extends StatefulWidget {
  final String username;
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
  final int _maxHargaEntries = 100;
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];

  @override
  void initState() {
    super.initState();
    _tokoController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
    // _namaController.text = widget.username; // Surveyor name is now editable by user request
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
        content: Text(message, style: Theme.of(context).snackBarTheme.contentTextStyle),
        backgroundColor: isError ? AppSemanticColors.danger(context) : AppSemanticColors.success(context),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _keteranganController.clear();
      _namaController.clear(); // Clear surveyor name as well
      _selectedBrandinganOption = null;
      _brandingImageEtalase = null;
      _brandingImageTampakDepan = null;
      _operatorSurveyGroups.clear();
      _hargaEntryControllersMap.values.forEach((entryMap) {
        entryMap.values.forEach((controllers) => controllers.dispose());
      });
      _hargaEntryControllersMap.clear();
      _totalHargaEntriesCount = 0;
      if (_selectedOutlet == null) {
        _idOutletController.clear();
        _regionController.clear();
        _branchController.clear();
        _clusterController.clear();
        _hariController.clear();
      }
      _tokoController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
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
        _hargaEntryControllersMap[i] = {0: HargaEntryControllers()};
        _totalHargaEntriesCount++;
      }
    });
  }

  void _addHargaEntry(int groupIndex) {
    if (_totalHargaEntriesCount >= _maxHargaEntries) {
      _showStyledSnackBar("Batas maksimal $_maxHargaEntries data paket tercapai", isError: true);
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
        _showStyledSnackBar("Minimal harus ada satu data paket per operator", isError: true);
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
      var url = Uri.parse("$_outletApiUrl?user_id=${widget.userId}");
      var response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data is Map && data.containsKey("success") && data["success"] == true && data["outlets"] is List) {
          final List<Map<String, dynamic>> fetchedOutlets = List<Map<String, dynamic>>.from(data["outlets"] as List<dynamic>);
          Map<String, dynamic>? initialOutlet;
          String initialId = "", initialRegion = "", initialBranch = "", initialCluster = "", initialHari = "";
          if (fetchedOutlets.isNotEmpty) {
            initialOutlet = fetchedOutlets[0];
            initialId = initialOutlet["id_outlet"]?.toString() ?? "";
            initialRegion = initialOutlet["region"] ?? "";
            initialBranch = initialOutlet["branch"] ?? "";
            initialCluster = initialOutlet["cluster"] ?? initialOutlet["area"] ?? "";
            initialHari = initialOutlet["hari"] ?? "";
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
          String errorMessage = data is Map && data.containsKey("message") ? data["message"] : "Gagal mengambil data outlet: Format data tidak sesuai.";
          if (mounted) _showStyledSnackBar(errorMessage, isError: true);
        }
      } else {
        if (mounted) _showStyledSnackBar("Gagal mengambil data outlet (Error Server: ${response.statusCode})", isError: true);
      }
    } catch (e) {
      if (mounted) _showStyledSnackBar("Terjadi kesalahan jaringan saat mengambil outlet: $e", isError: true);
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
      if (mounted) _showStyledSnackBar("Gagal mengambil gambar: $e", isError: true);
    }
  }

  Future<void> _submitForm({bool confirmDuplicate = false}) async {
    FocusScope.of(context).unfocus();
    final ThemeData theme = Theme.of(context);

    if (!_formKey.currentState!.validate()) {
      _showStyledSnackBar("Harap periksa kembali data yang belum terisi atau tidak valid", isError: true);
      return;
    }
    if (_selectedOutlet == null) {
      _showStyledSnackBar("Outlet belum terpilih atau data outlet gagal dimuat", isError: true);
      return;
    }
    if (_selectedBrandinganOption == null) {
      _showStyledSnackBar("Silakan pilih jenis survei", isError: true);
      return;
    }
    if (_namaController.text.trim().isEmpty) {
        _showStyledSnackBar("Nama Surveyor tidak boleh kosong.", isError: true);
        return;
    }

    bool isBrandingValid = true;
    List<Map<String, dynamic>> finalHargaData = [];

    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        isBrandingValid = false;
        _showStyledSnackBar("Untuk Survei Branding, kedua gambar wajib diunggah.", isError: true);
        return;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      bool allHargaValid = true;
      for (int i = 0; i < _operatorSurveyGroups.length; i++) {
        var group = _operatorSurveyGroups[i];
        if (group["paket"] == null || (group["paket"] as String).isEmpty) {
          _showStyledSnackBar("Jenis paket untuk operator ${group["operator"]} belum dipilih.", isError: true);
          return;
        }
        List entries = group["entries"];
        for (int j = 0; j < entries.length; j++) {
          var entry = entries[j];
          HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
          if (controllers == null || controllers.namaPaketController.text.trim().isEmpty || controllers.hargaController.text.trim().isEmpty || controllers.jumlahController.text.trim().isEmpty) {
            allHargaValid = false;
            break;
          }
          entry["nama_paket"] = controllers.namaPaketController.text.trim();
          entry["harga"] = controllers.hargaController.text.trim().replaceAll(".", ""); // Remove dots for submission
          entry["jumlah"] = controllers.jumlahController.text.trim();
        }
        if (!allHargaValid) {
          _showStyledSnackBar("Data harga untuk operator ${group["operator"]} belum lengkap.", isError: true);
          return;
        }
        finalHargaData.add({
          "operator": group["operator"],
          "paket": group["paket"],
          "entries": entries,
        });
      }
      if (finalHargaData.isEmpty && _operatorSurveyGroups.isNotEmpty) {
         _showStyledSnackBar("Tidak ada data harga yang diisi.", isError: true);
         return;
      }
    }

    if (!isBrandingValid) return;

    if (mounted) setState(() => _isSubmitting = true);

    var request = http.MultipartRequest("POST", Uri.parse(_submitApiUrl));
    request.fields.addAll({
      "user_id": widget.userId.toString(),
      "username": _namaController.text.trim(), // Use surveyor name from input
      "id_outlet": _selectedOutlet!["id_outlet"].toString(),
      "nama_outlet": _selectedOutlet!["nama_outlet"].toString(),
      "tanggal_survei": _tokoController.text,
      "keterangan_kunjungan": _keteranganController.text,
      "jenis_survei": _selectedBrandinganOption!,
      "data_harga": _selectedBrandinganOption == "Survei harga" ? json.encode(finalHargaData) : "[]",
      "confirm_duplicate": confirmDuplicate.toString(),
    });

    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase != null) {
        request.files.add(await http.MultipartFile.fromPath("branding_etalase", _brandingImageEtalase!.path));
      }
      if (_brandingImageTampakDepan != null) {
        request.files.add(await http.MultipartFile.fromPath("branding_tampak_depan", _brandingImageTampakDepan!.path));
      }
    }

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data["success"] == true) {
        _showSuccessDialog(data["message"] ?? "Data survei berhasil dikirim!");
        _resetForm();
      } else if (response.statusCode == 409 && data["success"] == false && data["type"] == "DUPLICATE_ENTRY") {
        _showDuplicateConfirmationDialog(data["message"] ?? "Data survei untuk outlet ini pada tanggal yang sama sudah ada.");
      } else {
        _showErrorDialog(data["message"] ?? "Gagal mengirim data survei.");
      }
    } catch (e) {
      if (mounted) _showErrorDialog("Terjadi kesalahan: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Kesalahan", style: Theme.of(context).dialogTheme.titleTextStyle),
        content: Text(message, style: Theme.of(context).dialogTheme.contentTextStyle),
        actions: <Widget>[
          TextButton(
            child: Text("OK", style: Theme.of(context).textButtonTheme.style?.textStyle?.resolve({})),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Sukses", style: Theme.of(context).dialogTheme.titleTextStyle),
        content: Text(message, style: Theme.of(context).dialogTheme.contentTextStyle),
        actions: <Widget>[
          TextButton(
            child: Text("OK", style: Theme.of(context).textButtonTheme.style?.textStyle?.resolve({})),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showDuplicateConfirmationDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Konfirmasi Duplikasi", style: Theme.of(context).dialogTheme.titleTextStyle),
        content: Text("$message Apakah Anda yakin ingin tetap mengirimkan data ini?", style: Theme.of(context).dialogTheme.contentTextStyle),
        actions: <Widget>[
          TextButton(
            child: Text("Batal", style: Theme.of(context).textButtonTheme.style?.textStyle?.resolve({})),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text("Kirim Tetap", style: Theme.of(context).textButtonTheme.style?.textStyle?.resolve({})?.copyWith(color: AppSemanticColors.danger(context))),
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitForm(confirmDuplicate: true);
            },
          ),
        ],
      ),
    );
  }

  // Restoring original _buildTextFieldWithController styling for rumah_page.dart
  Widget _buildTextFieldWithController(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    String? prefixText,
    bool isSurveyorName = false, // Parameter specific to rumah_page
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType ?? TextInputType.text,
        inputFormatters: inputFormatters,
        style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
          prefixText: prefixText,
          filled: true,
          fillColor: readOnly
              ? colorScheme.onSurface.withOpacity(0.05)
              : (isSurveyorName 
                  ? colorScheme.surfaceVariant.withOpacity(0.3) // Original logic for surveyor name
                  : colorScheme.surfaceVariant.withOpacity(0.3)), // Default for other editable fields
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Original padding
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildImagePickerButton(String title, File? imageFile, VoidCallback onPressed) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
          ),
          child: imageFile != null
              ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.file(imageFile, fit: BoxFit.cover))
              : Center(child: Icon(Icons.image_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.7))),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(imageFile == null ? "Ambil Gambar" : "Ganti Gambar"),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
          ),
        ),
      ],
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
                  setState(() { _operatorSurveyGroups[groupIndex]["paket"] = newValue; });
                },
                validator: (value) => value == null ? "Jenis paket harus dipilih" : null,
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (group["entries"] as List).length,
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
                  style: TextButton.styleFrom(foregroundColor: colorScheme.primary)
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // MODIFIED: _buildHargaEntryCard to use vertical layout for rumah_page.dart
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
        title: Text("Form Survei Rumah", style: TextStyle(color: colorScheme.onPrimary)), // Title changed for RumahPage
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Informasi Outlet & Surveyor", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _isLoadingOutlets
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownSearch<Map<String, dynamic>>(
                              items: _outlets,
                              selectedItem: _selectedOutlet,
                              itemAsString: (Map<String, dynamic>? u) => u?["nama_outlet"]?.toString() ?? "",
                              onChanged: (Map<String, dynamic>? data) {
                                setState(() {
                                  _selectedOutlet = data;
                                  if (data != null) {
                                    _idOutletController.text = data["id_outlet"]?.toString() ?? "";
                                    _regionController.text = data["region"] ?? "";
                                    _branchController.text = data["branch"] ?? "";
                                    _clusterController.text = data["cluster"] ?? data["area"] ?? "";
                                    _hariController.text = data["hari"] ?? "";
                                  } else {
                                    _idOutletController.clear();
                                    _regionController.clear();
                                    _branchController.clear();
                                    _clusterController.clear();
                                    _hariController.clear();
                                  }
                                });
                              },
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    labelText: "Cari Outlet", 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                    filled: true,
                                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  ),
                                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                                ),
                                menuProps: MenuProps(backgroundColor: theme.cardTheme.color ?? colorScheme.surface),
                                itemBuilder: (context, item, isSelected) {
                                  return ListTile(
                                    title: Text(item["nama_outlet"]?.toString() ?? "", style: textTheme.bodyLarge?.copyWith(color: isSelected ? colorScheme.primary : colorScheme.onSurface)),
                                    subtitle: Text(item["id_outlet"]?.toString() ?? "", style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                  );
                                },
                              ),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: "Pilih Outlet", 
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                  filled: true,
                                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                ),
                                baseStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                              ),
                              validator: (value) => value == null ? "Outlet harus dipilih" : null,
                            ),
                      _buildTextFieldWithController(_idOutletController, "ID Outlet", readOnly: true),
                      _buildTextFieldWithController(_regionController, "Region", readOnly: true),
                      _buildTextFieldWithController(_branchController, "Branch", readOnly: true),
                      _buildTextFieldWithController(_clusterController, "Cluster/Area", readOnly: true),
                      _buildTextFieldWithController(_hariController, "Hari Kunjungan", readOnly: true),
                      // Surveyor name is editable in RumahPage
                      _buildTextFieldWithController(_namaController, "Nama Surveyor", isSurveyorName: true, validator: (value) => value == null || value.trim().isEmpty ? "Nama Surveyor tidak boleh kosong" : null),
                      _buildTextFieldWithController(_tokoController, "Tanggal Survei", readOnly: true, onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(_tokoController.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                           builder: (context, child) {
                             return Theme(
                                data: theme.copyWith(
                                  colorScheme: theme.colorScheme.copyWith(
                                    primary: colorScheme.primary,
                                    onPrimary: colorScheme.onPrimary,
                                    surface: colorScheme.surface,
                                    onSurface: colorScheme.onSurface,
                                  ),
                                  dialogBackgroundColor: theme.dialogTheme.backgroundColor ?? colorScheme.surface,
                                ),
                                child: child!,
                              );
                          }
                        );
                        if (pickedDate != null) {
                          _tokoController.text = DateFormat("yyyy-MM-dd").format(pickedDate);
                        }
                      }),
                      _buildTextFieldWithController(_keteranganController, "Keterangan Kunjungan", keyboardType: TextInputType.multiline, validator: (value) => value == null || value.isEmpty ? "Keterangan tidak boleh kosong" : null),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text("Jenis Survei", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Pilih Jenis Survei", 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true,
                      fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    ),
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                    value: _selectedBrandinganOption,
                    items: _brandinganOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedBrandinganOption = newValue;
                        if (newValue == "Survei harga") {
                          _initializeFixedSurveyHarga();
                        } else {
                          _operatorSurveyGroups.clear();
                          _hargaEntryControllersMap.clear();
                          _totalHargaEntriesCount = 0;
                        }
                      });
                    },
                    validator: (value) => value == null ? "Jenis survei harus dipilih" : null,
                  ),
                ),
              ),
              if (_selectedBrandinganOption == "Survei branding") ...[
                const SizedBox(height: 24),
                Text("Upload Gambar Branding", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildImagePickerButton("Foto Etalase Branding", _brandingImageEtalase, () => _pickImage(ImageSource.camera, (file) => setState(() => _brandingImageEtalase = file))),
                        const SizedBox(height: 16),
                        _buildImagePickerButton("Foto Tampak Depan Toko", _brandingImageTampakDepan, () => _pickImage(ImageSource.camera, (file) => setState(() => _brandingImageTampakDepan = file))),
                      ],
                    ),
                  ),
                ),
              ],
              if (_selectedBrandinganOption == "Survei harga") ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Detail Survei Harga", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
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
                icon: _isSubmitting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary)) : const Icon(Icons.send),
                label: Text(_isSubmitting ? "Mengirim..." : "Kirim Survei"),
                onPressed: _isSubmitting ? null : _submitForm,
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

