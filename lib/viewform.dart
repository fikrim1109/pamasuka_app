// viewform.dart
import 'dart:convert'; // For json operations
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For network requests
import 'package:intl/intl.dart'; // For date and number formatting
import 'package:intl/date_symbol_data_local.dart'; // For date locale data
import 'package:pamasuka/EditFormPage.dart'; // <-- VERIFY PATH

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

  final Map<String, String> operatorDisplayMap = {
    "TELKOMSEL": "Telkomsel",
    "XL": "XL",
    "INDOSAT": "Indosat",
    "AXIS": "Axis",
    "SMARTFREN": "Smartfren",
    "TRI": "Tri",
  };

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _fetchForms(isInitialLoad: true);
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

  Future<void> _fetchForms({bool isInitialLoad = false}) async {
    print("--- _fetchForms START (isInitialLoad: $isInitialLoad) ---");
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      return;
    }

    final url = Uri.https(
      'tunnel.jato.my.id',
      '/test api/get_survey_forms.php',
      {'outlet_nama': widget.outletName, 'user_id': widget.userId.toString()},
    );
    print("Fetching forms from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      print("ViewForm Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(utf8.decode(response.bodyBytes));
        } on FormatException catch (e) {
          throw Exception('Format respons tidak valid: ${e.message}');
        }

        if (data is Map && data['success'] == true && data['forms'] is List) {
          final List<dynamic> rawForms = data['forms'];
          final List<Map<String, dynamic>> processedForms = [];
          print("Raw forms received: ${rawForms.length}");

          for (var rawForm in rawForms) {
            if (rawForm is! Map<String, dynamic>) continue;
            Map<String, dynamic> processedForm = Map.from(rawForm);
            final formIdForLog = processedForm['id'] ?? 'UNKNOWN_ID';

            if (processedForm['jenis_survei'] == 'Survei harga') {
              print("Processing percentages for form ID: $formIdForLog");
              final String? dataHargaString = processedForm['data_harga']?.toString();
              Map<String, double> voucherPercentages = {};
              Map<String, double> perdanaPercentages = {};
              int totalVoucherCount = 0;
              int totalPerdanaCount = 0;

              if (dataHargaString != null &&
                  dataHargaString.isNotEmpty &&
                  dataHargaString.trim().toLowerCase() != 'null' &&
                  dataHargaString.trim() != '[]') {
                try {
                  final List<dynamic> parsedPriceData = json.decode(dataHargaString);
                  if (parsedPriceData is List) {
                    // Collect unique operator display names dynamically
                    final Set<String> operatorDisplayNames = {};
                    final Map<String, int> voucherCounts = {};
                    final Map<String, int> perdanaCounts = {};

                    for (var operatorDataRaw in parsedPriceData) {
                      if (operatorDataRaw is Map<String, dynamic>) {
                        final String? operatorNameFromJsonRaw =
                            operatorDataRaw['operator']?.toString();
                        final String operatorNameFromJson =
                            operatorNameFromJsonRaw?.toUpperCase() ?? '';
                        final String? packageTypeRaw =
                            operatorDataRaw['paket']?.toString();
                        final String packageType =
                            packageTypeRaw?.toUpperCase() ?? '';
                        final List<dynamic> entriesRaw =
                            operatorDataRaw['entries'] ?? [];

                        // Map operator name to display name, default to raw name if not in map
                        final String operatorDisplayName =
                            operatorDisplayMap[operatorNameFromJson] ??
                                operatorNameFromJsonRaw ??
                                'Unknown';
                        operatorDisplayNames.add(operatorDisplayName);

                        // Initialize counts if not already present
                        voucherCounts[operatorDisplayName] =
                            voucherCounts[operatorDisplayName] ?? 0;
                        perdanaCounts[operatorDisplayName] =
                            perdanaCounts[operatorDisplayName] ?? 0;

                        int currentOperatorPackageTotal = 0;
                        for (var entry in entriesRaw.whereType<Map<String, dynamic>>()) {
                          currentOperatorPackageTotal +=
                              int.tryParse(entry['jumlah']?.toString() ?? '0') ?? 0;
                        }

                        if (packageType == 'VOUCHER FISIK') {
                          voucherCounts[operatorDisplayName] =
                              (voucherCounts[operatorDisplayName] ?? 0) +
                                  currentOperatorPackageTotal;
                          totalVoucherCount += currentOperatorPackageTotal;
                        } else if (packageType == 'PERDANA INTERNET') {
                          perdanaCounts[operatorDisplayName] =
                              (perdanaCounts[operatorDisplayName] ?? 0) +
                                  currentOperatorPackageTotal;
                          totalPerdanaCount += currentOperatorPackageTotal;
                        }
                      }
                    }

                    // Calculate percentages for all collected operators
                    for (String opDisplayName in operatorDisplayNames) {
                      voucherPercentages[opDisplayName] = (totalVoucherCount > 0)
                          ? (voucherCounts[opDisplayName]! / totalVoucherCount) * 100
                          : 0.0;
                      perdanaPercentages[opDisplayName] = (totalPerdanaCount > 0)
                          ? (perdanaCounts[opDisplayName]! / totalPerdanaCount) * 100
                          : 0.0;
                    }

                    print(" -> Calculated V: $voucherPercentages / $totalVoucherCount");
                    print(" -> Calculated P: $perdanaPercentages / $totalPerdanaCount");
                  }
                } catch (e) {
                  print("Error pre-calculating percentages for form ID $formIdForLog: $e");
                }
              } else {
                print(" -> No valid 'data_harga' for percentage calculation, ID: $formIdForLog");
              }
              processedForm['calculated_voucher_percentages'] = voucherPercentages;
              processedForm['calculated_perdana_percentages'] = perdanaPercentages;
              processedForm['calculated_total_voucher_count'] = totalVoucherCount;
              processedForm['calculated_total_perdana_count'] = totalPerdanaCount;
            }
            processedForms.add(processedForm);
          }

          processedForms.sort((a, b) {
            final dateAString = a['tanggal_survei']?.toString();
            final dateBString = b['tanggal_survei']?.toString();
            DateTime? dateA = DateTime.tryParse(dateAString ?? '');
            DateTime? dateB = DateTime.tryParse(dateBString ?? '');
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });

          print("--- Processed ${processedForms.length} forms. Updating state. ---");
          if (processedForms.isNotEmpty &&
              _currentIndex >= 0 &&
              _currentIndex < processedForms.length) {
            final currentFormBeforeSetState = processedForms[_currentIndex];
            print("DEBUG: Form ID ${_currentIndex} (${currentFormBeforeSetState['id']}) CALC DATA before setState:");
            print("  Voucher %: ${currentFormBeforeSetState['calculated_voucher_percentages']}");
            print("  Perdana %: ${currentFormBeforeSetState['calculated_perdana_percentages']}");
          }

          if (mounted) {
            setState(() {
              _forms = processedForms;
              _isLoading = false;
              if (_forms.isEmpty) {
                _currentIndex = 0;
              } else {
                _currentIndex = _currentIndex.clamp(0, _forms.length - 1);
              }
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients && _forms.isNotEmpty) {
                final targetPage = _currentIndex.clamp(0, _forms.length - 1);
                if (_pageController.page?.round() != targetPage) {
                  print("Jumping PageController to index: $targetPage");
                  _pageController.jumpToPage(targetPage);
                } else {
                  print("PageController already at index: $targetPage, no jump needed.");
                }
              } else if (_forms.isEmpty && _pageController.hasClients) {
                _pageController.jumpToPage(0);
              }
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data.');
        }
      } else {
        throw Exception('Kesalahan server: ${response.statusCode}');
      }
    } catch (e, stacktrace) {
      print("Error fetching forms: $e\n$stacktrace");
      if (mounted) {
        setState(() {
          _errorMessage = "Terjadi kesalahan: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
    print("--- _fetchForms END ---");
  }

  Future<void> _deleteForm(int surveyId) async {
    print("--- _deleteForm START ---");
    if (mounted) {
      setState(() => _isLoading = true);
    } else {
      return;
    }

    final url = Uri.https('tunnel.jato.my.id', '/test api/delete_survey.php');
    print("Deleting survey ID: $surveyId from: $url");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'id': surveyId.toString(), 'user_id': widget.userId.toString()},
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Data survei berhasil dihapus.'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchForms();
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
        setState(() => _isLoading = false);
      }
    }
    print("--- _deleteForm END ---");
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        "--- ViewFormPage BUILD Start (isLoading: $_isLoading, forms: ${_forms.length}, currentIndex: $_currentIndex) ---");
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
        onPressed: _isLoading ? null : () => _fetchForms(),
        tooltip: 'Muat Ulang Data',
        backgroundColor: primaryColor,
        child: (_isLoading && _forms.isEmpty)
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _forms.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

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
                  Icon(
                    Icons.error_outline,
                    color: Colors.redAccent.shade200,
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Gagal Memuat Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
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
                    onPressed: _isLoading ? null : () => _fetchForms(),
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
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
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
                    onPressed: (_currentIndex > 0 && !_isLoading)
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading && _forms.isNotEmpty)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_isLoading && _forms.isNotEmpty) const SizedBox(width: 8),
                      Text(
                        'Survei ke-${_currentIndex + 1} dari ${_forms.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    color: _currentIndex < _forms.length - 1
                        ? primaryColor
                        : Colors.grey.shade400,
                    tooltip: 'Form Berikutnya',
                    splashRadius: 20,
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
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _forms.length,
            onPageChanged: (index) {
              if (!_isLoading) {
                setState(() => _currentIndex = index);
              }
            },
            itemBuilder: (context, index) {
              print("--- PageView itemBuilder START for index: $index ---");
              if (index < 0 || index >= _forms.length) {
                return const Center(child: Text("Error: Index Invalid"));
              }
              final form = _forms[index];
              final formId = form['id'] ?? 'invalid_id_${DateTime.now().millisecondsSinceEpoch}';

              return KeyedSubtree(
                key: ValueKey("form_$formId"),
                child: _buildFormDetailsCard(form),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormDetailsCard(Map<String, dynamic> form) {
    final formIdForLog = form['id'] ?? 'UNKNOWN';
    print("--- _buildFormDetailsCard START for ID: $formIdForLog ---");
    if (form['jenis_survei'] == 'Survei harga') {
      print("  Received V %: ${form['calculated_voucher_percentages']}");
      print("  Received P %: ${form['calculated_perdana_percentages']}");
    }

    String formattedDate = 'Tanggal tidak tersedia';
    final rawDate = form['tanggal_survei']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(rawDate));
      } catch (e) {
        formattedDate = 'Format Tanggal Salah';
        print('Error parsing date for form ID $formIdForLog: $e. Raw value: $rawDate');
      }
    }

    final int? surveyId = int.tryParse(form['id']?.toString() ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Chip(
                          label: Text(
                            form['jenis_survei'] ?? '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: primaryColor.withOpacity(0.9),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_note, color: primaryColor, size: 28),
                        tooltip: 'Edit Survei Ini',
                        splashRadius: 22,
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (surveyId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("ID Survei tidak valid.")),
                                  );
                                  return;
                                }
                                print("Navigating to EditFormPage for ID: $surveyId");
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
                                  if (result == true && mounted) {
                                    print("Returned TRUE from EditFormPage. Refreshing...");
                                    _fetchForms();
                                  } else {
                                    print(
                                        "Returned from EditFormPage without saving (result: $result).");
                                  }
                                });
                              },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever, color: Colors.red.shade600, size: 28),
                        tooltip: 'Hapus Survei Ini',
                        splashRadius: 22,
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (surveyId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("ID Survei tidak valid.")),
                                  );
                                  return;
                                }
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext dialogContext) => AlertDialog(
                                    title: const Text('Konfirmasi Hapus'),
                                    content: const Text(
                                        'Yakin hapus data survei ini? Tindakan ini tidak dapat dibatalkan.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, true),
                                        child: Text(
                                          'Hapus',
                                          style: TextStyle(color: Colors.red.shade600),
                                        ),
                                      ),
                                    ],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                  ),
                                );
                                if (confirm == true) {
                                  print("Confirmed delete for ID: $surveyId. Calling _deleteForm...");
                                  await _deleteForm(surveyId);
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 25, thickness: 1),
              _buildDetailItem(
                Icons.notes_rounded,
                'Keterangan Kunjungan:',
                form['keterangan_kunjungan']?.toString().trim().isNotEmpty == true
                    ? form['keterangan_kunjungan'].toString()
                    : 'Tidak ada keterangan',
              ),
              const SizedBox(height: 20),
              if (form['jenis_survei'] == 'Survei branding') ...[
                _buildImageSection('Foto Etalase', form['foto_etalase_url']?.toString(), form['id']),
                const SizedBox(height: 20),
                _buildImageSection('Foto Depan', form['foto_depan_url']?.toString(), form['id']),
              ] else if (form['jenis_survei'] == 'Survei harga') ...[
                _buildPriceDataSection(form),
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
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String label, String? url, dynamic formId) {
    bool isValidUrl = url != null && url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) =>
                        loadingProgress == null
                            ? child
                            : Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: primaryColor,
                                ),
                              ),
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image $url: $error');
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.redAccent,
                          size: 45,
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                      size: 45,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDataSection(Map<String, dynamic> form) {
    final formIdForLog = form['id'] ?? 'UNKNOWN';
    print("--- _buildPriceDataSection START for ID: $formIdForLog ---");

    final Map<String, double> voucherPercentages =
        Map<String, double>.from(form['calculated_voucher_percentages'] ?? {});
    final Map<String, double> perdanaPercentages =
        Map<String, double>.from(form['calculated_perdana_percentages'] ?? {});
    final int totalVoucherCount = form['calculated_total_voucher_count'] ?? 0;
    final int totalPerdanaCount = form['calculated_total_perdana_count'] ?? 0;

    print("  Using V %: $voucherPercentages / $totalVoucherCount");
    print("  Using P %: $perdanaPercentages / $totalPerdanaCount");

    final String? dataHargaString = form['data_harga']?.toString();
    List<dynamic> parsedPriceDataForDetails = [];
    bool detailDecodeError = false;
    if (dataHargaString != null &&
        dataHargaString.isNotEmpty &&
        dataHargaString.trim().toLowerCase() != 'null' &&
        dataHargaString.trim() != '[]') {
      try {
        final decoded = json.decode(dataHargaString);
        if (decoded is List) {
          parsedPriceDataForDetails = decoded;
        } else {
          detailDecodeError = true;
          print("Decoded data_harga for details is not a list, ID $formIdForLog");
        }
      } catch (e) {
        detailDecodeError = true;
        print("Error decoding data_harga for details display, ID $formIdForLog: $e");
      }
    }

    // Collect unique operator display names for the table
    final Set<String> operatorDisplayNames = {};
    for (var operatorDataRaw in parsedPriceDataForDetails) {
      if (operatorDataRaw is Map<String, dynamic>) {
        final String? operatorNameFromJsonRaw = operatorDataRaw['operator']?.toString();
        final String operatorNameFromJson = operatorNameFromJsonRaw?.toUpperCase() ?? '';
        final String operatorDisplayName = operatorDisplayMap[operatorNameFromJson] ??
            operatorNameFromJsonRaw ??
            'Unknown';
        operatorDisplayNames.add(operatorDisplayName);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Persentase Jumlah Unit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        _buildPercentageTable(
          'Voucher Fisik',
          voucherPercentages,
          totalVoucherCount,
          operatorDisplayNames.toList(),
        ),
        const SizedBox(height: 20),
        _buildPercentageTable(
          'Perdana Internet',
          perdanaPercentages,
          totalPerdanaCount,
          operatorDisplayNames.toList(),
        ),
        const SizedBox(height: 25),
        const Divider(thickness: 1),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: primaryColor.withOpacity(0.8),
                size: 22,
              ),
              const SizedBox(width: 12),
              const Text(
                'Rincian Data Harga:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (detailDecodeError)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              'Gagal menampilkan rincian harga (format data salah).',
              style: TextStyle(
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else if (parsedPriceDataForDetails.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              'Tidak ada data harga rinci untuk ditampilkan.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          )
        else
          ...parsedPriceDataForDetails.map((operatorDataRaw) {
            if (operatorDataRaw is! Map<String, dynamic>) return const SizedBox.shrink();
            final Map<String, dynamic> operatorData = operatorDataRaw;
            final String? operatorNameFromJsonRaw = operatorData['operator']?.toString();
            final String operatorNameFromJson = operatorNameFromJsonRaw?.toUpperCase() ?? '';
            final String operatorDisplayName = operatorDisplayMap[operatorNameFromJson] ??
                operatorNameFromJsonRaw ??
                '?';
            final String packageType = operatorData['paket']?.toString() ?? '?';
            final List<Map<String, dynamic>> entries =
                (operatorData['entries'] as List? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
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
                      operatorDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Jenis Paket: $packageType',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    Divider(
                      height: 18,
                      thickness: 0.8,
                      color: Colors.grey[200],
                    ),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, top: 6.0),
                        child: Text(
                          'Tidak ada rincian harga.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entries.map((entry) {
                          final String packageName = entry['nama_paket']?.toString() ?? '?';
                          final String priceRaw = entry['harga']?.toString() ?? '-';
                          final String amountRaw = entry['jumlah']?.toString() ?? '-';
                          String displayPrice = 'Rp -';
                          if (priceRaw != '-') {
                            try {
                              final cleanPrice = priceRaw.replaceAll(RegExp(r'[^\d]'), '');
                              if (cleanPrice.isNotEmpty) {
                                final priceNum = int.parse(cleanPrice);
                                displayPrice = NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(priceNum);
                              } else {
                                displayPrice = 'Rp ?';
                              }
                            } catch (e) {
                              displayPrice = 'Rp ? (err)';
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: 4.0, top: 8.0, bottom: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0, right: 6.0),
                                      child: Icon(
                                        Icons.fiber_manual_record,
                                        size: 8,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        packageName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18.0, top: 4.0),
                                  child: Text(
                                    'Harga: $displayPrice',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18.0, top: 2.0),
                                  child: Text(
                                    'Jumlah: $amountRaw',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
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

  Widget _buildPercentageTable(
    String title,
    Map<String, double> percentages,
    int totalCount,
    List<String> operatorDisplayNames,
  ) {
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Text(
              'Total Unit: $totalCount',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            DataTable(
              columnSpacing: 15,
              horizontalMargin: 8,
              headingRowHeight: 35,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 40,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontSize: 14,
              ),
              columns: const [
                DataColumn(label: Text('Operator')),
                DataColumn(label: Text('Persen'), numeric: true),
              ],
              rows: operatorDisplayNames.map((opDisplayName) {
                final double percentage = percentages[opDisplayName] ?? 0.0;
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        opDisplayName,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            if (totalCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Center(
                  child: Text(
                    'Tidak ada data unit untuk jenis paket ini.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}