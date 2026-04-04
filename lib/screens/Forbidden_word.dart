import 'dart:ui';
import 'package:flutter/material.dart';
import 'ParentControlScreen.dart';
import '../database_helper.dart';
import '../session.dart';

class ForbiddenWordsScreen extends StatefulWidget {
  const ForbiddenWordsScreen({super.key});

  @override
  State<ForbiddenWordsScreen> createState() => _ForbiddenWordsScreenState();
}

class _ForbiddenWordsScreenState extends State<ForbiddenWordsScreen> {
  final TextEditingController wordController = TextEditingController();
  final FocusNode wordFocusNode = FocusNode();

  final List<Map<String, dynamic>> forbiddenWords = [];

  bool showAddBar = false;
  bool isAddPressed = false;
  bool isSavePressed = false;
  bool isBackPressed = false;

  @override
  void initState() {
    super.initState();
    loadForbiddenWords();
  }

  @override
  void dispose() {
    wordController.dispose();
    wordFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadForbiddenWords() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final words = await DatabaseHelper.instance.getForbiddenWords(parentId);

    if (!mounted) return;
    setState(() {
      forbiddenWords
        ..clear()
        ..addAll(words);
    });
  }

  Future<void> addWord() async {
    final word = wordController.text.trim();
    final parentId = Session.currentParentId;

    if (word.isEmpty || parentId == null) return;

    final alreadyExists = forbiddenWords.any(
      (item) => item['word'].toString().trim() == word,
    );

    if (alreadyExists) {
      wordController.clear();
      return;
    }

    await DatabaseHelper.instance.addForbiddenWord(
      parentId: parentId,
      word: word,
    );

    wordController.clear();
    await loadForbiddenWords();
  }

  Future<void> removeWord(int id) async {
    await DatabaseHelper.instance.deleteForbiddenWord(id);
    await loadForbiddenWords();
  }

  Widget forbiddenChip(Map<String, dynamic> item) {
    final int id = item['id'] as int;
    final String word = item['word'].toString();

    return SizedBox(
      width: 150,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/added.png',
            width: 150,
            height: 66,
            fit: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E9155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => removeWord(id),
                  child: Image.asset(
                    'assets/images/cross.png',
                    width: 35,
                    height: 35,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget addButton() {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isAddPressed = true;
        });
      },
      onTapUp: (_) async {
        setState(() {
          isAddPressed = false;
          showAddBar = true;
        });
        await Future.delayed(const Duration(milliseconds: 80));
        if (!mounted) return;
        FocusScope.of(context).requestFocus(wordFocusNode);
      },
      onTapCancel: () {
        setState(() {
          isAddPressed = false;
        });
      },
      child: AnimatedScale(
        scale: isAddPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: 150,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/addbox.png',
                width: 150,
                height: 62,
                fit: BoxFit.contain,
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'إضافة',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '+',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget addInputBox() {
    return Expanded(
      child: SizedBox(
        height: 62,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/addnew.png',
              width: double.infinity,
              height: 62,
              fit: BoxFit.fill,
            ),
            TextField(
              controller: wordController,
              focusNode: wordFocusNode,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6E9155),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'أضف كلمة جديدة',
                hintStyle: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6E9155),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
              ),
              onSubmitted: (_) async {
                await addWord();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget addArea() {
    if (!showAddBar) {
      return Align(
        alignment: Alignment.centerRight,
        child: addButton(),
      );
    }

    return Row(
      children: [
        addInputBox(),
        const SizedBox(width: 10),
        addButton(),
      ],
    );
  }

  Widget wordsWrap() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: forbiddenWords.map((item) => forbiddenChip(item)).toList(),
    );
  }

  Future<void> handleSave() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ الكلمات الممنوعة'),
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
                        'الكلمات الممنوعة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E4D2B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'الكلمات التي لن يسمح للطفل بكتابتها\nأو استخدامها',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                            child: Container(
                              width: double.infinity,
                              height: 380,
                              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
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
                                  addArea(),
                                  const SizedBox(height: 28),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: SingleChildScrollView(
                                        child: wordsWrap(),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTapDown: (_) {
                                      setState(() {
                                        isSavePressed = true;
                                      });
                                    },
                                    onTapUp: (_) async {
                                      setState(() {
                                        isSavePressed = false;
                                      });
                                      await Future.delayed(
                                        const Duration(milliseconds: 100),
                                      );
                                      if (!mounted) return;
                                      await handleSave();
                                    },
                                    onTapCancel: () {
                                      setState(() {
                                        isSavePressed = false;
                                      });
                                    },
                                    child: AnimatedScale(
                                      scale: isSavePressed ? 0.97 : 1.0,
                                      duration: const Duration(milliseconds: 120),
                                      child: Container(
                                        width: 310,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF18C34A),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'حفظ',
                                            style: TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}