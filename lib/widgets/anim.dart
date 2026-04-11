// widgets/anim.dart
import 'package:flutter/material.dart';
import '../services/app_theme.dart';

/// Fade + slide-up on first build
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

/// Tap scale bounce
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _s = Tween(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(),
    onTapUp: (_) {
      _c.reverse();
      widget.onTap();
    },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: widget.child),
  );
}

/// Elastic pop on check
class ElasticScale extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const ElasticScale({super.key, required this.child, required this.trigger});

  @override
  State<ElasticScale> createState() => _ElasticScaleState();
}

class _ElasticScaleState extends State<ElasticScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  bool _prev = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _s = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(ElasticScale old) {
    super.didUpdateWidget(old);
    if (!_prev && widget.trigger) _c.forward(from: 0);
    _prev = widget.trigger;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _s, child: widget.child);
}

/// Shimmer loading placeholder
class Shimmer extends StatefulWidget {
  final double width, height, radius;
  const Shimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + _c.value * 3, 0),
          end: Alignment(0.5 + _c.value * 3, 0),
          colors: const [AppTheme.card, Color(0xFF303030), AppTheme.card],
        ),
      ),
    ),
  );
}

/// A small accent pill badge
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const Pill(
    this.text, {
    super.key,
    this.color = AppTheme.accent,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Section header
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppTheme.border)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}
