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

// --- IMPORT FILE YANG MENDEFINISIKAN routeObserver ---
// Pastikan path ini benar menuju file main.dart Anda atau file lain
// tempat Anda mendefinisikan routeObserver secara global/static.
import 'package:pamasuka/main.dart'; // <-- PERIKSA PATH INI

// --- User ID Range Definition ---
const int MIN_NORMAL_USER_ID_RANGE = 6;
const int MAX_NORMAL_USER_ID_RANGE = 784;
// --- ---

class MenuPage extends StatefulWidget {
  final String username;
  final int userId;

  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

// --- Add RouteAware mixin ---
class _MenuPageState extends State<MenuPage> with RouteAware {
  double? _telkomselPercentage;
  String _performanceStatus = 'Memuat...';
  Color _performanceColor = Colors.grey.shade400;
  bool _isLoadingPerformance = false; // Start as false, set true in fetch
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
       _performanceStatus = 'N/A';
       _performanceColor = Colors.blueGrey;
    }
  }

  // --- Subscribe to RouteObserver ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      // FIX: Akses routeObserver dari file yang diimpor
      routeObserver.subscribe(this, route);
      print("MenuPage subscribed to RouteObserver.");
    } else {
       print("MenuPage failed to subscribe: route is null or not a PageRoute.");
    }
  }

  // --- Unsubscribe from RouteObserver ---
  @override
  void dispose() {
    print("MenuPage disposing and unsubscribing from RouteObserver.");
    // FIX: Akses routeObserver dari file yang diimpor
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // --- Called when the top route has been popped and this route is now visible ---
  @override
  void didPopNext() {
    super.didPopNext();
    print("MenuPage received didPopNext. Refreshing performance data...");
    if (isNormalUser && mounted) {
       _fetchTelkomselPerformance();
    }
  }

  // --- Fetch Performance Data ---
  Future<void> _fetchTelkomselPerformance() async {
    if (_isLoadingPerformance || !mounted) return;

    print("Starting performance fetch...");
    setState(() {
      _isLoadingPerformance = true;
      _performanceError = null;
    });

    // --- PASTIKAN URL BENAR ---
    final url = Uri.https(
      'tunnel.jato.my.id',
      '/test api/get_user_telkomsel_performance.php',
      {'user_id': widget.userId.toString()},
    );
    // --- ---

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
           if (percentageValue is num) { percentage = percentageValue.toDouble(); }
           else if (percentageValue is String) { percentage = double.tryParse(percentageValue) ?? 0.0; }

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

  // --- Update UI based on percentage ---
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

  // --- Build Performance Indicator Widget ---
  Widget _buildPerformanceIndicator() {
    // Section 1: Non-normal users
    if (!isNormalUser) {
      return const SizedBox.shrink();
    }

    // Section 2: Loading state
    if (_isLoadingPerformance) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
               _telkomselPercentage == null ? 'Memuat Performa Telkomsel...' : 'Memuat Ulang Performa...',
               style: const TextStyle(color: Colors.black54, fontSize: 14),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 15),
             CircularProgressIndicator(
               color: Colors.redAccent.shade100,
               strokeWidth: 3,
             ),
          ],
        ),
      );
    }

    // Section 3: Error state
    if (_performanceError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
        child: Card(
           color: Colors.orange.shade50,
           elevation: 0,
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(8),
             side: BorderSide(color: Colors.orange.shade200)
           ),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column( // Column ini TIDAK boleh const
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 35),
                 const SizedBox(height: 10),
                  // Text TIDAK boleh const karena stylenya menggunakan warna non-const
                 Text(
                   'Gagal Memuat Performa',
                   style: TextStyle(
                     color: Colors.orange.shade900, // <-- INI TIDAK CONST
                     fontWeight: FontWeight.bold,
                     fontSize: 16
                   ),
                   textAlign: TextAlign.center,
                 ),
                  const SizedBox(height: 5),
                  Text(
                   _performanceError!,
                   textAlign: TextAlign.center,
                   // TextStyle TIDAK boleh const karena stylenya menggunakan warna non-const
                   style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                 ),
                 const SizedBox(height: 10),
                 TextButton.icon(
                   icon: const Icon(Icons.refresh, size: 18),
                   label: const Text("Coba Lagi"),
                   onPressed: _isLoadingPerformance ? null : _fetchTelkomselPerformance,
                   style: TextButton.styleFrom(foregroundColor: Colors.redAccent.shade200),
                 )
               ],
             ),
           ),
        ),
      );
    }

    // Section 4: Success state
    final percentage = _telkomselPercentage ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Status Performa Telkomsel:',
            style: TextStyle(
                fontSize: 15,
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _performanceStatus,
            style: TextStyle( // TIDAK const karena _performanceColor tidak const
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _performanceColor,
                shadows: const [ // Shadow bisa const
                  Shadow(blurRadius: 1.0, color: Color(0x26000000), offset: Offset(1, 1))
                ]),
          ),
          const SizedBox(height: 12),
          Container(
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(10),
               boxShadow: const [ // BoxShadow bisa const
                 BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))
               ]
             ),
             child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator( // TIDAK const karena value dan color tidak const
                value: percentage / 100.0,
                backgroundColor: _performanceColor.withOpacity(0.2), // TIDAK const
                valueColor: AlwaysStoppedAnimation<Color>(_performanceColor), // TIDAK const
                minHeight: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%', // TIDAK const karena percentage tidak const
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samalonian APP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB6B6), Color(0xFFFF8E8E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'images/Samalonian_app.png',
                  height: MediaQuery.of(context).size.height * 0.18,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading menu logo: $error");
                    // Placeholder widget saat error load image
                    return const SizedBox(
                      height: 100, // Beri ukuran agar tidak hilang
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.black38),
                            SizedBox(height: 8),
                            Text("Logo Error", style: TextStyle(color: Colors.black45, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Selamat datang,\n${widget.username}!',
                    style: const TextStyle( // Bisa const jika Shadow const
                      fontSize: 26, fontWeight: FontWeight.w600, color: Color(0xFF3B3A3A),
                      letterSpacing: 0.5, height: 1.3,
                      shadows: [ Shadow(blurRadius: 4.0, color: Color(0x42000000), offset: Offset(1.0, 1.0)) ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // Performance Indicator
                _buildPerformanceIndicator(),

                const SizedBox(height: 10),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.0),
                  child: Text(
                    'Pilih menu di bawah untuk melanjutkan',
                    style: TextStyle(fontSize: 16, color: Color(0xFF555555)),
                    textAlign: TextAlign.center,
                  ),
                ),
                 const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 10,
        color: Colors.white,
        child: BottomNavBar(username: widget.username, userId: widget.userId, isNormalUser: isNormalUser),
      ),
    );
  }
}

