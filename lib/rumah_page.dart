// RumahPage.dart (File Path jika relevan)
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

// --- Helper Class for Controller per Entri Harga (DITAMBAH jumlahController) ---
class HargaEntryControllers {
  final TextEditingController namaPaketController; // Sebelumnya keteranganController
  final TextEditingController hargaController;
  final TextEditingController jumlahController; // Controller baru

  HargaEntryControllers()
      : namaPaketController = TextEditingController(),
        hargaController = TextEditingController(),
        jumlahController = TextEditingController(); // Inisialisasi

  void dispose() {
    namaPaketController.dispose();
    hargaController.dispose();
    jumlahController.dispose(); // Dispose controller baru
  }
}


class _RumahPageState extends State<RumahPage> {
  final _formKey = GlobalKey<FormState>();

  // --- API Endpoint ---
  final String _submitApiUrl = "https://tunnel.jato.my.id/test%20api/submit_survey.php"; // Use 192.168.1.27 for Android emulator localhost
  final String _outletApiUrl = "https://tunnel.jato.my.id/test%20api/getAreas.php"; // Tambahkan URL Outlet API

  // Controller untuk field yang auto-fill dari Outlet
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController(); // Hari Kunjungan

  // Controller lain
  final TextEditingController _namaController = TextEditingController(); // Untuk Nama Surveyor
  final TextEditingController _tokoController = TextEditingController(); // TANGGAL
  final TextEditingController _keteranganController = TextEditingController(); // Keterangan Kunjungan

  // Data Outlet & Loading State
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoading = false; // Loading for outlets (Gunakan _isLoadingOutlets jika prefer)
  bool _isSubmitting = false; // Loading for form submission

  // Opsi Jenis Survei
  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  // Data Survei Branding
  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // --- Data Survei Harga (Struktur DIMODIFIKASI) ---
  List<Map<String, dynamic>> _operatorSurveyGroups = []; // Tetap list, tapi isinya akan fix
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  // Definisikan daftar operator tetap (BARU)
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"];

  // State untuk Limit Survei Harga
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 15;

  // Opsi Dropdown Survei Harga
  // final List<String> _operatorOptions = ["XL", "INDOSAT OOREDO", "AXIS", "SMARTFREN" , "3", "TELKOMSEL"]; // Tidak lagi dipakai untuk dropdown
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"];

  @override
  void initState() {
    super.initState();
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Tidak mengisi _namaController di sini, biarkan user input
    _fetchOutlets();
  }

