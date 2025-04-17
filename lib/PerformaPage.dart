import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

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
  final Color startColor = const Color(0xFFFFB6B6);
  final Color endColor = const Color(0xFFFF8E8E);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performa Outlet'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchData,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Kesalahan: $_errorMessage', style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _buildFilterDropdown(),
                      _buildMonthlyChart(),
                      Expanded(
                        child: _outletVisits.isEmpty
                            ? const Center(child: Text('Tidak ada data untuk periode ini'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: _outletVisits.length,
                                itemBuilder: (context, index) {
                                  final visit = _outletVisits[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              visit.outletName,
                                              style: const TextStyle(fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            '${visit.visitCount} kunjungan',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Berdasarkan Periode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: _selectedFilter,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: 'all',
                    child: Text('Semua'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: 'today',
                    child: Text('Hari Ini'),
                  ),
                  ...List.generate(12, (index) {
                    final month = (index + 1).toString();
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(_monthNames[index]),
                    );
                  }),
                ],
                onChanged: _isLoading ? null : _onFilterChanged,
                underline: const SizedBox(),
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
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kunjungan Per Bulan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                            width: 16,
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
                              return Text(
                                _monthNames[month - 1].substring(0, 3),
                                style: const TextStyle(color: Colors.black, fontSize: 12),
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
                          reservedSize: 40,
                          interval: interval,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value % interval == 0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(color: Colors.black, fontSize: 12),
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