// --- Bottom Navigation Bar Widget --- (Tidak perlu diubah)
class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;
  final bool isNormalUser;

  const BottomNavBar({Key? key, required this.username, required this.userId, required this.isNormalUser}) : super(key: key);
  void _showAccessDeniedDialog(BuildContext context) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [ Icon(Icons.cancel_outlined, color: Colors.red, size: 28), SizedBox(width: 10), Text('Akses Ditolak', style: TextStyle(fontWeight: FontWeight.bold)),]),
        content: const Text('Anda tidak memiliki izin untuk mengakses halaman ini.'),
        actions: [ TextButton(style: TextButton.styleFrom(foregroundColor: Colors.redAccent), onPressed: () => Navigator.pop(context), child: const Text('OK'),),],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      ),
    );
  }
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
       context: context, barrierDismissible: false, builder: (context) => AlertDialog(
         title: const Text('Konfirmasi Logout'), content: const Text('Apakah Anda yakin ingin keluar?'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
           TextButton(
             onPressed: () {
               Navigator.pop(context); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false,);
             },
             child: const Text('Logout', style: TextStyle(color: Colors.red)),
           ),
         ], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: SafeArea(
        bottom: true, top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavBarItem(icon: Icons.store_mall_directory_outlined, label: 'Outlet PJP', onTap: () { if (!isNormalUser) { _showAccessDeniedDialog(context); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage(username: username, userId: userId))); },),
            _NavBarItem(icon: Icons.home_work_outlined, label: 'Non PJP', onTap: () { if (isNormalUser) { _showAccessDeniedDialog(context); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => RumahPage(username: username, userId: userId))); },),
            _NavBarItem(icon: Icons.analytics_outlined, label: 'Performa', onTap: () { if (!isNormalUser) { _showAccessDeniedDialog(context); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => PerformaPage(userId: userId))); },),
            _NavBarItem(icon: Icons.account_circle_outlined, label: 'Akun', onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AkunPage(userId: userId, username: username))); },),
            _NavBarItem(icon: Icons.logout, label: 'Logout', onTap: () => _showLogoutConfirmationDialog(context)),
          ],
        ),
      ),
    );
  }
}

// --- Reusable Bottom Navigation Bar Item Widget --- (Tidak perlu diubah)
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavBarItem({ Key? key, required this.icon, required this.label, required this.onTap }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     const Color iconColor = Colors.redAccent;
     const Color textColor = Colors.black87;
     final Color splashColor = Colors.red.withOpacity(0.1);
     final Color highlightColor = Colors.red.withOpacity(0.05);

     return Expanded(
      child: InkWell(
        onTap: onTap, splashColor: splashColor, highlightColor: highlightColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 5),
              Text(
                label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}