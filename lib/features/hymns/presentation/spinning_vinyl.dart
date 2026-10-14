import 'package:flutter/material.dart';

class SpinningVinyl extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const SpinningVinyl({
    super.key,
    required this.isPlaying,
    required this.color,
    this.size = 20,
  });

  @override
  State<SpinningVinyl> createState() => _SpinningVinylState();
}

class _SpinningVinylState extends State<SpinningVinyl> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SpinningVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        Icons.album,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