  @override
  void dispose() {
    _regionController.dispose();
    _branchController.dispose();
    _clusterController.dispose();
    _namaController.dispose(); // Pastikan dispose namaController
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

  // --- Fungsi Reset Form (BARU) ---
  void _resetForm() {
      _formKey.currentState?.reset(); // Reset validation state
      setState(() {
          // Clear controllers (nama surveyor juga)
          _namaController.clear(); // Bersihkan nama surveyor
          _keteranganController.clear();

          // Reset selections and dynamic data
          _selectedBrandinganOption = null;
          _brandingImageEtalase = null;
          _brandingImageTampakDepan = null;
          _operatorSurveyGroups.clear();
           _hargaEntryControllersMap.values.forEach((entryMap) {
               entryMap.values.forEach((controllers) => controllers.dispose());
           });
           _hargaEntryControllersMap.clear();
           _totalHargaEntriesCount = 0;

           // Reset outlet selection to the first one if available
          //  _selectedOutlet = _outlets.isNotEmpty ? _outlets[0] : null;
           if (_selectedOutlet != null) {
                _idOutletController.text = _selectedOutlet!['id_outlet']?.toString() ?? '';
                _regionController.text = _selectedOutlet!['region'] ?? '';
                _branchController.text = _selectedOutlet!['branch'] ?? '';
                _clusterController.text = _selectedOutlet!['cluster'] ?? _selectedOutlet!['area'] ?? '';
                _hariController.text = _selectedOutlet!['hari'] ?? '';
           } else {
               // Clear outlet related fields if no outlet selected/available
               _idOutletController.clear();
               _regionController.clear();
               _branchController.clear();
               _clusterController.clear();
               _hariController.clear();
           }
           // Set date again if needed
          _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      });
  }


  // --- Fungsi untuk inisialisasi atau reset survei harga (DIMODIFIKASI menjadi Fixed) ---
  void _initializeFixedSurveyHarga() { // Nama diubah untuk kejelasan
     setState(() {
       // Bersihkan data dan controller sebelumnya
       _operatorSurveyGroups.clear();
       _hargaEntryControllersMap.values.forEach((entryMap) {
        entryMap.values.forEach((controllers) => controllers.dispose());
       });
       _hargaEntryControllersMap.clear();
       _totalHargaEntriesCount = 0;

       // Buat 6 grup operator tetap dari _fixedOperators
       for (int i = 0; i < _fixedOperators.length; i++) {
         String operatorName = _fixedOperators[i];
         _operatorSurveyGroups.add({
           "operator": operatorName, // Langsung isi nama operator
           "paket": null,
           "entries": [{"nama_paket": "", "harga": "", "jumlah": ""}],
           "isHidden": false
         });
         // Inisialisasi controller untuk entri pertama
         _hargaEntryControllersMap[i] = { 0: HargaEntryControllers() };
         _totalHargaEntriesCount++;
       }
     });
  }

   // --- Fungsi untuk menambahkan grup operator baru (TIDAK DIPAKAI LAGI) ---
   /*
   void _addOperatorGroup() {
     // ... logika lama ...
   }
   */

  // --- Fungsi untuk menambah data (entri) dalam satu grup (DITAMBAH 'jumlah') ---
  void _addHargaEntry(int groupIndex) {
     if (_totalHargaEntriesCount >= _maxHargaEntries) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batas maksimal $_maxHargaEntries data paket tercapai')),
       );
       return;
     }

    setState(() {
      // Pastikan grup index valid
      if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;

      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""});

