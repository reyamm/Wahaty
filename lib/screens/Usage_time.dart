import 'dart:ui';
import 'package:flutter/material.dart';
import 'ParentControlScreen.dart';
import '../database_helper.dart';
import '../session.dart';

class UsageTimeScreen extends StatefulWidget {
  const UsageTimeScreen({super.key});

  @override
  State<UsageTimeScreen> createState() => _UsageTimeScreenState();
}

class _UsageTimeScreenState extends State<UsageTimeScreen> {
  bool isBackPressed = false;
  bool isOn = false;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    loadUsageSettings();
  }

  Future<void> loadUsageSettings() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final settings =
        await DatabaseHelper.instance.getUsageSettings(parentId);

    if (settings == null) return;

    if (!mounted) return;
    setState(() {
      selectedIndex = settings['selected_index'] as int;
      isOn = (settings['auto_stop'] as int) == 1;
    });
  }

  Future<void> saveUsageSettings() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    await DatabaseHelper.instance.saveUsageSettings(
      parentId: parentId,
      selectedIndex: selectedIndex,
      autoStop: isOn,
    );
  }

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          isBackPressed = true;
                        });
                      },
                      onTapUp: (_) async {
                        setState(() {
                          isBackPressed = false;
                        });
                        await Future.delayed(
                          const Duration(milliseconds: 120),
                        );
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentControlScreen(),
                          ),
                        );
                      },
                      onTapCancel: () {
                        setState(() {
                          isBackPressed = false;
                        });
                      },
                      child: AnimatedScale(
                        scale: isBackPressed ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Image.asset(
                          'assets/images/back_arrow.png',
                          width: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 180),
                      const Text(
                        'وقت الاستخدام',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E4D2B),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                          child: Container(
                            width: double.infinity,
                            height: 420,
                            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                            decoration: BoxDecoration(
                              color: const Color(0x24F6F8EA),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'تحديد الحد اليومي',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E4D2B),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'حدد عدد الساعات المتاحة للاستخدام يوميا',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4FAF54),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: timeButton('٢ ساعة', 2),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: timeButton('١ ساعة', 1),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: timeButton('٣٠ دقيقة', 0),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 60),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 18),
                                        child: Text(
                                          'تفعيل الإيقاف التلقائي عند انتهاء الوقت',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1E4D2B),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () async {
                                        setState(() {
                                          isOn = !isOn;
                                        });
                                        await saveUsageSettings();
                                      },
                                      child: Image.asset(
                                        isOn
                                            ? 'assets/images/switch_on.png'
                                            : 'assets/images/switch_off.png',
                                        width: 75,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget timeButton(String text, int index) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () async {
        setState(() {
          selectedIndex = index;
        });
        await saveUsageSettings();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A7C3E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.55), width: 1)
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : const Color(0xFF1E4D2B),
            ),
          ),
        ),
      ),
    );
  }
}