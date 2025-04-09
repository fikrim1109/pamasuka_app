import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';

class HomePage extends StatefulWidget {
  final String username;
  final int userId;
  const HomePage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

// --- Helper Class untuk Controller per Entri Harga ---
// Agar tidak kehilangan state saat list rebuild
class HargaEntryControllers {
  final TextEditingController keteranganController;
  final TextEditingController hargaController;

  HargaEntryControllers()
      : keteranganController = TextEditingController(),
        hargaController = TextEditingController();

  void dispose() {
    keteranganController.dispose();
    hargaController.dispose();
  }
}


class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController(); // Keterangan Kunjungan

  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoading = false;

  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // --- Struktur Data Baru untuk Survei Harga ---
  List<Map<String, dynamic>> _operatorSurveyGroups = [];
  // Map<groupIndex, Map<entryIndex, HargaEntryControllers>>
  Map<int, Map<int, HargaEntryControllers>> _hargaEntryControllersMap = {};


  // --- State Variable Baru ---
  int _totalHargaEntriesCount = 0;
  final int _maxHargaEntries = 10; // Batas maksimal

  final List<String> _operatorOptions = ["xl", "indosat ooredo", "axis", "smartfren", "3", "telkomsel"];
  final List<String> _paketOptions = ["Voucher Fisik", "Voucher Perdana"];


  @override
  void initState() {
    super.initState();
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _namaController.text = widget.username;
    _fetchOutlets();
    // Inisialisasi grup survei harga pertama jika dipilih
    // Dihapus dari sini, ditambahkan saat jenis survei dipilih
  }

  @override
  void dispose() {
    _regionController.dispose();
    _branchController.dispose();
    _clusterController.dispose();
    _namaController.dispose();
    _tokoController.dispose();
    _idOutletController.dispose();
    _keteranganController.dispose();
    // Dispose semua controller dinamis
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

   // --- Fungsi untuk menambahkan grup operator baru ---
  void _addOperatorGroup() {
    setState(() {
      int newGroupIndex = _operatorSurveyGroups.length;
      // Tambahkan grup baru
      _operatorSurveyGroups.add({
        "operator": null, // Mulai dengan null
        "paket": null,    // Mulai dengan null
        "entries": [
          {"keterangan": "", "harga": ""} // Satu entri harga awal
        ],
        "isHidden": false // Default tidak tersembunyi
      });

      // Inisialisasi controllers untuk entri pertama di grup baru
      _hargaEntryControllersMap[newGroupIndex] = {
         0: HargaEntryControllers()
      };

      // Increment total count untuk entri awal ini
      _totalHargaEntriesCount++;
      // Jika sudah mencapai batas, jangan tambahkan lagi (meskipun tombol add group tetap ada)
      // Namun, logika penambahan entri akan diblokir.
    });
  }

  // --- Fungsi untuk menambah data (keterangan/harga) dalam satu grup ---
  void _addHargaEntry(int groupIndex) {
     if (_totalHargaEntriesCount >= _maxHargaEntries) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batas maksimal $_maxHargaEntries data harga tercapai')),
       );
       return; // Jangan tambahkan jika sudah mencapai batas
     }

