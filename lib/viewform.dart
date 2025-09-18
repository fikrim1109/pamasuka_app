// File: lib/viewform.dart
import "dart:convert";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:intl/intl.dart";
import "package:intl/date_symbol_data_local.dart";
import "package:pamasuka/EditFormPage.dart";
import "package:pamasuka/app_theme.dart";

class ViewFormPage extends StatefulWidget {
  final String outletName;
  final int userId;

  const ViewFormPage({Key? key, required this.outletName, required this.userId}) : super(key: key);

  @override
  _ViewFormPageState createState() => _ViewFormPageState();
}

class _ViewFormPageState extends State<ViewFormPage> {
  List<Map<String, dynamic>> _forms = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  final PageController _pageController = PageController();

  final Map<String, String> operatorDisplayMap = {
    "TELKOMSEL": "Telkomsel",
    "XL": "XL",
    "INDOSAT": "Indosat",
    "INDOSAT OOREDOO": "Indosat Ooredoo",
    "AXIS": "Axis",
    "SMARTFREN": "Smartfren",
    "TRI": "Tri",
    "3": "3",
  };

  @override
  void initState() {
    super.initState();
    initializeDateFormatting("id_ID", null).then((_) {
      _fetchForms(isInitialLoad: true);
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal menginisialisasi format tanggal.";
        });
      }
    });
  }

  Future<void> _fetchForms({bool isInitialLoad = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      return;
    }

    // --- [FIXED 1] Nama file PHP disesuaikan dengan yang sudah kita perbaiki ---
    final url = Uri.https(
      "android.samalonian.my.id",
      "/test api/get_survey_forms.php", 
      {"outlet_nama": widget.outletName, "user_id": widget.userId.toString()},
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      if (!mounted) return;

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(utf8.decode(response.bodyBytes));
        } on FormatException catch (e) {
          throw Exception("Format respons tidak valid: ${e.message}");
        }

        if (data is Map && data["success"] == true && data["forms"] is List) {
          final List<dynamic> rawForms = data["forms"];
          final List<Map<String, dynamic>> processedForms = [];

          for (var rawForm in rawForms) {
            if (rawForm is! Map<String, dynamic>) continue;
            Map<String, dynamic> processedForm = Map.from(rawForm);
            
            if (processedForm["jenis_survei"] == "Survei harga") {
              // --- [FIXED 2] Kunci JSON diubah menjadi 'data_harga_json' ---
              final String? dataHargaString = processedForm["data_harga_json"]?.toString();
              Map<String, double> voucherPercentages = {};
              Map<String, double> perdanaPercentages = {};
              int totalVoucherCount = 0;
              int totalPerdanaCount = 0;

              if (dataHargaString != null && dataHargaString.isNotEmpty && dataHargaString.trim().toLowerCase() != "null" && dataHargaString.trim() != "[]") {
                try {
                  final List<dynamic> parsedPriceData = json.decode(dataHargaString);
                  if (parsedPriceData is List) {
                    final Set<String> operatorDisplayNames = {};
                    final Map<String, int> voucherCounts = {};
                    final Map<String, int> perdanaCounts = {};

                    for (var operatorDataRaw in parsedPriceData) {
                      if (operatorDataRaw is Map<String, dynamic>) {
                        final String operatorNameFromJson = (operatorDataRaw["operator"]?.toString() ?? "").toUpperCase();
                        final String packageType = (operatorDataRaw["paket"]?.toString() ?? "").toUpperCase();
                        final List<dynamic> entriesRaw = operatorDataRaw["entries"] ?? [];
                        final String operatorDisplayName = operatorDisplayMap[operatorNameFromJson] ?? operatorDataRaw["operator"]?.toString() ?? "Unknown";
                        
                        operatorDisplayNames.add(operatorDisplayName);
                        voucherCounts.putIfAbsent(operatorDisplayName, () => 0);
                        perdanaCounts.putIfAbsent(operatorDisplayName, () => 0);

                        int currentOperatorPackageTotal = 0;
                        for (var entry in entriesRaw.whereType<Map<String, dynamic>>()) {
                          currentOperatorPackageTotal += int.tryParse(entry["jumlah"]?.toString() ?? "0") ?? 0;
                        }

                        if (packageType == "VOUCHER FISIK") {
                          voucherCounts[operatorDisplayName] = voucherCounts[operatorDisplayName]! + currentOperatorPackageTotal;
                          totalVoucherCount += currentOperatorPackageTotal;
                        } else if (packageType == "PERDANA INTERNET") {
                          perdanaCounts[operatorDisplayName] = perdanaCounts[operatorDisplayName]! + currentOperatorPackageTotal;
                          totalPerdanaCount += currentOperatorPackageTotal;
                        }
                      }
                    }
                    for (String opDisplayName in operatorDisplayNames) {
                      voucherPercentages[opDisplayName] = (totalVoucherCount > 0) ? (voucherCounts[opDisplayName]! / totalVoucherCount) * 100 : 0.0;
                      perdanaPercentages[opDisplayName] = (totalPerdanaCount > 0) ? (perdanaCounts[opDisplayName]! / totalPerdanaCount) * 100 : 0.0;
                    }
                  }
                } catch (e) { /* Gagal kalkulasi, biarkan kosong */ }
              }
              processedForm["calculated_voucher_percentages"] = voucherPercentages;
              processedForm["calculated_perdana_percentages"] = perdanaPercentages;
              processedForm["calculated_total_voucher_count"] = totalVoucherCount;
              processedForm["calculated_total_perdana_count"] = totalPerdanaCount;
            }
            processedForms.add(processedForm);
          }

          processedForms.sort((a, b) {
            DateTime? dateA = DateTime.tryParse(a["tanggal_survei"]?.toString() ?? "");
            DateTime? dateB = DateTime.tryParse(b["tanggal_survei"]?.toString() ?? "");
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });

          if (mounted) {
            setState(() {
              _forms = processedForms;
              _isLoading = false;
              _currentIndex = _forms.isEmpty ? 0 : _currentIndex.clamp(0, _forms.length - 1);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients && _forms.isNotEmpty) {
                final targetPage = _currentIndex.clamp(0, _forms.length - 1);
                if (_pageController.page?.round() != targetPage) {
                  _pageController.jumpToPage(targetPage);
                }
              }
            });
          }
        } else {
          throw Exception(data["message"] ?? "Gagal mengambil data.");
        }
      } else {
        throw Exception("Kesalahan server: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Terjadi kesalahan: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteForm(int surveyId) async {
    if (mounted) {
      setState(() => _isLoading = true);
    } else {
      return;
    }
    final ThemeData theme = Theme.of(context);

    final url = Uri.https("android.samalonian.my.id", "/test api/delete_survey.php");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"id": surveyId.toString(), "user_id": widget.userId.toString()},
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Data survei berhasil dihapus.", style: theme.snackBarTheme.contentTextStyle),
            backgroundColor: AppSemanticColors.success(context),
          ),
        );
        await _fetchForms();
      } else {
        throw Exception(data["message"] ?? "Gagal menghapus data survei.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus: ${e.toString()}", style: theme.snackBarTheme.contentTextStyle),
            backgroundColor: AppSemanticColors.danger(context),
          ),
        );
        setState(() => _isLoading = false);
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Riwayat Survei: ${widget.outletName}", style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _buildBody(theme, colorScheme, textTheme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _fetchForms(),
        tooltip: "Muat Ulang Data",
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Icon(Icons.refresh, color: colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading && _forms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: AppSemanticColors.danger(context), size: 50),
                  const SizedBox(height: 15),
                  Text("Gagal Memuat Data", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _fetchForms(),
                    icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                    label: Text("Coba Lagi", style: TextStyle(color: colorScheme.onPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isLoading && _forms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 15),
            Text("Tidak ada data survei ditemukan\nuntuk outlet ini.", textAlign: TextAlign.center, style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_forms.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.primary),
                  onPressed: _currentIndex > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn) : null,
                ),
                Text("Survei ke-${_currentIndex + 1} dari ${_forms.length}", style: textTheme.titleMedium),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: colorScheme.primary),
                  onPressed: _currentIndex < _forms.length - 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn) : null,
                ),
              ],
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _forms.length,
            onPageChanged: (index) {
              if (mounted) setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildFormCard(_forms[index], theme, colorScheme, textTheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(Map<String, dynamic> form, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    final String jenisSurvei = form["jenis_survei"] ?? "Tidak diketahui";
    String formattedDate = "Tanggal tidak tersedia";
    if (form["tanggal_survei"] != null) {
      try {
        formattedDate = DateFormat("EEEE, dd MMMM yyyy", "id_ID").format(DateTime.parse(form["tanggal_survei"]));
      } catch (e) {
        formattedDate = "Format Tanggal Salah";
      }
    }
    final String surveyor = form["outlet_nama"] ?? widget.outletName;
    final String keterangan = form["keterangan_kunjungan"] ?? "Tidak ada keterangan.";
    final int surveyId = form["id"] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(jenisSurvei, style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  if (surveyId > 0)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_note_outlined, color: colorScheme.secondary),
                          tooltip: "Edit Survei Ini",
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EditFormPage(userId: widget.userId, outletName: widget.outletName, formData: form)),
                            );
                            if (result == true && mounted) _fetchForms();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppSemanticColors.danger(context)),
                          tooltip: "Hapus Survei Ini",
                          onPressed: () => _confirmDelete(surveyId, theme, colorScheme, textTheme),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(formattedDate, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              Text("Nama Outlet: $surveyor", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Text("Keterangan Kunjungan:", style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(keterangan, style: textTheme.bodyLarge),
              if (jenisSurvei == "Survei branding") ..._buildBrandingSection(form, theme, colorScheme, textTheme),
              if (jenisSurvei == "Survei harga") ..._buildHargaSection(form, theme, colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBrandingSection(Map<String, dynamic> form, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    final String? fotoEtalaseUrl = form["foto_etalase_url"]?.toString();
    final String? fotoDepanUrl = form["foto_depan_url"]?.toString();
    
    final String? posterPromoJson = form['poster_promo_json'] as String?;
    final String? layarTokoJson = form['layar_toko_json'] as String?;
    final String? shopSignJson = form['shop_sign_json'] as String?;
    final String? papanHargaJson = form['papan_harga_json'] as String?;
    final String? fullBrandingOperator = form['full_branding_operator'] as String?;
    final int? presentaseOutlet = form['presentase_outlet'] as int?;

    return [
      const Divider(height: 24),
      Text("Detail Branding:", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),

      _buildBrandingDetailList("Poster Promo", posterPromoJson, theme, colorScheme, textTheme),
      _buildBrandingDetailList("Layar Toko", layarTokoJson, theme, colorScheme, textTheme),
      _buildBrandingDetailList("Shop Sign", shopSignJson, theme, colorScheme, textTheme),
      _buildBrandingDetailList("Papan Harga", papanHargaJson, theme, colorScheme, textTheme),
      _buildBrandingDetailRow("Outlet Full Branding", fullBrandingOperator, theme, colorScheme, textTheme),
      if (presentaseOutlet != null)
        _buildPercentageIndicator("Persentase Branding Telkomsel", presentaseOutlet, theme, colorScheme, textTheme),
      
      const Divider(height: 24),
      Text("Foto Branding:", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),

      if (fotoEtalaseUrl != null && fotoEtalaseUrl.isNotEmpty) 
        _buildImageDisplay("Foto Etalase", fotoEtalaseUrl, theme, colorScheme, textTheme) 
      else 
        Text("Foto Etalase tidak tersedia.", style: textTheme.bodyMedium),
      
      const SizedBox(height: 12),
      if (fotoDepanUrl != null && fotoDepanUrl.isNotEmpty) 
        _buildImageDisplay("Foto Tampak Depan", fotoDepanUrl, theme, colorScheme, textTheme) 
      else 
        Text("Foto Tampak Depan tidak tersedia.", style: textTheme.bodyMedium),
    ];
  }

  Widget _buildBrandingDetailList(String title, String? jsonString, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    List<String> items = [];
    if (jsonString != null && jsonString.isNotEmpty && jsonString != '[]') {
      try {
        items = List<String>.from(json.decode(jsonString));
      } catch (e) { /* Abaikan jika JSON tidak valid */ }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text("$title:", style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(
            flex: 3,
            child: items.isEmpty
                ? Text("Tidak Ada", style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) => Text("• $item", style: textTheme.bodyLarge)).toList(),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBrandingDetailRow(String label, String? value, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text("$label:", style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(
            flex: 3,
            child: Text(
              (value != null && value.isNotEmpty) ? value : "Tidak Ada",
              style: textTheme.bodyLarge?.copyWith(
                color: (value != null && value.isNotEmpty) ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPercentageIndicator(String label, int percentage, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label:", style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100.0,
                    minHeight: 12,
                    backgroundColor: colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("$percentage%", style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageDisplay(String title, String imageUrl, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
              },
              errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image_outlined, size: 50, color: colorScheme.error)),
            ),
          ),
        ),
      ],
    );
  }

  // --- [FIXED 3] Nama kunci diubah menjadi 'data_harga_json' saat membaca ---
  List<Widget> _buildHargaSection(Map<String, dynamic> form, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    final String? dataHargaString = form["data_harga_json"]?.toString();
    List<dynamic> dataHarga = [];
    if (dataHargaString != null && dataHargaString.isNotEmpty && dataHargaString.trim().toLowerCase() != "null" && dataHargaString.trim() != "[]") {
      try {
        dataHarga = json.decode(dataHargaString);
      } catch (e) {
        return [Text("Data harga tidak valid atau rusak.", style: textTheme.bodyLarge?.copyWith(color: AppSemanticColors.danger(context)))];
      }
    }

    if (dataHarga.isEmpty) {
      return [const SizedBox.shrink()];
    }
    
    final Map<String, double> voucherPercentages = form["calculated_voucher_percentages"] as Map<String, double>? ?? {};
    final Map<String, double> perdanaPercentages = form["calculated_perdana_percentages"] as Map<String, double>? ?? {};
    final int totalVoucherCount = form["calculated_total_voucher_count"] as int? ?? 0;
    final int totalPerdanaCount = form["calculated_total_perdana_count"] as int? ?? 0;

    List<Widget> hargaWidgets = [
      const Divider(height: 24),
      Text("Detail Harga:", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8)
    ];

    for (var operatorDataRaw in dataHarga) {
      if (operatorDataRaw is! Map<String, dynamic>) continue;
      final String? operatorNameRaw = operatorDataRaw["operator"]?.toString();
      final String operatorName = operatorDisplayMap[operatorNameRaw?.toUpperCase() ?? ""] ?? operatorNameRaw ?? "Operator Tidak Dikenal";
      final String? paketJenis = operatorDataRaw["paket"]?.toString();
      final List<dynamic> entries = operatorDataRaw["entries"] ?? [];

      hargaWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$operatorName - $paketJenis", style: textTheme.titleSmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.w600)),
              if (entries.isEmpty) Text("  Tidak ada entri.", style: textTheme.bodyMedium),
              ...entries.map<Widget>((entry) {
                if (entry is! Map<String, dynamic>) return const SizedBox.shrink();
                final String namaPaket = entry["nama_paket"]?.toString() ?? "N/A";
                String harga = entry["harga"]?.toString() ?? "N/A";
                try {
                  harga = NumberFormat("#,###", "id_ID").format(int.parse(harga.replaceAll(".", "")));
                } catch (e) { /* biarkan harga asli jika gagal parsing */ }
                final String jumlah = entry["jumlah"]?.toString() ?? "N/A";
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                  child: Text("• $namaPaket: Rp $harga (Jumlah: $jumlah)", style: textTheme.bodyMedium),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }
    
    if (voucherPercentages.isNotEmpty || perdanaPercentages.isNotEmpty) {
      hargaWidgets.add(const SizedBox(height: 16));
      hargaWidgets.add(Text("Persentase Share Display:", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)));
      hargaWidgets.add(const SizedBox(height: 8));

      if (voucherPercentages.isNotEmpty) {
        hargaWidgets.add(Text("Voucher Fisik (Total: $totalVoucherCount)", style: textTheme.titleSmall?.copyWith(color: colorScheme.secondary)));
        voucherPercentages.forEach((op, perc) {
          hargaWidgets.add(Text("  • $op: ${perc.toStringAsFixed(1)}%", style: textTheme.bodyMedium));
        });
        hargaWidgets.add(const SizedBox(height: 8));
      }
      if (perdanaPercentages.isNotEmpty) {
        hargaWidgets.add(Text("Perdana Internet (Total: $totalPerdanaCount)", style: textTheme.titleSmall?.copyWith(color: colorScheme.secondary)));
        perdanaPercentages.forEach((op, perc) {
          hargaWidgets.add(Text("  • $op: ${perc.toStringAsFixed(1)}%", style: textTheme.bodyMedium));
        });
      }
    }

    return hargaWidgets;
  }

  void _confirmDelete(int surveyId, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text("Konfirmasi Hapus", style: textTheme.titleLarge?.copyWith(color: AppSemanticColors.danger(context))),
          content: Text("Apakah Anda yakin ingin menghapus data survei ini? Tindakan ini tidak dapat diurungkan.", style: textTheme.bodyLarge),
          actions: <Widget>[
            TextButton(
              child: Text("Batal", style: TextStyle(color: colorScheme.onSurface)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text("Hapus", style: TextStyle(color: AppSemanticColors.danger(context))),
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteForm(surveyId);
              },
            ),
          ],
        );
      },
    );
  }
}