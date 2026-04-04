import 'dart:ui';
import 'package:flutter/material.dart';
import 'Kid_Mode.dart';
import 'ParentControlScreen.dart';
import '../database_helper.dart';
import '../session.dart';

class ParentPasswordScreen extends StatefulWidget {
  const ParentPasswordScreen({super.key});

  @override
  State<ParentPasswordScreen> createState() => _ParentPasswordScreenState();
}

class _ParentPasswordScreenState extends State<ParentPasswordScreen> {
  bool isNextPressed = false;
  bool isArrowPressed = false;

  final TextEditingController c1 = TextEditingController();
  final TextEditingController c2 = TextEditingController();
  final TextEditingController c3 = TextEditingController();
  final TextEditingController c4 = TextEditingController();

  final FocusNode f1 = FocusNode();
  final FocusNode f2 = FocusNode();
  final FocusNode f3 = FocusNode();
  final FocusNode f4 = FocusNode();

  @override
  void dispose() {
    c1.dispose();
    c2.dispose();
    c3.dispose();
    c4.dispose();
    f1.dispose();
    f2.dispose();
    f3.dispose();
    f4.dispose();
    super.dispose();
  }

  String get enteredPassword {
    return '${c1.text}${c2.text}${c3.text}${c4.text}';
  }

  Future<void> handleParentPassword() async {
    final parentId = Session.currentParentId;

    if (parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في الحساب'),
        ),
      );
      return;
    }

    if (c1.text.isEmpty || c2.text.isEmpty || c3.text.isEmpty || c4.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخلي 4 أرقام كاملة'),
        ),
      );
      return;
    }

    final password = enteredPassword;
    final savedPassword =
        await DatabaseHelper.instance.getParentPassword(parentId);

    if (savedPassword == null) {
      await DatabaseHelper.instance.saveParentPassword(
        parentId: parentId,
        password: password,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ParentControlScreen(),
        ),
      );
      return;
    }

    if (savedPassword == password) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ParentControlScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور غير صحيحة'),
        ),
      );
    }
  }

  Widget passBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required void Function(String) onChanged,
  }) {
    return SizedBox(
      width: 78,
      height: 94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/pass_buttom.png',
            width: 78,
            height: 94,
            fit: BoxFit.contain,
          ),
          SizedBox(
            width: 44,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 1,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF21411E),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
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
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          isArrowPressed = true;
                        });
                      },
                      onTapUp: (_) async {
                        setState(() {
                          isArrowPressed = false;
                        });
                        await Future.delayed(
                          const Duration(milliseconds: 120),
                        );
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KidModeScreen(),
                          ),
                        );
                      },
                      onTapCancel: () {
                        setState(() {
                          isArrowPressed = false;
                        });
                      },
                      child: AnimatedScale(
                        scale: isArrowPressed ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Image.asset(
                          'assets/images/back_arrow.png',
                          width: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(38),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 70),
                          padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
                          decoration: BoxDecoration(
                            color: const Color(0x24F6F8EA),
                            borderRadius: BorderRadius.circular(38),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.3,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 18),
                              const Text(
                                'أدخل كلمة المرور',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0B3B1A),
                                ),
                              ),
                              const SizedBox(height: 42),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  passBox(
                                    controller: c4,
                                    focusNode: f4,
                                    onChanged: (v) {},
                                  ),
                                  passBox(
                                    controller: c3,
                                    focusNode: f3,
                                    onChanged: (v) {
                                      if (v.isNotEmpty) {
                                        FocusScope.of(context).requestFocus(f4);
                                      } else {
                                        FocusScope.of(context).requestFocus(f2);
                                      }
                                    },
                                  ),
                                  passBox(
                                    controller: c2,
                                    focusNode: f2,
                                    onChanged: (v) {
                                      if (v.isNotEmpty) {
                                        FocusScope.of(context).requestFocus(f3);
                                      } else {
                                        FocusScope.of(context).requestFocus(f1);
                                      }
                                    },
                                  ),
                                  passBox(
                                    controller: c1,
                                    focusNode: f1,
                                    onChanged: (v) {
                                      if (v.isNotEmpty) {
                                        FocusScope.of(context).requestFocus(f2);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 54),
                              GestureDetector(
                                onTapDown: (_) {
                                  setState(() {
                                    isNextPressed = true;
                                  });
                                },
                                onTapUp: (_) async {
                                  setState(() {
                                    isNextPressed = false;
                                  });
                                  await Future.delayed(
                                    const Duration(milliseconds: 120),
                                  );
                                  if (!mounted) return;
                                  await handleParentPassword();
                                },
                                onTapCancel: () {
                                  setState(() {
                                    isNextPressed = false;
                                  });
                                },
                                child: AnimatedScale(
                                  scale: isNextPressed ? 0.97 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  child: AnimatedOpacity(
                                    opacity: isNextPressed ? 0.9 : 1.0,
                                    duration: const Duration(milliseconds: 120),
                                    child: Container(
                                      width: double.infinity,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A8D31),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'التالي',
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}