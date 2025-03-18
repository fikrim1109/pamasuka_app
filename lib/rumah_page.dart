import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk input formatter
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class RumahPage extends StatefulWidget {
  final String username;
  final int userId;
  const RumahPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  State<RumahPage> createState() => _RumahPageState();
}

class _RumahPageState extends State<RumahPage> {
  // Controllers untuk field utama
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController();
  // Field outlet input manual
  final TextEditingController _outletController = TextEditingController();
  // Controller untuk ID Outlet (sekarang input manual dengan default value)
  final TextEditingController _idOutletController = TextEditingController();

  bool _isLoading = false;

  // Dropdown untuk Hari Kunjungan (pilihan Senin s.d. Minggu)
  String? _selectedHariKunjungan;
  final List<String> _hariOptions = [
    "Senin",
    "Selasa",
    "Rabu",
    "Kamis",
    "Jumat",
    "Sabtu",
    "Minggu"
  ];

  // Opsi survey tipe (Brandingan)
  String? _selectedBrandinganOption;
  final List<String> _brandinganOptions = ["Surver branding", "Survei harga"];

  // Untuk opsi "Surver branding": 2 gambar
  File? _brandingImageEtalase;
  File? _brandingImageTampakDepan;

  // Untuk opsi "Survei harga": daftar entri dinamis
  // Setiap entri: {"kompetitor": "", "keterangan": "", "harga": ""}
  List<Map<String, String>> _surveyHargaEntries = [
    {"kompetitor": "", "keterangan": "", "harga": ""}
  ];
  final List<String> _kompetitorOptions = ["xl", "indosat ooredo", "axis", "smartfren"];

  // Untuk keterangan kunjungan (paragraf panjang)
  final TextEditingController _keteranganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Nama otomatis dari parameter
    _namaController.text = widget.username;
    // Tanggal otomatis (format: yyyy-MM-dd)
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // ID Outlet default diisi dengan tanggal (misalnya: yyyyMMdd) tetapi bisa diedit
    _idOutletController.text = DateFormat('yyyyMMdd').format(DateTime.now());
    // Hari Kunjungan default diisi dengan nama hari (tetapi user bisa memilih dari dropdown)
    _selectedHariKunjungan = DateFormat('EEEE', 'id_ID').format(DateTime.now());
  }

  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        onImagePicked(File(pickedFile.path));
      });
    }
  }

  Future<void> _submitForm() async {
    // Validasi form dan outlet (harus diisi)
    if (!_formKey.currentState!.validate() ||
        _outletController.text.trim().isEmpty ||
        _idOutletController.text.trim().isEmpty ||
        _selectedHariKunjungan == null) return;

    // Validasi untuk opsi survey
    if (_selectedBrandinganOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select survey type')),
      );
      return;
    }
    if (_selectedBrandinganOption == "Surver branding") {
      if (_brandingImageEtalase == null || _brandingImageTampakDepan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please take both branding images')),
        );
        return;
      }
    } else if (_selectedBrandinganOption == "Survei harga") {
      // Pastikan setiap entri di survey harga diisi lengkap
      for (var entry in _surveyHargaEntries) {
        if ((entry["kompetitor"] ?? "").trim().isEmpty ||
            (entry["harga"] ?? "").trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete all survey harga entries')),
          );
          return;
        }
      }
    }

    // Jika validasi lolos, tampilkan dialog sukses (placeholder)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: const Text('Data submitted successfully (placeholder)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // _buildTextField dengan dukungan onChanged dan input formatter tambahan
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
        hintText: hint,
        prefixText: prefixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // Widget untuk image picker (untuk branding)
  Widget _buildImagePicker({required String label, File? image, required VoidCallback onPick, required VoidCallback onRetake}) {
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
        title: const Text('Survey Form'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          // Menggunakan gradient yang sama seperti sebelumnya (bisa diubah jika diperlukan)
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
                            // Field Nama (otomatis)
                            _buildTextField(
                              controller: _namaController,
                              label: 'Nama',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Text field untuk Outlet (input manual)
                            _buildTextField(
                              controller: _outletController,
                              label: 'Outlet',
                              hint: 'Masukkan nama outlet',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter outlet';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Field ID Outlet (input manual)
                            _buildTextField(
                              controller: _idOutletController,
                              label: 'ID Outlet',
                              hint: 'Masukkan ID Outlet',
                            ),
                            const SizedBox(height: 16),
                            // Field Tanggal (otomatis)
                            _buildTextField(
                              controller: _tokoController,
                              label: 'Tanggal',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            // Dropdown untuk Hari Kunjungan
                            DropdownButtonFormField<String>(
                              value: _selectedHariKunjungan,
                              decoration: InputDecoration(
                                labelText: 'Hari Kunjungan',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: _hariOptions.map((hari) {
                                return DropdownMenuItem<String>(
                                  value: hari,
                                  child: Text(hari),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedHariKunjungan = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a day';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Dropdown Jenis Survey (Brandingan)
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedBrandinganOption,
                              hint: const Text("Pilih Jenis Survey"),
                              decoration: InputDecoration(
                                labelText: 'Jenis Survey',
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
                                  // Reset data survey harga atau branding
                                  _brandingImageEtalase = null;
                                  _brandingImageTampakDepan = null;
                                  _surveyHargaEntries = [
                                    {"kompetitor": "", "keterangan": "", "harga": ""}
                                  ];
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select survey type';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Jika opsi survey adalah "Surver branding"
                            if (_selectedBrandinganOption == "Surver branding") ...[
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
                            // Jika opsi survey adalah "Survei harga"
                            if (_selectedBrandinganOption == "Survei harga") ...[
                              // Daftar entri survey harga dinamis
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _surveyHargaEntries.length,
                                itemBuilder: (context, index) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Dropdown Kompetitor untuk entri ini
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: ((_surveyHargaEntries[index]["kompetitor"] ?? "").trim().isEmpty
                                            ? null
                                            : _surveyHargaEntries[index]["kompetitor"]) as String?,
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
                                            return 'Please select a kompetitor';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // TextField untuk Keterangan (di atas harga)
                                      _buildTextField(
                                        controller: TextEditingController(text: _surveyHargaEntries[index]["keterangan"]),
                                        label: 'Keterangan',
                                        onChanged: (val) {
                                          _surveyHargaEntries[index]["keterangan"] = val;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // TextField untuk Harga dengan prefix "Rp. " dan hanya menerima angka dan titik
                                      _buildTextField(
                                        controller: TextEditingController(text: _surveyHargaEntries[index]["harga"]),
                                        label: 'Masukkan Harga',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        prefixText: 'Rp. ',
                                        onChanged: (val) {
                                          _surveyHargaEntries[index]["harga"] = val;
                                        },
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter harga';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // Tombol hapus data jika lebih dari 1 entri
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
                                  return 'Please enter keterangan kunjungan';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Tombol Submit
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
