import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:blizzardping/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                FadeTransition(opacity: animation, child: const V2RayManager()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            FadeInDown(
              duration: const Duration(milliseconds: 1000),
              child: Container(
                width: size.width * 0.4,
                height: size.width * 0.4,
                padding: EdgeInsets.all(size.width * 0.05),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isDark
                          ? Colors.black.withOpacity(0.8)
                          : Colors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/splash_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.04),

            // App Name
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Text(
                'Blizzard Ping',
                style: TextStyle(
                  fontSize: size.width * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.02),

            // Subtitle
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 200),
              child: Text(
                'اتصال سریع و امن',
                style: TextStyle(
                  fontSize: size.width * 0.04,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.04),

            // Loading Indicator
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 400),
              child: SizedBox(
                width: size.width * 0.1,
                height: size.width * 0.1,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
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
