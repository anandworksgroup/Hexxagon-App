import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'token_painter.dart';

/// Page scaffold for menu screens: letter-spaced title and a centred,
/// width-limited column so tablets don't stretch buttons edge to edge.
class MenuScaffold extends StatelessWidget {
  const MenuScaffold({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 560,
    this.actions,
    this.bottom,
  });

  final String title;
  final Widget child;
  final double maxWidth;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title.toUpperCase()), actions: actions, bottom: bottom),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.subtitle,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? accent : p.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: enabled ? p.symbol : p.textSecondary, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: enabled ? p.symbol : p.textSecondary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (enabled ? p.symbol : p.textSecondary).withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: p.text, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: onPressed == null ? p.textSecondary : p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of mutually exclusive options (difficulty, board size, theme...).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          Semantics(
            selected: v == selected,
            button: true,
            label: label(v),
            excludeSemantics: true,
            child: Material(
              color: v == selected ? accent : p.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(v),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 46, minWidth: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        label(v),
                        style: TextStyle(
                          color: v == selected ? p.symbol : p.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.palette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    ),
  );
}

/// Rounded dark card used for list rows and panels.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 14, this.max = 3});
  final int stars;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$stars of $max stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars ? const Color(0xFFF7C948) : p.textSecondary.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }
}

/// Small cluster of hexes and tokens used as the game's logo.
class HexLogo extends StatelessWidget {
  const HexLogo({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LogoPainter(context.palette)),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.p);
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 5.4;
    final c = size.center(Offset.zero);
    const cells = [(0, 0), (1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];
    const owners = [0, 0, 1, -1, 0, -1, 1];
    for (var i = 0; i < cells.length; i++) {
      final (q, r) = cells[i];
      final center = c + Offset(1.5 * q * s, math.sqrt(3) * (r + q / 2) * s);
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3;
        final o = center + Offset(math.cos(a), math.sin(a)) * s * 0.92;
        k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = p.board);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = p.boardEdge,
      );
      final o = owners[i];
      if (o >= 0) {
        TokenArt.paint(
          canvas,
          center,
          s * 0.6,
          o == 0 ? p.players[0] : p.players[1],
          o == 0 ? 0 : 2,
          symbolColor: p.symbol,
          outline: !p.isDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.p != p;
}

/// Three dots that pulse while a computer opponent is thinking.
class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key, required this.color});
  final Color color;

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Opacity(
              opacity: 0.25 + 0.75 * (0.5 + 0.5 * math.sin((_c.value - i * 0.18) * 2 * math.pi)),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String cancel = 'Cancel',
  bool destructive = false,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(
          confirm,
          style: TextStyle(
            color: destructive ? Theme.of(context).colorScheme.error : null,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  ),
);
