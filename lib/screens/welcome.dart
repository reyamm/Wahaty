import 'dart:math';
import 'package:flutter/material.dart';
import 'Log_In.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController yellowController;
  late AnimationController pinkController;
  late AnimationController greenController;

  late AnimationController yellowPulse;
  late AnimationController pinkPulse;
  late AnimationController greenPulse;

  late Animation<double> yellowScale;
  late Animation<double> pinkScale;
  late Animation<double> greenScale;

  late AnimationController startEntranceController;
  late Animation<Offset> startSlideAnimation;
  late Animation<double> startFadeAnimation;

  bool showYellow = false;
  bool showPink = false;
  bool showGreen = false;
  bool isStartPressed = false;

  final Random random = Random();

  @override
  void initState() {
    super.initState();

    yellowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    pinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    greenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    yellowPulse = AnimationController(vsync: this);
    pinkPulse = AnimationController(vsync: this);
    greenPulse = AnimationController(vsync: this);

    yellowScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: yellowController,
        curve: Curves.easeOutBack,
      ),
    );

    pinkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: pinkController,
        curve: Curves.easeOutBack,
      ),
    );

    greenScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: greenController,
        curve: Curves.easeOutBack,
      ),
    );

    startEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    startSlideAnimation = Tween<Offset>(
      begin: const Offset(0.8, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: startEntranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    startFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: startEntranceController,
        curve: Curves.easeOut,
      ),
    );

    startSequence();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        startEntranceController.forward();
      }
    });
  }

  Future<void> startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));

    setState(() => showYellow = true);
    await yellowController.forward();
    startPulse(yellowPulse);

    await Future.delayed(const Duration(milliseconds: 200));

    setState(() => showPink = true);
    await pinkController.forward();
    startPulse(pinkPulse);

    await Future.delayed(const Duration(milliseconds: 200));

    setState(() => showGreen = true);
    await greenController.forward();
    startPulse(greenPulse);
  }

  void startPulse(AnimationController controller) {
    controller.duration = Duration(milliseconds: 1500 + random.nextInt(1000));
    controller.repeat(reverse: true);
  }

  Widget blob({
    required bool visible,
    required Animation<double> scale,
    required AnimationController pulse,
    required String image,
    required String text,
    required double width,
    required Color textColor,
  }) {
    if (!visible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([scale, pulse]),
      builder: (context, child) {
        final pulseValue = 0.97 + (0.06 * pulse.value);

        return Transform.scale(
          scale: scale.value * pulseValue,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                image,
                width: width,
              ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    yellowController.dispose();
    pinkController.dispose();
    greenController.dispose();
    yellowPulse.dispose();
    pinkPulse.dispose();
    greenPulse.dispose();
    startEntranceController.dispose();
    super.dispose();
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
          Positioned(
            top: 190,
            left: 0,
            child: blob(
              visible: showPink,
              scale: pinkScale,
              pulse: pinkPulse,
              image: 'assets/images/pink blob.png',
              text: 'تعلّم',
              width: 220,
              textColor: const Color(0xFF5B2C5F),
            ),
          ),
          Positioned(
            top: 190,
            right: 0,
            child: blob(
              visible: showGreen,
              scale: greenScale,
              pulse: greenPulse,
              image: 'assets/images/green blob.png',
              text: 'استمتع',
              width: 230,
              textColor: const Color(0xFF355A44),
            ),
          ),
          Positioned(
            top: 350,
            left: 0,
            right: 0,
            child: Center(
              child: blob(
                visible: showYellow,
                scale: yellowScale,
                pulse: yellowPulse,
                image: 'assets/images/yellow blob.png',
                text: 'استكشف',
                width: 300,
                textColor: const Color(0xFF6A5B2A),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: startFadeAnimation,
              child: SlideTransition(
                position: startSlideAnimation,
                child: GestureDetector(
                  onTapDown: (_) {
                    setState(() {
                      isStartPressed = true;
                    });
                  },
                  onTapUp: (_) async {
                    setState(() {
                      isStartPressed = false;
                    });

                    await Future.delayed(const Duration(milliseconds: 120));

                    if (!mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  onTapCancel: () {
                    setState(() {
                      isStartPressed = false;
                    });
                  },
                  child: AnimatedScale(
                    scale: isStartPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: isStartPressed ? 0.9 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/cartoon.png',
                            height: 430,
                          ),
                          const Positioned(
                            bottom: 60,
                            child: Text(
                              'ابدأ الآن',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF113B68),
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
        ],
      ),
    );
  }
}