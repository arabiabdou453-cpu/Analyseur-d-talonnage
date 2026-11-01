/// Composants d'interface partagés.
library;

import 'package:flutter/material.dart';

enum Tone { error, warn, info, ok }

class Palette {
  static const primary = Color(0xFF0E6E8C);
  static const warnLight = Color(0xFFA16207), warnDark = Color(0xFFFBBF24);
  static const okLight = Color(0xFF15803D), okDark = Color(0xFF4ADE80);

  static Color tone(BuildContext context, Tone t) {
    final s = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (t) {
      Tone.error => s.error,
      Tone.warn => dark ? warnDark : warnLight,
      Tone.ok => dark ? okDark : okLight,
      Tone.info => s.primary,
    };
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, this.icon, this.subtitle, this.trailing, required this.child});
  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 20, color: theme.colorScheme.primary), const SizedBox(width: 8)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class AlertBox extends StatelessWidget {
  const AlertBox(this.text, {super.key, this.tone = Tone.info});
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = Palette.tone(context, tone);
    final icon = switch (tone) {
      Tone.error => Icons.error_outline,
      Tone.warn => Icons.warning_amber_rounded,
      Tone.ok => Icons.check_circle_outline,
      Tone.info => Icons.info_outline,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13.5))),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.info, this.icon});
  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = Palette.tone(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class Kpi extends StatelessWidget {
  const Kpi({super.key, required this.label, required this.value, this.unit = ''});
  final String label, value, unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: mono(theme).copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
              if (unit.isNotEmpty)
                TextSpan(text: '  $unit', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

/// Grille de tuiles à hauteur naturelle (pas de ratio fixe : aucun débordement
/// sur petit écran ni avec une grande taille de police d'accessibilité).
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children, this.columns = 2, this.spacing = 8});
  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) cells.add(SizedBox(width: spacing));
        cells.add(Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
    }
    return Column(children: rows);
  }
}

TextStyle mono(ThemeData theme) => (theme.textTheme.bodyMedium ?? const TextStyle())
    .copyWith(fontFamily: 'monospace', fontFeatures: const [FontFeature.tabularFigures()]);

/// Texte numérique toujours de gauche à droite, même en arabe.
class Ltr extends StatelessWidget {
  const Ltr(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: Text(text, style: style ?? mono(Theme.of(context))));
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.text, required this.action, required this.onAction});
  final String title, text, action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.insights_outlined, size: 32, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(action)),
        ]),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, this.subtitle, {super.key});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// Logo de l'application : marque vectorielle (tracé de MCA Icon.svg) sur sa tuile.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .26),
        child: CustomPaint(size: Size.square(size), painter: const _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static final Path _mark = Path()
    ..moveTo(523.66, 27.72)
    ..relativeLineTo(0, 279.09)
    ..relativeCubicTo(0, 15.31, -12.41, 27.72, -27.72, 27.72)
    ..relativeLineTo(-75.91, 0)
    ..relativeCubicTo(-15.31, 0, -27.72, -12.41, -27.72, -27.72)
    ..lineTo(392.31, 85.06)
    ..relativeCubicTo(0, -11.2, -14.15, -16.1, -21.08, -7.29)
    ..relativeLineTo(-32.21, 40.96)
    ..relativeCubicTo(-7.48, 9.51, -11.54, 21.25, -11.54, 33.35)
    ..relativeLineTo(0, 154.73)
    ..relativeCubicTo(0, 15.31, -12.41, 27.72, -27.72, 27.72)
    ..relativeLineTo(-75.91, 0)
    ..relativeCubicTo(-15.29, 0, -27.7, -12.41, -27.7, -27.72)
    ..relativeLineTo(0, -120.11)
    ..relativeCubicTo(0, -11.2, -14.15, -16.1, -21.08, -7.29)
    ..relativeLineTo(-32.22, 40.98)
    ..relativeCubicTo(-7.48, 9.51, -11.54, 21.25, -11.54, 33.35)
    ..relativeLineTo(0, 53.07)
    ..relativeCubicTo(0, 15.31, -12.41, 27.72, -27.72, 27.72)
    ..lineTo(27.72, 334.53)
    ..relativeCubicTo(-15.31, 0, -27.72, -12.41, -27.72, -27.72)
    ..relativeLineTo(0, -75.91)
    ..relativeCubicTo(0, -15.29, 12.41, -27.7, 27.72, -27.7)
    ..relativeLineTo(71.95, 0)
    ..relativeCubicTo(10.78, 0, 20.96, -4.95, 27.62, -13.42)
    ..relativeLineTo(48.16, -61.25)
    ..relativeCubicTo(13.08, -16.63, 33.06, -26.34, 54.22, -26.34)
    ..relativeLineTo(65.66, 0)
    ..relativeCubicTo(10.78, 0, 20.96, -4.95, 27.62, -13.42)
    ..relativeLineTo(56.88, -72.34)
    ..relativeCubicTo(8.16, -10.38, 20.63, -16.44, 33.83, -16.44)
    ..relativeLineTo(82.26, 0)
    ..relativeCubicTo(15.31, 0, 27.72, 12.41, 27.72, 27.72)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEEF0FF));
    canvas.scale(size.width / 640);
    canvas.translate(58.17, 152.735);
    canvas.drawPath(_mark, Paint()..color = const Color(0xFF2B3BFC));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
