import 'dart:ui';
import 'package:flutter/material.dart';
import 'ParentControlScreen.dart';
import '../database_helper.dart';
import '../session.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  bool isBackPressed = false;

  List<Map<String, dynamic>> todayLogs = [];
  List<Map<String, dynamic>> yesterdayLogs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final logs =
        await DatabaseHelper.instance.getActivityLogs(parentId);

    List<Map<String, dynamic>> today = [];
    List<Map<String, dynamic>> yesterday = [];

    for (var log in logs) {
      if (log['day_label'] == 'اليوم') {
        today.add(log);
      } else if (log['day_label'] == 'أمس') {
        yesterday.add(log);
      }
    }

    if (!mounted) return;
    setState(() {
      todayLogs = today;
      yesterdayLogs = yesterday;
    });
  }

  String getIconPath(String type) {
    if (type == 'not_allowed') {
      return 'assets/images/not_allowed.png';
    }
    return 'assets/images/check_icon.png';
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
                            builder: (_) =>
                                const ParentControlScreen(),
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
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 180),
                      const Text(
                        'سجل النشاط',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E4D2B),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 18),
                              decoration: BoxDecoration(
                                color: const Color(0x24F6F8EA),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [

                                    if (todayLogs.isNotEmpty) ...[
                                      const Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'اليوم',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      ...todayLogs.map((log) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: activityCard(
                                            time: log['time'],
                                            text: log['details'],
                                            iconPath: getIconPath(log['icon_type']),
                                          ),
                                        );
                                      }),
                                    ],

                                    if (yesterdayLogs.isNotEmpty) ...[
                                      const SizedBox(height: 24),
                                      const Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'أمس',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      ...yesterdayLogs.map((log) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: activityCard(
                                            time: log['time'],
                                            text: log['details'],
                                            iconPath: getIconPath(log['icon_type']),
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
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

  Widget activityCard({
    required String time,
    required String text,
    required String iconPath,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x9D73DB73),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  time,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Image.asset(
                iconPath,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}