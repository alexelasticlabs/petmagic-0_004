import 'package:flutter/material.dart';

class PremiumShimmerButton extends StatefulWidget {
  const PremiumShimmerButton({
    required this.label,
    required this.onTap,
    super.key,
    this.height = 44,
    this.borderRadius = 12,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final double borderRadius;

  @override
  State<PremiumShimmerButton> createState() => _PremiumShimmerButtonState();
}

class _PremiumShimmerButtonState extends State<PremiumShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE0A91E).withValues(alpha: 0.26),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              clipBehavior: Clip.antiAlias,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final shimmerStart = -1.6 + (t * 2.8);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF4C64D), Color(0xFFEAB13A)],
                          ),
                        ),
                        child: child,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(shimmerStart, -1),
                                end: Alignment(shimmerStart + 0.9, 1),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.62),
                                  Colors.transparent,
                                ],
                                stops: const [0.23, 0.5, 0.77],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Color(0xFF261903),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF261903),
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

