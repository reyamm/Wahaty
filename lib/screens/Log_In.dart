import 'dart:ui';
import 'package:flutter/material.dart';
import 'Kid_Mode.dart';
import 'Sign_In.dart';
import '../database_helper.dart';
import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool isNextPressed = false;
  bool isBubblePressed = false;

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
    emailController.dispose();
    passwordController.dispose();
    entranceController.dispose();
    bubblePulseController.dispose();
    super.dispose();
  }

  Widget inputField(
    String label,
    String iconPath,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0D3D1D),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(11),
                child: Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تعبئة البريد الإلكتروني وكلمة المرور'),
        ),
      );
      return;
    }

    final parent = await DatabaseHelper.instance.loginParent(
      email: email,
      password: password,
    );

    if (parent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('البريد الإلكتروني أو كلمة المرور غير صحيحة'),
        ),
      );
      return;
    }

    Session.currentParentId = parent['id'] as int;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KidModeScreen(),
      ),
    );
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
                    'مرحبًا بعودتك',
                    style: TextStyle(
                      fontSize: 50,
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
                                      40,
                                      22,
                                      20,
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
                                          'البريد الإلكتروني',
                                          'assets/images/icon_user.png',
                                          emailController,
                                        ),
                                        const SizedBox(height: 22),
                                        inputField(
                                          'كلمة المرور',
                                          'assets/images/icon_password.png',
                                          passwordController,
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
                                            await handleLogin();
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
                          top: 16,
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: charFadeAnimation,
                            child: SlideTransition(
                              position: charSlideAnimation,
                              child: Center(
                                child: Image.asset(
                                  'assets/images/wink_char.png',
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
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
                                          'assets/images/bubble_create_account.png',
                                          width: 300,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 30,
                                        ),
                                        child: Text(
                                          'ماعندك حساب ؟\nخلينا نسوي لك واحد جديد',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 24,
                                            height: 1.28,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1B1B1B),
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