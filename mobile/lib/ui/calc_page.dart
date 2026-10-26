import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/engine.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import 'charts.dart';
import 'common.dart';

class CalcPage extends StatelessWidget {
  const CalcPage({super.key, required this.goData});
  final VoidCallback goData;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.analysis;
    if (a == null) {
      return EmptyState(title: s.t('calc.empty.h'), text: s.t('calc.empty.p'), action: s.t('btn.goData'), onAction: goData);
    }
    final theme = Theme.of(context);
    final m = s.analysisMeta!;
    String n(double v, [int d = 10]) => fmtNum(v, s.lang, d);
    final r = s.lastResult;
    final unitI = m.unitI.isNotEmpty ? m.unitI : m.unitC;
    final unitU = s.uncType == UncType.relative ? m.unitI : m.unitU;
    final shown = r == null ? null : afficherResultat(r, s.lang); // règles communes avec le site
    final k = '${m.k.isEmpty ? '—' : m.k}${s.kVerified ? '' : ' (${s.t('k.verify')})'}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        PageHeader(s.t('calc.h'), s.t('calc.p')),
        if (s.expired) AlertBox(s.t('calc.expired', {'d': m.validUntil}), tone: Tone.error),
        SectionCard(
          title: s.t('calc.result'),
          icon: Icons.calculate_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: s.calcInput,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textDirection: TextDirection.ltr,
              style: mono(theme).copyWith(fontSize: 18),
              onChanged: (_) => s.liveCalc(),
              decoration: InputDecoration(
                labelText: s.t('f.inputI'),
                suffixText: m.unitI,
                helperText: s.t('calc.range', {'lo': n(a.lo), 'hi': n(a.hi)}),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: s.confirmed,
              onChanged: (v) => s.setCalcOptions(confirm: v ?? false),
              title: Text(s.t('calc.confirm'), style: theme.textTheme.bodyMedium),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (s.calcError != null) ...[const SizedBox(height: 4), AlertBox(s.errorText(s.calcError!), tone: Tone.error)],
            if (r != null && shown != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('calc.corrected'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Ltr('${shown.corrected} ± ${shown.u} $unitI',
                      style: mono(theme).copyWith(fontSize: 24, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text(s.t('calc.heroNote', {'k': k}), style: theme.textTheme.bodySmall),
                ]),
              ),
              const SizedBox(height: 10),
              KpiGrid(children: [
                Kpi(label: '${s.t('calc.correction')} C(I)', value: shown.c, unit: m.unitC.isEmpty ? unitI : m.unitC),
                Kpi(label: s.t('calc.corrected'), value: shown.corrected, unit: unitI),
                Kpi(label: '${s.t('calc.uFit')} (k = ${m.k.isEmpty ? '—' : m.k})', value: shown.u, unit: unitU),
              ]),
              const SizedBox(height: 10),
              KpiGrid(children: [
                Kpi(label: s.t('f.certificate'), value: m.certificate.isEmpty ? '—' : m.certificate),
                Kpi(label: s.t('calc.validRange'), value: '${n(a.lo)} – ${n(a.hi)}', unit: m.unitI),
                Kpi(label: s.t('calc.resMaxC'), value: n(a.c.residuMax)),
                Kpi(label: s.t('calc.exact'), value: 'C ${n(r.c, 6)} · U ${n(r.uFit, 6)}'),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.copy),
                  label: Text(s.t('btn.copy')),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: [
                      '${s.t('calc.indication')} : ${n(r.x)} $unitI',
                      '${s.t('calc.correction')} C(I) : ${shown.c} ${m.unitC.isEmpty ? unitI : m.unitC}',
                      '${s.t('calc.corrected')} : ${shown.corrected} $unitI',
                      '${s.t('calc.uFit')} : ${shown.u} $unitU (k = $k)',
                      '${s.t('f.certificate')} : ${m.certificate.isEmpty ? '—' : m.certificate} · ${s.t('calc.validRange')} : ${n(a.lo)} → ${n(a.hi)}',
                    ].join('\n')));
                    messenger.showSnackBar(SnackBar(content: Text(s.t('toast.copied'))));
                  },
                ),
                OutlinedButton.icon(icon: const Icon(Icons.playlist_add), label: Text(s.t('btn.addHistory')), onPressed: s.calculate),
              ]),
              const SizedBox(height: 6),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(s.t('calc.formulas'), style: theme.textTheme.titleSmall),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in [
                    'C(I) = a_C · I + b_C = ${equation('C', a.c.a, a.c.b, s.lang).substring(4)}',
                    'I_corr = I + C(I)',
                    'U(I) = a_U · I + b_U = ${equation('U', a.u.a, a.u.b, s.lang).substring(4)}',
                    'e_i = y_i − (a · x_i + b)',
                  ])
                    Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Ltr(f, style: mono(theme).copyWith(fontSize: 12.5))),
                  const SizedBox(height: 6),
                  Text(s.t('calc.formulasNote'), style: theme.textTheme.bodySmall),
                ],
              ),
              ModelChart(analysis: a, uncertainty: false, marker: Offset(r.x, r.c), height: 190),
              const SizedBox(height: 6),
              Text('${s.t('calc.note')} · ${s.t('method.${r.methodC.name}')}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ]),
        ),
        SectionCard(
          title: s.t('calc.history'),
          icon: Icons.history,
          trailing: s.history.isEmpty
              ? null
              : IconButton(tooltip: s.t('btn.clear'), icon: const Icon(Icons.delete_outline), onPressed: s.clearHistory),
          child: s.history.isEmpty
              ? Text(s.t('calc.historyEmpty'), style: theme.textTheme.bodySmall)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 34,
                    columns: [
                      const DataColumn(label: Text('#'), numeric: true),
                      DataColumn(label: Text(s.t('calc.indication')), numeric: true),
                      DataColumn(label: Text(s.t('calc.correction')), numeric: true),
                      DataColumn(label: Text(s.t('calc.corrected')), numeric: true),
                      DataColumn(label: Text(s.t('calc.uFit')), numeric: true),
                    ],
                    rows: [
                      for (final (i, h) in s.history.indexed)
                        () {
                          final d = afficherResultat(h, s.lang);
                          return DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Ltr(n(h.x))),
                            DataCell(Ltr(d.c)),
                            DataCell(Ltr(d.corrected, style: mono(theme).copyWith(fontWeight: FontWeight.w700))),
                            DataCell(Ltr('${d.u} (${h.nature}, k = ${h.k.isEmpty ? '—' : h.k})')),
                          ]);
                        }(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
