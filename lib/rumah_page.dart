// RumahPage.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
// Import path package for file extension if needed for more robust filename generation (optional)
// import 'package:path/path.dart' as p;

class RumahPage extends StatefulWidget {
  final String username;
  final int userId;
  const RumahPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  State<RumahPage> createState() => _RumahPageState();
}

// --- Helper Class for Controller per Entri Harga ---
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

  // --- API Endpoint ---
  final String _submitApiUrl = "https://tunnel.jato.my.id/test%20api/submit_survey.php";
  final String _outletApiUrl = "https://tunnel.jato.my.id/test%20api/getAreas.php";

  // Controller untuk field yang auto-fill dari Outlet
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController(); // Hari Kunjungan

  // Controller lain
  final TextEditingController _namaController = TextEditingController(); // Untuk Nama Surveyor INPUT
  final TextEditingController _tokoController = TextEditingController(); // TANGGAL
  final TextEditingController _keteranganController = TextEditingController(); // Keterangan Kunjungan

  // Data Outlet & Loading State
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoadingOutlets = false;
  bool _isSubmitting = false;

  // Opsi Jenis Survei
  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  // Data Survei Branding
  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // --- Data Survei Harga (Struktur DIMODIFIKASI) ---
  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"];

  // State untuk Limit Survei Harga
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 15;

  // Opsi Dropdown Survei Harga
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];

  @override
  void initState() {
    super.initState();
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // _namaController TIDAK diisi otomatis di sini
    _fetchOutlets();
  }

  @override
  void dispose() {
    _regionController.dispose();
    _branchController.dispose();
    _clusterController.dispose();
    _namaController.dispose(); // Dispose namaController
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

  // --- Fungsi Reset Form ---
  void _resetForm() {
      _formKey.currentState?.reset();
      setState(() {
          // _namaController.clear(); // Bersihkan nama surveyor input
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
               // Fields sudah terisi
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


  // --- Fungsi untuk inisialisasi atau reset survei harga ---
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
         _operatorSurveyGroups.add({ "operator": operatorName, "paket": null, "entries": [{"nama_paket": "", "harga": "", "jumlah": ""}], "isHidden": false });
         _hargaEntryControllersMap[i] = { 0: HargaEntryControllers() };
         _totalHargaEntriesCount++;
       }
     });
  }

  // --- Fungsi untuk menambah data (entri) dalam satu grup ---
  void _addHargaEntry(int groupIndex) {
     if (_totalHargaEntriesCount >= _maxHargaEntries) {
       ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Batas maksimal $_maxHargaEntries data paket tercapai')), );
       return;
     }
    setState(() {
      if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""});
      if (_hargaEntryControllersMap[groupIndex] == null) { _hargaEntryControllersMap[groupIndex] = {}; }
       _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();
       _totalHargaEntriesCount++;
    });
  }

  // --- Fungsi untuk menghapus data (entri) dalam satu grup ---
  void _removeHargaEntry(int groupIndex, int entryIndex) {
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length || _hargaEntryControllersMap[groupIndex] == null || entryIndex < 0) return;
    setState(() {
       List entries = _operatorSurveyGroups[groupIndex]["entries"];
       if (entries.length > 1) {
         if(entryIndex < entries.length){
             _hargaEntryControllersMap[groupIndex]?[entryIndex]?.dispose();
             _hargaEntryControllersMap[groupIndex]?.remove(entryIndex);
             entries.removeAt(entryIndex);
            Map<int, HargaEntryControllers> updatedControllers = {};
            int currentNewIndex = 0;
            var sortedKeys = _hargaEntryControllersMap[groupIndex]?.keys.toList()?..sort();
            sortedKeys?.forEach((oldIndex) { if (_hargaEntryControllersMap[groupIndex]![oldIndex] != null) { updatedControllers[currentNewIndex] = _hargaEntryControllersMap[groupIndex]![oldIndex]!; currentNewIndex++; } });
            _hargaEntryControllersMap[groupIndex] = updatedControllers;
             _totalHargaEntriesCount--;
         }
       } else { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Minimal harus ada satu data paket per operator')), ); }
    });
  }

  // --- Fungsi untuk toggle hide/show grup ---
  void _toggleGroupVisibility(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
    setState(() { _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"]; });
  }

  // --- Fungsi untuk mengambil data outlet dari API ---
  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoadingOutlets = true;
       _outlets = []; _selectedOutlet = null;
       _idOutletController.clear(); _regionController.clear(); _branchController.clear(); _clusterController.clear(); _hariController.clear();
    });
    try {
      var url = Uri.parse('$_outletApiUrl?user_id=${widget.userId}');
      var response = await http.get(url).timeout(const Duration(seconds: 20));
      print("Outlet API Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['success'] == true && data['outlets'] is List) {
          final List<Map<String, dynamic>> fetchedOutlets = List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
          print("Outlets dimuat: ${fetchedOutlets.length}");

          Map<String, dynamic>? initialOutlet;
          String initialId = ''; String initialRegion = ''; String initialBranch = ''; String initialCluster = ''; String initialHari = '';

          if (fetchedOutlets.isNotEmpty) {
            initialOutlet = fetchedOutlets[0];
            initialId = initialOutlet['id_outlet']?.toString() ?? ''; initialRegion = initialOutlet['region'] ?? ''; initialBranch = initialOutlet['branch'] ?? ''; initialCluster = initialOutlet['cluster'] ?? initialOutlet['area'] ?? ''; initialHari = initialOutlet['hari'] ?? '';
            print("Outlet pertama dipilih: ${initialOutlet['nama_outlet']}");
          } else { print("Tidak ada data outlet ditemukan."); }

          if(mounted) {
            setState(() {
              _outlets = fetchedOutlets; _selectedOutlet = initialOutlet;
              _idOutletController.text = initialId; _regionController.text = initialRegion; _branchController.text = initialBranch; _clusterController.text = initialCluster; _hariController.text = initialHari;
            });
          }
        } else {
          print("Gagal mengambil data outlet: ${data['message'] ?? 'Format data tidak sesuai'}");
           if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(data['message'] ?? 'Gagal mengambil data outlet: Format tidak sesuai')), ); }
        }
      } else {
        print("Gagal mengambil data outlet: Server error ${response.statusCode}");
         if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Gagal mengambil data outlet (Error: ${response.statusCode})')), ); }
      }
    } catch (e, stacktrace) {
       print("Error fetching outlets: $e\n$stacktrace");
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Terjadi kesalahan jaringan: $e')), ); }
    } finally {
       if (mounted) { setState(() { _isLoadingOutlets = false; }); }
    }
  }


  // --- Fungsi untuk mengambil gambar ---
  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
      final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        if (mounted) { setState(() { onImagePicked(File(pickedFile.path)); }); }
      }
    } catch (e) {
      print("Error picking image: $e");
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Gagal mengambil gambar: $e')), ); }
    }
  }

  // --- DIMODIFIKASI: Fungsi untuk validasi dan submit form ke API ---
  Future<void> _submitForm({bool confirmDuplicate = false}) async {
    FocusScope.of(context).unfocus();

    // 1. Validasi Form Lokal
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Harap periksa kembali data yang belum terisi atau tidak valid')), );
      return;
    }
     if (_selectedOutlet == null) {
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Outlet belum terpilih atau data outlet gagal dimuat')), );
       return;
     }
    if (_selectedBrandinganOption == null) {
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Silakan pilih jenis survei')), );
      return;
    }

    // 2. Persiapan Data
    bool isBrandingValid = true;
    List<Map<String, dynamic>> finalHargaData = [];

    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Silakan ambil kedua gambar branding')), );
        isBrandingValid = false;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      for (int i = 0; i < _operatorSurveyGroups.length; i++) {
        var group = _operatorSurveyGroups[i]; String operatorName = group["operator"]; String? paketType = group["paket"];
        if (paketType != null && paketType.isNotEmpty) {
          List<Map<String, String>> currentEntriesData = []; List groupEntries = group["entries"];
          for (int j = 0; j < groupEntries.length; j++) {
            HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
            String namaPaket = controllers?.namaPaketController.text.trim() ?? ""; String hargaInput = controllers?.hargaController.text.trim() ?? ""; String jumlahInput = controllers?.jumlahController.text.trim() ?? ""; String hargaNumerikBersih = hargaInput.replaceAll('.', '');
            currentEntriesData.add({ "nama_paket": namaPaket, "harga": hargaNumerikBersih, "jumlah": jumlahInput });
          }
          finalHargaData.add({ "operator": operatorName, "paket": paketType, "entries": currentEntriesData });
          print("Menambahkan data untuk operator (RumahPage): $operatorName");
        } else { print("Melewati operator (RumahPage): $operatorName karena paket tidak dipilih."); }
      }
    }

    // 3. Final Check
    if (!isBrandingValid) { return; }

    // 4. Set Loading State
    setState(() { _isSubmitting = true; });

    // 5. Prepare Data for API
    var request = http.MultipartRequest('POST', Uri.parse(_submitApiUrl));
    request.fields['user_id'] = widget.userId.toString();
    request.fields['username'] = widget.username;
    request.fields['nama_surveyor'] = _namaController.text.trim(); // Nama surveyor dari INPUT field
    request.fields['outlet_id'] = _idOutletController.text;
    request.fields['outlet_nama'] = _selectedOutlet?['nama_outlet'] ?? 'N/A';
    request.fields['region'] = _regionController.text;
    request.fields['branch'] = _branchController.text;
    request.fields['cluster'] = _clusterController.text;
    request.fields['hari'] = _hariController.text;
    request.fields['tanggal_survei'] = _tokoController.text;
    request.fields['jenis_survei'] = _selectedBrandinganOption!;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();
    if (confirmDuplicate) {
      request.fields['confirm_duplicate'] = 'true';
       print("Mengirim dengan confirm_duplicate=true (RumahPage)");
    }

    try {
        if (_selectedBrandinganOption == "Survei branding") {
          if (_brandingImageEtalase != null) { request.files.add(await http.MultipartFile.fromPath( 'foto_etalase', _brandingImageEtalase!.path )); }
          if (_brandingImageTampakDepan != null) { request.files.add(await http.MultipartFile.fromPath( 'foto_depan', _brandingImageTampakDepan!.path )); }
        } else if (_selectedBrandinganOption == "Survei harga") {
          request.fields['data_harga'] = jsonEncode(finalHargaData);
        }
    } catch (e) {
        print("Error mempersiapkan data request (file/json): $e");
        if (mounted) { setState(() { _isSubmitting = false; }); _showErrorDialog('Error Mempersiapkan Data', 'Gagal memproses data survei sebelum mengirim: $e'); }
        return;
    }

    // 6. Send Request and Handle Response
    try {
      print("--- Mengirim Data ke API (RumahPage) ---");
      print("URL: $_submitApiUrl");
      print("Fields: ${request.fields}");
       if (_selectedBrandinganOption == "Survei branding") { print("Files: foto_etalase=${_brandingImageEtalase?.path}, foto_depan=${_brandingImageTampakDepan?.path}"); }
       else { print("JSON Data Harga yang Dikirim: ${request.fields['data_harga']}"); }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

      print("API Response Status: ${response.statusCode}");
      print("API Response Body: ${response.body}");

      if (mounted) {
         setState(() { _isSubmitting = false; });

        if (response.statusCode == 200) {
          try {
              var responseData = jsonDecode(response.body);

              if (responseData is Map && responseData.containsKey('status') && responseData['status'] == 'duplicate_found') {
                  _showDuplicateConfirmationDialog(responseData['message'] ?? 'Data duplikat ditemukan. Yakin ingin melanjutkan?');
              }
              else if (responseData is Map && responseData.containsKey('success') && responseData['success'] == true) {
                _showSuccessDialog(responseData['message'] ?? 'Data survei berhasil dikirim.');
                _resetForm();
              } else {
                String errorMessage = responseData is Map && responseData.containsKey('message') ? responseData['message'] : 'Terjadi kesalahan yang tidak diketahui dari server.';
                _showErrorDialog('Gagal Mengirim Data', errorMessage);
              }
          } catch (e) {
              print("Error decoding JSON response: $e");
              _showErrorDialog('Gagal Memproses Respon', 'Respon dari server tidak valid.');
          }
        } else {
           _showErrorDialog('Error Server', 'Gagal terhubung ke server (Kode: ${response.statusCode}).\n${response.reasonPhrase ?? ''}');
        }
      }

    } catch (e, stacktrace) {
      print("Error submitting form: $e\n$stacktrace");
      if (mounted) {
         setState(() { _isSubmitting = false; });
         _showErrorDialog('Error Jaringan', 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.\nError: $e');
      }
    }
  }

  // --- Fungsi helper untuk menampilkan dialog error ---
  void _showErrorDialog(String title, String message) {
     if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 10), Text(title)]),
          content: SingleChildScrollView(child: Text(message)),
          actions: [ TextButton( onPressed: () => Navigator.pop(context), child: const Text('OK'), ), ],
        ),
      );
  }

   // --- Fungsi helper untuk menampilkan dialog sukses ---
  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Berhasil')]),
        content: Text(message),
        actions: [ TextButton( onPressed: () => Navigator.pop(context), child: const Text('OK'), ), ],
      ),
    );
  }

  // --- Fungsi helper untuk menampilkan dialog konfirmasi duplikat ---
  void _showDuplicateConfirmationDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text('Konfirmasi')]),
        content: Text(message),
        actions: [
          TextButton( onPressed: () { Navigator.pop(context); }, child: const Text('Batal'), style: TextButton.styleFrom(foregroundColor: Colors.grey), ),
          TextButton( onPressed: () { Navigator.pop(context); _submitForm(confirmDuplicate: true); }, child: const Text('Lanjutkan'), style: TextButton.styleFrom(foregroundColor: Colors.redAccent), ),
        ],
      ),
    );
  }


  // --- Widget builder untuk TextField standar ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false, // Tetap ada parameter readOnly
    int maxLines = 1,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
      // 'readOnly' sekarang dikontrol dari pemanggilan widget, bukan di sini
      return TextFormField(
      controller: controller,
      readOnly: readOnly, // Gunakan nilai readOnly yang diteruskan
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        hintText: hint,
        filled: readOnly, // 'filled' bergantung pada 'readOnly'
        fillColor: readOnly ? Colors.grey[200] : null, // Warna fill juga
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
       style: TextStyle(color: readOnly ? Colors.grey[700] : null),
       enableInteractiveSelection: !readOnly,
       focusNode: readOnly ? FocusNode(canRequestFocus: false) : null,
    );
  }

  // --- Widget builder untuk Image Picker ---
  Widget _buildImagePicker({
    required String label, File? image, required VoidCallback onPick, required VoidCallback onRetake, bool disabled = false,
  }) {
      return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), Container( height: 150, width: double.infinity, decoration: BoxDecoration( border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12), color: disabled ? Colors.grey[300] : Colors.grey[100], ),
          child: image != null ? Stack( alignment: Alignment.center, fit: StackFit.expand, children: [ ClipRRect( borderRadius: BorderRadius.circular(11.0), child: Image.file(image, fit: BoxFit.cover) ), Positioned( top: 4, right: 4, child: Container( decoration: BoxDecoration( color: Colors.black.withOpacity(0.5), shape: BoxShape.circle, ), child: IconButton( icon: const Icon(Icons.refresh, color: Colors.white, size: 20), tooltip: "Ambil Ulang Foto", onPressed: disabled ? null : onRetake, padding: EdgeInsets.zero, constraints: const BoxConstraints(), ), ), ), ], )
              : Center( child: IconButton( icon: Icon(Icons.camera_alt, size: 40, color: disabled ? Colors.grey[500] : Colors.grey[600]), tooltip: "Ambil Foto", onPressed: disabled ? null : onPick, ), ), ), ], );
  }

  @override
  Widget build(BuildContext context) {
    bool canAddMoreHarga = _totalHargaEntriesCount < _maxHargaEntries;
    // Tentukan apakah Superuser (HANYA untuk UI, logika validasi tetap)
    // bool isSuperUser = widget.userId == 785; // Tidak perlu lagi di sini

    return Scaffold(
      appBar: AppBar( title: const Text('Form Survei '), centerTitle: true, backgroundColor: Colors.redAccent, ),
      body: Container(
        decoration: const BoxDecoration( gradient: LinearGradient( colors: [Color(0xFFFFB6B6), Color(0xFFFF8E8E)], begin: Alignment.topCenter, end: Alignment.bottomCenter, ), ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    // --- Main Form Content ---
                    _isLoadingOutlets && _outlets.isEmpty
                        ? const Center( child: Column( mainAxisSize: MainAxisSize.min, children: [ CircularProgressIndicator(), SizedBox(height: 15), Text("Memuat data outlet...") ], ) )
                        : Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- PERBAIKAN FIELD NAMA SURVEYOR ---
                                _buildTextField(
                                  controller: _namaController,
                                  label: 'Nama Surveyor *',
                                  // readOnly: false, // Hapus atau set false secara eksplisit
                                  readOnly: _isSubmitting, // Hanya readOnly saat mengirim
                                  hint: 'Masukkan nama',
                                  validator: (value) {
                                    // Validasi tetap diperlukan (PHP juga akan validasi)
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nama Surveyor wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // --- Fields Read Only: Region, Branch, Cluster ---
                                _buildTextField( controller: _regionController, label: 'Region', readOnly: true, ), const SizedBox(height: 16),
                                _buildTextField( controller: _branchController, label: 'Branch', readOnly: true, ), const SizedBox(height: 16),
                                _buildTextField( controller: _clusterController, label: 'Cluster', readOnly: true, ), const SizedBox(height: 16),
                                _buildTextField(controller: _hariController, label: 'Hari Kunjungan (Outlet)', readOnly: true, ), const SizedBox(height: 16),

                                // --- Dropdown Outlet ---
                                DropdownSearch<Map<String, dynamic>>(
                                  popupProps: PopupProps.menu( showSearchBox: true, searchFieldProps: const TextFieldProps( decoration: InputDecoration( hintText: "Cari nama outlet...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder() ) ), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4), emptyBuilder: (context, searchEntry) => const Center(child: Text("Outlet tidak ditemukan")), errorBuilder: (context, searchEntry, exception) => const Center(child: Text("Gagal memuat outlet")), loadingBuilder: (context, searchEntry) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), menuProps: const MenuProps(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))), ),
                                  items: _outlets, itemAsString: (outlet) => outlet['nama_outlet'] ?? 'Tanpa Nama', selectedItem: _selectedOutlet,
                                  dropdownDecoratorProps: DropDownDecoratorProps( dropdownSearchDecoration: InputDecoration( labelText: "Pilih Outlet *", hintText: _outlets.isEmpty && !_isLoadingOutlets ? "Tidak ada data outlet" : "Pilih outlet lainnya...", border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), ), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ), ),
                                  onChanged: (value) { setState(() { _selectedOutlet = value; if (value != null) { _idOutletController.text = value['id_outlet']?.toString() ?? ''; _regionController.text = value['region'] ?? ''; _branchController.text = value['branch'] ?? ''; _clusterController.text = value['cluster'] ?? value['area'] ?? ''; _hariController.text = value['hari'] ?? ''; } else { _idOutletController.clear(); _regionController.clear(); _branchController.clear(); _clusterController.clear(); _hariController.clear(); } }); },
                                  validator: (value) { if (value == null) { return 'Silakan pilih outlet'; } return null; },
                                  enabled: !_isLoadingOutlets && _outlets.isNotEmpty && !_isSubmitting,
                                ), const SizedBox(height: 16),

                                // --- Fields Read Only: ID Outlet, Tanggal ---
                                _buildTextField( controller: _idOutletController, label: 'ID Outlet', readOnly: true, ), const SizedBox(height: 16),
                                _buildTextField( controller: _tokoController, label: 'Tanggal Survei', readOnly: true, ), const SizedBox(height: 16),

                                // --- Dropdown Jenis Survei ---
                                DropdownButtonFormField<String>(
                                  isExpanded: true, value: _selectedBrandinganOption, hint: const Text("Pilih Jenis Survei"),
                                  decoration: InputDecoration( labelText: 'Jenis Survei *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ),
                                  items: _brandinganOptions.map((option) { return DropdownMenuItem<String>(value: option, child: Text(option)); }).toList(),
                                  onChanged: _isSubmitting ? null : (value) { setState(() { _selectedBrandinganOption = value; _brandingImageEtalase = null; _brandingImageTampakDepan = null; if (value == "Survei harga") { _initializeFixedSurveyHarga(); } else { _operatorSurveyGroups.clear(); _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose())); _hargaEntryControllersMap.clear(); _totalHargaEntriesCount = 0; } }); },
                                  validator: (value) { if (value == null || value.isEmpty) return 'Silakan pilih jenis survei'; return null; },
                                ), const SizedBox(height: 16),

                                // --- Konten Dinamis ---
                                // === SURVEI BRANDING ===
                                if (_selectedBrandinganOption == "Survei branding") ...[
                                  _buildImagePicker( label: "Foto Etalase *", image: _brandingImageEtalase, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), ), const SizedBox(height: 16),
                                  _buildImagePicker( label: "Foto Tampak Depan *", image: _brandingImageTampakDepan, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), ), const SizedBox(height: 16),
                                ],

                                // === SURVEI HARGA ===
                                if (_selectedBrandinganOption == "Survei harga") ...[
                                  AbsorbPointer( absorbing: _isSubmitting, child: ListView.builder( shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _operatorSurveyGroups.length,
                                      itemBuilder: (context, groupIndex) { final group = _operatorSurveyGroups[groupIndex]; bool isHidden = group["isHidden"]; List entries = group["entries"]; String operatorName = group["operator"];
                                        return Card( margin: const EdgeInsets.symmetric(vertical: 8.0), elevation: 2, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300) ), child: Padding( padding: const EdgeInsets.all(12.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( children: [ Expanded( child: Text( operatorName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), ), ), TextButton.icon( icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), label: Text(isHidden ? 'Tampilkan' : 'Sembunyikan', style: const TextStyle(fontSize: 12)), onPressed: _isSubmitting ? null : () => _toggleGroupVisibility(groupIndex), style: TextButton.styleFrom( foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap, minimumSize: const Size(0, 30) ), ), ], ),
                                                if (!isHidden) ...[ const Divider(thickness: 1, height: 20), DropdownButtonFormField<String>( validator: null, isExpanded: true, value: group["paket"], hint: const Text("Pilih Paket"), decoration: InputDecoration( labelText: 'Paket', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ), items: _paketOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(), onChanged: _isSubmitting ? null : (value) { setState(() { _operatorSurveyGroups[groupIndex]["paket"] = value; }); }, ), const SizedBox(height: 20),
                                                  ListView.builder( shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: entries.length, itemBuilder: (context, entryIndex) { if (_hargaEntryControllersMap[groupIndex] == null) { _hargaEntryControllersMap[groupIndex] = {}; } if (_hargaEntryControllersMap[groupIndex]![entryIndex] == null) { _hargaEntryControllersMap[groupIndex]![entryIndex] = HargaEntryControllers(); } HargaEntryControllers controllers = _hargaEntryControllersMap[groupIndex]![entryIndex]!; return Container( padding: const EdgeInsets.all(10).copyWith(bottom: 0), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration( color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200) ), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("   Data Paket Ke-${entryIndex + 1}", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])), const SizedBox(height: 8),
                                                            _buildTextField( controller: controllers.namaPaketController, label: 'Nama Paket *', hint: 'Contoh: Xtra Combo Lite L 3.5GB', readOnly: _isSubmitting, validator: (value) { if (group["paket"] != null && group["paket"].isNotEmpty) { if (value == null || value.trim().isEmpty) { return 'Masukkan nama paket'; } } return null; } ), const SizedBox(height: 16),
                                                            _buildTextField( controller: controllers.hargaController, label: 'Harga Satuan *', prefixText: 'Rp ', hint: 'Contoh: 10000 atau 10.000', readOnly: _isSubmitting, keyboardType: const TextInputType.numberWithOptions(decimal: false), inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')) ], validator: (value) { if (group["paket"] != null && group["paket"].isNotEmpty) { if (value == null || value.trim().isEmpty) return 'Masukkan harga'; final numericString = value.replaceAll('.', ''); if (numericString.isEmpty || double.tryParse(numericString) == null) return 'Format angka tidak valid'; if (double.parse(numericString) <= 0) return 'Harga harus > 0'; } return null; } ), const SizedBox(height: 16),
                                                            _buildTextField( controller: controllers.jumlahController, label: 'Jumlah *', hint: 'Jumlah barang/stok', readOnly: _isSubmitting, keyboardType: TextInputType.number, inputFormatters: [ FilteringTextInputFormatter.digitsOnly ], validator: (value) { if (group["paket"] != null && group["paket"].isNotEmpty) { if (value == null || value.trim().isEmpty) return 'Masukkan jumlah'; final int? jumlah = int.tryParse(value); if (jumlah == null) return 'Jumlah harus angka'; if (jumlah <= 0) return 'Jumlah harus > 0'; } return null; } ), const SizedBox(height: 0),
                                                            Align( alignment: Alignment.centerRight, child: (entries.length > 1) ? TextButton.icon( icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600), label: Text("Hapus", style: TextStyle(color: Colors.red.shade600, fontSize: 12)), onPressed: _isSubmitting ? null : () => _removeHargaEntry(groupIndex, entryIndex), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5), minimumSize: const Size(0, 25)), ) : const SizedBox(height: 25), ), ], ), ); }, ),
                                                  Align( alignment: Alignment.centerRight, child: TextButton.icon( icon: const Icon(Icons.add_circle_outline, size: 20), label: const Text("Tambah Data Paket"), onPressed: _isSubmitting || !canAddMoreHarga ? null : () => _addHargaEntry(groupIndex), style: TextButton.styleFrom( foregroundColor: _isSubmitting || !canAddMoreHarga ? Colors.grey : Theme.of(context).primaryColor, ), ), ), ]
                                                else ...[ Padding( padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), child: Text( "Paket: ${group['paket'] ?? '(Belum dipilih)'}", style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis, ), ), ] ], ), ), ); }, ), ),
                                  const SizedBox(height: 10), if (!canAddMoreHarga) Padding( padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), child: Row( children: [ Icon(Icons.info_outline, color: Colors.orange.shade800, size: 16), const SizedBox(width: 8), Expanded( child: Text( "Batas maksimal $_maxHargaEntries data paket telah tercapai.", style: TextStyle(color: Colors.orange.shade900, fontStyle: FontStyle.italic), ), ), ], ), ),
                                  const SizedBox(height: 16),
                                ], // End Survei Harga Section

                                // --- Keterangan Kunjungan ---
                                _buildTextField( controller: _keteranganController, label: 'Keterangan Kunjungan *', hint: 'Masukkan detail atau catatan penting selama kunjungan...', maxLines: 5, readOnly: _isSubmitting, validator: (value) { if (value == null || value.trim().isEmpty) return 'Keterangan kunjungan wajib diisi'; if (value.trim().length < 10) return 'Keterangan terlalu pendek (min. 10 karakter)'; return null; }, ), const SizedBox(height: 24),

                                // --- Tombol Submit ---
                                SizedBox( width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : () => _submitForm(),
                                    style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.redAccent, disabledBackgroundColor: Colors.grey, ),
                                    child: _isSubmitting ? const SizedBox( height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)) )
                                        : const Text( 'Submit Data Survei', style: TextStyle(fontSize: 18, color: Colors.white), ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    // --- Overlay Loading Indicator ---
                    if (_isSubmitting) Positioned.fill( child: Container( decoration: BoxDecoration( color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(16), ), child: const Center( child: Column( mainAxisSize: MainAxisSize.min, children: [ CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)), SizedBox(height: 15), Text("Mengirim data...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), ], ), ), ), ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} // End of _RumahPageState