// home_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
// Impor package path jika diperlukan untuk pembuatan nama file yang lebih kuat (opsional)
// import 'package:path/path.dart' as p;

class HomePage extends StatefulWidget {
  final String username;
  final int userId;
  const HomePage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

// --- Helper Class untuk Controller per Entri Harga ---
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

  // --- API Endpoint ---
  // Gunakan 10.0.2.2 untuk localhost emulator Android, ganti dengan IP Anda jika menguji di perangkat fisik
  final String _submitApiUrl = "https://tunnel.jato.my.id/test%20api/submit_survey.php";
  final String _outletApiUrl = "https://tunnel.jato.my.id/test%20api/getAreas.php"; // URL API outlet diekstrak

  // Controller untuk field yang terisi otomatis dari Outlet
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController(); // Hari Kunjungan

  // Controller Lain
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController(); // Menyimpan tanggal
  final TextEditingController _keteranganController = TextEditingController(); // Keterangan Kunjungan

  // Data Outlet & Status Loading
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoadingOutlets = false; // Nama diubah untuk kejelasan
  bool _isSubmitting = false; // Loading untuk pengiriman form

  // Opsi Jenis Survei
  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  // Data Survei Branding
  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // --- Data Survei Harga (Dimodifikasi) ---
  // List untuk menampung data 6 grup operator tetap
  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  // Map untuk menampung controller, dikunci oleh indeks grup lalu indeks entri
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};
  // Definisikan daftar operator tetap
  static const List<String> _fixedOperators = ["TELKOMSEL", "XL", "INDOSAT OOREDOO", "AXIS", "SMARTFREN", "3"]; // Perbaikan typo OOREDOO

  // Batas Survei Harga
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 15; // Batas total entri di semua operator

  // Opsi Dropdown Survei Harga
  // Opsi operator sekarang tetap, daftar ini digunakan untuk inisialisasi
  // final List<String> _operatorOptions = ["XL", "INDOSAT OOREDO", "AXIS", "SMARTFREN" , "3", "TELKOMSEL"]; // Tidak lagi diperlukan untuk dropdown
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
    // Dispose semua controller
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

  // --- Fungsi Reset Form ---
  void _resetForm() {
      _formKey.currentState?.reset(); // Reset status validasi
      setState(() {
          // Bersihkan controller yang diinput manual
          _keteranganController.clear();

          // Reset pilihan dan data dinamis
          _selectedBrandinganOption = null;
          _brandingImageEtalase = null;
          _brandingImageTampakDepan = null;

          // Bersihkan dan dispose data survei harga dan controller
          _operatorSurveyGroups.clear();
           _hargaEntryControllersMap.values.forEach((entryMap) {
               entryMap.values.forEach((controllers) => controllers.dispose());
           });
           _hargaEntryControllersMap.clear();
           _totalHargaEntriesCount = 0;

          //  // Reset pilihan outlet ke yang pertama jika tersedia
          //  _selectedOutlet = _outlets.isNotEmpty ? _outlets[0] : null;
           if (_selectedOutlet != null) {
                _idOutletController.text = _selectedOutlet!['id_outlet']?.toString() ?? '';
                _regionController.text = _selectedOutlet!['region'] ?? '';
                _branchController.text = _selectedOutlet!['branch'] ?? '';
                _clusterController.text = _selectedOutlet!['cluster'] ?? _selectedOutlet!['area'] ?? '';
                _hariController.text = _selectedOutlet!['hari'] ?? '';
           } else {
               _idOutletController.clear();
               _regionController.clear();
               _branchController.clear();
               _clusterController.clear();
               _hariController.clear();
           }
           // Atur tanggal lagi
          _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      });
  }


  // --- DIMODIFIKASI: Fungsi untuk inisialisasi 6 grup operator tetap ---
  void _initializeFixedSurveyHarga() {
     setState(() {
       // Bersihkan data dan controller sebelumnya terlebih dahulu
       _operatorSurveyGroups.clear();
       _hargaEntryControllersMap.values.forEach((entryMap) {
        entryMap.values.forEach((controllers) => controllers.dispose());
       });
       _hargaEntryControllersMap.clear();
       _totalHargaEntriesCount = 0;

       // Buat 6 grup operator tetap
       for (int i = 0; i < _fixedOperators.length; i++) {
         String operatorName = _fixedOperators[i];
         _operatorSurveyGroups.add({
           "operator": operatorName, // Nama operator sudah diisi
           "paket": null, // Pengguna masih perlu memilih jenis paket
           "entries": [{"nama_paket": "", "harga": "", "jumlah": ""}], // Mulai dengan satu entri kosong
           "isHidden": false // Awalnya terlihat
         });

         // Inisialisasi controller untuk entri pertama grup ini
         _hargaEntryControllersMap[i] = { 0: HargaEntryControllers() };
         _totalHargaEntriesCount++; // Tambah hitungan untuk entri awal
       }
     });
  }

   // --- DIHAPUS: Fungsi _addOperatorGroup tidak lagi diperlukan ---
   /*
   void _addOperatorGroup() { ... } // Fungsi ini dihapus karena grup sudah tetap
   */

  // --- Fungsi untuk menambah entri harga dalam grup operator tertentu ---
  void _addHargaEntry(int groupIndex) {
     if (_totalHargaEntriesCount >= _maxHargaEntries) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batas maksimal $_maxHargaEntries data paket tercapai')),
       );
       return;
     }

    setState(() {
      // Pastikan grup ada sebelum menambahkan entri
      if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) {
        print("Error: Indeks grup tidak valid $groupIndex untuk menambahkan entri.");
        return;
      }
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;
      // Tambahkan map entri kosong baru
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""});

      // Pastikan map untuk grup ada
      if (_hargaEntryControllersMap[groupIndex] == null) {
        _hargaEntryControllersMap[groupIndex] = {};
      }
       // Tambahkan controller baru untuk entri baru
       _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();
       _totalHargaEntriesCount++; // Tambah hitungan total
    });
  }

  // --- Fungsi untuk menghapus entri harga dari dalam grup operator tertentu ---
  void _removeHargaEntry(int groupIndex, int entryIndex) {
    // Pastikan indeks grup dan entri valid
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length ||
        _hargaEntryControllersMap[groupIndex] == null ||
        entryIndex < 0) {
      print("Error: Indeks tidak valid ($groupIndex, $entryIndex) untuk menghapus entri.");
      return;
    }

    setState(() {
       List entries = _operatorSurveyGroups[groupIndex]["entries"];
       // Cegah penghapusan entri terakhir dalam grup
       if (entries.length > 1) {
         // Periksa apakah indeks entri ada sebelum menghapus
         if (entryIndex < entries.length) {
           // Dispose controller sebelum menghapus data dan entri map
           _hargaEntryControllersMap[groupIndex]?[entryIndex]?.dispose();
           _hargaEntryControllersMap[groupIndex]?.remove(entryIndex);
           entries.removeAt(entryIndex); // Hapus data

           // Re-indeks controller yang tersisa untuk grup ini agar berurutan
           Map<int, HargaEntryControllers> updatedControllers = {};
           int currentNewIndex = 0;
           // Urutkan kunci untuk memastikan urutan sebelum re-indeks
           var sortedKeys = _hargaEntryControllersMap[groupIndex]?.keys.toList()?..sort();
           sortedKeys?.forEach((oldIndex) {
               if (_hargaEntryControllersMap[groupIndex]![oldIndex] != null) {
                  updatedControllers[currentNewIndex] = _hargaEntryControllersMap[groupIndex]![oldIndex]!;
                  currentNewIndex++;
               }
           });
           _hargaEntryControllersMap[groupIndex] = updatedControllers; // Perbarui map untuk grup

           _totalHargaEntriesCount--; // Kurangi hitungan total
         } else {
             print("Error: Indeks entri $entryIndex di luar batas untuk grup $groupIndex saat penghapusan.");
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
     // Pastikan indeks grup valid
    if (groupIndex < 0 || groupIndex >= _operatorSurveyGroups.length) {
      print("Error: Indeks grup tidak valid $groupIndex untuk toggle visibilitas.");
      return;
    }
    setState(() {
      // Toggle flag isHidden
      _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"];
    });
  }

  // --- Fungsi untuk mengambil data outlet dari API ---
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
      // Bangun URL dengan ID pengguna
      var url = Uri.parse('$_outletApiUrl?user_id=${widget.userId}');
      print("Mengambil outlet dari: $url"); // Cetak debug
      var response = await http.get(url).timeout(const Duration(seconds: 20)); // Tingkatkan timeout sedikit
      print("Status Respons API Outlet: ${response.statusCode}"); // Cetak debug

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        // Periksa flag sukses dan bahwa 'outlets' adalah list
        if (data is Map && data.containsKey('success') && data['success'] == true && data['outlets'] is List) {
          final List<Map<String, dynamic>> fetchedOutlets =
              List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
          print("Outlet dimuat: ${fetchedOutlets.length}"); // Cetak debug

          Map<String, dynamic>? initialOutlet;
          String initialId = '';
          String initialRegion = '';
          String initialBranch = '';
          String initialCluster = '';
          String initialHari = '';

          if (fetchedOutlets.isNotEmpty) {
            // Default ke outlet pertama dalam daftar
            initialOutlet = fetchedOutlets[0];
            initialId = initialOutlet['id_outlet']?.toString() ?? '';
            initialRegion = initialOutlet['region'] ?? '';
            initialBranch = initialOutlet['branch'] ?? '';
            // Gunakan 'cluster' jika tersedia, jika tidak fallback ke 'area'
            initialCluster = initialOutlet['cluster'] ?? initialOutlet['area'] ?? '';
            initialHari = initialOutlet['hari'] ?? '';
            print("Outlet pertama dipilih: ${initialOutlet['nama_outlet']}"); // Cetak debug
          } else {
             print("Tidak ada data outlet ditemukan dalam respons."); // Cetak debug
          }

          // Perbarui state hanya jika widget masih ter-mount
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
          // Tangani pesan error API atau format data yang salah
          String errorMessage = data is Map && data.containsKey('message')
              ? data['message']
              : 'Gagal mengambil data outlet: Format data tidak sesuai diterima dari server.';
          print(errorMessage); // Cetak debug
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
          }
        }
      } else {
        // Tangani error HTTP
        String errorMessage = 'Gagal mengambil data outlet (Error Server: ${response.statusCode})';
        print(errorMessage); // Cetak debug
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e, stacktrace) { // Tangkap error spesifik dan cetak stacktrace
       print("Error mengambil outlets: $e\n$stacktrace"); // Cetak debug dengan stacktrace
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan jaringan saat mengambil outlet: $e')),
        );
       }
    } finally {
       // Pastikan indikator loading dimatikan terlepas dari hasilnya
       if (mounted) {
           setState(() {
             _isLoadingOutlets = false;
           });
       }
    }
  }


  // --- Fungsi untuk mengambil gambar ---
  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    try {
      // Ambil gambar dengan kualitas yang ditentukan
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80); // Atur kualitas gambar
      if (pickedFile != null) {
        if (mounted) {
          setState(() {
             // Fungsi callback dengan file yang dipilih
             onImagePicked(File(pickedFile.path));
          });
        }
      }
    } catch (e) {
      print("Error mengambil gambar: $e"); // Cetak debug
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Gagal mengambil gambar: $e')),
           );
       }
    }
  }

  // --- DIMODIFIKASI: Fungsi untuk validasi dan kirim data form ---
  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus(); // Tutup keyboard

    // 1. Validasi Form Dasar (GlobalKey & Outlet/Jenis Survei)
    // Panggil validate(). Ini memicu validator individual yang relevan.
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Harap periksa kembali data yang belum terisi atau tidak valid')),
       );
      return;
    }
    // Validasi Outlet & Jenis Survei (tetap)
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
    bool isBrandingValid = true; // Flag khusus untuk branding
    List<Map<String, dynamic>> finalHargaData = []; // Inisialisasi list kosong untuk data harga yang AKAN DIKIRIM

    if (_selectedBrandinganOption == "Survei branding") {
      // Validasi branding (tetap sama)
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan ambil kedua gambar branding')),
        );
        isBrandingValid = false; // Set flag jika tidak valid
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      // --- A. Kumpulkan Data Harga HANYA dari Grup yang Paketnya Dipilih ---
      // Loop ini dijalankan SETELAH _formKey.validate() memastikan field yang relevan valid
      for (int i = 0; i < _operatorSurveyGroups.length; i++) {
        var group = _operatorSurveyGroups[i];
        String operatorName = group["operator"];
        String? paketType = group["paket"]; // Ambil nilai paket

        // *** KONDISI PENGUMPULAN DATA: Hanya kumpulkan jika paket DIPILIH ***
        if (paketType != null && paketType.isNotEmpty) {
          List<Map<String, String>> currentEntriesData = [];
          List groupEntries = group["entries"];

          // Kumpulkan entri untuk grup ini (data sudah divalidasi oleh _formKey.validate())
          for (int j = 0; j < groupEntries.length; j++) {
            HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
            // Asumsikan controller ada karena sudah lolos validasi jika paket dipilih
            // Tambahkan null check safety jika diperlukan, meskipun secara logika seharusnya tidak null di sini
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
          // Tambahkan data grup ini ke list final HANYA jika paket dipilih
          finalHargaData.add({
            "operator": operatorName,
            "paket": paketType, // Kirim paket yang dipilih
            "entries": currentEntriesData
          });
          print("Menambahkan data untuk operator: $operatorName"); // Debug: lihat operator mana yang datanya ditambahkan
        } else {
           print("Melewati operator: $operatorName karena paket tidak dipilih."); // Debug: lihat operator mana yang dilewati
        }
        // Jika paketType null atau kosong, data grup ini tidak ditambahkan ke finalHargaData
      } // Akhir loop pengumpulan data kondisional

      // Tidak perlu loop validasi tambahan di sini, sudah ditangani _formKey.validate()
    } // Akhir else if (Survei harga)

    // 3. Pemeriksaan Akhir Hasil Validasi
    if (!isBrandingValid) { // Cek hanya error branding eksplisit
      // Pesan error branding sudah ditampilkan sebelumnya
      return; // Hentikan jika branding tidak valid
    }
    // Jika lolos sampai sini, berarti _formKey.validate() return true
    // dan validasi branding (jika relevan) juga lolos.

    // 4. Set Status Loading
    setState(() { _isSubmitting = true; });

    // 5. Siapkan Multipart Request
    var request = http.MultipartRequest('POST', Uri.parse(_submitApiUrl));
    request.fields['user_id'] = widget.userId.toString();
    request.fields['username'] = widget.username;
    request.fields['outlet_id'] = _idOutletController.text;
    request.fields['outlet_nama'] = _selectedOutlet?['nama_outlet']?.toString() ?? 'N/A';
    request.fields['region'] = _regionController.text;
    request.fields['branch'] = _branchController.text;
    request.fields['cluster'] = _clusterController.text;
    request.fields['hari'] = _hariController.text;
    request.fields['tanggal_survei'] = _tokoController.text;
    request.fields['jenis_survei'] = _selectedBrandinganOption!;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();

    // --- Tambahkan data spesifik survei ---
    try {
      if (_selectedBrandinganOption == "Survei branding") {
        if (_brandingImageEtalase != null) { request.files.add(await http.MultipartFile.fromPath('foto_etalase', _brandingImageEtalase!.path)); }
        if (_brandingImageTampakDepan != null) { request.files.add(await http.MultipartFile.fromPath('foto_depan', _brandingImageTampakDepan!.path)); }
      } else if (_selectedBrandinganOption == "Survei harga") {
        // *** Kirim `finalHargaData` yang HANYA berisi data operator yang relevan ***
        // Jika finalHargaData kosong (tidak ada paket yg dipilih), JSON kosong "[]" akan dikirim.
        request.fields['data_harga'] = jsonEncode(finalHargaData);
      }
    } catch (e) {
        print("Error mempersiapkan data request (file/json): $e");
        if (mounted) {
           setState(() { _isSubmitting = false; });
           _showErrorDialog('Error Mempersiapkan Data', 'Gagal memproses data survei sebelum mengirim: $e');
        }
        return; // Hentikan jika persiapan data gagal
    }


    // 6. Kirim Request dan Tangani Respons (Tidak ada perubahan)
    try {
      print("--- Mengirim Data ke API ---");
      print("URL: $_submitApiUrl");
      print("Fields: ${request.fields}");
       if (_selectedBrandinganOption == "Survei branding") {
         print("File terlampir: foto_etalase=${_brandingImageEtalase != null}, foto_depan=${_brandingImageTampakDepan != null}");
       } else {
          print("JSON Data Harga yang Dikirim: ${request.fields['data_harga']}"); // Cetak JSON yang dikirim
       }

      // Kirim request dengan timeout
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60)); // Tingkatkan timeout
      // Baca respons
      var response = await http.Response.fromStream(streamedResponse);

      print("Status Respons API: ${response.statusCode}"); // Cetak debug
      print("Body Respons API: ${response.body}"); // Cetak debug

      // Proses respons hanya jika widget masih ter-mount
      if (mounted) {
         setState(() { _isSubmitting = false; }); // Hentikan indikator loading

        if (response.statusCode == 200) {
          try {
              // Coba dekode respons JSON
              var responseData = jsonDecode(response.body);
              // Periksa flag sukses dari API
              if (responseData is Map && responseData.containsKey('success') && responseData['success'] == true) {
                // Tampilkan Dialog Sukses
                showDialog(
                  context: context,
                  barrierDismissible: false, // Pengguna harus menekan tombol untuk menutup
                  builder: (context) => AlertDialog(
                    title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Berhasil')]), // 'Berhasil'
                    content: Text(responseData['message'] ?? 'Data survei berhasil dikirim.'), // 'Data survei berhasil dikirim.'
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Tutup dialog
                          _resetForm(); // Reset form setelah pengiriman berhasil
                        },
                        child: const Text('OK'), // 'OK'
                      ),
                    ],
                  ),
                );
              } else {
                // Tangani pesan error API (flag sukses false atau hilang)
                String errorMessage = responseData is Map && responseData.containsKey('message')
                    ? responseData['message']
                    : 'Terjadi kesalahan yang tidak diketahui dari server.'; // 'Terjadi kesalahan yang tidak diketahui dari server.'
                _showErrorDialog('Gagal Mengirim Data', errorMessage); // 'Gagal Mengirim Data'
              }
          } catch (e) {
              // Tangani error dekode JSON
              print("Error dekode respons JSON: $e");
              _showErrorDialog('Gagal Memproses Respon', 'Respon dari server tidak valid.'); // 'Gagal Memproses Respon', 'Respon dari server tidak valid.'
          }
        } else {
          // Tangani error HTTP (4xx, 5xx)
           _showErrorDialog('Error Server', 'Gagal terhubung ke server (Kode: ${response.statusCode}).\n${response.reasonPhrase ?? ''}'); // 'Error Server', 'Gagal terhubung ke server...'
        }
      }

    } catch (e, stacktrace) { // Tangkap error jaringan atau lainnya saat pengiriman
      print("Error mengirim form: $e\n$stacktrace"); // Log error dengan stacktrace
      if (mounted) {
         setState(() { _isSubmitting = false; }); // Hentikan loading
         // Tampilkan Dialog Error Jaringan
         _showErrorDialog('Error Jaringan', 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.\nError: $e'); // 'Error Jaringan', 'Tidak dapat terhubung ke server...'
      }
    }
  }

  // --- Fungsi helper untuk menampilkan dialog error ---
  void _showErrorDialog(String title, String message) {
     // Pastikan dialog hanya ditampilkan jika widget ter-mount
     if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 10), Text(title)]),
          content: SingleChildScrollView(child: Text(message)), // Buat konten dapat di-scroll
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Tutup dialog
              child: const Text('OK'), // 'OK'
            ),
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
      validator: validator, // Validator tetap dipasang di sini
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

  // --- Widget builder untuk Image Picker ---
  Widget _buildImagePicker({
    required String label,
    File? image,
    required VoidCallback onPick,
    required VoidCallback onRetake,
    bool disabled = false,
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
            color: disabled ? Colors.grey[300] : Colors.grey[100],
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
                    icon: Icon(Icons.camera_alt, size: 40, color: disabled ? Colors.grey[500] : Colors.grey[600]),
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
    bool canAddMoreHarga = _totalHargaEntriesCount < _maxHargaEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Survei'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F0), Color(0xFFFFE0E0)],
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
                child: Stack( // Stack untuk overlay loading
                  children: [
                    // --- Konten Form Utama ---
                    _isLoadingOutlets && _outlets.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 50.0),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 15),
                                    Text("Memuat data outlet...")
                                  ],
                              ),
                            )
                          )
                        : Form(
                            key: _formKey, // Form Key digunakan di sini
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Field Read Only ---
                                _buildTextField(controller: _regionController, label: 'Region', readOnly: true), const SizedBox(height: 16),
                                _buildTextField(controller: _branchController, label: 'Branch', readOnly: true), const SizedBox(height: 16),
                                _buildTextField(controller: _clusterController, label: 'Cluster', readOnly: true), const SizedBox(height: 16),
                                _buildTextField(controller: _namaController, label: 'Nama Surveyor', readOnly: true), const SizedBox(height: 16),
                                _buildTextField(controller: _hariController, label: 'Hari Kunjungan (Outlet)', readOnly: true), const SizedBox(height: 16),

                                // --- Dropdown Outlet ---
                                DropdownSearch<Map<String, dynamic>>(
                                  popupProps: PopupProps.menu( showSearchBox: true, searchFieldProps: const TextFieldProps( decoration: InputDecoration( hintText: "Cari nama outlet...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder() ) ), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4), emptyBuilder: (context, searchEntry) => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Outlet tidak ditemukan"))), errorBuilder: (context, searchEntry, exception) => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Gagal memuat outlet"))), loadingBuilder: (context, searchEntry) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), menuProps: const MenuProps( elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))) ), ),
                                  items: _outlets, itemAsString: (outlet) => outlet['nama_outlet']?.toString() ?? 'Outlet Tidak Dikenal', selectedItem: _selectedOutlet,
                                  dropdownDecoratorProps: DropDownDecoratorProps( dropdownSearchDecoration: InputDecoration( labelText: "Pilih Outlet *", hintText: _outlets.isEmpty && !_isLoadingOutlets ? "Tidak ada data outlet" : "Pilih outlet lainnya...", border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), ), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ), ),
                                  onChanged: (value) { setState(() { _selectedOutlet = value; if (value != null) { _idOutletController.text = value['id_outlet']?.toString() ?? ''; _regionController.text = value['region'] ?? ''; _branchController.text = value['branch'] ?? ''; _clusterController.text = value['cluster'] ?? value['area'] ?? ''; _hariController.text = value['hari'] ?? ''; } else { _idOutletController.clear(); _regionController.clear(); _branchController.clear(); _clusterController.clear(); _hariController.clear(); } }); },
                                  validator: (value) { if (value == null) { return 'Silakan pilih outlet'; } return null; }, // Validator untuk DropdownSearch
                                  enabled: !_isLoadingOutlets && _outlets.isNotEmpty && !_isSubmitting,
                                ), const SizedBox(height: 16),

                                // --- Field Read Only Lanjutan ---
                                _buildTextField(controller: _idOutletController, label: 'ID Outlet', readOnly: true), const SizedBox(height: 16),
                                _buildTextField(controller: _tokoController, label: 'Tanggal Survei', readOnly: true), const SizedBox(height: 16),

                                // --- Dropdown Jenis Survei ---
                                DropdownButtonFormField<String>(
                                  isExpanded: true, value: _selectedBrandinganOption, hint: const Text("Pilih Jenis Survei"),
                                  decoration: InputDecoration( labelText: 'Jenis Survei *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), ),
                                  items: _brandinganOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
                                  onChanged: _isSubmitting ? null : (value) { setState(() { _selectedBrandinganOption = value; _brandingImageEtalase = null; _brandingImageTampakDepan = null; if (value == "Survei harga") { _initializeFixedSurveyHarga(); } else { _operatorSurveyGroups.clear(); _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose())); _hargaEntryControllersMap.clear(); _totalHargaEntriesCount = 0; } }); },
                                  validator: (value) { if (value == null || value.isEmpty) return 'Silakan pilih jenis survei'; return null; }, // Validator untuk DropdownButtonFormField
                                ), const SizedBox(height: 20),

                                // --- Konten Dinamis ---
                                // === SURVEI BRANDING ===
                                if (_selectedBrandinganOption == "Survei branding") ...[
                                  _buildImagePicker( label: "Foto Etalase *", image: _brandingImageEtalase, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file), ), const SizedBox(height: 16),
                                  _buildImagePicker( label: "Foto Tampak Depan *", image: _brandingImageTampakDepan, disabled: _isSubmitting, onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file), ), const SizedBox(height: 16),
                                ],

                                // === SURVEI HARGA ===
                                if (_selectedBrandinganOption == "Survei harga") ...[
                                  AbsorbPointer( absorbing: _isSubmitting,
                                    child: ListView.builder( shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _operatorSurveyGroups.length,
                                      itemBuilder: (context, groupIndex) {
                                        // Ambil data grup dari state (penting untuk akses di validator)
                                        final group = _operatorSurveyGroups[groupIndex];
                                        bool isHidden = group["isHidden"];
                                        List entries = group["entries"];
                                        String operatorName = group["operator"];

                                        return Card( margin: const EdgeInsets.symmetric(vertical: 8.0), elevation: 2, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300) ),
                                          child: Padding( padding: const EdgeInsets.all(12.0),
                                            child: Column( crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [ // Header Grup
                                                Row( children: [ Expanded( child: Text( operatorName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), ), ), TextButton.icon( icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), label: Text(isHidden ? 'Tampilkan' : 'Sembunyikan', style: const TextStyle(fontSize: 12)), onPressed: _isSubmitting ? null : () => _toggleGroupVisibility(groupIndex), style: TextButton.styleFrom( foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap, minimumSize: const Size(0, 30) ), ), ], ),
                                                // Detail Grup
                                                if (!isHidden) ...[ const Divider(thickness: 1, height: 20),
                                                  // Dropdown Paket (Tanpa Validator)
                                                  DropdownButtonFormField<String>(
                                                    validator: null, // *** VALIDATOR DIHAPUS dari Dropdown Paket ***
                                                    isExpanded: true, value: group["paket"], hint: const Text("Pilih Paket"),
                                                    decoration: InputDecoration(
                                                      labelText: 'Paket', // Bintang (*) dihapus
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    ),
                                                    items: _paketOptions.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
                                                    onChanged: _isSubmitting ? null : (value) { setState(() { _operatorSurveyGroups[groupIndex]["paket"] = value; }); },
                                                  ), const SizedBox(height: 20),
                                                  // --- List Entri Harga ---
                                                  ListView.builder( shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: entries.length,
                                                    itemBuilder: (context, entryIndex) {
                                                      if (_hargaEntryControllersMap[groupIndex] == null) { _hargaEntryControllersMap[groupIndex] = {}; } if (_hargaEntryControllersMap[groupIndex]![entryIndex] == null) { _hargaEntryControllersMap[groupIndex]![entryIndex] = HargaEntryControllers(); }
                                                      HargaEntryControllers controllers = _hargaEntryControllersMap[groupIndex]![entryIndex]!;
                                                      return Container( padding: const EdgeInsets.all(10).copyWith(bottom: 0), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration( color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200) ),
                                                        child: Column( crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [ Text("   Data Paket Ke-${entryIndex + 1}", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])), const SizedBox(height: 8),
                                                            // Nama Paket dengan Validator Kondisional
                                                            _buildTextField(
                                                              controller: controllers.namaPaketController,
                                                              label: 'Nama Paket *', hint: 'Contoh: Xtra Combo Lite L 3.5GB', readOnly: _isSubmitting,
                                                              validator: (value) {
                                                                // Akses 'group' dari scope itemBuilder luar
                                                                if (group["paket"] != null && group["paket"].isNotEmpty) {
                                                                    if (value == null || value.trim().isEmpty) {
                                                                        return 'Masukkan nama paket';
                                                                    }
                                                                }
                                                                return null; // Tidak validasi jika paket belum dipilih
                                                              }
                                                            ), const SizedBox(height: 16),
                                                            // Harga dengan Validator Kondisional
                                                            _buildTextField(
                                                              controller: controllers.hargaController,
                                                              label: 'Harga Satuan *', prefixText: 'Rp ', hint: 'Contoh: 10000 atau 10.000', readOnly: _isSubmitting,
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                                              inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')) ],
                                                              validator: (value) {
                                                                if (group["paket"] != null && group["paket"].isNotEmpty) {
                                                                    if (value == null || value.trim().isEmpty) return 'Masukkan harga';
                                                                    final numericString = value.replaceAll('.', '');
                                                                    if (numericString.isEmpty || double.tryParse(numericString) == null) return 'Format angka tidak valid';
                                                                    if (double.parse(numericString) <= 0) return 'Harga harus > 0';
                                                                }
                                                                return null; // Tidak validasi jika paket belum dipilih
                                                              }
                                                            ), const SizedBox(height: 16),
                                                            // Jumlah dengan Validator Kondisional
                                                            _buildTextField(
                                                              controller: controllers.jumlahController,
                                                              label: 'Jumlah *', hint: 'Jumlah barang/stok', readOnly: _isSubmitting,
                                                              keyboardType: TextInputType.number,
                                                              inputFormatters: [ FilteringTextInputFormatter.digitsOnly ],
                                                              validator: (value) {
                                                                if (group["paket"] != null && group["paket"].isNotEmpty) {
                                                                    if (value == null || value.trim().isEmpty) return 'Masukkan jumlah';
                                                                    final int? jumlah = int.tryParse(value);
                                                                    if (jumlah == null) return 'Jumlah harus angka';
                                                                    if (jumlah <= 0) return 'Jumlah harus > 0';
                                                                }
                                                                return null; // Tidak validasi jika paket belum dipilih
                                                              }
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
                                  ),
                                  const SizedBox(height: 10),
                                  // Info Batas Max
                                  if (!canAddMoreHarga) Padding( padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), child: Row( children: [ Icon(Icons.info_outline, color: Colors.orange.shade800, size: 16), const SizedBox(width: 8), Expanded( child: Text( "Batas maksimal $_maxHargaEntries data paket telah tercapai.", style: TextStyle(color: Colors.orange.shade900, fontStyle: FontStyle.italic), ), ), ], ), ),
                                  const SizedBox(height: 16),
                                ], // End Survei Harga

                                // --- Keterangan Kunjungan ---
                                _buildTextField(
                                  controller: _keteranganController, label: 'Keterangan Kunjungan *', hint: 'Masukkan detail atau catatan penting selama kunjungan...', maxLines: 5, readOnly: _isSubmitting,
                                  validator: (value) { if (value == null || value.trim().isEmpty) return 'Keterangan kunjungan wajib diisi'; if (value.trim().length < 10) return 'Keterangan terlalu pendek (min. 10 karakter)'; return null; }, // Validator Keterangan
                                ), const SizedBox(height: 24),

                                // --- Tombol Submit ---
                                SizedBox( width: double.infinity,
                                  child: ElevatedButton( onPressed: _isSubmitting ? null : _submitForm, style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.redAccent, disabledBackgroundColor: Colors.grey, disabledForegroundColor: Colors.white70, ),
                                    child: _isSubmitting ? const SizedBox( height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)) )
                                        : const Text( 'Submit Data Survei', style: TextStyle(fontSize: 18, color: Colors.white), ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    // --- Overlay Loading ---
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
} // Akhir dari _HomePageState