import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/hymn.dart';

class TvRemoteControlScreen extends StatefulWidget {
  final Hymn hymn;
  final String roomId;

  const TvRemoteControlScreen({super.key, required this.hymn, required this.roomId});

  @override
  State<TvRemoteControlScreen> createState() => _TvRemoteControlScreenState();
}

class _TvRemoteControlScreenState extends State<TvRemoteControlScreen> {
  int _currentBlockIndex = -1;
  bool _isBlank = false;
  late List<String> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = widget.hymn.lyrics.split('\n\n');
    _syncWithTv();
  }

  Future<void> _syncWithTv() async {
    final block = _currentBlockIndex >= 0 && _currentBlockIndex < _blocks.length 
        ? _blocks[_currentBlockIndex] 
        : '';
        
    await FirebaseFirestore.instance.collection('tv_rooms').doc(widget.roomId).update({
      'hymnId': widget.hymn.id,
      'hymnTitle': '${widget.hymn.id}. ${widget.hymn.title}',
      'currentBlock': block,
      'isBlank': _isBlank,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _nextBlock() {
    if (_currentBlockIndex < _blocks.length - 1) {
      setState(() {
        _currentBlockIndex++;
        _isBlank = false;
      });
      _syncWithTv();
    }
  }

  void _prevBlock() {
    if (_currentBlockIndex > 0) {
      setState(() {
        _currentBlockIndex--;
        _isBlank = false;
      });
      _syncWithTv();
    }
  }

  void _toggleBlank() {
    setState(() {
      _isBlank = !_isBlank;
    });
    _syncWithTv();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Proyector'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(_isBlank ? Icons.visibility_off : Icons.visibility),
            onPressed: _toggleBlank,
            tooltip: 'Ocultar/Mostrar texto',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Row(
              children: [
                const Icon(Icons.tv, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conectado a Sala: ${widget.roomId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Desconectar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _blocks.length,
              itemBuilder: (context, index) {
                final isSelected = _currentBlockIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBlockIndex = index;
                      _isBlank = false;
                    });
                    _syncWithTv();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigo : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Text(
                      _blocks[index],
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'prevBtn',
                    onPressed: _currentBlockIndex > 0 ? _prevBlock : null,
                    backgroundColor: _currentBlockIndex > 0 ? Colors.indigo.shade100 : Colors.grey.shade300,
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Anterior'),
                  ),
                  FloatingActionButton.extended(
                    heroTag: 'nextBtn',
                    onPressed: _currentBlockIndex < _blocks.length - 1 ? _nextBlock : null,
                    backgroundColor: _currentBlockIndex < _blocks.length - 1 ? Colors.indigo : Colors.grey.shade300,
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('Siguiente'),
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