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
          final hymnTitle = data['hymnTitle'] as String? ?? '';

          if (currentBlock.isEmpty && hymnTitle.isNotEmpty) {
            return _buildWaitingScreen(title: 'Conectado. Esperando letra...');
          }

          if (currentBlock.isEmpty) {
            return _buildWaitingScreen();
          }

          return AnimatedOpacity(
            opacity: isBlank ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60.0),
                    child: Text(
                      currentBlock,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontSize: 64, // Texto gigante para TV
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        shadows: [
                          const Shadow(
                            blurRadius: 10.0,
                            color: Colors.black54,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 40,
                  child: Text(
                    hymnTitle,
                    style: GoogleFonts.notoSans(
                      color: Colors.white54,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
