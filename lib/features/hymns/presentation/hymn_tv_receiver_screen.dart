import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class HymnTvReceiverScreen extends StatefulWidget {
  const HymnTvReceiverScreen({super.key});

  @override
  State<HymnTvReceiverScreen> createState() => _HymnTvReceiverScreenState();
}

class _HymnTvReceiverScreenState extends State<HymnTvReceiverScreen> {
  String? _roomId;

  @override
  void initState() {
    super.initState();
    _generateRoom();
  }

  Future<void> _generateRoom() async {
    // Generate a 4-digit code
    final code = (Random().nextInt(9000) + 1000).toString();
    setState(() {
      _roomId = code;
    });

    // Create room in Firestore
    await FirebaseFirestore.instance.collection('tv_rooms').doc(code).set({
      'hymnId': '',
      'hymnTitle': '',
      'currentBlock': '',
      'isBlank': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_roomId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('tv_rooms').doc(_roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildWaitingScreen();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentBlock = data['currentBlock'] as String? ?? '';
          final isBlank = data['isBlank'] as bool? ?? false;
          final isChorus = data['isChorus'] as bool? ?? false;
          final activeHighlight = data['activeHighlight'] as String?;
          final fontSize = (data['fontSize'] as num?)?.toDouble() ?? 64.0;
          final themeStr = data['theme'] as String? ?? 'darkPremium';
          final hymnTitle = data['hymnTitle'] as String? ?? '';

          if (currentBlock.isEmpty && hymnTitle.isEmpty) {
            return _buildWaitingScreen();
          }

          final RegExp tagRegExp = RegExp(
            r'^(coro\s+[ivx]+|coro\s+\d+|coro|puente|final|est\.\s*\d+|estrofa\s+\d+|\d+\.|\d+)\s*:?\s*', 
            caseSensitive: false
          );

          String displayText = currentBlock;
          String headerTag = '';

          final lines = currentBlock.split('\n');
          if (lines.isNotEmpty) {
            final firstLine = lines.first.trim();
            if (tagRegExp.hasMatch(firstLine)) {
              final lineWithoutTag = firstLine.replaceFirst(tagRegExp, '').trim();
              if (lineWithoutTag.isEmpty) {
                displayText = lines.skip(1).join('\n').trim();
              } else {
                final rest = lines.skip(1).join('\n');
                displayText = '$lineWithoutTag\n$rest'.trim();
              }
              headerTag = firstLine.replaceAll(lineWithoutTag, '').replaceAll(RegExp(r'[:.]'), '').trim().toUpperCase();
            } else if (activeHighlight != null) {
              headerTag = activeHighlight;
            } else if (isChorus) {
              headerTag = 'CORO';
            }
          }
          
          Color textColor = Colors.white;
          BoxDecoration decoration = const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
            ),
          );

          switch (themeStr) {
            case 'vitralChurch':
              textColor = isChorus ? const Color(0xFFF472B6) : const Color(0xFFE2E8F0);
              decoration = const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1B4B), Color(0xFF31103F), Color(0xFF0F172A)],
                ),
              );
              break;
            case 'highContrast':
              textColor = isChorus ? Colors.yellowAccent : Colors.white;
              decoration = const BoxDecoration(color: Colors.black);
              break;
            case 'whiteProjector':
              textColor = isChorus ? const Color(0xFF1E3A8A) : Colors.black;
              decoration = const BoxDecoration(color: Colors.white);
              break;
            case 'darkPremium':
            default:
              textColor = isChorus ? const Color(0xFFFDE047) : Colors.white;
              decoration = const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F172A), Color(0xFF020617)],
                ),
              );
              break;
          }

          return Container(
            decoration: decoration,
            child: AnimatedOpacity(
              opacity: isBlank ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Spacer(),
                          SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (currentBlock.isEmpty)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                                        child: Text(
                                          hymnTitle.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontFamily: 'Nunito', 
                                            fontSize: 90,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (RegExp(r'^\d+\.').hasMatch(hymnTitle))
                                        Text(
                                          'Himno ${hymnTitle.split('.').first}',
                                          style: TextStyle(fontFamily: 'Nunito', 
                                            fontSize: 40,
                                            color: textColor.withValues(alpha: 0.6),
                                            letterSpacing: 3.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  )
                                else ...[
                                  if (headerTag.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: textColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
                                      ),
                                      child: Text(
                                        headerTag,
                                        style: TextStyle(fontFamily: 'Nunito', 
                                          color: textColor,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  Text(
                                    displayText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Nunito', 
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: isChorus ? FontStyle.italic : FontStyle.normal,
                                      color: textColor,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (currentBlock.isNotEmpty && hymnTitle.isNotEmpty)
                            Text(
                              hymnTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Nunito', 
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.25),
                                letterSpacing: 1.0,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaitingScreen({String? title}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cast_connected, color: Colors.white54, size: 100),
          const SizedBox(height: 30),
          Text(
            title ?? 'Modo Proyector',
            style: GoogleFonts.notoSans(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (title == null)
            Text(
              'Ingresa este código en tu celular para conectar:',
              style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 24),
            ),
          const SizedBox(height: 40),
          if (title == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: Text(
                _roomId!,
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
