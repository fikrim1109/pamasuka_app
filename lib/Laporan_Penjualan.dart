
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class LaporanPenjualan extends StatefulWidget {
  final String username;
  final int userId;
  final String outletType; // 'pjp' or 'nonpjp'

  const LaporanPenjualan({
    Key? key,
    required this.username,
    required this.userId,
    required this.outletType,
  }) : super(key: key);

  @override
  State<LaporanPenjualan> createState() => _LaporanPenjualanState();
}

class _LaporanPenjualanState extends State<LaporanPenjualan> {
  final _formKey = GlobalKey<FormState>();
  final String _submitApiUrl = "https://tunnel.jato.my.id/test%20api/submit_laporan.php";
  final String _outletApiUrl = "https://tunnel.jato.my.id/test%20api/getAreas.php";

  // Controllers untuk field outlet
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _clusterController = TextEditingController();
  final TextEditingController _idOutletController = TextEditingController();
  final TextEditingController _hariController = TextEditingController();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  // Data outlet
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _isLoadingOutlets = false;
  bool _isSubmitting = false;

  // Entries untuk gambar dan nomor telepon
  List<Map<String, dynamic>> _entries = [];
  List<TextEditingController> _phoneNumberControllers = [];

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fetchOutlets();
  }

  @override
  void dispose() {
    _regionController.dispose();
    _branchController.dispose();
    _clusterController.dispose();
    _idOutletController.dispose();
    _hariController.dispose();
    _tanggalController.dispose();
    _keteranganController.dispose();
    for (var controller in _phoneNumberControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Mengambil data outlet dari API
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
      var url = Uri.parse('$_outletApiUrl?user_id=${widget.userId}&type=${widget.outletType}');
      print("Fetching outlets from: $url");
      var response = await http.get(url).timeout(const Duration(seconds: 20));
      print("Outlet API response status: ${response.statusCode}");
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['success'] == true && data['outlets'] is List) {
          setState(() {
            _outlets = List<Map<String, dynamic>>.from(data['outlets']);
            if (_outlets.isNotEmpty) {
              _selectedOutlet = _outlets[0];
              _idOutletController.text = _selectedOutlet!['id_outlet']?.toString() ?? '';
              _regionController.text = _selectedOutlet!['region'] ?? '';
              _branchController.text = _selectedOutlet!['branch'] ?? '';
              _clusterController.text = _selectedOutlet!['cluster'] ?? '';
              _hariController.text = _selectedOutlet!['hari'] ?? '';
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Gagal mengambil data outlet')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error Server: ${response.statusCode}')),
        );
      }
    } catch (e, stacktrace) {
      print("Error fetching outlets: $e\n$stacktrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoadingOutlets = false;
      });
    }
  }

  // Ekstrak nomor telepon dari gambar menggunakan OCR
