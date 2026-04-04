import 'dart:ui';
import 'package:flutter/material.dart';
import 'Kid_Mode.dart';
import '../database_helper.dart';
import '../session.dart';

class ChildInfoScreen extends StatefulWidget {
  const ChildInfoScreen({super.key});

  @override
  State<ChildInfoScreen> createState() => _ChildInfoScreenState();
}

class _ChildInfoScreenState extends State<ChildInfoScreen> {
  String selectedGender = '';
  bool isNextPressed = false;

  final TextEditingController childNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  @override
  void dispose() {
    childNameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Widget sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0D3D1D),
        ),
      ),
    );
  }

  Widget inputField(TextEditingController controller) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget genderCard(String label, String imagePath) {
    final isSelected = selectedGender == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGender = label;
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 170,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0x99F2EDAC),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? const Color(0xFF0C8E34) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                imagePath,
                height: 130,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D3A1A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0D3A1A),
                        width: 1.8,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0C8E34),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> handleChildInfo() async {
    final childName = childNameController.text.trim();
    final age = ageController.text.trim();
    final gender = selectedGender.trim();
    final parentId = Session.currentParentId;

    if (childName.isEmpty || age.isEmpty || gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تعبئة جميع بيانات الطفل'),
        ),
      );
      return;
    }

    if (parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في بيانات الحساب'),
        ),
      );
      return;
    }

    await DatabaseHelper.instance.createChild(
      parentId: parentId,
      childName: childName,
      age: age,
      gender: gender,
    );

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
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 790),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                      decoration: BoxDecoration(
                        color: const Color(0x20F6F8EA),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.2,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                'معلومات الطفل',
                                style: TextStyle(
                                  fontSize: 33,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0B3B1A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 34),
                            sectionLabel('اسم الطفل'),
                            const SizedBox(height: 10),
                            inputField(childNameController),
                            const SizedBox(height: 22),
                            sectionLabel('عمر الطفل'),
                            const SizedBox(height: 10),
                            inputField(ageController),
                            const SizedBox(height: 28),
                            const Center(
                              child: Text(
                                'جنس الطفل',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0B3B1A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                genderCard('أنثى', 'assets/images/girl.png'),
                                genderCard('ذكر', 'assets/images/boy.png'),
                              ],
                            ),
                            const SizedBox(height: 65),
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
                                await handleChildInfo();
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
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A8D31),
                                      borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 4),
                          ],
                        ),
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