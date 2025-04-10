import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';

class RumahPage extends StatefulWidget {
  final String username;
  final int userId;
  const RumahPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  State<RumahPage> createState() => _RumahPageState();
}

// --- Helper Class untuk Controller per Entri Harga (DITAMBAH jumlahController) ---
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

  // Controller untuk field yang auto-fill dari Outlet
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController(); // Hari Kunjungan

  // Controller lain
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController(); // Keterangan Kunjungan

  // Data Outlet & Loading State
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoading = false;

  // Opsi Jenis Survei
  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  // Data Survei Branding
  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // Data Survei Harga (Struktur Baru - DITAMBAH 'jumlah')
  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  // Contoh struktur satu grup:
    // {
    //   "operator": "XL",
    //   "paket": "VOUCHER FISIK",
    //   "entries": [
    //     {"nama_paket": "Xtra Combo Lite L", "harga": "50000", "jumlah": "10"}, // nama_paket & jumlah
    //     {"nama_paket": "Xtra Combo Lite M", "harga": "35000", "jumlah": "25"}
    //   ],
    //   "isHidden": false
    // }
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};

  // State untuk Limit Survei Harga
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 15; // Batas maksimal tetap berlaku untuk jumlah BARIS entri

  // Opsi Dropdown Survei Harga (SUDAH DIUBAH SESUAI PERMINTAAN)
  final List<String> _operatorOptions = ["XL", "INDOSAT OOREDO", "AXIS", "SMARTFREN" , "3", "TELKOMSEL"]; // Kapital Semua
  final List<String> _paketOptions = ["VOUCHER FISIK", "PERDANA INTERNET"]; // Voucher Fisik diubah

  @override
  void initState() {
    super.initState();
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _namaController.text = widget.username; // Nama dari login
    _fetchOutlets(); // Ambil data outlet dan auto-select pertama
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
    // Dispose semua controller dinamis survei harga
    _hargaEntryControllersMap.values.forEach((entryMap) {
      entryMap.values.forEach((controllers) {
        controllers.dispose();
      });
    });
    super.dispose();
  }

  // --- Fungsi untuk inisialisasi atau reset survei harga ---
  void _initializeSurveyHarga() {
     setState(() {
       // Reset data lama dan controller
       _operatorSurveyGroups.clear();
       _hargaEntryControllersMap.values.forEach((entryMap) {
        entryMap.values.forEach((controllers) => controllers.dispose());
       });
       _hargaEntryControllersMap.clear();
       _totalHargaEntriesCount = 0; // Reset counter

       // Tambahkan grup pertama secara otomatis
       _addOperatorGroup();
     });
  }

   // --- Fungsi untuk menambahkan grup operator baru (DITAMBAH 'jumlah') ---
  void _addOperatorGroup() {
    setState(() {
      int newGroupIndex = _operatorSurveyGroups.length;
      _operatorSurveyGroups.add({
        "operator": null,
        "paket": null,
        "entries": [{"nama_paket": "", "harga": "", "jumlah": ""}], // Tambah jumlah
        "isHidden": false
      });

      _hargaEntryControllersMap[newGroupIndex] = { 0: HargaEntryControllers() };
      _totalHargaEntriesCount++;
    });
  }

  // --- Fungsi untuk menambah data (entri) dalam satu grup (DITAMBAH 'jumlah') ---
  void _addHargaEntry(int groupIndex) {
     if (_totalHargaEntriesCount >= _maxHargaEntries) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batas maksimal $_maxHargaEntries data paket tercapai')),
       );
       return;
     }

    setState(() {
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;
      entries.add({"nama_paket": "", "harga": "", "jumlah": ""}); // Tambah jumlah

      if (_hargaEntryControllersMap[groupIndex] == null) {
        _hargaEntryControllersMap[groupIndex] = {};
      }
       _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();
       _totalHargaEntriesCount++;
    });
  }

  // --- Fungsi untuk menghapus data (entri) dalam satu grup ---
  void _removeHargaEntry(int groupIndex, int entryIndex) {
    setState(() {
       List entries = _operatorSurveyGroups[groupIndex]["entries"];
       if (entries.length > 1) {
         entries.removeAt(entryIndex);
         // Dispose controller (termasuk jumlahController)
         _hargaEntryControllersMap[groupIndex]?[entryIndex]?.dispose();
         _hargaEntryControllersMap[groupIndex]?.remove(entryIndex);

        // Update key controller map setelah penghapusan
        Map<int, HargaEntryControllers> updatedControllers = {};
        _hargaEntryControllersMap[groupIndex]?.forEach((oldIndex, controller) {
           int newIndex = (oldIndex > entryIndex) ? oldIndex - 1 : oldIndex;
           updatedControllers[newIndex] = controller;
        });
        _hargaEntryControllersMap[groupIndex] = updatedControllers;

         _totalHargaEntriesCount--; // Kurangi counter
       } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Minimal harus ada satu data paket per operator')),
          );
       }
    });
  }

  // --- Fungsi untuk toggle hide/show grup ---
  void _toggleGroupVisibility(int groupIndex) {
    setState(() {
      _operatorSurveyGroups[groupIndex]["isHidden"] = !_operatorSurveyGroups[groupIndex]["isHidden"];
    });
  }

  // Fungsi untuk mengambil data outlet dari API (Tetap sama)
  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoading = true;
       _outlets = [];
       _selectedOutlet = null;
       _idOutletController.clear();
       _regionController.clear();
       _branchController.clear();
       _clusterController.clear();
       _hariController.clear();
    });
    try {
      var url = Uri.parse(
          'http://10.0.2.2/test%20api/getAreas.php?user_id=${widget.userId}'); // Ganti dengan URL API Anda
      var response = await http.get(url).timeout(const Duration(seconds: 15));
      print("Outlet API Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['success'] == true && data['outlets'] is List) {
          final List<Map<String, dynamic>> fetchedOutlets =
              List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
          print("Outlets dimuat: ${fetchedOutlets.length}");

          Map<String, dynamic>? initialOutlet;
          String initialId = '';
          String initialRegion = '';
          String initialBranch = '';
          String initialCluster = '';
          String initialHari = '';

          if (fetchedOutlets.isNotEmpty) {
            initialOutlet = fetchedOutlets[0];
            initialId = initialOutlet['id_outlet']?.toString() ?? '';
            initialRegion = initialOutlet['region'] ?? '';
            initialBranch = initialOutlet['branch'] ?? '';
            initialCluster = initialOutlet['cluster'] ?? initialOutlet['area'] ?? '';
            initialHari = initialOutlet['hari'] ?? '';
            print("Outlet pertama dipilih: ${initialOutlet['nama_outlet']}");
          } else {
             print("Tidak ada data outlet ditemukan.");
          }

          setState(() {
            _outlets = fetchedOutlets;
            _selectedOutlet = initialOutlet;
            _idOutletController.text = initialId;
            _regionController.text = initialRegion;
            _branchController.text = initialBranch;
            _clusterController.text = initialCluster;
            _hariController.text = initialHari;
          });

        } else {
          print("Gagal mengambil data outlet: ${data['message'] ?? 'Format data tidak sesuai'}");
           if (mounted) setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(data['message'] ?? 'Gagal mengambil data outlet: Format tidak sesuai')),
          );
        }
      } else {
        print("Gagal mengambil data outlet: Server error ${response.statusCode}");
         if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data outlet (Error: ${response.statusCode})')),
        );
      }
    } catch (e) {
       if (mounted) setState(() {});
      print("Error fetching outlets: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan jaringan: $e')),
      );
    } finally {
       if (mounted) {
           setState(() {
             _isLoading = false;
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

  // Fungsi untuk validasi dan submit form (DITAMBAH VALIDASI 'jumlah')
  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Harap periksa kembali data yang belum terisi')),
       );
      return;
    }
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

    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan ambil kedua gambar branding')),
        );
        return;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
       if (_operatorSurveyGroups.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan tambahkan minimal satu data survei harga')),
          );
          return;
       }

       for (int i = 0; i < _operatorSurveyGroups.length; i++) {
         var group = _operatorSurveyGroups[i];
         if ((group["operator"] == null || group["operator"].isEmpty) ||
             (group["paket"] == null || group["paket"].isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lengkapi Operator dan Paket untuk Grup ${i + 1}')),
            );
            return;
         }

         List entries = group["entries"];
          if (entries.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Grup ${i + 1} tidak memiliki data harga')),
              );
              return;
          }

         // Validasi Entri dalam Grup
         for (int j = 0; j < entries.length; j++) {
            HargaEntryControllers? controllers = _hargaEntryControllersMap[i]?[j];
            if (controllers == null) {
                 print("ERROR: Controller tidak ditemukan untuk Grup $i, Entri $j saat submit");
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Terjadi error internal pada data Grup ${i+1}')),
                 );
                 return;
            }

            String namaPaket = controllers.namaPaketController.text.trim(); // Ganti nama
            String hargaInput = controllers.hargaController.text;
            String jumlahInput = controllers.jumlahController.text.trim(); // Ambil jumlah
            String hargaNumerikBersih = hargaInput.replaceAll('.', '');

            // Validasi Nama Paket
            if (namaPaket.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lengkapi Nama Paket data ke-${j + 1} di Grup ${i + 1}')),
              );
              return;
            }
            // Validasi Harga
            if (hargaNumerikBersih.isEmpty || double.tryParse(hargaNumerikBersih) == null || double.parse(hargaNumerikBersih) <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Masukkan Harga valid (> 0) data ke-${j + 1} di Grup ${i + 1}')),
                  );
                  return;
            }
             // Validasi Jumlah (Wajib diisi, angka > 0)
            if (jumlahInput.isEmpty || int.tryParse(jumlahInput) == null || int.parse(jumlahInput) <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Masukkan Jumlah valid (> 0) data ke-${j + 1} di Grup ${i + 1}')),
              );
              return;
            }

            // Update map dengan data bersih *sebelum* dikirim
             _operatorSurveyGroups[i]["entries"][j]["nama_paket"] = namaPaket; // Ganti nama key
             _operatorSurveyGroups[i]["entries"][j]["harga"] = hargaNumerikBersih;
             _operatorSurveyGroups[i]["entries"][j]["jumlah"] = jumlahInput; // Simpan jumlah
         }
       }
    }

     // --- Data Siap Kirim (DITAMBAH 'jumlah') ---
    print("--- Data Form Siap Dikirim ---");
    print("User ID: ${widget.userId}");
    print("Username: ${widget.username}");
    print("Outlet ID: ${_idOutletController.text}");
    print("Outlet Nama: ${_selectedOutlet?['nama_outlet'] ?? 'N/A'}");
    print("Region: ${_regionController.text}");
    print("Branch: ${_branchController.text}");
    print("Cluster: ${_clusterController.text}");
    print("Hari: ${_hariController.text}");
    print("Tanggal: ${_tokoController.text}");
    print("Jenis Survei: $_selectedBrandinganOption");

    if (_selectedBrandinganOption == "Survei branding") {
       print("Foto Etalase Path: ${_brandingImageEtalase?.path ?? 'N/A'}");
       print("Foto Tampak Depan Path: ${_brandingImageTampakDepan?.path ?? 'N/A'}");
    } else if (_selectedBrandinganOption == "Survei harga") {
       print("Data Harga (JSON):");
       print(jsonEncode(_operatorSurveyGroups)); // Print struktur lengkap
    }
    print("Keterangan Kunjungan: ${_keteranganController.text.trim()}");
    print("--- Akhir Data ---");

    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) { /* ... Dialog Loading ... */
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Mengirim data..."),
              ],
            ),
          ),
        );
      },
    );

    // --- TODO: Implementasi pengiriman data ke API ---
    await Future.delayed(const Duration(seconds: 2)); // Placeholder

    if (mounted) Navigator.pop(context); // Tutup loading

    // Tampilkan hasil
    if (mounted) {
         showDialog(
          context: context,
          builder: (context) => AlertDialog( /* ... Dialog Sukses ... */
            title: const Text('Berhasil'),
            content: const Text('Data survei berhasil dikirim.'),
            actions: [
              TextButton(
                onPressed: () {
                   Navigator.pop(context);
                   // Optional: Reset form
                   // _resetForm();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
    }
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
      validator: validator,
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
  }) {
     /* ... Kode _buildImagePicker ... */
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
            color: Colors.grey[100],
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
                           tooltip: "Ambil Ulang",
                          onPressed: onRetake,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                    tooltip: "Ambil Gambar",
                    onPressed: onPick,
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
          gradient: LinearGradient( /* ... Gradient ... */
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
                child: _isLoading && _outlets.isEmpty
                    ? const Center( /* ... Loading Indicator ... */
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
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Fields Read Only: Region, Branch, Cluster, Nama ---
                            /* ... Kode _buildTextField untuk Region, Branch, Cluster, Nama ... */
                             _buildTextField(
                              controller: _regionController,
                              label: 'Region',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _branchController,
                              label: 'Branch',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _clusterController,
                              label: 'Cluster',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _namaController,
                              label: 'Nama',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(controller: _hariController, 
                             label: 'Hari',
                             readOnly: true,
                            ),
                            const SizedBox(height: 16),

                            // --- Dropdown Outlet ---
                            /* ... Kode DropdownSearch Outlet ... */
                             DropdownSearch<Map<String, dynamic>>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: const TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: "Cari nama outlet...",
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder()
                                   ),
                                ),
                                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                                emptyBuilder: (context, searchEntry) => const Center(child: Text("Outlet tidak ditemukan")),
                                errorBuilder: (context, searchEntry, exception) => const Center(child: Text("Gagal memuat outlet")),
                                loadingBuilder: (context, searchEntry) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                menuProps: const MenuProps(),
                              ),
                              items: _outlets,
                              itemAsString: (outlet) => outlet['nama_outlet'] ?? 'Tanpa Nama',
                              selectedItem: _selectedOutlet,
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: "Pilih Outlet",
                                  hintText: _outlets.isEmpty ? "Memuat atau tidak ada data" : "Pilih outlet lainnya...",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    _regionController.clear();
                                    _branchController.clear();
                                    _clusterController.clear();
                                    _hariController.clear();
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Silakan pilih outlet';
                                }
                                return null;
                              },
                              enabled: !_isLoading && _outlets.isNotEmpty,
                            ),
                            const SizedBox(height: 16),

                            // --- Fields Read Only: ID Outlet, Tanggal ---
                            /* ... Kode _buildTextField untuk ID Outlet, Tanggal ... */
                             _buildTextField(
                              controller: _idOutletController,
                              label: 'ID Outlet',
                              readOnly: true,
                            ),

                            const SizedBox(height: 16),
                             _buildTextField(
                              controller: _tokoController,
                              label: 'Tanggal',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),

                            // --- Dropdown Jenis Survei ---
                            /* ... Kode DropdownButtonFormField Jenis Survei ... */
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedBrandinganOption,
                              hint: const Text("Pilih Jenis Survei"),
                              decoration: InputDecoration(
                                labelText: 'Jenis Survei',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: _brandinganOptions.map((option) {
                                return DropdownMenuItem<String>(value: option, child: Text(option));
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBrandinganOption = value;
                                  _brandingImageEtalase = null;
                                  _brandingImageTampakDepan = null;
                                  if (value == "Survei harga") {
                                     _initializeSurveyHarga();
                                  } else {
                                     _operatorSurveyGroups.clear();
                                     _hargaEntryControllersMap.values.forEach((map) => map.values.forEach((c) => c.dispose()));
                                     _hargaEntryControllersMap.clear();
                                     _totalHargaEntriesCount = 0;
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Silakan pilih jenis survei';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // --- Konten Dinamis Berdasarkan Jenis Survei ---

                            // === SURVEI BRANDING ===
                            if (_selectedBrandinganOption == "Survei branding") ...[
                               /* ... Kode _buildImagePicker Etalase & Tampak Depan ... */
                                _buildImagePicker(
                                label: "Foto Etalase",
                                image: _brandingImageEtalase,
                                onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file),
                                onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageEtalase = file),
                              ),
                              const SizedBox(height: 16),
                              _buildImagePicker(
                                label: "Foto Tampak Depan",
                                image: _brandingImageTampakDepan,
                                onPick: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file),
                                onRetake: () => _pickImage(ImageSource.camera, (file) => _brandingImageTampakDepan = file),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // === SURVEI HARGA (DENGAN PERUBAHAN LABEL & FIELD JUMLAH) ===
                            if (_selectedBrandinganOption == "Survei harga") ...[
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _operatorSurveyGroups.length,
                                itemBuilder: (context, groupIndex) {
                                  var group = _operatorSurveyGroups[groupIndex];
                                  bool isHidden = group["isHidden"];
                                  List entries = group["entries"];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder( /* ... Shape ... */
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade300)
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header Grup (Judul, Tombol Hide/Show)
                                           /* ... Kode Row Header Grup ... */
                                            Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Data Operator ${groupIndex + 1}',
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              TextButton.icon(
                                                 icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                                 label: Text(isHidden ? 'Tampilkan' : 'Sembunyikan', style: const TextStyle(fontSize: 12)),
                                                 onPressed: () => _toggleGroupVisibility(groupIndex),
                                                 style: TextButton.styleFrom( /* ... Style ... */
                                                   foregroundColor: Colors.grey[600],
                                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                   minimumSize: const Size(0, 30)
                                                 ),
                                              ),
                                            ],
                                          ),
                                          // Detail Grup (jika tidak hidden)
                                           if (!isHidden) ...[
                                             const Divider(thickness: 1),
                                             const SizedBox(height: 12),
                                            // Dropdown Operator & Paket
                                             /* ... Kode Dropdown Operator & Paket (VOUCHER FISIK kapital)... */
                                            DropdownButtonFormField<String>( // Operator
                                              isExpanded: true,
                                              value: group["operator"],
                                              hint: const Text("Pilih Operator"),
                                              decoration: InputDecoration( /* ... Decoration ... */
                                                labelText: 'Operator *',
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                              items: _operatorOptions.map((option) {
                                                return DropdownMenuItem<String>(value: option, child: Text(option));
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _operatorSurveyGroups[groupIndex]["operator"] = value;
                                                });
                                              },
                                              validator: (value) { /* ... Validator ... */
                                                if (value == null || value.isEmpty) return 'Pilih operator';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>( // Paket
                                              isExpanded: true,
                                              value: group["paket"],
                                              hint: const Text("Pilih Paket"),
                                              decoration: InputDecoration( /* ... Decoration ... */
                                                labelText: 'Paket *',
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                              items: _paketOptions.map((option) {
                                                return DropdownMenuItem<String>(value: option, child: Text(option));
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _operatorSurveyGroups[groupIndex]["paket"] = value;
                                                });
                                              },
                                              validator: (value) { /* ... Validator ... */
                                                if (value == null || value.isEmpty) return 'Pilih paket';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 20),

                                            // --- List View untuk Entri Harga/Paket/Jumlah ---
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: entries.length,
                                              itemBuilder: (context, entryIndex) {
                                                  // Ambil controller
                                                  if (_hargaEntryControllersMap[groupIndex] == null) {
                                                      _hargaEntryControllersMap[groupIndex] = {};
                                                  }
                                                  if (_hargaEntryControllersMap[groupIndex]![entryIndex] == null) {
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex] = HargaEntryControllers();
                                                      // Set nilai awal jika ada (misal dari data tersimpan)
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex]!.namaPaketController.text = entries[entryIndex]["nama_paket"] ?? "";
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex]!.hargaController.text = entries[entryIndex]["harga"] ?? "";
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex]!.jumlahController.text = entries[entryIndex]["jumlah"] ?? "";
                                                  }
                                                  HargaEntryControllers controllers = _hargaEntryControllersMap[groupIndex]![entryIndex]!;

                                                return Container(
                                                   padding: const EdgeInsets.all(10).copyWith(bottom: 0),
                                                   margin: const EdgeInsets.only(bottom: 10),
                                                   decoration: BoxDecoration( /* ... Decoration ... */
                                                       color: Colors.grey[50],
                                                       borderRadius: BorderRadius.circular(8),
                                                       border: Border.all(color: Colors.grey.shade200)
                                                   ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text("   Data Paket Ke-${entryIndex + 1}", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                                                      const SizedBox(height: 8),

                                                      // Field Nama Paket (Label diubah)
                                                      _buildTextField(
                                                        controller: controllers.namaPaketController, // Ganti controller
                                                        label: 'Nama Paket *', // Label diubah
                                                        hint: 'Contoh: Telkomsel Prabayar 3.5GB',
                                                        validator: (value) { // Validasi dasar bisa di sini
                                                           if (value == null || value.trim().isEmpty) {
                                                             return 'Masukkan nama paket';
                                                           }
                                                           return null;
                                                        },
                                                      ),
                                                      const SizedBox(height: 16),

                                                      // Field Harga
                                                      _buildTextField(
                                                        controller: controllers.hargaController,
                                                        label: 'Harga Satuan *',
                                                        prefixText: 'Rp ',
                                                        hint: 'Contoh: 10.000',
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')) ],
                                                         validator: (value) { /* ... Validator Harga ... */
                                                          if (value == null || value.trim().isEmpty) return 'Masukkan harga';
                                                          final numericString = value.replaceAll('.', '');
                                                          if (numericString.isEmpty || double.tryParse(numericString) == null) return 'Format angka tidak valid';
                                                          if (value.split('.').length > 2) return 'Format titik tidak valid';
                                                           if (double.parse(numericString) <= 0) return 'Harga harus > 0';
                                                          return null;
                                                        },
                                                      ),
                                                      const SizedBox(height: 16), // Jarak

                                                      // Field Jumlah (BARU)
                                                      _buildTextField(
                                                        controller: controllers.jumlahController, // Controller baru
                                                        label: 'Jumlah *',
                                                        hint: 'Jumlah barang/stok',
                                                        keyboardType: TextInputType.number, // Keyboard angka saja
                                                        inputFormatters: [ FilteringTextInputFormatter.digitsOnly ], // Hanya izinkan digit
                                                         validator: (value) {
                                                           if (value == null || value.trim().isEmpty) {
                                                             return 'Masukkan jumlah';
                                                           }
                                                           final int? jumlah = int.tryParse(value);
                                                           if (jumlah == null) {
                                                              return 'Jumlah harus angka'; // Seharusnya tidak terjadi karena digitsOnly
                                                           }
                                                           if (jumlah <= 0) {
                                                               return 'Jumlah harus > 0';
                                                           }
                                                           return null;
                                                         },
                                                      ),
                                                      const SizedBox(height: 0), // Kurangi jarak bawah sebelum tombol hapus

                                                      // Tombol Hapus Entri
                                                      Align( /* ... Tombol Hapus ... */
                                                        alignment: Alignment.centerRight,
                                                        child: (entries.length > 1)
                                                          ? TextButton.icon(
                                                              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                                              label: Text("Hapus", style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                                                              onPressed: () => _removeHargaEntry(groupIndex, entryIndex),
                                                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5), minimumSize: const Size(0, 25)),
                                                            )
                                                          : const SizedBox(height: 25),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            // Tombol Tambah Data Harga/Paket
                                            Align( /* ... Tombol Tambah Data ... */
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                                label: const Text("Tambah Data Paket"), // Ganti Teks
                                                onPressed: canAddMoreHarga ? () => _addHargaEntry(groupIndex) : null,
                                                style: TextButton.styleFrom( /* ... Style ... */
                                                   foregroundColor: canAddMoreHarga ? Theme.of(context).primaryColor : Colors.grey,
                                                ),
                                              ),
                                            ),
                                           ] else ...[
                                              // Tampilan saat hidden
                                              Padding( /* ... Tampilan Hidden ... */
                                                 padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                                 child: Text(
                                                     "Operator: ${group['operator'] ?? '(...)'} | Paket: ${group['paket'] ?? '(...)'}",
                                                     style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                                     overflow: TextOverflow.ellipsis,
                                                 ),
                                              ),
                                           ]
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              // Tombol Tambah Operator Lain
                              Align( /* ... Tombol Tambah Operator ... */
                                 alignment: Alignment.centerLeft,
                                 child: ElevatedButton.icon(
                                   icon: const Icon(Icons.add_business_outlined),
                                   label: const Text("Tambah Operator Lain"),
                                   onPressed: _addOperatorGroup,
                                   style: ElevatedButton.styleFrom( /* ... Style ... */
                                     backgroundColor: Colors.teal,
                                     foregroundColor: Colors.white,
                                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   ),
                                 ),
                              ),
                              const SizedBox(height: 10),
                               // Informasi Batas Maksimal
                              if (!canAddMoreHarga)
                                Padding( /* ... Info Batas Max ... */
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                  child: Row(
                                      children: [
                                         Icon(Icons.info_outline, color: Colors.orange.shade800, size: 16),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: Text(
                                              "Batas maksimal $_maxHargaEntries data paket telah tercapai.",
                                              style: TextStyle(color: Colors.orange.shade900, fontStyle: FontStyle.italic),
                                           ),
                                         ),
                                      ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ], // End Survei Harga Section

                            // --- Keterangan Kunjungan ---
                            /* ... Kode _buildTextField Keterangan Kunjungan ... */
                            _buildTextField(
                              controller: _keteranganController,
                              label: 'Keterangan Kunjungan *',
                              hint: 'Masukkan detail atau catatan penting selama kunjungan...',
                              maxLines: 5,
                              validator: (value) { /* ... Validator Keterangan ... */
                                if (value == null || value.trim().isEmpty) return 'Keterangan kunjungan wajib diisi';
                                if (value.trim().length < 10) return 'Keterangan terlalu pendek (min. 10 karakter)';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // --- Tombol Submit ---
                            /* ... Kode Tombol Submit ... */
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom( /* ... Style ... */
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: Colors.redAccent,
                                ),
                                child: const Text(
                                  'Submit Data Survei',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
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
      ),
    );
  }
}