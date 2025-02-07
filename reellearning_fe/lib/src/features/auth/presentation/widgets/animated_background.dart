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
  late final List<double> opacitySpeeds;
  late final List<double> opacityOffsets;

  @override
  void initState() {
    super.initState();
    const availableSymbols = '∑∏∆∇∫≈≠∞αβγπΩ∄∋=+%';
    final random = math.Random();
    
    symbols = List.generate(20, (index) {
      return availableSymbols[random.nextInt(availableSymbols.length)];
    });
    
    directions = List.generate(20, (index) => index < 10 ? true : false)..shuffle(random);
    
    speeds = List.generate(20, (index) {
      return 8 + random.nextDouble() * 4; 
    });
    
    startOffsets = List.generate(20, (index) {
      return random.nextDouble();
    });

    opacitySpeeds = List.generate(20, (index) {
      return 1.5 + random.nextDouble(); 
    });

    opacityOffsets = List.generate(20, (index) {
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
          opacitySpeed: opacitySpeeds[index],
          opacityOffset: opacityOffsets[index],
        ),
      ),
    );
  }
}

class SymbolWidget extends StatefulWidget {
  final String symbol;
  final int index;
  final bool reverse;
  final double speed;
  final double startOffset;
  final double opacitySpeed;
  final double opacityOffset;

  const SymbolWidget({
    super.key,
    required this.symbol,
    required this.index,
    required this.reverse,
    required this.speed,
    required this.startOffset,
    required this.opacitySpeed,
    required this.opacityOffset,
  });

  @override
  State<SymbolWidget> createState() => _SymbolWidgetState();
}

class _SymbolWidgetState extends State<SymbolWidget> with TickerProviderStateMixin {
  late final AnimationController _positionController;
  late final AnimationController _opacityController;
  late final Animation<double> _opacityAnimation;
  Animation<double>? _positionAnimation;

  @override
  void initState() {
    super.initState();
    
    _positionController = AnimationController(
      duration: Duration(seconds: widget.speed.round()),
      vsync: this,
    );

    _opacityController = AnimationController(
      duration: Duration(milliseconds: (widget.opacitySpeed * 1000).round()),
      vsync: this,
      value: widget.opacityOffset, 
    );

    _opacityAnimation = Tween<double>(
      begin: 0.05,
      end: 0.25,
    ).animate(CurvedAnimation(
      parent: _opacityController,
      curve: Curves.easeInOut,
    ));

    _positionController.repeat();
    _opacityController.repeat(reverse: true);
  }

  void _setupAnimations() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate actual symbol width based on font size
    final symbolWidth = (30 + (widget.index % 5) * 15) * 1.2; // Add 20% padding
    
    final startPosition = widget.reverse
        ? screenWidth + (widget.startOffset * symbolWidth)
        : -symbolWidth - (widget.startOffset * symbolWidth);
    final endPosition = widget.reverse
        ? -symbolWidth - (widget.startOffset * symbolWidth)
        : screenWidth + (widget.startOffset * symbolWidth);

    _positionAnimation = Tween<double>(
      begin: startPosition,
      end: endPosition,
    ).animate(_positionController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupAnimations();
  }

  @override
  void dispose() {
    _positionController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure position animation is set up
    if (_positionAnimation == null) {
      _setupAnimations();
    }
    
    return AnimatedBuilder(
      animation: Listenable.merge([_positionController, _opacityAnimation]),
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation!.value,
          top: 50.0 + (widget.index * 80),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.rotate(
              angle: widget.index * (math.pi / 12),
              child: Text(
                widget.symbol,
                style: GoogleFonts.notoSans(
                  fontSize: 30 + (widget.index % 5) * 15,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
