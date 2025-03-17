import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tokoController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  // List outlet yang diambil dari API.
  List<Map<String, dynamic>> _outlets = [];
  String? _selectedOutletId;
  Map<String, dynamic>? _selectedOutlet;

  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController.text = widget.username;
    _tokoController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fetchOutlets();
  }

  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      var url = Uri.parse('http://10.0.2.2/test%20api/getAreas.php?user_id=${widget.userId}');
      var response = await http.get(url);
      print("Response body: ${response.body}"); // Debug print

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print("Decoded data: $data"); // Debug print

        if (data['success'] == true && data['outlets'] is List) {
          setState(() {
            _outlets = List<Map<String, dynamic>>.from(data['outlets'] as List<dynamic>);
            print("Outlets loaded: ${_outlets.length}"); // Debug print
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
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedImage != null && _selectedOutlet != null) {
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
    } else if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image.')),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            // Dropdown yang menampilkan nama outlet
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedOutletId,
                              hint: const Text("Pilih Outlet"),
                              decoration: InputDecoration(
                                labelText: 'Pilih Outlet',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: _outlets.map((outlet) {
                                // Tampilkan nama outlet sebagai teks,
                                // namun nilai (value) tetap id_outlet (dikonversi ke string)
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
                                  return 'Please select an outlet';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Tampilkan detail outlet (ID Outlet dan Hari Kunjungan)
                            if (_selectedOutlet != null && _selectedOutlet!.isNotEmpty) ...[
                              _buildTextField(
                                controller: TextEditingController(
                                    text: _selectedOutlet?['id_outlet']?.toString() ?? ''),
                                label: 'ID Outlet',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: TextEditingController(
                                    text: _selectedOutlet?['hari'] ?? ''),
                                label: 'Hari Kunjungan',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildTextField(
                              controller: _tokoController,
                              label: 'Tanggal',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _unitController,
                              label: 'Brandingan',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter brandingan';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'Select Image:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.black),
                                  onPressed: () => _pickImage(ImageSource.camera),
                                ),
                              ],
                            ),
                            if (_selectedImage != null)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                height: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
