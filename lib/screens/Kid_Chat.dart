import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'Kid_Mode.dart';
import '../database_helper.dart';
import '../session.dart';

class KidChatScreen extends StatefulWidget {
  const KidChatScreen({super.key});

  @override
  State<KidChatScreen> createState() => _KidChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}

class _KidChatScreenState extends State<KidChatScreen>
    with TickerProviderStateMixin {
  bool isArrowPressed = false;

  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final ScrollController chatScrollController = ScrollController();

  final List<ChatMessage> messages = [];
  List<String> forbiddenWords = [];

  String childName = 'طفلي';

  bool autoStopEnabled = false;
  int selectedUsageIndex = 0;
  DateTime? chatSessionStartTime;
  bool isUsageBlocked = false;
  bool usageDialogShown = false;
  bool usageLogAdded = false;
  Timer? usageTimer;

  late final AnimationController entranceController;
  late final AnimationController bubbleFloatController;

  late final Animation<Offset> arrowSlideAnimation;
  late final Animation<double> arrowFadeAnimation;

  late final Animation<Offset> bubbleSlideAnimation;
  late final Animation<double> bubbleFadeAnimation;

  late final Animation<Offset> boxSlideAnimation;
  late final Animation<double> boxFadeAnimation;

  late final Animation<double> bubbleFloatAnimation;

  @override
  void initState() {
    super.initState();

    entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    bubbleFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    arrowSlideAnimation = Tween<Offset>(
      begin: const Offset(0.8, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    arrowFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.0, 0.3),
      ),
    );

    bubbleSlideAnimation = Tween<Offset>(
      begin: const Offset(0.9, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.15, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    bubbleFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.15, 0.55),
      ),
    );

    boxSlideAnimation = Tween<Offset>(
      begin: const Offset(0.8, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    boxFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: entranceController,
        curve: const Interval(0.35, 0.75),
      ),
    );

    bubbleFloatAnimation = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(
      CurvedAnimation(
        parent: bubbleFloatController,
        curve: Curves.easeInOut,
      ),
    );

    _startAnimations();
    loadChildName();
    loadForbiddenWords();
    loadUsageSettings();
  }

  Future<void> loadChildName() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final child = await DatabaseHelper.instance.getChild(parentId);

    if (!mounted) return;

    if (child != null) {
      setState(() {
        childName = (child['child_name'] ?? 'طفلي').toString();
      });
    }
  }

  Future<void> _startAnimations() async {
    await entranceController.forward();
    await bubbleFloatController.forward();
    await bubbleFloatController.reverse();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!chatScrollController.hasClients) return;
      chatScrollController.animateTo(
        chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> loadForbiddenWords() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final words = await DatabaseHelper.instance.getForbiddenWords(parentId);

    if (!mounted) return;
    setState(() {
      forbiddenWords = words
          .map((item) => item['word'].toString().trim().toLowerCase())
          .toList();
    });
  }

  Future<void> loadUsageSettings() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final settings = await DatabaseHelper.instance.getUsageSettings(parentId);

    if (settings != null) {
      autoStopEnabled = (settings['auto_stop'] as int) == 1;
      selectedUsageIndex = settings['selected_index'] as int;
    }

    chatSessionStartTime = DateTime.now();
    startUsageTimer();

    if (!mounted) return;
    setState(() {});
  }

  void startUsageTimer() {
    usageTimer?.cancel();

    usageTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || !autoStopEnabled || chatSessionStartTime == null) return;

      final now = DateTime.now();
      final elapsedMinutes = now.difference(chatSessionStartTime!).inMinutes;
      final allowedMinutes = getAllowedMinutes();

      if (elapsedMinutes >= allowedMinutes && !isUsageBlocked) {
        setState(() {
          isUsageBlocked = true;
        });

        await addUsageEndLog();

        if (!usageDialogShown && mounted) {
          usageDialogShown = true;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) {
              return AlertDialog(
                title: const Text('انتهى وقت الاستخدام'),
                content: const Text('يمكنك الرجوع الآن'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('حسنًا'),
                  ),
                ],
              );
            },
          );
        }
      }
    });
  }

  int getAllowedMinutes() {
    switch (selectedUsageIndex) {
      case 0:
        return 30;
      case 1:
        return 60;
      case 2:
        return 120;
      default:
        return 30;
    }
  }

  String formatArabicTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final int minute = dateTime.minute;
    final bool isPm = hour >= 12;

    hour = hour % 12;
    if (hour == 0) hour = 12;

    final String minuteText = minute.toString().padLeft(2, '0');
    final String period = isPm ? 'م' : 'ص';

    return '$hour:$minuteText $period';
  }

  String getDayLabel(DateTime now) {
    return 'اليوم';
  }

  Future<void> addForbiddenWordLog(String word) async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final now = DateTime.now();

    await DatabaseHelper.instance.addActivityLog(
      parentId: parentId,
      title: 'تم محاولة استخدام كلمة محظورة',
      details: 'الكلمة المحظورة: $word',
      time: '${formatArabicTime(now)} — ${formatArabicTime(now)}',
      dayLabel: getDayLabel(now),
      iconType: 'not_allowed',
      createdAt: now.toIso8601String(),
    );
  }

  Future<void> addUsageEndLog() async {
    if (usageLogAdded) return;

    final parentId = Session.currentParentId;
    if (parentId == null || chatSessionStartTime == null) return;

    final now = DateTime.now();
    final start = formatArabicTime(chatSessionStartTime!);
    final end = formatArabicTime(now);
    final usedMinutes = now.difference(chatSessionStartTime!).inMinutes;

    await DatabaseHelper.instance.addActivityLog(
      parentId: parentId,
      title: 'انتهى وقت الاستخدام داخل الشات',
      details: 'تم استخدام الشات لمدة $usedMinutes دقيقة',
      time: '$start — $end',
      dayLabel: getDayLabel(now),
      iconType: 'not_allowed',
      createdAt: now.toIso8601String(),
    );

    usageLogAdded = true;
  }

  bool containsForbiddenWord(String text) {
    final normalizedText = text.trim().toLowerCase();

    for (final word in forbiddenWords) {
      if (word.isNotEmpty && normalizedText.contains(word)) {
        return true;
      }
    }
    return false;
  }

  String firstForbiddenWord(String text) {
    final normalizedText = text.trim().toLowerCase();

    for (final word in forbiddenWords) {
      if (word.isNotEmpty && normalizedText.contains(word)) {
        return word;
      }
    }
    return '';
  }

  Future<String> getBotReply(String text) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'child_name': childName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['answer'] != null) {
          return data['answer'].toString();
        }
      }

      return 'عذرًا، لم أستطع الرد الآن';
    } catch (e) {
      return 'تعذر الاتصال بالنظام الآن';
    }
  }

  Future<void> sendMessage() async {
    if (isUsageBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهى الوقت المسموح'),
        ),
      );
      return;
    }

    final text = messageController.text.trim();
    if (text.isEmpty) return;

    if (containsForbiddenWord(text)) {
      final blockedWord = firstForbiddenWord(text);

      await addForbiddenWordLog(blockedWord);

      messageController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الكلمة غير مسموح باستخدامها'),
        ),
      );
      return;
    }

    setState(() {
      messages.add(ChatMessage(text: text, isUser: true));
    });

    messageController.clear();
    messageFocusNode.requestFocus();
    scrollToBottom();

    final botReply = await getBotReply(text);

    if (!mounted) return;

    setState(() {
      messages.add(ChatMessage(text: botReply, isUser: false));
    });

    scrollToBottom();
  }

  @override
  void dispose() {
    usageTimer?.cancel();
    messageController.dispose();
    messageFocusNode.dispose();
    chatScrollController.dispose();
    entranceController.dispose();
    bubbleFloatController.dispose();
    super.dispose();
  }

  Widget userMessageBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 220,
              maxHeight: 120,
            ),
            margin: const EdgeInsets.only(bottom: 12, left: 60),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFD89A3B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: SingleChildScrollView(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D4D2D),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget botMessageBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 285,
              maxHeight: 180,
            ),
            margin: const EdgeInsets.only(bottom: 14, right: 40),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFDDE8A6).withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: SingleChildScrollView(
              child: Text(
                text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3F4C22),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMessageBubble(ChatMessage message) {
    if (message.isUser) {
      return userMessageBubble(message.text);
    }
    return botMessageBubble(message.text);
  }

  Widget buildInputArea(double screenWidth) {
    return FadeTransition(
      opacity: boxFadeAnimation,
      child: SlideTransition(
        position: boxSlideAnimation,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Image.asset(
              'assets/images/question_box.png',
              width: screenWidth,
              height: 360,
              fit: BoxFit.fill,
            ),
            Positioned(
              top: 168,
              left: 45,
              right: 45,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: messageController,
                  focusNode: messageFocusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) async {
                    await sendMessage();
                  },
                  enabled: !isUsageBlocked,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6A6B44),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '... اكتب سؤالك هنا',
                    hintStyle: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6A6B44),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_kid.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: FadeTransition(
                    opacity: arrowFadeAnimation,
                    child: SlideTransition(
                      position: arrowSlideAnimation,
                      child: Align(
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
                              width: 150,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (messages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: FadeTransition(
                      opacity: bubbleFadeAnimation,
                      child: SlideTransition(
                        position: bubbleSlideAnimation,
                        child: AnimatedBuilder(
                          animation: bubbleFloatAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, bubbleFloatAnimation.value),
                              child: child,
                            );
                          },
                          child: Center(
                            child: Image.asset(
                              'assets/images/intro_bubble.png',
                              width: 480,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(
                        overscroll: false,
                      ),
                      child: ListView.builder(
                        controller: chatScrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return buildMessageBubble(messages[index]);
                        },
                      ),
                    ),
                  ),
                ),
                buildInputArea(screenWidth),
              ],
            ),
          ),
          if (isUsageBlocked)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}