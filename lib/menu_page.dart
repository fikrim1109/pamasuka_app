import 'package:flutter/material.dart';
import 'package:pamasuka/rumah_page.dart';
import 'home_page.dart';
import 'login_page.dart';

class MenuPage extends StatelessWidget {
  final String username;
  final int userId;
  const MenuPage({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color softRed = const Color(0xFFF71212);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Samalonian APP',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        color: softRed,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white, // Mengatur warna latar belakang putih
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selamat datang, $username!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Image.asset(
                        'images/Samalonian APP.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(username: username, userId: userId),
      backgroundColor: Colors.white,
    );
  }
}

class BottomNavBar extends StatelessWidget {
  final String username;
  final int userId;

  const BottomNavBar({Key? key, required this.username, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color.fromARGB(255, 252, 252, 252)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarItem(
                label: 'Outlet PJP',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HomePage(username: username, userId: userId),
                    ),
                  );
                },
              ),
              _NavBarItem(
                label: 'Outlet Non PJP',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RumahPage(username: username, userId: userId),
                    ),
                  );
                },
              ),
              _NavBarItem(
                label: 'Logout',
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavBarItem({Key? key, required this.label, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: const Color.fromARGB(255, 243, 243, 243),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}