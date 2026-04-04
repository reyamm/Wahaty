import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

import 'Kid_Chat.dart';
import 'Parent_Password.dart';
import '../database_helper.dart';
import '../session.dart';

class KidModeScreen extends StatefulWidget {
  const KidModeScreen({super.key});

  @override
  State<KidModeScreen> createState() => _KidModeScreenState();
}

class _KidModeScreenState extends State<KidModeScreen> {
  bool isMicOn = false;
  bool isMenuPressed = false;
  bool isChatPressed = false;
  bool isMicPressed = false;

  int mouthState = 0;
  Timer? mouthTimer;
  Timer? usageTimer;
  StreamSubscription<PlayerState>? playerStateSubscription;

  bool autoStopEnabled = false;
  int selectedUsageIndex = 0;
  DateTime? sessionStartTime;
  bool isUsageBlocked = false;
  bool usageDialogShown = false;
  bool usageLogAdded = false;

  final AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();

  String? recordedFilePath;
  bool isSendingVoice = false;
  bool isSpeaking = false;

  String childName = 'طفلي';

  @override
  void initState() {
    super.initState();
    loadChildName();
    loadUsageSettings();

    playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      if (state == PlayerState.playing) {
        startMouthAnimation();
      } else {
        stopMouthAnimation();
      }
    });
  }

  Future<void> loadChildName() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final child = await DatabaseHelper.instance.getChildByParentId(parentId);

    if (!mounted) return;

    if (child != null && child['child_name'] != null) {
      setState(() {
        childName = child['child_name'].toString().trim();
      });
    }
  }

  Future<void> requestMicPermission() async {
    await Permission.microphone.request();
  }

  void startMouthAnimation() {
    mouthTimer?.cancel();

    setState(() {
      isSpeaking = true;
    });

    mouthTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted) return;
      setState(() {
        mouthState = (mouthState + 1) % 3;
      });
    });
  }

  void stopMouthAnimation() {
    mouthTimer?.cancel();

    if (!mounted) return;
    setState(() {
      isSpeaking = false;
      mouthState = 0;
    });
  }

  Future<void> startVoiceRecording() async {
    await requestMicPermission();

    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لازم تسمحين بالمايك أول'),
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    recordedFilePath = '${dir.path}/kid_voice.m4a';

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: recordedFilePath!,
    );
  }

  Future<void> stopVoiceRecordingAndSend() async {
    final path = await recorder.stop();

    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ما تم تسجيل الصوت'),
        ),
      );
      return;
    }

    setState(() {
      isSendingVoice = true;
    });

    try {
      final uri = Uri.parse('http://10.0.2.2:8000/voice-chat');
      final request = http.MultipartRequest('POST', uri);

      request.fields['child_name'] = childName;

      request.files.add(
        await http.MultipartFile.fromPath('file', path),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Server error: ${streamedResponse.statusCode}');
      }

      final data = jsonDecode(responseBody);
      final answer = (data['answer'] ?? '').toString();
      final audioBase64 = (data['audio_base64'] ?? '').toString();

      if (audioBase64.isNotEmpty) {
        final bytes = base64Decode(audioBase64);
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/reply.wav');
        await audioFile.writeAsBytes(bytes, flush: true);

        await player.stop();
        await player.play(DeviceFileSource(audioFile.path));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              answer.isNotEmpty ? answer : 'ما وصل صوت الرد',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('صار خطأ أثناء إرسال الصوت'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingVoice = false;
        });
      }
    }
  }

  Future<void> loadUsageSettings() async {
    final parentId = Session.currentParentId;
    if (parentId == null) return;

    final settings = await DatabaseHelper.instance.getUsageSettings(parentId);

    if (settings != null) {
      autoStopEnabled = (settings['auto_stop'] as int) == 1;
      selectedUsageIndex = settings['selected_index'] as int;
    }

    sessionStartTime = DateTime.now();
    startUsageTimer();

    if (!mounted) return;
    setState(() {});
  }

  void startUsageTimer() {
    usageTimer?.cancel();

    usageTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || !autoStopEnabled || sessionStartTime == null) return;

      final now = DateTime.now();
      final elapsedMinutes = now.difference(sessionStartTime!).inMinutes;
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
                content: const Text('انتهى الوقت المسموح لاستخدام التطبيق اليوم'),
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

  Future<void> addUsageEndLog() async {
    if (usageLogAdded) return;

    final parentId = Session.currentParentId;
    if (parentId == null || sessionStartTime == null) return;

    final now = DateTime.now();

    await DatabaseHelper.instance.addActivityLog(
      parentId: parentId,
      title: 'انتهى وقت الاستخدام',
      details: 'تم انتهاء وقت الاستخدام',
      time: '',
      dayLabel: 'اليوم',
      iconType: 'not_allowed',
      createdAt: now.toIso8601String(),
    );

    usageLogAdded = true;
  }

  String getMouthImage() {
    switch (mouthState) {
      case 0:
        return 'assets/images/closed_mouth.png';
      case 1:
        return 'assets/images/half_open.png';
      default:
        return 'assets/images/open_mouth.png';
    }
  }

  Future<void> handleChatTap() async {
    if (isUsageBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهى الوقت المسموح'),
        ),
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KidChatScreen(),
      ),
    );
  }

  Future<void> handleMicTap() async {
    if (isUsageBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهى الوقت المسموح'),
        ),
      );
      return;
    }

    if (isSendingVoice) return;

    if (!isMicOn) {
      await startVoiceRecording();

      if (!mounted) return;
      setState(() {
        isMicOn = true;
      });
    } else {
      if (!mounted) return;
      setState(() {
        isMicOn = false;
      });

      await stopVoiceRecordingAndSend();
    }
  }

  @override
  void dispose() {
    mouthTimer?.cancel();
    usageTimer?.cancel();
    playerStateSubscription?.cancel();
    recorder.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_kid.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => isMenuPressed = true),
                      onTapUp: (_) async {
                        setState(() => isMenuPressed = false);
                        await Future.delayed(const Duration(milliseconds: 120));
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentPasswordScreen(),
                          ),
                        );
                      },
                      onTapCancel: () => setState(() => isMenuPressed = false),
                      child: AnimatedScale(
                        scale: isMenuPressed ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: _glitterButton(
                          glitterPath: 'assets/images/green_glitter.png',
                          iconPath: 'assets/images/Menu.png',
                          width: 112,
                          height: 112,
                          iconSize: 42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '! اسألني',
                    style: TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5A3B1D),
                    ),
                  ),
                  Expanded(
                    child: OverflowBox(
                      maxHeight: 1000,
                      child: Transform.translate(
                        offset: const Offset(0, 30),
                        child: Center(
                          child: Image.asset(
                            getMouthImage(),
                            height: 650,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTapDown: (_) => setState(() => isChatPressed = true),
                        onTapUp: (_) async {
                          setState(() => isChatPressed = false);
                          await handleChatTap();
                        },
                        onTapCancel: () => setState(() => isChatPressed = false),
                        child: AnimatedScale(
                          scale: isChatPressed ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          child: _glitterButton(
                            glitterPath: 'assets/images/yellow_glitter.png',
                            iconPath: 'assets/images/chat.png',
                            width: 152,
                            height: 128,
                            iconSize: 62,
                          ),
                        ),
                      ),
                      const SizedBox(width: 70),
                      GestureDetector(
                        onTapDown: (_) => setState(() => isMicPressed = true),
                        onTapUp: (_) async {
                          setState(() {
                            isMicPressed = false;
                          });
                          await handleMicTap();
                        },
                        onTapCancel: () => setState(() => isMicPressed = false),
                        child: AnimatedScale(
                          scale: isMicPressed ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          child: _glitterButton(
                            glitterPath: 'assets/images/yellow_glitter.png',
                            iconPath: isMicOn
                                ? 'assets/images/mic_on.png'
                                : 'assets/images/mic_off.png',
                            width: 152,
                            height: 128,
                            iconSize: 62,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
          if (isUsageBlocked)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              bottom: 0,
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

  Widget _glitterButton({
    required String glitterPath,
    required String iconPath,
    required double width,
    required double height,
    required double iconSize,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            glitterPath,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
          Image.asset(
            iconPath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