    setState(() {
      List entries = _operatorSurveyGroups[groupIndex]["entries"];
      int newEntryIndex = entries.length;

      entries.add({"keterangan": "", "harga": ""});

      // Inisialisasi controllers untuk entri baru
      if (_hargaEntryControllersMap[groupIndex] == null) {
        _hargaEntryControllersMap[groupIndex] = {};
      }
       _hargaEntryControllersMap[groupIndex]![newEntryIndex] = HargaEntryControllers();

       _totalHargaEntriesCount++; // Increment counter
    });
  }

  // --- Fungsi untuk menghapus data (keterangan/harga) dalam satu grup ---
  void _removeHargaEntry(int groupIndex, int entryIndex) {
    setState(() {
       List entries = _operatorSurveyGroups[groupIndex]["entries"];
       // Jangan hapus jika hanya tersisa satu entri dalam grup
       if (entries.length > 1) {
         entries.removeAt(entryIndex);

         // Hapus dan dispose controller yang sesuai
         _hargaEntryControllersMap[groupIndex]?[entryIndex]?.dispose();
         _hargaEntryControllersMap[groupIndex]?.remove(entryIndex);

        // Update key controller map setelah penghapusan
        Map<int, HargaEntryControllers> updatedControllers = {};
        _hargaEntryControllersMap[groupIndex]?.forEach((oldIndex, controller) {
           int newIndex = (oldIndex > entryIndex) ? oldIndex - 1 : oldIndex;
           updatedControllers[newIndex] = controller;
        });
        _hargaEntryControllersMap[groupIndex] = updatedControllers;


         _totalHargaEntriesCount--; // Decrement counter
       } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Minimal harus ada satu data harga per operator')),
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


  Future<void> _fetchOutlets() async {
    // ... (kode fetch outlet tetap sama) ...
     setState(() {
      _isLoading = true;
    });
    try {
      var url =
          Uri.parse('http://10.0.2.2/test%20api/getAreas.php?user_id=${widget.userId}');
      var response = await http.get(url);
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print("Decoded data: $data");
        if (data['success'] == true && data['outlets'] is List) {
          setState(() {
            _outlets =
                List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
            print("Outlets dimuat: ${_outlets.length}");
            // Jangan set outlet default disini agar user memilih
            // if (_outlets.isNotEmpty) {
            //   _selectedOutlet = _outlets[0];
            //   _idOutletController.text = _selectedOutlet?['id_outlet'].toString() ?? '';
            //   _regionController.text = _selectedOutlet?['region'] ?? '';
            //   _branchController.text = _selectedOutlet?['branch'] ?? '';
            //   _clusterController.text = _selectedOutlet?['cluster'] ?? _selectedOutlet?['area'] ?? '';
            // }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(data['message'] ?? 'Gagal mengambil data outlet')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil data outlet')),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(
      ImageSource source, Function(File) onImagePicked) async {
    // ... (kode pick image tetap sama) ...
     final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        onImagePicked(File(pickedFile.path));
      });
    }
  }

  Future<void> _submitForm() async {
    // --- Update Validasi ---
    if (!_formKey.currentState!.validate() || _selectedOutlet == null) return;

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
       // Validasi survei harga dengan struktur baru
       if (_operatorSurveyGroups.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan tambahkan data survei harga')),
          );
          return;
       }

       for (int i = 0; i < _operatorSurveyGroups.length; i++) {
         var group = _operatorSurveyGroups[i];
         if ((group["operator"] ?? "").isEmpty || (group["paket"] ?? "").isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Silakan pilih Operator dan Paket untuk Grup ${i + 1}')),
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

         for (int j = 0; j < entries.length; j++) {
            var entry = entries[j];
             // Ambil data dari controller jika ada, atau dari map jika controller belum terinisialisasi (seharusnya tidak terjadi)
             String keterangan = _hargaEntryControllersMap[i]?[j]?.keteranganController.text ?? entry["keterangan"] ?? "";
             String harga = _hargaEntryControllersMap[i]?[j]?.hargaController.text ?? entry["harga"] ?? "";

            if (keterangan.trim().isEmpty || harga.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lengkapi Keterangan dan Harga untuk data ke-${j + 1} di Grup ${i + 1}')),
              );
              return;
            }
            // Update map dengan data dari controller sebelum submit (jika perlu)
             _operatorSurveyGroups[i]["entries"][j]["keterangan"] = keterangan;
             _operatorSurveyGroups[i]["entries"][j]["harga"] = harga;
         }
       }
    }

     // --- Log data sebelum dikirim (placeholder) ---
    print("--- Data Form ---");
    print("Outlet: ${_selectedOutlet?['nama_outlet']}");
    print("ID Outlet: ${_idOutletController.text}");
    print("Tanggal: ${_tokoController.text}");
    print("Nama: ${_namaController.text}");
    print("Jenis Survei: $_selectedBrandinganOption");

    if (_selectedBrandinganOption == "Survei branding") {
       print("Foto Etalase: ${_brandingImageEtalase?.path}");
       print("Foto Tampak Depan: ${_brandingImageTampakDepan?.path}");
    } else if (_selectedBrandinganOption == "Survei harga") {
       print("Data Harga:");
       for (var group in _operatorSurveyGroups) {
         print("  Operator: ${group['operator']}, Paket: ${group['paket']}");
         for (var entry in group['entries']) {
           print("    Keterangan: ${entry['keterangan']}, Harga: ${entry['harga']}");
         }
       }
    }
    print("Keterangan Kunjungan: ${_keteranganController.text}");
    print("--- Akhir Data ---");

    // Jika validasi berhasil, tampilkan dialog sukses (placeholder)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berhasil!'),
        content: const Text('Data siap dikirim (implementasi API call disini)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // --- TODO: Implementasi pengiriman data ke API ---
    // Anda perlu mengubah endpoint API dan cara mengirim data
    // sesuai dengan struktur _operatorSurveyGroups jika jenis survei adalah harga.
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
    // ... (kode build text field tetap sama) ...
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    File? image,
    required VoidCallback onPick,
    required VoidCallback onRetake,
  }) {
    // ... (kode build image picker tetap sama) ...
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: image != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(image, fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: onRetake,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 40),
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB6B6), Color(0xFFFF8E8E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start, // Align start
                          children: [
                            // ... (Field Region, Branch, Cluster, Nama, Outlet, ID Outlet, Tanggal tetap sama) ...
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
                              readOnly: true, // Nama dari login, tidak perlu validasi lagi
                              // validator: (value) { ... } // Dihapus
                            ),
                            const SizedBox(height: 16),
                            DropdownSearch<Map<String, dynamic>>(
                              popupProps: const PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(hintText: "Cari outlet..."),
                                ),
                                constraints: BoxConstraints(maxHeight: 300),
                                menuProps: MenuProps( // Tambahkan ini untuk batasi tinggi menu dropdown
                                ),
                              ),
                              items: _outlets,
                              itemAsString: (outlet) => outlet['nama_outlet'] ?? 'Tanpa Nama',
                              selectedItem: _selectedOutlet,
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: "Pilih Outlet",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
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
                                  } else {
                                    // Reset jika tidak ada outlet dipilih
                                    _idOutletController.clear();
                                    _regionController.clear();
                                    _branchController.clear();
                                    _clusterController.clear();
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Silakan pilih outlet';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
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
                            // Dropdown Jenis Survei
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
                                  // Reset data spesifik jenis survei sebelumnya
                                  _brandingImageEtalase = null;
                                  _brandingImageTampakDepan = null;
                                   // Jika memilih Survei Harga, inisialisasi
                                  if (value == "Survei harga") {
                                     _initializeSurveyHarga();
                                  } else {
                                     // Jika memilih jenis lain, bersihkan data survei harga
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
                            if (_selectedBrandinganOption == "Survei branding") ...[
                              // ... (Kode Image Picker Survei Branding tetap sama) ...
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
                            if (_selectedBrandinganOption == "Survei harga") ...[
                              // --- List View untuk Grup Operator ---
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _operatorSurveyGroups.length,
                                itemBuilder: (context, groupIndex) {
                                  var group = _operatorSurveyGroups[groupIndex];
                                  bool isHidden = group["isHidden"];
                                  List entries = group["entries"];

                                  return Card( // Bungkus setiap grup dengan Card
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // --- Header Grup (Operator, Paket, Tombol Hide/Show) ---
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Data Operator ${groupIndex + 1}',
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
                                                tooltip: isHidden ? 'Tampilkan Detail' : 'Sembunyikan Detail',
                                                onPressed: () => _toggleGroupVisibility(groupIndex),
                                              ),
                                              // Tombol hapus grup (opsional, jika diperlukan)
                                              // if (_operatorSurveyGroups.length > 1)
                                              //   IconButton(
                                              //     icon: Icon(Icons.delete_forever, color: Colors.red),
                                              //     tooltip: 'Hapus Grup Operator Ini',
                                              //     onPressed: () => _removeOperatorGroup(groupIndex), // Anda perlu buat fungsi ini
                                              //   ),
                                            ],
                                          ),
                                           if (!isHidden) ...[ // Tampilkan detail jika tidak hidden
                                             const Divider(),
                                             const SizedBox(height: 12),
                                            // Dropdown Operator
                                            DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              value: group["operator"],
                                              hint: const Text("Pilih Operator"),
                                              decoration: InputDecoration(
                                                labelText: 'Operator',
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
                                              validator: (value) {
                                                if (value == null || value.isEmpty) return 'Pilih operator';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            // Dropdown Paket
                                            DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              value: group["paket"],
                                              hint: const Text("Pilih Paket"),
                                              decoration: InputDecoration(
                                                labelText: 'Paket',
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
                                              validator: (value) {
                                                if (value == null || value.isEmpty) return 'Pilih paket';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            // --- List View untuk Entri Harga dalam Grup ---
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: entries.length,
                                              itemBuilder: (context, entryIndex) {
                                                  // Pastikan controller ada
                                                  if (_hargaEntryControllersMap[groupIndex] == null) {
                                                      _hargaEntryControllersMap[groupIndex] = {};
                                                  }
                                                  if (_hargaEntryControllersMap[groupIndex]![entryIndex] == null) {
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex] = HargaEntryControllers();
                                                      // Set initial text if exists in map (misal saat load data)
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex]!.keteranganController.text = entries[entryIndex]["keterangan"] ?? "";
                                                      _hargaEntryControllersMap[groupIndex]![entryIndex]!.hargaController.text = entries[entryIndex]["harga"] ?? "";
                                                  }

                                                  HargaEntryControllers controllers = _hargaEntryControllersMap[groupIndex]![entryIndex]!;


                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 16.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text("Data Harga Ke-${entryIndex + 1}", style: TextStyle(fontWeight: FontWeight.w500)),
                                                      const SizedBox(height: 8),
                                                      _buildTextField(
                                                        controller: controllers.keteranganController,
                                                        label: 'Keterangan',
                                                        onChanged: (val) {
                                                          // Update map saat text berubah (opsional, bisa saat submit saja)
                                                           // entries[entryIndex]["keterangan"] = val;
                                                        },
                                                        // validator dipindahkan ke _submitForm
                                                      ),
                                                      const SizedBox(height: 16),
                                                      _buildTextField(
                                                        controller: controllers.hargaController,
                                                        label: 'Masukkan Harga',
                                                        keyboardType: TextInputType.number,
                                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]' ))], // Hanya angka
                                                        prefixText: 'Rp.',
                                                         onChanged: (val) {
                                                            // Update map saat text berubah (opsional)
                                                            // entries[entryIndex]["harga"] = val;
                                                         },
                                                         // validator dipindahkan ke _submitForm
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Tombol Hapus Entri Harga
                                                      if (entries.length > 1)
                                                        Align(
                                                          alignment: Alignment.centerRight,
                                                          child: TextButton.icon(
                                                            icon: Icon(Icons.delete, size: 18, color: Colors.red.shade700),
                                                            label: Text("Hapus Data Harga", style: TextStyle(color: Colors.red.shade700)),
                                                            onPressed: () => _removeHargaEntry(groupIndex, entryIndex),
                                                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                                          ),
                                                        ),
                                                         if (entryIndex < entries.length - 1) const Divider(height: 24), // Divider antar entri harga
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            // Tombol Tambah Data Harga (dalam grup ini)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                                label: const Text("Tambah Data Harga"),
                                                // Aktifkan hanya jika belum mencapai batas
                                                onPressed: canAddMoreHarga ? () => _addHargaEntry(groupIndex) : null,
                                                style: TextButton.styleFrom(
                                                   foregroundColor: canAddMoreHarga ? Theme.of(context).primaryColor : Colors.grey,
                                                ),
                                              ),
                                            ),
                                           ] else ...[
                                              // Tampilan saat hidden: Tampilkan Operator dan Paket saja
                                              Padding(
                                                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                 child: Text(
                                                     "Operator: ${group['operator'] ?? 'Belum dipilih'} | Paket: ${group['paket'] ?? 'Belum dipilih'}",
                                                     style: TextStyle(color: Colors.grey.shade700),
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
                              Align(
                                 alignment: Alignment.centerLeft, // Posisikan di kiri
                                 child: ElevatedButton.icon(
                                   icon: const Icon(Icons.add_business_outlined),
                                   label: const Text("Tambah Operator Lain"),
                                   onPressed: _addOperatorGroup, // Tombol ini selalu aktif
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.teal, // Warna berbeda
                                     foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                   ),
                                 ),
                              ),
                              const SizedBox(height: 10),
                               // Informasi Batas Maksimal
                              if (!canAddMoreHarga)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                  child: Text(
                                     "Batas maksimal $_maxHargaEntries data harga telah tercapai.",
                                     style: TextStyle(color: Colors.red.shade700, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],

                            // --- Keterangan Kunjungan & Tombol Submit ---
                            _buildTextField(
                              controller: _keteranganController,
                              label: 'Keterangan Kunjungan',
                              hint: 'Masukkan detail kunjungan...',
                              maxLines: 5,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Masukkan keterangan kunjungan';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: Theme.of(context).primaryColor, // Warna utama tema
                                ),
                                child: const Text(
                                  'Submit',
                                  style: TextStyle(fontSize: 18, color: Colors.white), // Teks putih
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