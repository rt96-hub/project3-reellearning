import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final bool enforceEvenDistribution;
  
  const AnimatedBackground({
    super.key,
    this.enforceEvenDistribution = true,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  late final List<String> symbols;
  late final List<bool> directions;
  late final List<double> speeds;
  late final List<double> startOffsets;

  @override
  void initState() {
    super.initState();
    const availableSymbols = '∑∏∆∇∫≈≠∞♪♫αβγπΩ';
    final random = math.Random();
    
    symbols = List.generate(20, (index) {
      return availableSymbols[random.nextInt(availableSymbols.length)];
    });
    
    directions = List.generate(20, (index) => index < 10 ? true : false)..shuffle(random);
    
    speeds = List.generate(20, (index) {
      return 10 + random.nextDouble() * 4;
    });
    
    startOffsets = List.generate(20, (index) {
      return random.nextDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(
        20,
        (index) => SymbolWidget(
          symbol: symbols[index],
          index: index,
          reverse: directions[index],
          speed: speeds[index],
          startOffset: startOffsets[index],
        ),
      ),
    );
  }
}

class SymbolWidget extends StatelessWidget {
  final String symbol;
  final int index;
  final bool reverse;
  final double speed;
  final double startOffset;

  const SymbolWidget({
    super.key,
    required this.symbol,
    required this.index,
    required this.reverse,
    required this.speed,
    required this.startOffset,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final startPosition = reverse 
        ? screenWidth + (startOffset * screenWidth)
        : -300 - (startOffset * screenWidth);
    final endPosition = reverse
        ? -300 - (startOffset * screenWidth)
        : screenWidth + (startOffset * screenWidth);
    
    return CustomAnimationBuilder<double>(
      tween: Tween<double>(
        begin: startPosition,
        end: endPosition,
      ),
      duration: Duration(seconds: speed.round()),
      builder: (context, position, child) {
        return CustomAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.02, end: 0.25),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, opacity, _) {
            return Positioned(
              left: position,
              top: 50.0 + (index * 80),
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: index * (math.pi / 12),
                  child: Text(
                    symbol,
                    style: GoogleFonts.notoSans(
                      fontSize: 30 + (index % 5) * 15,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