Future<String> _extractPhoneNumber(File image) async {
  final inputImage = InputImage.fromFile(image);
  final textRecognizer = TextRecognizer();
  final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
  textRecognizer.close();

  // Extract only digits (0-9) and '+' from recognized text
  String extractedText = '';
  for (TextBlock block in recognizedText.blocks) {
    for (TextLine line in block.lines) {
      // Keep only digits and '+' characters
      String cleanedLine = line.text.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanedLine.isNotEmpty) {
        extractedText += cleanedLine;
      }
    }
  }

  // Apply phone number regex to validate
  RegExp phoneRegex = RegExp(r'(\+62|08)\d{8,12}');
  Match? match = phoneRegex.firstMatch(extractedText);
  return match != null ? match.group(0)! : extractedText.trim();
}

  // Kompresi gambar (dinonaktifkan sementara, kembalikan file asli)
  Future<File> _compressImage(File image) async {
    // Komentar: Kompresi dinonaktifkan sesuai kebutuhan pengguna
    // Jika ingin mengaktifkan kembali, uncomment kode berikut dan pastikan flutter_image_compress diimpor
    /*
    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    File? compressedFile;
    int quality = 70;
    do {
      compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.absolute.path,
        outPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );
      if (compressedFile == null) break;
      final sizeKB = await compressedFile.length() / 1024;
      if (sizeKB <= 300) break;
      quality -= 10;
    } while (quality > 10);
    return compressedFile ?? image;
    */
    return image; // Kembalikan file asli tanpa kompresi
  }

  // Tambah entri baru (gambar + nomor telepon)
  Future<void> _addEntry() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile != null) {
      File image = File(pickedFile.path); // Convert XFile to File
      String phoneNumber = await _extractPhoneNumber(image);
      setState(() {
        _entries.add({'image': image, 'phoneNumber': phoneNumber});
        _phoneNumberControllers.add(TextEditingController(text: phoneNumber));
      });
    }
  }

  // Hapus entri
  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
      _phoneNumberControllers[index].dispose();
      _phoneNumberControllers.removeAt(index);
    });
  }

  // Kirim form ke server
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedOutlet == null || _entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lengkapi outlet dan tambahkan setidaknya satu data')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    var request = http.MultipartRequest('POST', Uri.parse(_submitApiUrl));
    request.fields['user_id'] = widget.userId.toString();
    request.fields['username'] = widget.username;
    request.fields['outlet_id'] = _idOutletController.text;
    request.fields['outlet_nama'] = _selectedOutlet!['nama_outlet'].toString();
    request.fields['region'] = _regionController.text;
    request.fields['branch'] = _branchController.text;
    request.fields['cluster'] = _clusterController.text;
    request.fields['hari'] = _hariController.text;
    request.fields['tanggal_survei'] = _tanggalController.text;
    request.fields['keterangan_kunjungan'] = _keteranganController.text.trim();

    List<String> phoneNumbers = [];
    try {
      for (int i = 0; i < _entries.length; i++) {
        File processedImage = await _compressImage(_entries[i]['image']);
        request.files.add(await http.MultipartFile.fromPath('images[]', processedImage.path));
        phoneNumbers.add(_phoneNumberControllers[i].text.trim());
      }
      request.fields['phone_numbers'] = jsonEncode(phoneNumbers);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showErrorDialog('Error', 'Gagal memproses gambar: $e');
      return;
    }

    try {
      print("Sending request to: $_submitApiUrl");
      print("Fields: ${request.fields}");
      print("Files: ${request.files.length}");
      var response = await request.send().timeout(const Duration(seconds: 60));
      var responseBody = await http.Response.fromStream(response);
      print("Response status: ${responseBody.statusCode}");
      print("Response body: ${responseBody.body}");

      if (responseBody.statusCode == 200) {
        var data = jsonDecode(responseBody.body);
        if (data['success'] == true) {
          _showSuccessDialog(data['message']);
          setState(() {
            _entries.clear();
            _phoneNumberControllers.clear();
            _keteranganController.clear();
          });
        } else {
          _showErrorDialog('Gagal', data['message']);
        }
      } else {
        _showErrorDialog('Error Server', 'Kode: ${responseBody.statusCode}');
      }
    } catch (e, stacktrace) {
      print("Error submitting form: $e\n$stacktrace");
      _showErrorDialog('Error', 'Gagal terhubung ke server: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Dialog Sukses
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Berhasil'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Dialog Error
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Widget untuk setiap entri
  Widget _buildEntry(int index) {
    final entry = _entries[index];
    final controller = _phoneNumberControllers[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(entry['image'], fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Nomor HP *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Masukkan nomor HP';
                if (!RegExp(r'(\+62|08)\d{8,12}').hasMatch(value)) {
                  return 'Nomor HP tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                onPressed: _isSubmitting ? null : () => _removeEntry(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk TextField
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[200] : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F0), Color(0xFFFFE0E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Stack(
                children: [
                  _isLoadingOutlets && _outlets.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 15),
                              Text("Memuat data outlet..."),
                            ],
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dropdown Outlet
                              DropdownSearch<Map<String, dynamic>>(
                                popupProps: PopupProps.menu(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: "Cari nama outlet...",
                                      prefixIcon: Icon(Icons.search),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                items: _outlets,
                                itemAsString: (outlet) => outlet['nama_outlet']?.toString() ?? 'Unknown',
                                selectedItem: _selectedOutlet,
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    labelText: "Pilih Outlet *",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedOutlet = value;
                                    if (value != null) {
                                      _idOutletController.text = value['id_outlet']?.toString() ?? '';
                                      _regionController.text = value['region'] ?? '';
                                      _branchController.text = value['branch'] ?? '';
                                      _clusterController.text = value['cluster'] ?? '';
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
                                validator: (value) => value == null ? 'Pilih outlet' : null,
                                enabled: !_isSubmitting,
                              ),
                              const SizedBox(height: 16),
                              // Field Read-Only
                              _buildTextField(
                                controller: _idOutletController,
                                label: 'ID Outlet',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
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
                                controller: _hariController,
                                label: 'Hari Kunjungan',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _tanggalController,
                                label: 'Tanggal Survei',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              // List Entri
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _entries.length,
                                itemBuilder: (context, index) => _buildEntry(index),
                              ),
                              const SizedBox(height: 16),
                              // Tombol Tambah Data
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _addEntry,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Data'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Keterangan
                              _buildTextField(
                                controller: _keteranganController,
                                label: 'Keterangan Kunjungan *',
                                maxLines: 3,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Masukkan keterangan';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              // Tombol Submit
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isSubmitting
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Submit Laporan', style: TextStyle(color: Colors.white, fontSize: 18)),
                                ),
                              ),
                            ],
                          ),
                        ),
                  // Overlay Loading
                  if (_isSubmitting)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 15),
                              Text(
                                "Mengirim data...",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
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
    );
  }
}
