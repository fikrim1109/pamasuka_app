// File: lib/menu_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pamasuka/akunpage.dart';
import 'package:pamasuka/login_page.dart';
import 'package:pamasuka/home_page.dart';
import 'package:pamasuka/performapage.dart';
import 'package:pamasuka/rumah_page.dart';
import 'package:pamasuka/main.dart';
import 'package:google_fonts/google_fonts.dart';

const int MIN_NORMAL_USER_ID_RANGE = 6;
const int MAX_NORMAL_USER_ID_RANGE = 784;

class MenuPage extends StatefulWidget {
  final String username;
  final int userId;

  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with RouteAware {
  double? _telkomselPercentage;
  String _performanceStatus = 'Memuat...';
  Color _performanceColor = Colors.grey.shade400;
  bool _isLoadingPerformance = false;
  String? _performanceError;
  late bool isNormalUser;

  @override
  void initState() {
    super.initState();
    isNormalUser = (widget.userId >= MIN_NORMAL_USER_ID_RANGE &&
        widget.userId <= MAX_NORMAL_USER_ID_RANGE);

    if (isNormalUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchTelkomselPerformance();
        }
      });
    } else {
      _isLoadingPerformance = false;
      _performanceStatus = 'Tidak Tersedia';
      _performanceColor = Colors.blueGrey;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      routeObserver.subscribe(this, route);
      print("MenuPage subscribed to RouteObserver.");
    } else {
      print("MenuPage failed to subscribe: route is null or not a PageRoute.");
    }
  }

  @override
  void dispose() {
    print("MenuPage disposing and unsubscribing from RouteObserver.");
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    print("MenuPage received didPopNext. Refreshing performance data...");
    if (isNormalUser && mounted) {
      _fetchTelkomselPerformance();
    }
  }

  Future<void> _fetchTelkomselPerformance() async {
    if (_isLoadingPerformance || !mounted) return;

    print("Starting performance fetch...");
    setState(() {
      _isLoadingPerformance = true;
      _performanceError = null;
    });

    final url = Uri.https(
      'tunnel.jato.my.id',
      '/test api/get_user_telkomsel_performance.php',
      {'user_id': widget.userId.toString()},
    );

    print("Fetching performance from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      print("Performance Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['telkomsel_percentage'] != null) {
          final dynamic percentageValue = data['telkomsel_percentage'];
          double percentage = 0.0;
          if (percentageValue is num) {
            percentage = percentageValue.toDouble();
          } else if (percentageValue is String) {
            percentage = double.tryParse(percentageValue) ?? 0.0;
          }

          if (mounted) {
            setState(() {
              _telkomselPercentage = percentage;
              _updatePerformanceUI(percentage);
              _isLoadingPerformance = false;
              _performanceError = null;
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Data performa tidak lengkap dari server.');
        }
      } else {
        throw Exception('Kesalahan server: ${response.statusCode}');
      }
    } catch (e, stacktrace) {
      print("Error fetching performance: $e\n$stacktrace");
      if (mounted) {
        setState(() {
          _performanceError = 'Gagal memuat data performa.';
          _isLoadingPerformance = false;
          _performanceStatus = 'Error';
          _performanceColor = Colors.orange.shade700;
          _telkomselPercentage = null;
        });
      }
    }
  }

  void _updatePerformanceUI(double percentage) {
    if (percentage >= 50) {
      _performanceStatus = 'Aman';
      _performanceColor = Colors.green.shade600;
    } else if (percentage >= 30) {
      _performanceStatus = 'Bahaya';
      _performanceColor = Colors.yellow.shade700;
    } else {
      _performanceStatus = 'Darurat';
      _performanceColor = Colors.red.shade700;
    }
  }

  Widget _buildPerformanceIndicator() {
    if (!isNormalUser) {
      return const SizedBox.shrink();
    }

    if (_isLoadingPerformance) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _telkomselPercentage == null ? 'Memuat Performa Telkomsel...' : 'Memuat Ulang Performa...',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CircularProgressIndicator(
              color: const Color(0xFFC0392B),
              strokeWidth: 3,
            ),
          ],
        ),
      );
    }

    if (_performanceError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 35),
              const SizedBox(height: 8),
              Text(
                'Gagal Memuat Performa',
                style: GoogleFonts.poppins(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _performanceError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.orange.shade800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Coba Lagi', style: GoogleFonts.poppins()),
                onPressed: _isLoadingPerformance ? null : _fetchTelkomselPerformance,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFC0392B)),
              ),
            ],
          ),
        ),
      );
    }

    final percentage = _telkomselPercentage ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Status Display Shared',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _performanceStatus,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _performanceColor,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage / 100.0,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_performanceColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Aplikasi Samalonian', style: GoogleFonts.poppins()),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'images/Samalonian_app.png',
                  height: MediaQuery.of(context).size.height * 0.15,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading menu logo: $error");
                    return const Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Selamat Datang, ${widget.username}!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC0392B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pilih opsi di bawah untuk melanjutkan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildPerformanceIndicator(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        username: widget.username,
        userId: widget.userId,
        isNormalUser: isNormalUser,
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;
  final bool isNormalUser;

  const BottomNavBar({Key? key, required this.username, required this.userId, required this.isNormalUser}) : super(key: key);

  void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFC0392B), size: 24),
            const SizedBox(width: 8),
            Text('Akses Ditolak', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text('Anda tidak memiliki izin untuk mengakses halaman ini.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC0392B)),
            onPressed: () => Navigator.pop(context),
            child: Text('Oke', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Keluar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Apakah Anda yakin ingin keluar?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: Text('Keluar', style: GoogleFonts.poppins(color: const Color(0xFFC0392B))),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFC0392B), width: 1), // Border atas merah
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavBarItem(
              icon: Icons.store_mall_directory_outlined,
              label: 'Outlet PJP',
              onTap: () {
                if (!isNormalUser) {
                  _showAccessDeniedDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage(username: username, userId: userId)),
                );
              },
            ),
            _NavBarItem(
              icon: Icons.home_work_outlined,
              label: 'Non PJP',
              onTap: () {
                if (isNormalUser) {
                  _showAccessDeniedDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RumahPage(username: username, userId: userId)),
                );
              },
            ),
            _NavBarItem(
              icon: Icons.analytics_outlined,
              label: 'Performa',
              onTap: () {
                if (!isNormalUser) {
                  _showAccessDeniedDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PerformaPage(userId: userId)),
                );
              },
            ),
            _NavBarItem(
              icon: Icons.account_circle_outlined,
              label: 'Akun',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AkunPage(userId: userId, username: username)),
                );
              },
            ),
            _NavBarItem(
              icon: Icons.logout,
              label: 'Keluar',
              onTap: () => _showLogoutConfirmationDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavBarItem({Key? key, required this.icon, required this.label, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFC0392B).withOpacity(0.1),
        highlightColor: const Color(0xFFC0392B).withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFC0392B), size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}