import 'dart:ui';
import 'package:flutter/material.dart';
import 'Child_Info.dart';
import '../database_helper.dart';
import '../session.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  bool isNextPressed = false;
  bool isBubblePressed = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late final AnimationController entranceController;
  late final AnimationController bubblePulseController;

  late final Animation<double> glassFadeAnimation;
  late final Animation<Offset> glassSlideAnimation;

  late final Animation<double> charFadeAnimation;
  late final Animation<Offset> charSlideAnimation;

  late final Animation<double> bubbleFadeAnimation;
  late final Animation<double> bubblePulseAnimation;

  @override
  void initState() {
    super.initState();

    entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    bubblePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    glassFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    glassSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    charFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.20, 0.60, curve: Curves.easeOut),
      ),
    );

    charSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.20, 0.75, curve: Curves.easeOutBack),
      ),
    );

    bubbleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.55, 0.90, curve: Curves.easeOut),
      ),
    );

    bubblePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(
      CurvedAnimation(
        parent: bubblePulseController,
        curve: Curves.easeInOut,
      ),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await entranceController.forward();

    for (int i = 0; i < 2; i++) {
      await bubblePulseController.forward();
      await bubblePulseController.reverse();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    entranceController.dispose();
    bubblePulseController.dispose();
    super.dispose();
  }

  Widget inputField({
    required String hint,
    required String iconPath,
    required TextEditingController controller,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(11),
            child: Image.asset(
              iconPath,
              width: 25,
              height: 25,
            ),
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D3D1D),
          ),
        ),
      ),
    );
  }

  Future<void> handleSignUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تعبئة الاسم والبريد الإلكتروني وكلمة المرور'),
        ),
      );
      return;
    }

    try {
      final parentId = await DatabaseHelper.instance.createParent(
        name: name,
        email: email,
        password: password,
      );

      Session.currentParentId = parentId;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChildInfoScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا البريد الإلكتروني مستخدم مسبقًا'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
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
              child: Column(
                children: [
                  const SizedBox(height: 38),
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B3B1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 150,
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: glassFadeAnimation,
                            child: SlideTransition(
                              position: glassSlideAnimation,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(38),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 2,
                                    sigmaY: 2,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      42,
                                      22,
                                      22,
                                    ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        inputField(
                                          hint: 'اسمك',
                                          iconPath:
                                              'assets/images/icon_user.png',
                                          controller: nameController,
                                        ),
                                        const SizedBox(height: 20),
                                        inputField(
                                          hint: 'البريد الالكتروني',
                                          iconPath:
                                              'assets/images/icon_email.png',
                                          controller: emailController,
                                        ),
                                        const SizedBox(height: 20),
                                        inputField(
                                          hint: 'كلمة المرور',
                                          iconPath:
                                              'assets/images/icon_password.png',
                                          controller: passwordController,
                                        ),
                                        const SizedBox(height: 46),
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
                                            await handleSignUp();
                                          },
                                          onTapCancel: () {
                                            setState(() {
                                              isNextPressed = false;
                                            });
                                          },
                                          child: AnimatedScale(
                                            scale: isNextPressed ? 0.97 : 1.0,
                                            duration: const Duration(
                                              milliseconds: 120,
                                            ),
                                            child: AnimatedOpacity(
                                              opacity:
                                                  isNextPressed ? 0.9 : 1.0,
                                              duration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              child: Container(
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF0A8D31),
                                                  borderRadius:
                                                      BorderRadius.circular(13),
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    'التالي',
                                                    style: TextStyle(
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.w900,
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
                          ),
                        ),
                        Positioned(
                          top: 28,
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: charFadeAnimation,
                            child: SlideTransition(
                              position: charSlideAnimation,
                              child: Center(
                                child: Image.asset(
                                  'assets/images/hi_char.png',
                                  height: 165,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: bubbleFadeAnimation,
                            child: GestureDetector(
                              onTapDown: (_) {
                                setState(() {
                                  isBubblePressed = true;
                                });
                              },
                              onTapUp: (_) async {
                                setState(() {
                                  isBubblePressed = false;
                                });
                                await Future.delayed(
                                  const Duration(milliseconds: 120),
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                              },
                              onTapCancel: () {
                                setState(() {
                                  isBubblePressed = false;
                                });
                              },
                              child: AnimatedScale(
                                scale: isBubblePressed ? 0.96 : 1.0,
                                duration: const Duration(milliseconds: 120),
                                child: Center(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: bubblePulseAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: bubblePulseAnimation.value,
                                            child: child,
                                          );
                                        },
                                        child: Image.asset(
                                          'assets/images/bubble_login.png',
                                          width: 300,
                                        ),
                                      ),
                                      const Text(
                                        'لدي حساب سابق',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1B1B1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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