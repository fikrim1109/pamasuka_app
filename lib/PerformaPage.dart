// File: lib/PerformaPage.dart
import "dart:convert";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:fl_chart/fl_chart.dart";
// import "package:google_fonts/google_fonts.dart"; // Replaced by Theme
import "package:pamasuka/viewform.dart"; // Import ViewFormPage
import "package:pamasuka/app_theme.dart"; // Import AppTheme

class PerformaPage extends StatefulWidget {
  final int userId;
  const PerformaPage({Key? key, required this.userId}) : super(key: key);

  @override
  _PerformaPageState createState() => _PerformaPageState();
}

class _PerformaPageState extends State<PerformaPage> {
  List<MonthlyVisit> _monthlyVisits = [];
  List<OutletVisit> _outletVisits = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedFilter;

  // Removed: final Color primaryColor = const Color(0xFFC0392B);

  final List<String> _monthNames = [
    "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember"
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _getSurveyData();
      if (!mounted) return;
      setState(() {
        _monthlyVisits = data["monthly_visits"];
        _outletVisits = data["outlet_visits"];
        _outletVisits.sort((a, b) => a.outletName.compareTo(b.outletName));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getSurveyData() async {
    final url = Uri.parse("https://android.samalonian.my.id/test%20api/get_survei_data.php");
    final queryParams = <String, String>{
      "user_id": widget.userId.toString(),
    };

    if (_selectedFilter == "today") {
      queryParams["filter"] = "today";
    } else if (_selectedFilter != null && _selectedFilter != "all") {
      queryParams["month"] = _selectedFilter!;
    }

    final response = await http.get(url.replace(queryParameters: queryParams)).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        if (data is Map && data["success"] == true) {
          return {
            "monthly_visits": (data["monthly_visits"] as List).map((e) => MonthlyVisit.fromJson(e)).toList(),
            "outlet_visits": (data["outlet_visits"] as List).map((e) => OutletVisit.fromJson(e)).toList(),
          };
        } else if (data is Map && data["success"] == false) {
          throw Exception(data["message"] ?? "Kesalahan tidak diketahui dari server.");
        } else {
          throw Exception("Format respons tidak valid dari server.");
        }
      } catch (e) {
        throw Exception("Gagal memproses data: ${e.toString()}");
      }
    } else {
      throw Exception("Gagal memuat data dari server: Status ${response.statusCode}");
    }
  }

  void _onFilterChanged(String? filter) {
    if (!mounted) return;
    setState(() {
      _selectedFilter = filter;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      // backgroundColor: theme.scaffoldBackgroundColor, // Handled by theme
      appBar: AppBar(
        title: Text("Performa SF", style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary)),
        // centerTitle, backgroundColor, foregroundColor, elevation, shadowColor handled by theme.appBarTheme
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onPrimary), // Ensure icon color contrasts
            onPressed: _isLoading ? null : _fetchData,
            tooltip: "Segarkan Data",
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(), // Color handled by theme
                    const SizedBox(height: 15),
                    Text("Memuat data...", style: textTheme.bodyLarge),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
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
                              Text("Kesalahan Memuat Data", style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary), textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              Text(_errorMessage!, textAlign: TextAlign.center, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _fetchData,
                                icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                                label: Text("Coba Lagi", style: TextStyle(color: colorScheme.onPrimary)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: colorScheme.primary, // Refresh indicator color
                    backgroundColor: colorScheme.surface, // Refresh indicator background
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(), // Ensures RefreshIndicator works even if content is small
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFilterDropdown(theme, colorScheme, textTheme),
                          if (_monthlyVisits.isNotEmpty) _buildMonthlyChart(theme, colorScheme, textTheme),
                          if (_monthlyVisits.isEmpty && !_isLoading && _errorMessage == null) 
                            Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text("Tidak ada data kunjungan bulanan untuk periode ini", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center,)
                                ),
                            ),
                          if (_outletVisits.isEmpty && !_isLoading && _errorMessage == null)
                            Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text("Tidak ada data kunjungan outlet untuk periode ini", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center,)
                                ),
                            )
                          else if (_outletVisits.isNotEmpty)
                            ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _outletVisits.length,
                                itemBuilder: (context, index) {
                                  final visit = _outletVisits[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    // elevation, shape handled by theme.cardTheme
                                    child: ListTile(
                                      title: Text(visit.outletName, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                                      trailing: Text("${visit.visitCount} kunjungan", style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ViewFormPage(
                                              outletName: visit.outletName,
                                              userId: widget.userId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildFilterDropdown(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        // elevation, shape handled by theme.cardTheme
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Filter Berdasarkan Periode", style: textTheme.titleLarge?.copyWith(color: colorScheme.primary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Pilih Periode",
                  // prefixIcon: Icon(Icons.filter_list, color: colorScheme.onSurfaceVariant),
                  // filled, fillColor, border handled by theme.inputDecorationTheme
                ),
                style: textTheme.bodyLarge,
                items: [
                  DropdownMenuItem<String?>(
                    value: "all",
                    child: Text("Semua", style: textTheme.bodyLarge),
                  ),
                  DropdownMenuItem<String?>(
                    value: "today",
                    child: Text("Hari Ini", style: textTheme.bodyLarge),
                  ),
                  ...List.generate(12, (index) {
                    final month = (index + 1).toString();
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(_monthNames[index], style: textTheme.bodyLarge),
                    );
                  }),
                ],
                onChanged: _isLoading ? null : _onFilterChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    double maxVisitCount = _monthlyVisits.fold(0, (prev, mv) => mv.visitCount > prev ? mv.visitCount.toDouble() : prev.toDouble());
    double interval = (maxVisitCount / 5).ceil().toDouble(); // Dynamic interval, at least 1
    if (interval < 1.0) interval = 1.0;
    if (maxVisitCount == 0) interval = 1.0; // Ensure interval is not 0 if maxVisitCount is 0
    
    double maxY = (maxVisitCount / interval).ceil() * interval;
    if (maxY == 0 && maxVisitCount > 0) maxY = interval; // Ensure maxY is at least interval if there are visits
    if (maxY == 0 && maxVisitCount == 0) maxY = 5 * interval; // Default if no visits at all

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        // elevation, shape handled by theme.cardTheme
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Kunjungan Per Bulan", style: textTheme.titleLarge?.copyWith(color: colorScheme.primary)),
              const SizedBox(height: 20),
              SizedBox(
                height: 220, // Increased height for better readability
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (BarChartGroupData group) => colorScheme.surfaceVariant, // Use theme color for tooltip background
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                String monthName = _monthNames[group.x.toInt() -1];
                                return BarTooltipItem(
                                    "$monthName\n",
                                    textTheme.bodyMedium!.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                    children: <TextSpan>[
                                        TextSpan(
                                            text: rod.toY.round().toString(),
                                            style: textTheme.bodyLarge!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                            text: " kunjungan",
                                            style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurfaceVariant),
                                        ),
                                    ],
                                );
                            }
                        ),
                    ),
                    barGroups: _monthlyVisits.map((mv) {
                      return BarChartGroupData(
                        x: mv.month,
                        barRods: [
                          BarChartRodData(
                            toY: mv.visitCount.toDouble(),
                            color: colorScheme.primary, // Use theme color
                            width: 14, // Adjusted width
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            int month = value.toInt();
                            if (month >= 1 && month <= 12) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  _monthNames[month - 1].substring(0, 3),
                                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          interval: interval,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value % interval == 0 || value == maxY) {
                              return Text(
                                value.toInt().toString(),
                                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                            return FlLine(color: colorScheme.onSurface.withOpacity(0.1), strokeWidth: 1);
                        },
                    ),
                    borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1), width: 1)
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthlyVisit {
  final int month;
  final int visitCount;

  MonthlyVisit({required this.month, required this.visitCount});

  factory MonthlyVisit.fromJson(Map<String, dynamic> json) {
    return MonthlyVisit(
      month: int.parse(json["month"].toString()),
      visitCount: int.parse(json["visit_count"].toString()),
    );
  }
}

class OutletVisit {
  final String outletName;
  final int visitCount;

  OutletVisit({required this.outletName, required this.visitCount});

  factory OutletVisit.fromJson(Map<String, dynamic> json) {
    return OutletVisit(
      outletName: json["outlet_nama"],
      visitCount: int.parse(json["visit_count"].toString()),
    );
  }
}

