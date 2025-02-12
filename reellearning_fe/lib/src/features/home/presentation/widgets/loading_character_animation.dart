import 'package:flutter/material.dart';
import 'dart:math' as math;

class LoadingCharacterAnimation extends StatefulWidget {
  final Color color;
  
  const LoadingCharacterAnimation({
    super.key,
    required this.color,
  });

  @override
  State<LoadingCharacterAnimation> createState() => _LoadingCharacterAnimationState();
}

class _LoadingCharacterAnimationState extends State<LoadingCharacterAnimation> {
  final List<OverlayEntry> _activeOverlays = [];
  final random = math.Random();
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _startEmittingCharacters());
  }

  @override
  void dispose() {
    for (final overlay in _activeOverlays) {
      overlay.remove();
    }
    _activeOverlays.clear();
    super.dispose();
  }

  void _startEmittingCharacters() {
    if (!mounted) return;
    
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _emitCharacter();
      _emitCharacter(); // Emit two at once for better effect
      _startEmittingCharacters();
    });
  }

  Offset _getButtonCenter() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    
    // Get the parent button's width to find its center
    final RenderBox? parentBox = context.findRenderObject() as RenderBox?;
    final parentWidth = parentBox?.size.width ?? 200; // Fallback width
    
    return Offset(
      position.dx + (parentWidth / 2),
      position.dy + (buttonSize.height / 2),
    );
  }

  void _emitCharacter() {
    const availableSymbols = '∑∏∆∇∫≈≠∞αβγπΩ∄∋=+%';
    final symbol = availableSymbols[random.nextInt(availableSymbols.length)];
    final buttonCenter = _getButtonCenter();
    
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 40 + random.nextDouble() * 40;
    final size = 16.0;

    late final OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final dx = math.cos(angle) * speed * value;
                  final dy = math.sin(angle) * speed * value;
                  
                  return Positioned(
                    left: buttonCenter.dx + dx - (size / 2),
                    top: buttonCenter.dy + dy - (size / 2),
                    child: Opacity(
                      opacity: 1.0 - (value * 0.8),
                      child: Transform.rotate(
                        angle: value * math.pi,
                        child: Text(
                          symbol,
                          style: TextStyle(
                            fontSize: size,
                            color: widget.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  overlay.remove();
                  _activeOverlays.remove(overlay);
                },
              ),
            ],
          ),
        );
      },
    );

    _activeOverlays.add(overlay);
    Overlay.of(context).insert(overlay);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _buttonKey,
      width: 1,
      height: 1,
    );
  }
} 