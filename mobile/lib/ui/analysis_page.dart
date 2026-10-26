import 'package:flutter/material.dart';

import '../core/engine.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import 'charts.dart';
import 'common.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key, required this.goData});
  final VoidCallback goData;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.analysis;
    if (a == null) {
      return EmptyState(title: s.t('an.empty.h'), text: s.t('an.empty.p'), action: s.t('btn.goData'), onAction: goData);
    }
    final m = s.analysisMeta!;
    String n(double v, [int d = 10]) => fmtNum(v, s.lang, d);
    final okC = a.decC.ok, okU = a.decU.ok;
    final tone = okC && okU ? Tone.ok : (!okC && !okU ? Tone.error : Tone.warn);
    final verdict = okC && okU ? 'verdict.ok' : (!okC && !okU ? 'verdict.ko' : 'verdict.mixed');
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final models = [
      _ModelCard(state: s, a: a, unc: false),
      _ModelCard(state: s, a: a, unc: true),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        PageHeader(s.t('an.h'), s.t('an.p')),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              tone == Tone.ok ? Icons.verified_outlined : (tone == Tone.error ? Icons.cancel_outlined : Icons.warning_amber_rounded),
              color: Palette.tone(context, tone),
              size: 34,
            ),
            title: Text(s.t(verdict), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.t('verdict.sub', {'n': a.pts.length, 'lo': n(a.lo), 'hi': n(a.hi)})),
          ),
        ),
        const SizedBox(height: 8),
        KpiGrid(
          columns: wide ? 4 : 2,
          children: [
            Kpi(label: s.t('kpi.points'), value: '${a.pts.length}'),
            Kpi(label: s.t('kpi.range'), value: '${n(a.lo)} – ${n(a.hi)}', unit: m.unitI),
          ],
        ),
        const SizedBox(height: 8),
        for (final w in s.warnings) AlertBox(s.t(w), tone: Tone.warn),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: models[0]),
            const SizedBox(width: 12),
            Expanded(child: models[1]),
          ])
        else
          ...models,
        const SizedBox(height: 8),
        AlertBox(s.t('an.disclaimer')),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.state, required this.a, required this.unc});
  final AppState state;
  final Analysis a;
  final bool unc;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final theme = Theme.of(context);
    final m = unc ? a.u : a.c;
    final d = unc ? a.decU : a.decC;
    String n(double v, [int digits = 10]) => fmtNum(v, s.lang, digits);
    Widget legend(Color color, String label, {bool dashed = false, bool dot = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          dot
              ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)))
              : Container(width: 16, height: 3, color: dashed ? color.withValues(alpha: .7) : color),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ]);
    final colors = ChartColors(theme.colorScheme);
    return SectionCard(
      title: s.t(unc ? 'model.uncertainty' : 'model.correction'),
      icon: Icons.show_chart,
      trailing: Pill(s.t(d.ok ? 'dec.ok' : 'dec.ko'), tone: d.ok ? Tone.ok : Tone.error, icon: d.ok ? Icons.check : Icons.close),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Ltr(equation(unc ? 'U' : 'C', m.a, m.b, s.lang),
                style: mono(theme).copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
            if (unc) ...[
              const SizedBox(height: 4),
              Text('${s.t('model.majorant')} :', style: theme.textTheme.bodySmall),
              Ltr(equation('U', a.maj.a, a.maj.b, s.lang), style: mono(theme).copyWith(color: colors.majorant)),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 4, children: [
          legend(colors.point, s.t('chart.measured'), dot: true),
          legend(colors.fit, s.t('chart.fit')),
          if (unc) legend(colors.majorant, s.t('chart.majorant'), dashed: true),
        ]),
        const SizedBox(height: 6),
        ModelChart(analysis: a, uncertainty: unc),
        const SizedBox(height: 10),
        KpiGrid(
          spacing: 6,
          children: [
            Kpi(label: s.t('st.r2'), value: n(m.r2, r2Digits)),
            Kpi(label: s.t('st.maxRes'), value: n(m.residuMax)),
          ],
        ),
        const SizedBox(height: 12),
        Text(s.t('chart.residuals').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(spacing: 14, children: [
          legend(colors.barOk, s.t('chart.residuals')),
          legend(colors.majorant, s.t('chart.threshold'), dashed: true),
        ]),
        ResidualChart(analysis: a, uncertainty: unc),
        const SizedBox(height: 8),
        Text(
          '${s.t(d.r2Key)}${unc ? ' ${s.t('maj.note', {'r': n(m.residuMax)})}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
