// viewform.dart
import 'dart:convert'; // For json operations
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For network requests
import 'package:intl/intl.dart'; // For date and number formatting
import 'package:intl/date_symbol_data_local.dart'; // For date locale data
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

  // Theme Colors
  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
  final Color primaryColor = const Color(0xFFC0392B);

  // Define the 6 operators consistently - MATCH THESE EXACTLY with JSON 'operator' values
  final List<String> operators = [
    "Telkomsel", // Assuming case sensitivity from your example "TELKOMSEL" - adjust if needed
    "XL",
    "Indosat",
    "Axis",
    "Smartfren",
    "Tri"
  ];
   // Map JSON operator names (case-sensitive) to display names if they differ
  final Map<String, String> operatorDisplayMap = {
    "TELKOMSEL": "Telkomsel",
    "XL": "XL",
    "INDOSAT": "Indosat",
    "AXIS": "Axis",
    "SMARTFREN": "Smartfren",
    "TRI": "Tri",
    // Add other variations if they exist in your data
  };


  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _fetchForms();
    }).catchError((error) {
      print("Error initializing date formatting: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal menginisialisasi format tanggal.";
        });
      }
    });
  }

  Future<void> _fetchForms() async {
    if (_isLoading && _forms.isNotEmpty) return; // Prevent refetch if already loading or has data (optional, remove if refresh always needed)

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.https(
      'tunnel.jato.my.id',
      '/test api/get_survey_forms.php',
      {
        'outlet_nama': widget.outletName,
        'user_id': widget.userId.toString(),
      },
    );
    print("Fetching forms from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      print("ViewForm Response Status: ${response.statusCode}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(utf8.decode(response.bodyBytes));
        } on FormatException catch (e) {
          print('Raw Response Body: ${response.body}');
          print('Error decoding JSON: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Format respons tidak valid dari server.';
            });
          }
          return; // Stop processing on format error
        }

        if (data is Map && data.containsKey('success')) {
          if (data['success'] == true && data.containsKey('forms') && data['forms'] is List) {
            final List<dynamic> rawForms = data['forms'];

            // Process forms immediately within setState
            setState(() {
              _forms = rawForms.whereType<Map<String, dynamic>>().toList();
              _forms.sort((a, b) {
                final dateAString = a['tanggal_survei']?.toString();
                final dateBString = b['tanggal_survei']?.toString();

                DateTime? dateA = DateTime.tryParse(dateAString ?? '');
                DateTime? dateB = DateTime.tryParse(dateBString ?? '');

                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });

              _isLoading = false;

              // Adjust currentIndex safely
              if (_forms.isEmpty) {
                _currentIndex = 0;
              } else if (_currentIndex >= _forms.length) {
                _currentIndex = _forms.length - 1;
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(_currentIndex);
                }
              });
            });
          } else {
             if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = data['message'] ?? 'Gagal mengambil data form atau format data salah.';
              });
            }
          }
        } else {
          if (mounted) {
             setState(() {
               _isLoading = false;
               _errorMessage = 'Format respons tidak dikenal dari server.';
             });
          }
        }
      } else {
        print('Server Error Response Body: ${response.body}');
         if (mounted) {
           setState(() {
             _isLoading = false;
             _errorMessage = 'Kesalahan server: ${response.statusCode} ${response.reasonPhrase ?? ""}.';
           });
         }
      }
    } catch (e, stacktrace) {
      print("Error fetching forms: $e\n$stacktrace");
      if (mounted) {
        setState(() {
          _errorMessage = "Terjadi kesalahan saat mengambil data: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

 Future<void> _deleteForm(int surveyId) async {
    setState(() => _isLoading = true); // Indicate loading during delete

    final url = Uri.https('tunnel.jato.my.id', '/test api/delete_survey.php');
    print("Deleting survey ID: $surveyId from: $url");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id': surveyId.toString(),
          'user_id': widget.userId.toString(),
        },
      ).timeout(const Duration(seconds: 30));

      print("Delete Response Status: ${response.statusCode}");
      if (!mounted) return;

      final responseBody = utf8.decode(response.bodyBytes);
      print("Delete Response Body: $responseBody");
      final data = json.decode(responseBody);

      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Data survei berhasil dihapus.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // --- UI Update Logic ---
        final initialLength = _forms.length;
        final initialIndex = _currentIndex;

        // Remove the item locally
        _forms.removeWhere((form) => form['id'] == surveyId);

        // Adjust current index
        if (_forms.isEmpty) {
          _currentIndex = 0;
        } else if (initialIndex >= _forms.length) {
          // If the deleted item was the last one, or beyond the new end
          _currentIndex = _forms.length - 1;
        } else if (initialIndex > 0 && initialIndex >= initialLength) {
            // Safety check if index was somehow out of bounds before deletion
            _currentIndex = _forms.length - 1;
        }
        // If deleted item was before or at the current index,
        // the effective index remains the same relative to the remaining items
        // unless it was the last item.

        setState(() {
          // Update state with the modified _forms list and potentially new _currentIndex
          _isLoading = false; // Deletion complete
        });

        // Animate or jump PageView AFTER setState has rebuilt the widget tree
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && _forms.isNotEmpty) {
            // Use jumpToPage for immediate change without animation
            _pageController.jumpToPage(_currentIndex);
            // Or animate if you prefer:
            // _pageController.animateToPage(
            //   _currentIndex,
            //   duration: const Duration(milliseconds: 300),
            //   curve: Curves.easeOut,
            // );
          } else if (_forms.isEmpty && _pageController.hasClients) {
             // Handle going back to a placeholder if the list is now empty
             _pageController.jumpToPage(0); // Or navigate away
          }
        });

        // Optional: Refetch from server to ensure absolute consistency,
        // but this will cause another loading state.
        // await _fetchForms();

      } else {
        throw Exception(data['message'] ?? 'Gagal menghapus data survei.');
      }
    } catch (e, stacktrace) {
      print("Error deleting form: $e\n$stacktrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false); // Stop loading indicator on error
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
        title: Text('Riwayat Survei: ${widget.outletName}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4.0,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _fetchForms,
        tooltip: 'Muat Ulang Data',
        backgroundColor: primaryColor,
        child: _isLoading && _forms.isEmpty // Show loading only if truly loading initial data
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

 Widget _buildBody() {
    // 1. Initial Loading State (only when _forms is empty)
    if (_isLoading && _forms.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // 2. Error State
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            color: Colors.white.withOpacity(0.95),
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
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    // Disable button while another operation (like delete) might be loading
                    onPressed: _isLoading ? null : _fetchForms,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 3. Empty State (No data found after successful fetch)
    if (!_isLoading && _forms.isEmpty) {
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
        ),
      );
    }

    // 4. Data Available State
    return Column(
      children: [
        // --- Navigation Header ---
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
                    // Disable navigation buttons during delete/refresh operations
                    onPressed: (_currentIndex > 0 && !_isLoading)
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                  // Show loading indicator during delete/refresh
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading) // Small indicator for ongoing operations
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_isLoading) const SizedBox(width: 8),
                      Text(
                        // Ensure length is checked against potentially updated _forms list
                        'Survei ke-${_currentIndex + 1} dari ${_forms.length}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: 'Form Berikutnya',
                    splashRadius: 20,
                    color: _currentIndex < _forms.length - 1 ? primaryColor : Colors.grey.shade400,
                     // Disable navigation buttons during delete/refresh operations
                    onPressed: (_currentIndex < _forms.length - 1 && !_isLoading)
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
        // --- PageView for Forms ---
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _forms.length, // Use the current length
            onPageChanged: (index) {
              if (!_isLoading) { // Prevent state change during delete/refresh
                 setState(() => _currentIndex = index);
              }
            },
            itemBuilder: (context, index) {
              // Bounds check just in case
              if (index < 0 || index >= _forms.length) {
                return const Center(child: Text("Index di luar batas"));
              }
              final form = _forms[index];
              // Key validation
              if (form['id'] == null) {
                print("Skipping form at index $index due to missing 'id'. Data: $form");
                return Card( /* ... error card ... */ );
              }
              // Build the card
              return _buildFormDetailsCard(form);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormDetailsCard(Map<String, dynamic> form) {
    String formattedDate = 'Tanggal tidak tersedia';
    final rawDate = form['tanggal_survei']?.toString();

    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(rawDate);
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(parsedDate);
      } catch (e) {
        formattedDate = 'Format Tanggal Salah: $rawDate';
        print('Error parsing date for form ID ${form['id']}: $e. Raw value: $rawDate');
      }
    }

    final int? surveyId = form['id'] is int
        ? form['id']
        : int.tryParse(form['id']?.toString() ?? '');

    return SingleChildScrollView(
      key: ValueKey(form['id']),
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Card Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Chip(
                          label: Text(
                            form['jenis_survei'] ?? 'Tipe Tidak Diketahui',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: primaryColor.withOpacity(0.9),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // --- Action Buttons ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_note, color: primaryColor, size: 28),
                        tooltip: 'Edit Survei Ini',
                        splashRadius: 22,
                        onPressed: _isLoading ? null : () { // Disable if loading
                          if (surveyId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("ID Survei tidak valid, tidak dapat mengedit.")),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditFormPage(
                                userId: widget.userId,
                                outletName: widget.outletName,
                                formData: form,
                              ),
                            ),
                          ).then((result) {
                             if (result == true) {
                                _fetchForms(); // Refresh on successful edit
                             }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever, color: Colors.red.shade600, size: 28),
                        tooltip: 'Hapus Survei Ini',
                        splashRadius: 22,
                        onPressed: _isLoading ? null : () async { // Disable if loading
                          if (surveyId == null) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("ID Survei tidak valid, tidak dapat menghapus.")),
                             );
                             return;
                          }
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Konfirmasi Hapus'),
                              content: const Text('Apakah Anda yakin ingin menghapus data survei ini? Tindakan ini tidak dapat dibatalkan.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Hapus', style: TextStyle(color: Colors.red.shade600)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                             await _deleteForm(surveyId);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 25, thickness: 1),

              // --- Keterangan ---
              _buildDetailItem(
                Icons.notes_rounded,
                'Keterangan Kunjungan:',
                form['keterangan_kunjungan']?.toString().trim().isNotEmpty == true
                    ? form['keterangan_kunjungan'].toString()
                    : 'Tidak ada keterangan',
              ),
              const SizedBox(height: 20),

              // --- Content based on survey type ---
              if (form['jenis_survei'] == 'Survei branding') ...[
                _buildImageSection('Foto Etalase', form['foto_etalase_url']?.toString(), form['id']),
                const SizedBox(height: 20),
                _buildImageSection('Foto Depan', form['foto_depan_url']?.toString(), form['id']),
              ] else if (form['jenis_survei'] == 'Survei harga') ...[
                // Build price section (includes percentage tables + details)
                _buildPriceDataSection(form['data_harga']?.toString(), form['id']),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor.withOpacity(0.8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String label, String? url, dynamic formId) {
     bool isValidUrl = false;
    if (url != null && url.isNotEmpty) {
      Uri? uri = Uri.tryParse(url);
      isValidUrl = uri != null && uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    }
    // Optional: Remove log in production
    // print("Image Section '$label' for form ID $formId: URL='$url', isValidUrl=$isValidUrl");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.5),
            child: isValidUrl
                ? Image.network(
                    url!,
                    fit: BoxFit.contain, // Use contain to avoid distortion
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, color: primaryColor));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image for form ID $formId from $url: $error');
                      return Center(child: Icon(Icons.broken_image_outlined, color: Colors.redAccent.shade100, size: 45));
                    },
                  )
                : Center(
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade500, size: 45),
                  ),
          ),
        ),
      ],
    );
  }

  // --- REVISED: Function to build price data section including percentage tables ---
  Widget _buildPriceDataSection(String? dataHargaString, dynamic formId) {
    // --- 1. Validate and Decode JSON ---
    if (dataHargaString == null || dataHargaString.isEmpty || dataHargaString.trim().toLowerCase() == 'null' || dataHargaString.trim() == '[]') {
      return _buildDetailItem(Icons.price_check_outlined, 'Data Harga:', 'Data harga tidak tersedia atau kosong.');
    }

    List<dynamic> parsedPriceData;
    try {
      parsedPriceData = json.decode(dataHargaString);
      if (parsedPriceData is! List) { // Check if it's a list, allow empty list
        print("Decoded data_harga for form ID $formId is not a list: $parsedPriceData");
        return _buildDetailItem(Icons.price_check_outlined, 'Data Harga:', 'Format data harga salah (bukan list).');
      }
       if (parsedPriceData.isEmpty) {
        // Handle empty list gracefully - show percentage tables as empty, then show "no detailed data" message.
        print("Decoded data_harga for form ID $formId is an empty list.");
       }
    } catch (e) {
      print("Error decoding data_harga JSON for form ID $formId: $e");
      print("Invalid data_harga string received: $dataHargaString");
      return _buildDetailItem(Icons.error_outline, 'Data Harga (Error Decode):', 'Format data harga tidak valid.');
    }

    // --- 2. Calculate Counts per Operator and Package Type ---
    // Initialize counts for ALL defined operators to 0
    Map<String, int> voucherCounts = { for (var op in operatorDisplayMap.values) op : 0 };
    Map<String, int> perdanaCounts = { for (var op in operatorDisplayMap.values) op : 0 };
    int totalVoucherCount = 0;
    int totalPerdanaCount = 0;

    // Use the defined list of operators for iteration keys
    final List<String> operatorKeysInJson = operatorDisplayMap.keys.toList();


    for (var operatorDataRaw in parsedPriceData) {
      if (operatorDataRaw is! Map<String, dynamic>) {
        print("Skipping invalid price data item (not a Map) for form ID $formId: $operatorDataRaw");
        continue; // Skip invalid entries
      }

      final Map<String, dynamic> operatorData = operatorDataRaw;
      final String? operatorNameFromJson = operatorData['operator']?.toString();
      final String? packageType = operatorData['paket']?.toString(); // e.g., "VOUCHER FISIK"
      final List<dynamic> entriesRaw = operatorData['entries'] ?? [];
      final List<Map<String, dynamic>> entries = entriesRaw.whereType<Map<String, dynamic>>().toList();

      // Validate Operator Name from JSON against our known keys
      if (operatorNameFromJson == null || !operatorKeysInJson.contains(operatorNameFromJson)) {
         print("Skipping unknown or null operator: '$operatorNameFromJson' in form ID $formId");
        continue; // Skip if operator unknown or not one we track
      }
       // Get the consistent display name
       final String operatorDisplayName = operatorDisplayMap[operatorNameFromJson]!;


      // Calculate total 'jumlah' for this operator/package entry
      int currentOperatorPackageTotal = 0;
      for (var entry in entries) {
        // Safely parse 'jumlah' string to int, default to 0 on error/null
        final int amount = int.tryParse(entry['jumlah']?.toString() ?? '0') ?? 0;
        currentOperatorPackageTotal += amount;
      }

      // Add to the correct category (Voucher or Perdana) using the display name as key
      if (packageType == 'VOUCHER FISIK') { // Match the exact string from JSON
        voucherCounts[operatorDisplayName] = (voucherCounts[operatorDisplayName] ?? 0) + currentOperatorPackageTotal;
        totalVoucherCount += currentOperatorPackageTotal;
      } else if (packageType == 'PERDANA INTERNET') { // Match the exact string from JSON
        perdanaCounts[operatorDisplayName] = (perdanaCounts[operatorDisplayName] ?? 0) + currentOperatorPackageTotal;
        totalPerdanaCount += currentOperatorPackageTotal;
      }
      // Ignore other package types for percentage calculation
    }

    // --- 3. Calculate Percentages ---
    Map<String, double> voucherPercentages = {};
    Map<String, double> perdanaPercentages = {};

    // Calculate percentages based on the *display names*
    for (String opDisplayName in operatorDisplayMap.values) {
      voucherPercentages[opDisplayName] = (totalVoucherCount > 0)
          ? (voucherCounts[opDisplayName]! / totalVoucherCount) * 100
          : 0.0; // Ensure division by zero is handled
      perdanaPercentages[opDisplayName] = (totalPerdanaCount > 0)
          ? (perdanaCounts[opDisplayName]! / totalPerdanaCount) * 100
          : 0.0; // Ensure division by zero is handled
    }

    // --- 4. Build the UI ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Percentage Tables Section ---
        const Text(
          'Ringkasan Persentase Jumlah Unit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),

        // Table for Voucher Fisik
        _buildPercentageTable('Voucher Fisik', voucherPercentages, totalVoucherCount),
        const SizedBox(height: 20),

        // Table for Perdana Internet
        _buildPercentageTable('Perdana Internet', perdanaPercentages, totalPerdanaCount),
        const SizedBox(height: 25),
        const Divider(thickness: 1),
        const SizedBox(height: 15),

        // --- Detailed Price List Section Header ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, color: primaryColor.withOpacity(0.8), size: 22),
              const SizedBox(width: 12),
              const Text('Rincian Data Harga:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- Detailed Price List Items ---
        if (parsedPriceData.isEmpty) // Handle case where JSON array was empty
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              'Tidak ada data harga rinci untuk ditampilkan.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          )
        else
          ...parsedPriceData.map((operatorDataRaw) {
            // Basic validation again for safety, though filtered earlier for counts
            if (operatorDataRaw is! Map<String, dynamic>) {
              return const SizedBox.shrink();
            }
            final Map<String, dynamic> operatorData = operatorDataRaw;

            // Use display map for consistent naming in the card header
            final String? operatorNameFromJson = operatorData['operator']?.toString();
            final String operatorDisplayName = operatorDisplayMap[operatorNameFromJson] ?? operatorNameFromJson ?? 'Operator Tdk Dikenal';

            final String packageType = operatorData['paket']?.toString() ?? 'Paket Tdk Dikenal';
            final List<dynamic> entriesRaw = operatorData['entries'] ?? [];
            final List<Map<String, dynamic>> entries = entriesRaw.whereType<Map<String, dynamic>>().toList();

            // --- Build the Card for each Operator's detailed prices ---
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 14.0, left: 4, right: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operatorDisplayName, // Use the display name
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
                    Text(
                      'Jenis Paket: $packageType',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    Divider(height: 18, thickness: 0.8, color: Colors.grey[200]),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, top: 6.0),
                        child: Text('Tidak ada rincian harga untuk operator/paket ini.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entries.map((entry) {
                          final String packageName = entry['nama_paket']?.toString() ?? 'Nama Paket Tdk Dikenal';
                          final String priceRaw = entry['harga']?.toString() ?? '-';
                          final String amountRaw = entry['jumlah']?.toString() ?? '-'; // Get raw amount string

                          // Format Price
                          String displayPrice = 'Rp -';
                          if (priceRaw != '-') {
                            try {
                              final cleanedPrice = priceRaw.replaceAll(RegExp(r'[^\d]'), '');
                              if (cleanedPrice.isNotEmpty) {
                                final priceNum = int.parse(cleanedPrice);
                                displayPrice = NumberFormat.currency(
                                  locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
                                ).format(priceNum);
                              } else { displayPrice = 'Rp ?'; }
                            } catch (e) { displayPrice = 'Rp ? (err)'; }
                          }

                          // Display Amount (just show the raw string here)
                          final String displayAmount = amountRaw;

                          return Padding(
                            padding: const EdgeInsets.only(left: 4.0, top: 8.0, bottom: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row( /* ... Package Name ... */
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0, right: 6.0),
                                      child: Icon(Icons.fiber_manual_record, size: 8, color: Colors.black54),
                                    ),
                                    Expanded(
                                      child: Text(
                                        packageName.isEmpty ? '(Nama Paket Kosong)' : packageName,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding( /* ... Price ... */
                                  padding: const EdgeInsets.only(left: 18.0, top: 4.0),
                                  child: Text('Harga: $displayPrice', style: TextStyle(color: Colors.black54, fontSize: 14)),
                                ),
                                Padding( /* ... Amount ... */
                                  padding: const EdgeInsets.only(left: 18.0, top: 2.0),
                                  child: Text('Jumlah: $displayAmount', style: TextStyle(color: Colors.black54, fontSize: 14)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // --- REVISED: Helper Function to build a percentage table ---
  Widget _buildPercentageTable(String title, Map<String, double> percentages, int totalCount) {
    // Use the display names (map values) for the table rows
    final List<String> operatorDisplayNames = operatorDisplayMap.values.toList();

    return Card(
       elevation: 1.5,
       margin: const EdgeInsets.symmetric(vertical: 5.0),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(8),
         side: BorderSide(color: Colors.grey.shade300, width: 0.5),
       ),
       child: Padding(
         padding: const EdgeInsets.all(12.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               title,
               style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
             ),
             Text(
                'Total Unit: $totalCount', // Show the calculated total
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
             ),
             const SizedBox(height: 10),
             // Always show the table structure, even if totalCount is 0
             DataTable(
               columnSpacing: 15, // Reduced spacing
               horizontalMargin: 8, // Reduced margin
               headingRowHeight: 35,
               dataRowMinHeight: 30,
               dataRowMaxHeight: 40,
               headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 14),
               columns: const [
                 DataColumn(label: Text('Operator')),
                 DataColumn(label: Text('Persen'), numeric: true), // Shorter label
               ],
               rows: operatorDisplayNames.map((opDisplayName) {
                 // Get the percentage for this display name, default to 0.0 if null
                 final double percentage = percentages[opDisplayName] ?? 0.0;
                 return DataRow(
                   cells: [
                     DataCell(Text(opDisplayName, style: const TextStyle(fontSize: 13.5))),
                     DataCell(
                       Text(
                         // Display 0.0% if percentage is 0 or total was 0
                         '${percentage.toStringAsFixed(1)}%',
                         textAlign: TextAlign.right, // Align right
                         style: const TextStyle(fontSize: 13.5)
                       )
                    ),
                   ],
                 );
               }).toList(),
             ),
             // Add message only if total count is zero AFTER the table
             if (totalCount == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Center(
                    child: Text(
                      'Tidak ada data unit untuk jenis paket ini.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                ),
           ],
         ),
       ),
    );
  }

} // End of _ViewFormPageState class