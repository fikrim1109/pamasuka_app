// viewform.dart
import 'dart:convert'; // For json operations
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For network requests
import 'package:intl/intl.dart'; // For date and number formatting
import 'package:intl/date_symbol_data_local.dart'; // For date locale data
// Import EditFormPage - Make sure this file exists when you create it
import 'package:pamasuka/EditFormPage.dart'; // Adjust path if necessary

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

  // Theme Colors (Consider defining these centrally)
  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    // Initialize date formatting locale ONCE for 'id_ID'
    initializeDateFormatting('id_ID', null).then((_) {
      // Fetch data only after initialization is complete
      _fetchForms();
    }).catchError((error) {
       // Handle error during locale initialization if needed
       print("Error initializing date formatting: $error");
       // You might want to show an error message here as well
       setState(() {
          _isLoading = false;
          _errorMessage = "Gagal menginisialisasi format tanggal.";
       });
    });
  }

  Future<void> _fetchForms() async {
    // Prevent fetch if already loading, unless explicitly retrying
    if (_isLoading && _forms.isNotEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Use Uri.https for better security and parameter encoding
    final url = Uri.https(
      'tunnel.jato.my.id', // Authority (domain)
      '/test api/get_survey_forms.php', // Unencoded path
      { // Query parameters map - handles encoding automatically
        'outlet_nama': widget.outletName,
        'user_id': widget.userId.toString(),
      },
    );
    print("Fetching forms from: $url"); // Log the constructed URL

    try {
      // Add timeout for network requests
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      print("ViewForm Response Status: ${response.statusCode}"); // Log status code

      if (response.statusCode == 200) {
        dynamic data;
        try {
          // Use utf8.decode for handling potential non-ASCII characters in response
          data = json.decode(utf8.decode(response.bodyBytes));
        } on FormatException catch (e) {
          print('Raw Response Body: ${response.body}'); // Log raw body on format error
          throw Exception('Format respons tidak valid dari server. ${e.message}');
        }

        // Check response structure carefully
        if (data is Map && data.containsKey('success')) {
            if (data['success'] == true && data.containsKey('forms') && data['forms'] is List) {
                final List<dynamic> rawForms = data['forms'];
                // Use mounted check before calling setState in async gap
                if (!mounted) return;
                setState(() {
                  // Perform type checking during conversion to filter out invalid items
                  _forms = rawForms
                      .whereType<Map<String, dynamic>>()
                      .toList();

                  // Sort forms by date (descending) - handles nulls and parse errors
                  _forms.sort((a, b) {
                    final dateAString = a['tanggal_survei']?.toString();
                    final dateBString = b['tanggal_survei']?.toString();

                    // Handle null dates during sorting
                    if (dateAString == null && dateBString == null) return 0;
                    if (dateAString == null) return 1; // Null dates go last
                    if (dateBString == null) return -1; // Null dates go last

                    try {
                      // Use DateTime.tryParse for safer parsing
                      DateTime? dateA = DateTime.tryParse(dateAString);
                      DateTime? dateB = DateTime.tryParse(dateBString);

                      if (dateA == null && dateB == null) return 0;
                      if (dateA == null) return 1;
                      if (dateB == null) return -1;

                      return dateB.compareTo(dateA); // Descending order
                    } catch (e) {
                      print("Error comparing dates: $e. Values: $dateAString, $dateBString");
                      return 0; // Keep original order on error
                    }
                  });
                  _isLoading = false;
                   // Reset index if needed after refetch/sort, ensuring it's valid
                  _currentIndex = _forms.isNotEmpty ? (_currentIndex < _forms.length ? _currentIndex : 0) : 0;
                  // Ensure PageController jumps to the correct page if index changed/data reloaded
                  // Use addPostFrameCallback to ensure build is complete
                  if (_forms.isNotEmpty && _pageController.hasClients && _pageController.page?.round() != _currentIndex) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_pageController.hasClients) { // Check again as it might be disposed
                           _pageController.jumpToPage(_currentIndex);
                        }
                     });
                  } else if (_forms.isEmpty && _pageController.hasClients) {
                       // If forms become empty, potentially jump to 0 (or handle as needed)
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (_pageController.hasClients) _pageController.jumpToPage(0);
                       });
                  }
                });
             } else {
                 // Handle success: false or missing/invalid 'forms' key
                 throw Exception(data['message'] ?? 'Gagal mengambil data form (respon server tidak sesuai).');
             }
        } else {
           // Handle unexpected top-level JSON structure
           throw Exception('Format respons tidak dikenal dari server.');
        }
      } else {
        // Handle non-200 HTTP status codes
        print('Server Error Response Body: ${response.body}');
        throw Exception('Kesalahan server: ${response.statusCode} ${response.reasonPhrase ?? ""}.');
      }
    } catch (e, stacktrace) { // Catch errors (TimeoutException, SocketException, etc.)
      print("Error fetching forms: $e\n$stacktrace"); // Log stacktrace for debugging
      // Use mounted check before calling setState in async error handler
      if (mounted) {
         setState(() {
             _errorMessage = "Terjadi kesalahan: ${e.toString()}";
             _isLoading = false;
         });
      }
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
        title: Text('Riwayat Survei: ${widget.outletName}'), // More descriptive title
        backgroundColor: primaryColor,
        foregroundColor: Colors.white, // Ensure text/icons are white
        elevation: 4.0, // Add slight shadow
      ),
      body: Container(
        // Apply gradient to the whole body
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
      // Add a refresh floating action button
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _fetchForms, // Disable while loading
        tooltip: 'Muat Ulang Data',
        backgroundColor: primaryColor,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      // Consistent loading indicator
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage != null) {
      // Improved Error Display Card
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            color: Colors.white.withOpacity(0.95), // Slightly less transparent
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent.shade200, size: 50),
                  const SizedBox(height: 15),
                  Text(
                    'Gagal Memuat Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!, // Already checked for null
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _fetchForms, // Retry button
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_forms.isEmpty) {
      // Improved Empty State Display
      return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 60, color: Colors.white70),
              SizedBox(height: 15),
              Text(
                'Tidak ada data survei ditemukan\nuntuk outlet ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          )
      );
    }

    // Main content when data is available
    return Column(
      children: [
        // Pagination Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    color: _currentIndex > 0 ? primaryColor : Colors.grey.shade400,
                    tooltip: 'Form Sebelumnya',
                    splashRadius: 20,
                    onPressed: _currentIndex > 0
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                  // More user-friendly pagination text
                  Text(
                    'Survei ke-${_currentIndex + 1} dari ${_forms.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: 'Form Berikutnya',
                    splashRadius: 20,
                    color: _currentIndex < _forms.length - 1 ? primaryColor : Colors.grey.shade400,
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
        // PageView for Forms
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _forms.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              // Provide default empty map if index is out of bounds (should not happen with itemCount)
              final form = (_forms.length > index) ? _forms[index] : <String, dynamic>{};
              // Check if form data is valid using 'id' before building card
              if (form.isEmpty || form['id'] == null) {
                 print("Skipping form at index $index due to missing or null 'id'. Data: $form");
                 // Display an error card for this specific item
                 return Card(
                   margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                   color: Colors.red.shade50,
                   child: Center(
                       child: Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Text(
                           "Data survei tidak valid (ID hilang)\nIndex: $index",
                           textAlign: TextAlign.center,
                           style: TextStyle(color: Colors.red.shade800)
                         ),
                       )
                   )
                 );
              }
              // Build the actual details card
              return _buildFormDetailsCard(form);
            },
          ),
        ),
      ],
    );
  }

  // Builds the card displaying details for a single form
  Widget _buildFormDetailsCard(Map<String, dynamic> form) {
    // --- Safely Format Date ---
    String formattedDate = 'Tanggal tidak tersedia'; // Default text
    final rawDate = form['tanggal_survei']?.toString();

    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        // Assuming PHP returns 'YYYY-MM-DD' or null
        final parsedDate = DateTime.parse(rawDate); // Use parse directly
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(parsedDate);
      } catch (e) {
        formattedDate = 'Format Tanggal Salah: $rawDate'; // Show raw value on error
        print('Error parsing date for form ID ${form['id']}: $e. Raw value: $rawDate');
      }
    } else {
       print('Tanggal survei null atau kosong untuk form ID: ${form['id']}');
    }

    // --- Extract survey ID using the key 'id' ---
    // This ensures we handle both integer and string IDs from JSON
    final int? surveyId = form['id'] is int
        ? form['id']
        : int.tryParse(form['id']?.toString() ?? '');
    // final int? outletId = form['outlet_id'] is int ? form['outlet_id'] : int.tryParse(form['outlet_id']?.toString() ?? ''); // Extract outlet_id if needed here

    // --- Build Card ---
    return SingleChildScrollView( // Allow card content to scroll if it overflows
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Adjust padding
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Row (Date, Type, Edit Button) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Survey Type
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor),
                          overflow: TextOverflow.ellipsis, // Prevent long dates overflowing
                        ),
                        const SizedBox(height: 5),
                        Chip(
                          label: Text(
                            form['jenis_survei'] ?? 'Tipe Tidak Diketahui',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: primaryColor.withOpacity(0.9),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact, // Make chip smaller
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Button
                  IconButton(
                    icon: Icon(Icons.edit_note, color: primaryColor, size: 28), // Slightly larger icon
                    tooltip: 'Edit Survei Ini',
                    splashRadius: 22,
                    onPressed: () {
                       // Ensure surveyId (extracted from form['id']) is valid before navigating
                       if (surveyId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("ID Survei tidak valid, tidak dapat mengedit."))
                          );
                          print("Edit button pressed but surveyId (from form['id']) is null. Form data: $form");
                          return;
                       }

                       print("Navigating to EditFormPage with surveyId (from form['id']): $surveyId, formData: $form");

                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditFormPage(
                            // Pass necessary data to the EditFormPage
                            userId: widget.userId,
                            outletName: widget.outletName, // Pass outlet name for context
                            // Pass the full form map, which now contains 'id' and 'outlet_id'
                            formData: form,
                          ),
                        ),
                      ).then((result) {
                        // Check if the edit page returned true (indicating a successful save)
                        if (result == true) {
                          print("Edit successful, refreshing forms...");
                          // Optionally show a success message
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(content: Text("Data survei berhasil diperbarui."), backgroundColor: Colors.green)
                          // );
                          _fetchForms(); // Refresh the list of forms
                        } else {
                           print("Edit page closed without saving or returned false.");
                        }
                      });
                    },
                  ),
                ],
              ),
              const Divider(height: 25, thickness: 1),

              // --- Keterangan Kunjungan ---
              _buildDetailItem(
                  Icons.notes_rounded, // Updated Icon
                  'Keterangan Kunjungan:',
                  // Provide default text if keterangan is null or empty
                  form['keterangan_kunjungan']?.toString().trim().isNotEmpty == true
                     ? form['keterangan_kunjungan'].toString()
                     : 'Tidak ada keterangan'
              ),
              const SizedBox(height: 20), // Increased spacing

              // --- Conditional Content (Branding vs Harga) ---
              if (form['jenis_survei'] == 'Survei branding') ...[
                _buildImageSection('Foto Etalase', form['foto_etalase_url']?.toString(), form['id']),
                const SizedBox(height: 20),
                _buildImageSection('Foto Depan', form['foto_depan_url']?.toString(), form['id']),
              ] else if (form['jenis_survei'] == 'Survei harga') ...[
                 _buildPriceDataSection(form['data_harga']?.toString(), form['id']),
              ],

              const SizedBox(height: 10), // Add some padding at the bottom
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for consistent detail item display
  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Adjust vertical padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor.withOpacity(0.8), size: 22), // Slightly larger icon
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)), // Bolder label
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.3)), // Add line height for readability
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for displaying image sections
  Widget _buildImageSection(String label, String? url, dynamic formId) {
    // More robust URL validation
    bool isValidUrl = false;
    if (url != null && url.isNotEmpty) {
       Uri? uri = Uri.tryParse(url);
       // Check if URI is absolute and has http/https scheme
       isValidUrl = uri != null && uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    }
    // Log URL validity including the form ID for context
    print("Image Section '$label' for form ID $formId: URL='$url', isValidUrl=$isValidUrl");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 280), // Slightly increased max height
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12), // More rounded corners
            color: Colors.grey[100], // Lighter background
          ),
          child: ClipRRect( // Ensure image respects border radius
            borderRadius: BorderRadius.circular(11.5), // Match container radius slightly smaller
            child: isValidUrl
                ? Image.network(
                    url!, // URL is confirmed non-null and valid here
                    width: double.infinity,
                    fit: BoxFit.contain, // Use contain to see the whole image without cropping
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child; // Image loaded
                      // Show determinate progress if possible
                      double? progressValue = loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null; // Indeterminate if total size is unknown
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(
                            value: progressValue,
                            color: primaryColor,
                            strokeWidth: 3.0,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // Log error with form ID for context
                      print('Error loading image for form ID $formId from $url: $error');
                      // Provide a more informative error display
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, color: Colors.redAccent.shade100, size: 45),
                              const SizedBox(height: 10),
                              const Text(
                                'Gagal memuat gambar',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.redAccent, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Center( // Display when URL is invalid or null
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade500, size: 45),
                          const SizedBox(height: 10),
                          Text(
                            url == null ? 'Gambar tidak tersedia' : 'URL Gambar tidak valid',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // Helper widget for displaying price data sections
  Widget _buildPriceDataSection(String? dataHargaString, dynamic formId) {
    // Check for null, empty, or literal "null" / "[]" string
    if (dataHargaString == null || dataHargaString.isEmpty || dataHargaString.trim().toLowerCase() == 'null' || dataHargaString.trim() == '[]') {
      return _buildDetailItem(Icons.price_check_outlined, 'Data Harga:', 'Data harga tidak tersedia atau kosong.');
    }

    List<dynamic> parsedPriceData;
    try {
      parsedPriceData = json.decode(dataHargaString);
      // Ensure it's a List and not empty after decoding
      if (parsedPriceData is! List || parsedPriceData.isEmpty) {
          print("Decoded data_harga for form ID $formId is not a non-empty list: $parsedPriceData");
          return _buildDetailItem(Icons.price_check_outlined, 'Data Harga:', 'Data harga kosong atau format salah setelah decode.');
      }
    } catch (e) {
      print("Error decoding data_harga JSON for form ID $formId: $e");
      print("Invalid data_harga string received: $dataHargaString");
      // Show the raw string if decoding fails, helps debugging
      return _buildDetailItem(Icons.error_outline, 'Data Harga (Error Decode):', 'Format data harga tidak valid.');
    }

    // --- Build Price Data Display ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
           padding: const EdgeInsets.symmetric(vertical: 6.0), // Consistent padding
           child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
             children: [
               Icon(Icons.receipt_long_outlined, color: primaryColor.withOpacity(0.8), size: 22),
               const SizedBox(width: 12),
               const Text('Rincian Data Harga:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
             ],
           ),
         ),
        const SizedBox(height: 12), // Spacing before the list of operator cards

        // Iterate through the decoded list (each item should be a map representing an operator's data)
        ...parsedPriceData.map((operatorDataRaw) {
          // Validate the structure of each operator's data
          if (operatorDataRaw is! Map<String, dynamic>) {
            print("Skipping invalid price data item (not a Map) for form ID $formId: $operatorDataRaw");
            return const SizedBox.shrink(); // Skip invalid entries silently
          }
          final Map<String, dynamic> operatorData = operatorDataRaw;

          // Safely extract operator details
          final String operatorName = operatorData['operator']?.toString() ?? 'Operator Tdk Dikenal';
          final String packageType = operatorData['paket']?.toString() ?? 'Paket Tdk Dikenal';
          final List<dynamic> entriesRaw = operatorData['entries'] ?? [];

          // Filter and cast entries to the expected type
          final List<Map<String, dynamic>> entries = entriesRaw
              .whereType<Map<String, dynamic>>() // Ensure each entry is a Map
              .toList();

          // --- Build Card for each Operator ---
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 14.0, left: 4, right: 4), // Add horizontal margin
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200, width: 0.5) // Subtle border
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Operator Header
                  Text(
                      operatorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black) // Slightly larger font
                  ),
                  Text(
                      'Jenis Paket: $packageType',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13) // Slightly darker grey
                  ),
                  Divider(height: 18, thickness: 0.8, color: Colors.grey[200]), // Thicker divider

                  // List of Price Entries for this Operator
                  if (entries.isEmpty)
                    const Padding( // Message when no entries found
                      padding: EdgeInsets.only(left: 8.0, top: 6.0),
                      child: Text('Tidak ada rincian harga untuk paket ini.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    )
                  else
                    // Use Column for better control over spacing than list spread
                    Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: entries.map((entry) {
                          // Safely extract entry details
                          final String packageName = entry['nama_paket']?.toString() ?? 'Nama Paket Tdk Dikenal';
                          final String priceRaw = entry['harga']?.toString() ?? '-';
                          final String amount = entry['jumlah']?.toString() ?? '-';

                          // --- Format Price using intl ---
                          String displayPrice = 'Rp -'; // Default value
                          if (priceRaw != '-') {
                              try {
                                  // Remove any non-digit characters (like dots used as thousands separators)
                                  final cleanedPrice = priceRaw.replaceAll(RegExp(r'[^\d]'), '');
                                  if (cleanedPrice.isNotEmpty) {
                                      final priceNum = int.parse(cleanedPrice); // Assuming integer price
                                      // Use NumberFormat for currency
                                      displayPrice = NumberFormat.currency(
                                          locale: 'id_ID', // Use Indonesian locale
                                          symbol: 'Rp ',    // Currency symbol
                                          decimalDigits: 0 // No decimal places for Rupiah typically
                                      ).format(priceNum);
                                  } else {
                                      // Handle cases where priceRaw was non-digit (e.g., "abc")
                                      displayPrice = 'Rp ?';
                                  }
                              } catch (e) {
                                  print("Error formatting price for form ID $formId: '$priceRaw'. Error: $e");
                                  displayPrice = 'Rp $priceRaw (err)'; // Show raw on error
                              }
                          }
                          // --- End Price Formatting ---

                          // --- Build Widget for each Price Entry ---
                          return Padding(
                            padding: const EdgeInsets.only(left: 4.0, top: 8.0, bottom: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row( // Use Row for bullet point and name
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0, right: 6.0), // Adjust bullet position
                                      child: Icon(Icons.fiber_manual_record, size: 8, color: Colors.black54),
                                    ),
                                    Expanded( // Allow package name to wrap
                                      child: Text(
                                          packageName.isEmpty ? '(Nama Paket Kosong)' : packageName,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5) // Slightly larger font
                                      ),
                                    ),
                                  ],
                                ),
                                // Price and Amount details indented
                                Padding(
                                  padding: const EdgeInsets.only(left: 18.0, top: 4.0),
                                  child: Text(
                                      'Harga: $displayPrice', // Use formatted price
                                      style: TextStyle(color: Colors.black54, fontSize: 14)
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18.0, top: 2.0),
                                  child: Text(
                                      'Jumlah: $amount',
                                      style: TextStyle(color: Colors.black54, fontSize: 14)
                                  ),
                                ),
                              ],
                            ),
                          );
                      }).toList(), // Convert map result to list
                    ),
                ],
              ),
            ),
          );
        }).toList(), // Convert map result to list
      ],
    );
  }
}