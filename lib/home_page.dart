import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  final String username;
  final int userId;
  const HomePage({super.key, required this.username, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Form key untuk validasi form
  final _formKey = GlobalKey<FormState>();
  // Controller untuk field nama dan tanggal
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController();

  // Variabel untuk dropdown outlet
  List<Map<String, dynamic>> _outlets = [];
  String? _selectedOutletId;
  Map<String, dynamic>? _selectedOutlet;

  bool _isLoading = false;

  // Variabel untuk opsi jenis survei
  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Survei branding", "Survei harga"];

  // Untuk opsi "Survei branding": dua gambar
  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // Untuk opsi "Survei harga": daftar entri dinamis
  // Setiap entri: {"kompetitor": "", "keterangan": "", "harga": ""}
  List<Map<String, String>> _surveyHargaEntries = [
    {"kompetitor": "", "keterangan": "", "harga": ""}
  ];
  final List<String> _kompetitorOptions = ["xl", "indosat ooredo", "axis", "smartfren"];

  // Controller untuk keterangan kunjungan (paragraf panjang)
  final TextEditingController _keteranganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set nilai awal nama sesuai parameter user
    _namaController.text = widget.username;
    // Set nilai tanggal otomatis dengan format yyyy-MM-dd
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Ambil data outlet dari API
    _fetchOutlets();
  }

  // Fungsi untuk mengambil data outlet dari API
  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      var url = Uri.parse('http://10.0.2.2/test%20api/getAreas.php?user_id=${widget.userId}');
      var response = await http.get(url);
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print("Decoded data: $data");
        if (data['success'] == true && data['outlets'] is List) {
          setState(() {
            _outlets = List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
            print("Outlets dimuat: ${_outlets.length}");
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Gagal mengambil data outlet')),
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

  // Fungsi untuk mengambil gambar dari kamera atau galeri
  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        onImagePicked(File(pickedFile.path));
      });
    }
  }

  // Fungsi untuk validasi dan submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedOutlet == null) return;

    // Validasi pilihan jenis survei
    if (_selectedBrandinganOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih jenis survei')),
      );
      return;
    }
    // Jika jenis survei adalah "Survei branding", pastikan kedua gambar telah diambil
    if (_selectedBrandinganOption == "Survei branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan ambil kedua gambar branding')),
        );
        return;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      // Pastikan semua entri survei harga telah diisi dengan lengkap
      for (var entry in _surveyHargaEntries) {
        if ((entry["kompetitor"] ?? "").trim().isEmpty ||
            (entry["harga"] ?? "").trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan lengkapi semua entri survei harga')),
          );
          return;
        }
      }
    }

    // Jika validasi berhasil, tampilkan dialog sukses (placeholder)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berhasil!'),
        content: const Text('Data berhasil dikirim (placeholder)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Widget untuk membangun TextField dengan properti yang dapat disesuaikan
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // Widget untuk menampilkan image picker (untuk pengambilan gambar branding)
  Widget _buildImagePicker({
    required String label,
    File? image,
    required VoidCallback onPick,
    required VoidCallback onRetake,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Survei'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          // Background menggunakan gradient merah
          gradient: LinearGradient(
            colors: [
              Color(0xFFF71212),
              Color.fromARGB(255, 229, 14, 14),
            ],
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
                          children: [
                            // Field Nama (otomatis diisi)
                            _buildTextField(
                              controller: _namaController,
                              label: 'Nama',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Silakan masukkan nama Anda';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Dropdown untuk memilih Outlet
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedOutletId,
                              hint: const Text("Pilih Outlet"),
                              decoration: InputDecoration(
                                labelText: 'Pilih Outlet',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: _outlets.map((outlet) {
                                return DropdownMenuItem<String>(
                                  value: outlet['id_outlet'].toString(),
                                  child: Text(outlet['nama_outlet'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedOutletId = value;
                                  if (value != null) {
                                    _selectedOutlet = _outlets.firstWhere(
                                      (outlet) => outlet['id_outlet'].toString() == value,
                                      orElse: () => {},
                                    );
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Silakan pilih outlet';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Tampilkan detail outlet: ID Outlet dan Hari Kunjungan (read-only) jika tersedia
                            if (_selectedOutlet != null && _selectedOutlet!.isNotEmpty) ...[
                              _buildTextField(
                                controller: TextEditingController(text: _selectedOutlet?['id_outlet'].toString() ?? ''),
                                label: 'ID Outlet',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: TextEditingController(text: _selectedOutlet?['hari'] ?? ''),
                                label: 'Hari Kunjungan',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Field Tanggal (otomatis)
                            _buildTextField(
                              controller: _tokoController,
                              label: 'Tanggal',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            // Dropdown untuk memilih jenis survei
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
                                return DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBrandinganOption = value;
                                  // Reset data survei harga atau branding ketika jenis survei berganti
                                  _brandingImageEtalase = null;
                                  _brandingImageTampakDepan = null;
                                  _surveyHargaEntries = [
                                    {"kompetitor": "", "keterangan": "", "harga": ""}
                                  ];
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Silakan pilih jenis survei';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Jika jenis survei adalah "Survei branding"
                            if (_selectedBrandinganOption == "Survei branding") ...[
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
                            // Jika jenis survei adalah "Survei harga"
                            if (_selectedBrandinganOption == "Survei harga") ...[
                              // Daftar entri untuk survei harga secara dinamis
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _surveyHargaEntries.length,
                                itemBuilder: (context, index) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Dropdown untuk memilih kompetitor
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: ((_surveyHargaEntries[index]["kompetitor"] ?? "") as String).trim().isEmpty
                                            ? null
                                            : _surveyHargaEntries[index]["kompetitor"],
                                        hint: const Text("Pilih Kompetitor"),
                                        decoration: InputDecoration(
                                          labelText: 'Kompetitor',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                        items: _kompetitorOptions.map((option) {
                                          return DropdownMenuItem<String>(
                                            value: option,
                                            child: Text(option),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _surveyHargaEntries[index]["kompetitor"] = value ?? "";
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Silakan pilih kompetitor';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // TextField untuk keterangan harga (di atas input harga)
                                      _buildTextField(
                                        controller: TextEditingController(text: _surveyHargaEntries[index]["keterangan"]),
                                        label: 'Keterangan',
                                        onChanged: (val) {
                                          _surveyHargaEntries[index]["keterangan"] = val;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // TextField untuk memasukkan harga
                                      _buildTextField(
                                        controller: TextEditingController(text: _surveyHargaEntries[index]["harga"]),
                                        label: 'Masukkan Harga',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        prefixText: 'Rp.',
                                        onChanged: (val) {
                                          _surveyHargaEntries[index]["harga"] = val;
                                        },
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Silakan masukkan harga';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // Tombol untuk menghapus entri (jika lebih dari 1)
                                      if (_surveyHargaEntries.length > 1)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _surveyHargaEntries.removeAt(index);
                                              });
                                            },
                                            child: const Text("Hapus Data"),
                                          ),
                                        ),
                                      const Divider(height: 32),
                                    ],
                                  );
                                },
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _surveyHargaEntries.add({"kompetitor": "", "keterangan": "", "harga": ""});
                                    });
                                  },
                                  child: const Text("Tambah Data"),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Text box untuk keterangan kunjungan (multiline)
                            _buildTextField(
                              controller: _keteranganController,
                              label: 'Keterangan Kunjungan',
                              hint: 'Masukkan detail kunjungan...',
                              maxLines: 5,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Silakan masukkan keterangan kunjungan';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Tombol Submit untuk mengirim data
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Submit',
                                  style: TextStyle(fontSize: 18, color: Colors.black),
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
