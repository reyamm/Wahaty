import 'package:flutter/material.dart';
import 'Kid_Mode.dart';
import 'Forbidden_word.dart';
import 'Activity_Log.dart';
import 'Usage_time.dart';

class ParentControlScreen extends StatefulWidget {
  const ParentControlScreen({super.key});

  @override
  State<ParentControlScreen> createState() => _ParentControlScreenState();
}

class _ParentControlScreenState extends State<ParentControlScreen> {
  bool isHomePressed = false;
  bool isForbiddenPressed = false;
  bool isActivityPressed = false;
  bool isUsagePressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 10,
                  child: GestureDetector(
                    onTapDown: (_) {
                      setState(() {
                        isHomePressed = true;
                      });
                    },
                    onTapUp: (_) async {
                      setState(() {
                        isHomePressed = false;
                      });
                      await Future.delayed(
                        const Duration(milliseconds: 120),
                      );
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KidModeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    onTapCancel: () {
                      setState(() {
                        isHomePressed = false;
                      });
                    },
                    child: AnimatedScale(
                      scale: isHomePressed ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/home_bg.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                            Image.asset(
                              'assets/images/home_icon.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 180),
                      const Center(
                        child: Text(
                          'وحدة التحكم',
                          style: TextStyle(
                            fontSize: 58,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E4D2B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 95),
                      _rockNavButton(
                        text: 'الكلمات الممنوعة',
                        isPressed: isForbiddenPressed,
                        onTapDown: () {
                          setState(() {
                            isForbiddenPressed = true;
                          });
                        },
                        onTapUp: () async {
                          setState(() {
                            isForbiddenPressed = false;
                          });
                          await Future.delayed(
                            const Duration(milliseconds: 120),
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForbiddenWordsScreen(),
                            ),
                          );
                        },
                        onTapCancel: () {
                          setState(() {
                            isForbiddenPressed = false;
                          });
                        },
                      ),
                      const SizedBox(height: 48),
                      _rockNavButton(
                        text: 'سجل النشاط',
                        isPressed: isActivityPressed,
                        onTapDown: () {
                          setState(() {
                            isActivityPressed = true;
                          });
                        },
                        onTapUp: () async {
                          setState(() {
                            isActivityPressed = false;
                          });
                          await Future.delayed(
                            const Duration(milliseconds: 120),
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ActivityLogScreen(),
                            ),
                          );
                        },
                        onTapCancel: () {
                          setState(() {
                            isActivityPressed = false;
                          });
                        },
                      ),
                      const SizedBox(height: 48),
                      _rockNavButton(
                        text: 'وقت الاستخدام',
                        isPressed: isUsagePressed,
                        onTapDown: () {
                          setState(() {
                            isUsagePressed = true;
                          });
                        },
                        onTapUp: () async {
                          setState(() {
                            isUsagePressed = false;
                          });
                          await Future.delayed(
                            const Duration(milliseconds: 120),
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UsageTimeScreen(),
                            ),
                          );
                        },
                        onTapCancel: () {
                          setState(() {
                            isUsagePressed = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rockNavButton({
    required String text,
    required bool isPressed,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
    required VoidCallback onTapCancel,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: AnimatedScale(
        scale: isPressed ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: 400,
          height: 125,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/rock.png',
                width: 400,
                height: 125,
                fit: BoxFit.contain,
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E4D2B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}