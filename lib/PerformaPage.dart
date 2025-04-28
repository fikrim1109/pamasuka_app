// File: lib/PerformaPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pamasuka/viewform.dart'; // Import ViewFormPage

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

  // Warna konsisten
  final Color primaryColor = const Color(0xFFC0392B);

  // Nama bulan dalam Bahasa Indonesia
  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _getSurveyData();
      setState(() {
        _monthlyVisits = data['monthly_visits'];
        _outletVisits = data['outlet_visits'];
        _outletVisits.sort((a, b) => a.outletName.compareTo(b.outletName));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getSurveyData() async {
    final url = Uri.parse('https://tunnel.jato.my.id/test%20api/get_survei_data.php');
    final queryParams = {
      'user_id': widget.userId.toString(),
    };

    if (_selectedFilter == 'today') {
      queryParams['filter'] = 'today';
    } else if (_selectedFilter != null && _selectedFilter != 'all') {
      queryParams['month'] = _selectedFilter!;
    }

    final response = await http.get(url.replace(queryParameters: queryParams));

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == true) {
          return {
            'monthly_visits': (data['monthly_visits'] as List).map((e) => MonthlyVisit.fromJson(e)).toList(),
            'outlet_visits': (data['outlet_visits'] as List).map((e) => OutletVisit.fromJson(e)).toList(),
          };
        } else if (data is Map && data['success'] == false) {
          throw Exception(data['message'] ?? 'Kesalahan tidak diketahui');
        } else {
          throw Exception('Format respons tidak valid');
        }
      } catch (e) {
        throw Exception('Format data tidak valid: $e');
      }
    } else {
      throw Exception('Gagal memuat data: ${response.statusCode}');
    }
  }

  void _onFilterChanged(String? filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _fetchData();
  }

  // --- Input Decoration Helper ---
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(Icons.filter_list, color: Colors.grey.shade600),
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Performa SF', style: GoogleFonts.poppins()),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF5F5),
        foregroundColor: primaryColor,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _isLoading ? null : _fetchData,
            tooltip: 'Segarkan Data',
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
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 15),
                    Text('Memuat data...', style: GoogleFonts.poppins()),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kesalahan: $_errorMessage',
                          style: GoogleFonts.poppins(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Coba Lagi', style: GoogleFonts.poppins()),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFilterDropdown(),
                        _buildMonthlyChart(),
                        _outletVisits.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'Tidak ada data untuk periode ini',
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: _outletVisits.length,
                                itemBuilder: (context, index) {
                                  final visit = _outletVisits[index];
                                  return GestureDetector(
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
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                visit.outletName,
                                                style: GoogleFonts.poppins(fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${visit.visitCount} kunjungan',
                                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Berdasarkan Periode',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String?>(
                  value: _selectedFilter,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Pilih Periode',
                    hint: 'Semua',
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: 'all',
                      child: Text('Semua', style: GoogleFonts.poppins()),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'today',
                      child: Text('Hari Ini', style: GoogleFonts.poppins()),
                    ),
                    ...List.generate(12, (index) {
                      final month = (index + 1).toString();
                      return DropdownMenuItem<String>(
                        value: month,
                        child: Text(_monthNames[index], style: GoogleFonts.poppins()),
                      );
                    }),
                  ],
                  onChanged: _isLoading ? null : _onFilterChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart() {
    double maxVisitCount = _monthlyVisits.fold(0, (prev, mv) => mv.visitCount > prev ? mv.visitCount : prev).toDouble();
    double interval = 5.0;
    double maxY = (maxVisitCount / interval).ceil() * interval;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kunjungan Per Bulan',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: _monthlyVisits.map((mv) {
                      return BarChartGroupData(
                        x: mv.month,
                        barRods: [
                          BarChartRodData(
                            toY: mv.visitCount.toDouble(),
                            color: primaryColor,
                            width: 12, // Dikurangi dari 16 untuk lebih banyak ruang
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
                            if (month >= 1 && month <= 12) { // Show all months
                              return RotatedBox(
                                quarterTurns: 1, // Rotasi 90 derajat untuk kejelasan
                                child: Text(
                                  _monthNames[month - 1].substring(0, 3),
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.black),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                          reservedSize: 40, // Ditambah dari 30 untuk teks yang diputar
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: interval,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value % interval == 0) {
                              return Text(
                                value.toInt().toString(),
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    maxY: maxY,
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
      month: json['month'] ?? 0,
      visitCount: (json['visit_count'] is int ? json['visit_count'] : int.tryParse(json['visit_count'].toString())) ?? 0,
    );
  }
}

class OutletVisit {
  final String outletName;
  final int visitCount;

  OutletVisit({required this.outletName, required this.visitCount});

  factory OutletVisit.fromJson(Map<String, dynamic> json) {
    return OutletVisit(
      outletName: json['outlet_nama'] ?? 'Tidak Diketahui',
      visitCount: (json['visit_count'] is int ? json['visit_count'] : int.tryParse(json['visit_count'].toString())) ?? 0,
    );
  }
}