      if (_hargaEntryControllersMap[groupIndex] == null) {
        _hargaEntryControllersMap[groupIndex] = {};
      }
       _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();
       _totalHargaEntriesCount++;
    });
  }

  // --- Fungsi untuk menghapus data (entri) dalam satu grup ---
  void _removeHargaEntry(int groupIndex, int entryIndex) {
     // Pastikan indeks grup dan entri valid
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length ||
        _hargaEntryControllersMap[groupIndex] == null || entryIndex < 0) return;

    setState(() {
       List entries = _operatorSurveyGroups[groupIndex]["entries"];
       if (entries.length > 1) { // Hanya bisa hapus jika > 1
         // Pastikan entryIndex valid
         if(entryIndex < entries.length){
             _hargaEntryControllersMap[groupIndex]?[entryIndex]?.dispose();
             _hargaEntryControllersMap[groupIndex]?.remove(entryIndex);
             entries.removeAt(entryIndex);

            // Re-index controllers map
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
            const SnackBar(content: Text('Minimal harus ada satu data paket per operator')),
          );
       }
    });
  }

  // --- Fungsi untuk toggle hide/show grup ---
  void _toggleGroupVisibility(int groupIndex) {
    // Pastikan group index valid
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) return;
    setState(() {
      _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"];
    });
  }

  // Fungsi untuk mengambil data outlet dari API (Tetap sama, menggunakan _outletApiUrl)
  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoading = true; // Gunakan _isLoading atau _isLoadingOutlets secara konsisten
       _outlets = [];
       _selectedOutlet = null;
       // _namaController.clear(); // Jangan clear nama surveyor di sini
       _idOutletController.clear();
       _regionController.clear();
       _branchController.clear();
       _clusterController.clear();
       _hariController.clear();
    });
    try {
      var url = Uri.parse('$_outletApiUrl?user_id=${widget.userId}'); // Gunakan _outletApiUrl
      var response = await http.get(url).timeout(const Duration(seconds: 20)); // Timeout
      print("Outlet API Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['success'] == true && data['outlets'] is List) {
          final List<Map<String, dynamic>> fetchedOutlets =
              List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
          print("Outlets dimuat: ${fetchedOutlets.length}");

          Map<String, dynamic>? initialOutlet;
          String initialId = ''; String initialRegion = ''; String initialBranch = ''; String initialCluster = ''; String initialHari = '';

          if (fetchedOutlets.isNotEmpty) {
            initialOutlet = fetchedOutlets[0]; // Pilih outlet pertama by default
            initialId = initialOutlet['id_outlet']?.toString() ?? '';
            initialRegion = initialOutlet['region'] ?? '';
            initialBranch = initialOutlet['branch'] ?? '';
            initialCluster = initialOutlet['cluster'] ?? initialOutlet['area'] ?? '';
            initialHari = initialOutlet['hari'] ?? '';
            print("Outlet pertama dipilih: ${initialOutlet['nama_outlet']}");
          } else {
             print("Tidak ada data outlet ditemukan.");
          }

          if(mounted) { // Cek mounted sebelum setState
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

        } else { // Handle error dari API (success false atau format salah)
          print("Gagal mengambil data outlet: ${data['message'] ?? 'Format data tidak sesuai'}");
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(data['message'] ?? 'Gagal mengambil data outlet: Format tidak sesuai')),
              );
           }
        }
      } else { // Handle error HTTP
        print("Gagal mengambil data outlet: Server error ${response.statusCode}");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal mengambil data outlet (Error: ${response.statusCode})')),
            );
         }
      }
    } catch (e, stacktrace) { // Handle error network/lainnya
       print("Error fetching outlets: $e\n$stacktrace");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Terjadi kesalahan jaringan: $e')),
          );
       }
    } finally {
       if (mounted) { // Pastikan loading selesai
           setState(() {
             _isLoading = false; // Gunakan _isLoading atau _isLoadingOutlets
           });
       }
    }
  }


  // Fungsi untuk mengambil gambar (Tetap sama)
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
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Gagal mengambil gambar: $e')),
           );
       }
    }
  }

  // --- DIMODIFIKASI: Fungsi untuk validasi dan submit form ke API ---
  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus(); // Tutup keyboard

    // 1. Validasi Form Lokal (Menggunakan GlobalKey)
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Harap periksa kembali data yang belum terisi atau tidak valid')),
       );
      return;
    }
    // Validasi Outlet & Jenis Survei (Tetap)
     if (_selectedOutlet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Outlet belum terpilih atau data outlet gagal dimuat')),
       );
       return;
     }
    if (_selectedBrandinganOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih jenis survei')),
      );
      return;
    }

    // 2. Persiapan Data dan Validasi Tambahan
    bool isBrandingValid = true; // Flag khusus branding
    List<Map<String, dynamic>> finalHargaData = []; // List untuk data harga yang AKAN DIKIRIM

    if (_selectedBrandinganOption == "Survei branding") {
      // Validasi branding (tetap sama)
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan ambil kedua gambar branding')),
        );
        isBrandingValid = false;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      // --- A. Kumpulkan Data Harga HANYA dari Grup yang Paketnya Dipilih ---
      // Dilakukan SETELAH _formKey.validate() memastikan field yg relevan valid
      for (int i = 0; i < _operatorSurveyGroups.length; i++) {
        var group = _operatorSurveyGroups[i];
        String operatorName = group["operator"];
        String? paketType = group["paket"];

        // *** KONDISI PENGUMPULAN DATA: Hanya kumpulkan jika paket DIPILIH ***
        if (paketType != null && paketType.isNotEmpty) {
          List<Map<String, String>> currentEntriesData = [];
          List groupEntries = group["entries"];

          for (int j = 0; j < groupEntries.length; j++) {
            HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
            String namaPaket = controllers?.namaPaketController.text.trim() ?? "";
            String hargaInput = controllers?.hargaController.text.trim() ?? "";
            String jumlahInput = controllers?.jumlahController.text.trim() ?? "";
            String hargaNumerikBersih = hargaInput.replaceAll('.', '');

            currentEntriesData.add({
                "nama_paket": namaPaket,
                "harga": hargaNumerikBersih,
                "jumlah": jumlahInput
            });
          }
          // Tambahkan data grup ini ke list final
          finalHargaData.add({
            "operator": operatorName,
            "paket": paketType,
            "entries": currentEntriesData
          });
          print("Menambahkan data untuk operator (RumahPage): $operatorName");
        } else {
           print("Melewati operator (RumahPage): $operatorName karena paket tidak dipilih.");
        }
      } // Akhir loop pengumpulan data kondisional
    } // Akhir else if (Survei harga)

    // 3. Final Check sebelum submitting (Hanya cek flag branding eksplisit)
    if (!isBrandingValid) {
      return; // Stop if branding validation failed
    }
    // Jika lolos, berarti _formKey.validate() true & branding valid

    // 4. Set Loading State
    setState(() { _isSubmitting = true; });

    // 5. Prepare Data for API
    var request = http.MultipartRequest('POST', Uri.parse(_submitApiUrl));

    // Add common fields (termasuk nama surveyor)
    request.fields['user_id'] = widget.userId.toString();
    request.fields['username'] = widget.username; // Username asli user login
    request.fields['nama_surveyor'] = _namaController.text.trim(); // Nama surveyor dari input field
    request.fields['outlet_id'] = _idOutletController.text;
    request.fields['outlet_nama'] = _selectedOutlet?['nama_outlet'] ?? 'N/A';
    request.fields['region'] = _regionController.text;
    request.fields['branch'] = _branchController.text;
    request.fields['cluster'] = _clusterController.text;
    request.fields['hari'] = _hariController.text; // Nama field di PHP
    request.fields['tanggal_survei'] = _tokoController.text;
    request.fields['jenis_survei'] = _selectedBrandinganOption!;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();

    // Add survey-specific data
    try { // Bungkus file/json encoding dalam try-catch
        if (_selectedBrandinganOption == "Survei branding") {
          // Add image files
          if (_brandingImageEtalase != null) {
            request.files.add(await http.MultipartFile.fromPath( 'foto_etalase', _brandingImageEtalase!.path ));
          }
          if (_brandingImageTampakDepan != null) {
             request.files.add(await http.MultipartFile.fromPath( 'foto_depan', _brandingImageTampakDepan!.path ));
          }
        } else if (_selectedBrandinganOption == "Survei harga") {
          // Add price data as JSON string (hanya yg relevan)
          request.fields['data_harga'] = jsonEncode(finalHargaData); // Kirim data bersih
        }
    } catch (e) {
        print("Error mempersiapkan data request (file/json): $e");
        if (mounted) {
           setState(() { _isSubmitting = false; });
           _showErrorDialog('Error Mempersiapkan Data', 'Gagal memproses data survei sebelum mengirim: $e');
        }
        return; // Hentikan jika persiapan data gagal
    }


    // 6. Send Request and Handle Response (Tidak ada perubahan)
    try {
      print("--- Mengirim Data ke API (RumahPage) ---");
      print("URL: $_submitApiUrl");
      print("Fields: ${request.fields}");
       if (_selectedBrandinganOption == "Survei branding") {
         print("Files: foto_etalase=${_brandingImageEtalase?.path}, foto_depan=${_brandingImageTampakDepan?.path}");
       } else {
          print("JSON Data Harga yang Dikirim: ${request.fields['data_harga']}");
       }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 60)); // Increased timeout
      var response = await http.Response.fromStream(streamedResponse);

      print("API Response Status: ${response.statusCode}");
      print("API Response Body: ${response.body}");

      if (mounted) { // Check if widget is still in the tree
         setState(() { _isSubmitting = false; }); // Stop loading

        if (response.statusCode == 200) {
          try {
              var responseData = jsonDecode(response.body);
              if (responseData['success'] == true) {
                // Success Dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Berhasil')]),
                    content: Text(responseData['message'] ?? 'Data survei berhasil dikirim.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetForm(); // Reset form on success
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } else {
                // API Error Dialog
                _showErrorDialog('Gagal Mengirim Data', responseData['message'] ?? 'Terjadi kesalahan yang tidak diketahui dari server.');
              }
          } catch (e) {
              print("Error decoding JSON response: $e");
              _showErrorDialog('Gagal Memproses Respon', 'Respon dari server tidak valid.');
          }
        } else {
          // HTTP Error Dialog
           _showErrorDialog('Error Server', 'Gagal terhubung ke server (Kode: ${response.statusCode}).\n${response.reasonPhrase ?? ''}');
        }
      }

    } catch (e, stacktrace) {
      print("Error submitting form: $e\n$stacktrace");
      if (mounted) {
         setState(() { _isSubmitting = false; }); // Stop loading
         // Network Error Dialog
         _showErrorDialog('Error Jaringan', 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.\nError: $e');
      }
    }
  }

  // Helper function for showing error dialog
  void _showErrorDialog(String title, String message) {
     if (!mounted) return; // Cek mounted
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 10), Text(title)]),
          content: SingleChildScrollView(child: Text(message)), // Scrollable
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
  }

  // Widget builder untuk TextField standar (Tetap sama)
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
      return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator, // Validator dipasang di sini
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        hintText: hint,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[200] : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
       style: TextStyle(color: readOnly ? Colors.grey[700] : null),
       enableInteractiveSelection: !readOnly,
       focusNode: readOnly ? FocusNode(canRequestFocus: false) : null,
    );
  }

  // Widget builder untuk Image Picker (Tetap sama)
  Widget _buildImagePicker({
    required String label,
    File? image,
    required VoidCallback onPick,
    required VoidCallback onRetake,
    bool disabled = false, // Tambahkan parameter disabled
  }) {
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
            color: disabled ? Colors.grey[300] : Colors.grey[100], // Warna disabled
          ),
          child: image != null
              ? Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                       borderRadius: BorderRadius.circular(11.0),
                       child: Image.file(image, fit: BoxFit.cover)
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                         decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                           tooltip: "Ambil Ulang Foto", // Tooltip bahasa Indonesia
                          onPressed: disabled ? null : onRetake, // Aksi disabled
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, size: 40, color: disabled ? Colors.grey[500] : Colors.grey[600]), // Warna ikon disabled
                    tooltip: "Ambil Foto", // Tooltip bahasa Indonesia
                    onPressed: disabled ? null : onPick, // Aksi disabled
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canAddMoreHarga = _totalHargaEntriesCount < _maxHargaEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Survei'), // Judul tetap
        centerTitle: true,
        backgroundColor: Colors.redAccent,
         // Optional: Add back button handling if needed
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient( // Gradient tetap
            colors: [Color(0xFFFFB6B6), Color(0xFFFF8E8E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack( // Stack untuk overlay loading indicator
                  children: [
                    // --- Main Form Content ---
                    _isLoading && _outlets.isEmpty // Loading for outlets
                        ? const Center( // Indikator loading outlet
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 15),
                                  Text("Memuat data outlet...")
                                ],
                            )
                          )
                        : Form(
                            key: _formKey, // GlobalKey form
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Field Nama Surveyor ---
                                _buildTextField(
                                  controller: _namaController, // Gunakan _namaController
                                  label: 'Nama Surveyor *', // Label nama surveyor
                                  validator: (value) { // Validator untuk nama surveyor
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nama Surveyor wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // --- Fields Read Only: Region, Branch, Cluster ---
                                _buildTextField( controller: _regionController, label: 'Region', readOnly: true, ),
                                const SizedBox(height: 16),
                                _buildTextField( controller: _branchController, label: 'Branch', readOnly: true, ),
                                const SizedBox(height: 16),
                                _buildTextField( controller: _clusterController, label: 'Cluster', readOnly: true, ),
                                const SizedBox(height: 16),
                                _buildTextField(controller: _hariController, label: 'Hari Kunjungan (Outlet)', readOnly: true, ),
                                const SizedBox(height: 16),

                                // --- Dropdown Outlet ---
                                DropdownSearch<Map<String, dynamic>>(
                                  popupProps: PopupProps.menu( showSearchBox: true, searchFieldProps: const TextFieldProps( decoration: InputDecoration( hintText: "Cari nama outlet...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder() ) ), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4), emptyBuilder: (context, searchEntry) => const Center(child: Text("Outlet tidak ditemukan")), errorBuilder: (context, searchEntry, exception) => const Center(child: Text("Gagal memuat outlet")), loadingBuilder: (context, searchEntry) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), menuProps: const MenuProps(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))), ),
                                  items: _outlets, itemAsString: (outlet) => outlet['nama_outlet'] ?? 'Tanpa Nama', selectedItem: _selectedOutlet,
                                  dropdownDecoratorProps: DropDownDecoratorProps( dropdownSearchDecoration: InputDecoration( labelText: "Pilih Outlet *", hintText: _outlets.isEmpty && !_isLoading ? "Tidak ada data outlet" : "Pilih outlet lainnya...", border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), ), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ), ),
                                  onChanged: (value) { // Update state saat outlet berubah
                                    setState(() {
                                      _selectedOutlet = value;
                                      if (value != null) { _idOutletController.text = value['id_outlet']?.toString() ?? ''; _regionController.text = value['region'] ?? ''; _branchController.text = value['branch'] ?? ''; _clusterController.text = value['cluster'] ?? value['area'] ?? ''; _hariController.text = value['hari'] ?? '';
                                      } else { _idOutletController.clear(); _regionController.clear(); _branchController.clear(); _clusterController.clear(); _hariController.clear(); /* Jangan clear _namaController di sini */ }
                                    });
                                  },
                                  validator: (value) { // Validator Outlet
                                    if (value == null) { return 'Silakan pilih outlet'; }
                                    return null;
                                  },
                                  enabled: !_isLoading && _outlets.isNotEmpty && !_isSubmitting, // Kondisi enabled
                                ),
                                const SizedBox(height: 16),

                                // --- Fields Read Only: ID Outlet, Tanggal ---
                                _buildTextField( controller: _idOutletController, label: 'ID Outlet', readOnly: true, ),
                                const SizedBox(height: 16),
                                _buildTextField( controller: _tokoController, label: 'Tanggal Survei', readOnly: true, ),
                                const SizedBox(height: 16),

                                // --- Dropdown Jenis Survei ---
                                DropdownButtonFormField<String>(
                                  isExpanded: true, value: _selectedBrandinganOption, hint: const Text("Pilih Jenis Survei"),
                                  decoration: InputDecoration( labelText: 'Jenis Survei *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ),
                                  items: _brandinganOptions.map((option) { return DropdownMenuItem<String>(value: option, child: Text(option)); }).toList(),
                                  onChanged: _isSubmitting ? null : (value) {
                                    setState(() {
                                      _selectedBrandinganOption = value;
                                      _brandingImageEtalase = null; _brandingImageTampakDepan = null;
                                      if (value == "Survei harga") {
                                        _initializeFixedSurveyHarga(); // Panggil inisialisasi baru
                                      } else {
                                        // Clear data harga jika jenis lain dipilih
                                        _operatorSurveyGroups.clear();
                                        _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose()));
                                        _hargaEntryControllersMap.clear();
                                        _totalHargaEntriesCount = 0;
                                      }
                                    });
                                  },
                                  validator: (value) { // Validator Jenis Survei
                                    if (value == null || value.isEmpty) return 'Silakan pilih jenis survei';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),


                                // --- Konten Dinamis Berdasarkan Jenis Survei ---

                                // === SURVEI BRANDING ===
                                if (_selectedBrandinganOption == "Survei branding") ...[
                                  // Image Pickers
                                  _buildImagePicker( label: "Foto Etalase *", image: _brandingImageEtalase, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), ),
                                  const SizedBox(height: 16),
                                  _buildImagePicker( label: "Foto Tampak Depan *", image: _brandingImageTampakDepan, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), ),
                                  const SizedBox(height: 16),
                                ],

                                // === SURVEI HARGA (FIXED OPERATORS) ===
                                if (_selectedBrandinganOption == "Survei harga") ...[
                                  AbsorbPointer( absorbing: _isSubmitting,
                                    child: ListView.builder(
                                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _operatorSurveyGroups.length, // Akan selalu 6
                                      itemBuilder: (context, groupIndex) {
                                        // Ambil data grup dari state
                                        final group = _operatorSurveyGroups[groupIndex];
                                        bool isHidden = group["isHidden"];
                                        List entries = group["entries"];
                                        String operatorName = group["operator"]; // Nama operator dari state

                                        return Card( // Card per operator
                                          margin: const EdgeInsets.symmetric(vertical: 8.0), elevation: 2, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300) ),
                                          child: Padding( padding: const EdgeInsets.all(12.0),
                                            child: Column( crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [ // Header Grup
                                                Row( children: [ Expanded( child: Text( operatorName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), ), ), TextButton.icon( icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), label: Text(isHidden ? 'Tampilkan' : 'Sembunyikan', style: const TextStyle(fontSize: 12)), onPressed: _isSubmitting ? null : () => _toggleGroupVisibility(groupIndex), style: TextButton.styleFrom( foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap, minimumSize: const Size(0, 30) ), ), ], ),
                                                // Detail Grup
                                                if (!isHidden) ...[ const Divider(thickness: 1, height: 20),
                                                  // Dropdown Paket (Tanpa Validator)
                                                  DropdownButtonFormField<String>(
                                                    validator: null, // VALIDATOR PAKET DIHAPUS
                                                    isExpanded: true, value: group["paket"], hint: const Text("Pilih Paket"),
                                                    decoration: InputDecoration( labelText: 'Paket', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ), // Bintang dihapus
                                                    items: _paketOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
                                                    onChanged: _isSubmitting ? null : (value) { setState(() { _operatorSurveyGroups[groupIndex]["paket"] = value; }); },
                                                  ), const SizedBox(height: 20),
                                                  // --- List Entri Harga ---
                                                  ListView.builder( shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: entries.length,
                                                    itemBuilder: (context, entryIndex) {
                                                      // Inisialisasi controller jika perlu
                                                      if (_hargaEntryControllersMap[groupIndex] == null) { _hargaEntryControllersMap[groupIndex] = {}; } if (_hargaEntryControllersMap[groupIndex]![entryIndex] == null) { _hargaEntryControllersMap[groupIndex]![entryIndex] = HargaEntryControllers(); }
                                                      HargaEntryControllers controllers = _hargaEntryControllersMap[groupIndex]![entryIndex]!;
                                                      return Container( // Container per entri harga
                                                        padding: const EdgeInsets.all(10).copyWith(bottom: 0), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration( color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200) ),
                                                        child: Column( crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [ Text("   Data Paket Ke-${entryIndex + 1}", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])), const SizedBox(height: 8),
                                                            // Nama Paket (Validator Kondisional)
                                                            _buildTextField( controller: controllers.namaPaketController, label: 'Nama Paket *', hint: 'Contoh: Xtra Combo Lite L 3.5GB', readOnly: _isSubmitting,
                                                              validator: (value) { if (group["paket"] != null && group["paket"].isNotEmpty) { if (value == null || value.trim().isEmpty) { return 'Masukkan nama paket'; } } return null; }
                                                            ), const SizedBox(height: 16),
                                                            // Harga (Validator Kondisional)
                                                            _buildTextField( controller: controllers.hargaController, label: 'Harga Satuan *', prefixText: 'Rp ', hint: 'Contoh: 10000 atau 10.000', readOnly: _isSubmitting, keyboardType: const TextInputType.numberWithOptions(decimal: false), inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')) ],
                                                              validator: (value) { if (group["paket"] != null && group["paket"].isNotEmpty) { if (value == null || value.trim().isEmpty) return 'Masukkan harga'; final numericString = value.replaceAll('.', ''); if (numericString.isEmpty || double.tryParse(numericString) == null) return 'Format angka tidak valid'; if (double.parse(numericString) <= 0) return 'Harga harus > 0'; } return null; }
                                                            ), const SizedBox(height: 16),
                                                            // Jumlah (Validator Kondisional)
                                                            _buildTextField( controller: controllers.jumlahController, label: 'Jumlah *', hint: 'Jumlah barang/stok', readOnly: _isSubmitting, keyboardType: TextInputType.number, inputFormatters: [ FilteringTextInputFormatter.digitsOnly ],
                                                              validator: (value) { if (group["paket"] != null && group["paket"].isNotEmpty) { if (value == null || value.trim().isEmpty) return 'Masukkan jumlah'; final int? jumlah = int.tryParse(value); if (jumlah == null) return 'Jumlah harus angka'; if (jumlah <= 0) return 'Jumlah harus > 0'; } return null; }
                                                            ), const SizedBox(height: 0),
                                                            // Tombol Hapus
                                                            Align( alignment: Alignment.centerRight, child: (entries.length > 1) ? TextButton.icon( icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600), label: Text("Hapus", style: TextStyle(color: Colors.red.shade600, fontSize: 12)), onPressed: _isSubmitting ? null : () => _removeHargaEntry(groupIndex, entryIndex), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5), minimumSize: const Size(0, 25)), ) : const SizedBox(height: 25), ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  // Tombol Tambah Data Paket
                                                  Align( alignment: Alignment.centerRight, child: TextButton.icon( icon: const Icon(Icons.add_circle_outline, size: 20), label: const Text("Tambah Data Paket"), onPressed: _isSubmitting || !canAddMoreHarga ? null : () => _addHargaEntry(groupIndex), style: TextButton.styleFrom( foregroundColor: _isSubmitting || !canAddMoreHarga ? Colors.grey : Theme.of(context).primaryColor, ), ), ),
                                                ] else ...[ // Tampilan Hidden
                                                  Padding( padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), child: Text( "Paket: ${group['paket'] ?? '(Belum dipilih)'}", style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis, ), ),
                                                ]
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ), // End AbsorbPointer
                                  const SizedBox(height: 10),
                                  // Tombol Tambah Operator Lain (DIHAPUS)
                                  // Align( ... ),
                                  // const SizedBox(height: 10),
                                  // Informasi Batas Maksimal
                                  if (!canAddMoreHarga)
                                    Padding( padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), child: Row( children: [ Icon(Icons.info_outline, color: Colors.orange.shade800, size: 16), const SizedBox(width: 8), Expanded( child: Text( "Batas maksimal $_maxHargaEntries data paket telah tercapai.", style: TextStyle(color: Colors.orange.shade900, fontStyle: FontStyle.italic), ), ), ], ), ),
                                  const SizedBox(height: 16),
                                ], // End Survei Harga Section


                                // --- Keterangan Kunjungan ---
                                _buildTextField(
                                  controller: _keteranganController, label: 'Keterangan Kunjungan *', hint: 'Masukkan detail atau catatan penting selama kunjungan...', maxLines: 5, readOnly: _isSubmitting,
                                  validator: (value) { // Validator Keterangan
                                    if (value == null || value.trim().isEmpty) return 'Keterangan kunjungan wajib diisi';
                                    if (value.trim().length < 10) return 'Keterangan terlalu pendek (min. 10 karakter)';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),


                                // --- Tombol Submit ---
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _submitForm, // Disable if submitting
                                    style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.redAccent, disabledBackgroundColor: Colors.grey, ), // Style tetap
                                    child: _isSubmitting
                                      ? const SizedBox( height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)) ) // Indikator loading
                                      : const Text( 'Submit Data Survei', style: TextStyle(fontSize: 18, color: Colors.white), ), // Teks tombol
                                  ),
                                ),
                              ],
                            ),
                          ),
                    // --- Overlay Loading Indicator (for submission) ---
                    if (_isSubmitting)
                       Positioned.fill(
                          child: Container(
                            // Match card shape
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
                              borderRadius: BorderRadius.circular(16), // Match card radius
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                  SizedBox(height: 15),
                                  Text("Mengirim data...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), // Teks loading
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
} // End of _RumahPageState