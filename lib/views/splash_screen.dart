import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../main.dart'; // Your MainScreen import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    // Prepare a controller, but don’t set a duration yet
    _logoController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // When Lottie finishes its single run, navigate
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ));
        }
      });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Cinematic gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade900, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The Lottie animation – we hook its duration into our controller
              SizedBox(
                width: 140,
                height: 140,
                child: Lottie.asset(
                  'assets/animated_logo_for_splash_screen.json',
                  controller: _logoController,
                  fit: BoxFit.contain,
                  onLoaded: (composition) {
                    // Set our controller’s duration to match the Lottie
                    _logoController
                      ..duration = composition.duration
                      ..forward();
                  },
                  repeat: false,
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _logoController.drive(
                  CurveTween(curve: Curves.easeOut),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Movie Recommendations',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 12),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
