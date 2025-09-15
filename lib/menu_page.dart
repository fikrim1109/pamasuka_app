// File: lib/menu_page.dart
import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:pamasuka/akunpage.dart";
import "package:pamasuka/login_page.dart";
import "package:pamasuka/home_page.dart";
import "package:pamasuka/performapage.dart";
import "package:pamasuka/rumah_page.dart";
import "package:pamasuka/main.dart"; // For routeObserver
import "package:pamasuka/app_theme.dart"; // Import AppTheme
import "package:provider/provider.dart"; // Import Provider
import "package:pamasuka/theme_provider.dart"; // Import ThemeNotifier

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
  String _performanceStatus = "Memuat...";
  late Color _performanceColor; 
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
          _performanceColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
          _fetchTelkomselPerformance();
        }
      });
    } else {
      _isLoadingPerformance = false;
      _performanceStatus = "Tidak Tersedia";
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    _performanceColor = _performanceError != null 
        ? AppSemanticColors.performanceError(context)
        : isNormalUser 
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) 
            : AppSemanticColors.performanceNotAvailable(context);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    if (isNormalUser && mounted) {
      _fetchTelkomselPerformance();
    }
  }

  Future<void> _fetchTelkomselPerformance() async {
    if (_isLoadingPerformance || !mounted) return;

    setState(() {
      _isLoadingPerformance = true;
      _performanceError = null;
    });

    final url = Uri.https(
      "android.samalonian.my.id",
      "/test api/get_user_telkomsel_performance.php",
      {"user_id": widget.userId.toString()},
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 25));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data["success"] == true && data["telkomsel_percentage"] != null) {
          final dynamic percentageValue = data["telkomsel_percentage"];
          double percentage = 0.0;
          if (percentageValue is num) {
            percentage = percentageValue.toDouble();
          } else if (percentageValue is String) {
            percentage = double.tryParse(percentageValue) ?? 0.0;
          }

          if (mounted) {
            setState(() {
              _telkomselPercentage = percentage;
              _updatePerformanceUI(percentage, context);
              _isLoadingPerformance = false;
              _performanceError = null;
            });
          }
        } else {
          throw Exception(data["message"] ?? "Data performa tidak lengkap dari server.");
        }
      } else {
        throw Exception("Kesalahan server: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _performanceError = "Gagal memuat data performa.";
          _isLoadingPerformance = false;
          _performanceStatus = "Error";
          _performanceColor = AppSemanticColors.performanceError(context);
          _telkomselPercentage = null;
        });
      }
    }
  }

  void _updatePerformanceUI(double percentage, BuildContext context) {
    if (percentage >= 50) {
      _performanceStatus = "Aman";
      _performanceColor = AppSemanticColors.performanceAman(context);
    } else if (percentage >= 30) {
      _performanceStatus = "Bahaya";
      _performanceColor = AppSemanticColors.performanceBahaya(context);
    } else {
      _performanceStatus = "Darurat";
      _performanceColor = AppSemanticColors.performanceDarurat(context);
    }
  }

  Widget _buildPerformanceIndicator(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
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
              _telkomselPercentage == null ? "Memuat Performa Telkomsel..." : "Memuat Ulang Performa...",
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CircularProgressIndicator(
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
              Icon(Icons.warning_amber_rounded, color: AppSemanticColors.warning(context), size: 35),
              const SizedBox(height: 8),
              Text(
                "Gagal Memuat Performa",
                style: textTheme.titleLarge?.copyWith(color: AppSemanticColors.warning(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _performanceError!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppSemanticColors.warning(context).withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Coba Lagi"),
                onPressed: _isLoadingPerformance ? null : _fetchTelkomselPerformance,
              ),
            ],
          ),
        ),
      );
    }
    
    if (_telkomselPercentage != null) _updatePerformanceUI(_telkomselPercentage!, context);
    else if (!isNormalUser) _performanceColor = AppSemanticColors.performanceNotAvailable(context);
    else _performanceColor = colorScheme.onSurface.withOpacity(0.6);

    final percentage = _telkomselPercentage ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Status Display Shared",
              style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _performanceStatus,
              style: textTheme.headlineSmall?.copyWith(color: _performanceColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage / 100.0,
                backgroundColor: colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(_performanceColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${percentage.toStringAsFixed(1)}%",
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    final String logoAsset = isDarkMode ? "images/Samalonian_app2.png" : "images/Samalonian_app.png";

    if (!_isLoadingPerformance && _performanceError == null) {
        if (_telkomselPercentage != null) {
            _updatePerformanceUI(_telkomselPercentage!, context);
        } else if (!isNormalUser) {
            _performanceColor = AppSemanticColors.performanceNotAvailable(context);
            _performanceStatus = "Tidak Tersedia";
        } else {
            _performanceColor = colorScheme.onSurface.withOpacity(0.6);
        }
    }

    IconData themeIcon;
    String themeTooltip;
    switch (themeNotifier.themeMode) {
      case ThemeMode.light:
        themeIcon = Icons.dark_mode_outlined;
        themeTooltip = "Ganti ke Mode Gelap";
        break;
      case ThemeMode.dark:
        themeIcon = Icons.brightness_auto_outlined;
        themeTooltip = "Ganti ke Mode Sistem";
        break;
      case ThemeMode.system:
      default:
        themeIcon = Icons.light_mode_outlined;
        themeTooltip = "Ganti ke Mode Terang";
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aplikasi Samalonian"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(themeIcon),
            tooltip: themeTooltip,
            onPressed: () {
              ThemeMode newMode;
              switch (themeNotifier.themeMode) {
                case ThemeMode.light:
                  newMode = ThemeMode.dark;
                  break;
                case ThemeMode.dark:
                  newMode = ThemeMode.system;
                  break;
                case ThemeMode.system:
                default:
                  newMode = ThemeMode.light;
                  break;
              }
              themeNotifier.setTheme(newMode);
            },
          ),
        ],
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
                  logoAsset, // Use theme-dependent logo
                  height: MediaQuery.of(context).size.height * 0.15,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading logo ($logoAsset): $error");
                    // Fallback to the default logo if the dark mode one fails, or show an icon
                    return Image.asset(
                      "images/Samalonian_app.png", 
                      height: MediaQuery.of(context).size.height * 0.15,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print("Error loading fallback logo: $error");
                        return Icon(Icons.image_not_supported_outlined, size: 60, color: colorScheme.onSurface.withOpacity(0.4));
                      }
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  "Selamat Datang, ${widget.username}!",
                  style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Pilih opsi di bawah untuk melanjutkan",
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildPerformanceIndicator(theme, colorScheme, textTheme),
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
    final ThemeData theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 24),
            const SizedBox(width: 8),
            Text("Akses Ditolak", style: theme.dialogTheme.titleTextStyle),
          ],
        ),
        content: Text("Anda tidak memiliki izin untuk mengakses halaman ini.", style: theme.dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Oke"),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Konfirmasi Keluar", style: theme.dialogTheme.titleTextStyle),
        content: Text("Apakah Anda yakin ingin keluar?", style: theme.dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
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
            child: Text("Keluar", style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BottomNavigationBarThemeData bottomNavTheme = theme.bottomNavigationBarTheme;

    return Material(
      elevation: bottomNavTheme.elevation ?? 8,
      color: bottomNavTheme.backgroundColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.primary, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavBarItem(
              icon: Icons.store_mall_directory_outlined,
              label: "Outlet PJP",
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
              label: "Non PJP",
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
              label: "Performa",
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
              icon: Icons.person_outline,
              label: "Akun",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AkunPage(username: username, userId: userId)),
                );
              },
            ),
            _NavBarItem(
              icon: Icons.logout_outlined,
              label: "Keluar",
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final BottomNavigationBarThemeData bottomNavTheme = theme.bottomNavigationBarTheme;

    // Determine color based on theme or explicit bottomNavTheme settings
    Color itemColor = bottomNavTheme.unselectedItemColor ?? colorScheme.onSurface.withOpacity(0.7);
    TextStyle labelStyle = bottomNavTheme.unselectedLabelStyle ?? textTheme.bodySmall!.copyWith(color: itemColor);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: itemColor, size: bottomNavTheme.unselectedIconTheme?.size ?? 24),
              const SizedBox(height: 4),
              Text(label, style: labelStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

