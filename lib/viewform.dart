import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// Make sure initializeDateFormatting is called in main.dart!

class ViewFormPage extends StatefulWidget {
  final String outletName;
  final int userId;

  const ViewFormPage({Key? key, required this.outletName, required this.userId})
      : super(key: key);

  @override
  _ViewFormPageState createState() => _ViewFormPageState();
}

class _ViewFormPageState extends State<ViewFormPage> {
  List<Map<String, dynamic>> _forms = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  final PageController _pageController = PageController();

  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _fetchForms();
    // DO NOT call initializeDateFormatting here if called in main()
  }

  Future<void> _fetchForms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse(
        'https://tunnel.jato.my.id/test%20api/get_survey_forms.php?outlet_nama=${Uri.encodeComponent(widget.outletName)}&user_id=${widget.userId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(response.body);
        } on FormatException catch (e) {
          print('Raw Response Body: ${response.body}');
          throw Exception('Format respons tidak valid dari server. ${e.message}');
        }

        if (data is Map && data['success'] == true) {
          final List<dynamic> rawForms = data['forms'] ?? [];
          setState(() {
            _forms = List<Map<String, dynamic>>.from(rawForms);
            _forms.sort((a, b) {
              try {
                 // Handle potential null dates during sorting
                 final dateAString = a['tanggal_survei']?.toString();
                 final dateBString = b['tanggal_survei']?.toString();

                 if (dateAString == null && dateBString == null) return 0;
                 if (dateAString == null) return 1; // Nulls go last
                 if (dateBString == null) return -1; // Nulls go last

                 DateTime dateA = DateTime.parse(dateAString);
                 DateTime dateB = DateTime.parse(dateBString);
                 return dateB.compareTo(dateA); // Sort descending
              } catch (e) {
                print("Error sorting dates: $e. Values: ${a['tanggal_survei']}, ${b['tanggal_survei']}");
                return 0; // Keep original order on error
              }
            });
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data form.');
        }
      } else {
        print('Server Error Response Body: ${response.body}');
        throw Exception('Kesalahan server: ${response.statusCode}.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan: ${e.toString()}";
        _isLoading = false;
      });
      print("Error fetching forms: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forms: ${widget.outletName}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

    Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            color: Colors.white.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    '$_errorMessage',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _fetchForms,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_forms.isEmpty) {
      return const Center(
          child: Text(
        'Tidak ada data survei ditemukan\nuntuk outlet ini.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.white70),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    color: _currentIndex > 0 ? primaryColor : Colors.grey,
                    tooltip: 'Previous Form',
                    onPressed: _currentIndex > 0
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                  Text(
                    'Form ${_currentIndex + 1} of ${_forms.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: 'Next Form',
                    color: _currentIndex < _forms.length - 1 ? primaryColor : Colors.grey,
                    onPressed: _currentIndex < _forms.length - 1
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _forms.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final form = _forms[index];
              return _buildFormDetailsCard(form);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormDetailsCard(Map<String, dynamic> form) {
    String formattedDate = 'Tanggal tidak valid';
    // Get raw date, might be null or a string 'YYYY-MM-DD'
    final rawDate = form['tanggal_survei'];

    // Check if rawDate is null or an empty string
    if (rawDate == null || rawDate.toString().isEmpty) {
      formattedDate = 'Tanggal tidak tersedia';
      print('Tanggal survei null atau kosong untuk form: $form');
    } else {
      try {
        // Ensure it's a string and trim whitespace
        final dateString = rawDate.toString().trim();
        print('Raw tanggal_survei string: $dateString');

        // **Optional but safer: Check format before parsing**
        // This expects exactly YYYY-MM-DD. Adjust regex if needed.
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
          final parsedDate = DateTime.parse(dateString);
          // Formatting should now work because initializeDateFormatting was called in main()
          formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(parsedDate);
          print('Formatted date: $formattedDate');
        } else {
           // Handle unexpected format from API if it ever happens
           formattedDate = 'Format Tanggal Tdk Dikenal: $dateString';
           print('Unexpected date format received: $dateString');
        }
      } catch (e) {
        // Catch potential DateTime.parse errors even if format seemed okay
        formattedDate = 'Tanggal: $rawDate';
        print('Error parsing date: $e. Raw value: $rawDate');
        // Note: The LocaleDataException should NOT happen here anymore if main() is set up correctly.
        // This catch block handles other potential parsing issues.
      }
    }

    // Rest of your card building logic...
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start, // Align top
                children: [
                  Flexible(
                    child: Text(
                      formattedDate, // Use the processed formattedDate
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8), // Add spacing
                  Chip(
                    label: Text(
                      form['jenis_survei'] ?? 'Tipe Tidak Diketahui',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: primaryColor.withOpacity(0.8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailItem(Icons.notes, 'Keterangan Kunjungan:', form['keterangan_kunjungan']?.toString() ?? 'Tidak ada keterangan'),
              const SizedBox(height: 16),
              if (form['jenis_survei'] == 'Survei branding') ...[
                _buildImageSection('Foto Etalase', form['foto_etalase_url']?.toString()),
                const SizedBox(height: 16),
                _buildImageSection('Foto Depan', form['foto_depan_url']?.toString()),
              ] else if (form['jenis_survei'] == 'Survei harga') ...[
                _buildPriceDataSection(form['data_harga']?.toString()), // Pass as string
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding( // Add padding for better spacing if text wraps
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor.withOpacity(0.7), size: 20),
          const SizedBox(width: 10), // Increased spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String label, String? url) {
    // Basic URL validation
    bool isValidUrl = url != null && Uri.tryParse(url)?.isAbsolute == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints( // Constrain height
            maxHeight: 250,
          ),
          width: double.infinity, // Take full width
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200], // Background color
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isValidUrl
                ? Image.network(
                    url,
                    // height: 200, // Height is controlled by ConstrainedBox now
                    width: double.infinity,
                    fit: BoxFit.contain, // Use contain to see the whole image
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center( // Center progress indicator
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: primaryColor,
                          strokeWidth: 2.0, // Make thinner
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image from $url: $error');
                      return const Center( // Center error message
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.redAccent, size: 40),
                            SizedBox(height: 8),
                            Text('Gagal memuat gambar', textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      );
                    },
                  )
                : const Center( // Center placeholder
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text('Gambar tidak tersedia', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDataSection(String? dataHargaString) {
     // Check for null, empty, or literal "null" string
    if (dataHargaString == null || dataHargaString.isEmpty || dataHargaString.trim().toLowerCase() == 'null' || dataHargaString.trim() == '[]') {
      return _buildDetailItem(Icons.price_check, 'Data Harga:', 'Data harga tidak tersedia atau kosong.');
    }

    List<dynamic> parsedData;
    try {
      // Decode the JSON string which contains a list of operator data maps
      parsedData = json.decode(dataHargaString);
      if (parsedData is! List || parsedData.isEmpty) { // Ensure it's a non-empty list
          return _buildDetailItem(Icons.price_check, 'Data Harga:', 'Data harga kosong atau format salah.');
      }
    } catch (e) {
      print("Error decoding data_harga JSON: $e");
      print("Invalid data_harga string: $dataHargaString");
      return _buildDetailItem(Icons.error_outline, 'Data Harga:', 'Format data harga tidak valid.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use _buildDetailItem style for consistency
         Padding(
           padding: const EdgeInsets.symmetric(vertical: 4.0),
           child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Icon(Icons.price_change_outlined, color: primaryColor.withOpacity(0.7), size: 20),
               const SizedBox(width: 10),
               const Text('Data Harga:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
             ],
           ),
         ),
        const SizedBox(height: 8),
        // Iterate through the list of operator data
        ...parsedData.map((operatorData) {
          // Defensive check if operatorData is a map
          if (operatorData is! Map<String, dynamic>) {
            return const SizedBox.shrink(); // Skip if not a map
          }

          final String operatorName = operatorData['operator']?.toString() ?? 'Operator Tdk Dikenal';
          final String packageType = operatorData['paket']?.toString() ?? 'Paket Tdk Dikenal';
          // Entries should be a list
          final List<dynamic> entriesRaw = operatorData['entries'] ?? [];
          final List<Map<String, dynamic>> entries = entriesRaw is List
             ? List<Map<String, dynamic>>.from(entriesRaw.whereType<Map<String, dynamic>>())
             : [];


          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12.0, left: 5, right: 5), // Add horizontal margin
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(operatorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                  Text('Jenis Paket: $packageType', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Divider(height: 15, thickness: 0.5, color: Colors.grey[300]), // Thinner divider
                  if (entries.isEmpty)
                    Padding( // Indent message
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: const Text('Tidak ada entri harga untuk paket ini.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    )
                  else
                    ...entries.map((entry) {
                      final String packageName = entry['nama_paket']?.toString() ?? 'Nama Tdk Dikenal';
                      final String price = entry['harga']?.toString() ?? '-';
                      final String amount = entry['jumlah']?.toString() ?? '-'; // Assuming 'jumlah' means quantity/amount

                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 6.0, bottom: 2.0), // Adjust padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(' • $packageName', style: const TextStyle(fontWeight: FontWeight.w500)),
                            Padding(
                              padding: const EdgeInsets.only(left: 18.0, top: 2.0), // Indent details
                              child: Text('Harga: Rp $price', style: TextStyle(color: Colors.black54, fontSize: 14)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 18.0, top: 2.0), // Indent details
                              child: Text('Jumlah: $amount', style: TextStyle(color: Colors.black54, fontSize: 14)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}