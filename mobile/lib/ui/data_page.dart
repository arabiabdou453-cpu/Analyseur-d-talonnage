import 'package:flutter/material.dart';

import '../core/certificate.dart';
import '../core/data_io.dart';
import '../core/engine.dart';
import '../core/pdf_text.dart';
import '../services/files.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import 'common.dart';

class DataPage extends StatelessWidget {
  const DataPage({super.key, required this.onAnalyzed});
  final VoidCallback onAnalyzed;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final points = _PointsCard(state: s);
    final side = [_MetaCard(state: s), _CriteriaCard(state: s)];
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            PageHeader(s.t('data.h'), s.t('data.p')),
            if (s.stale) AlertBox(s.t('stale'), tone: Tone.warn),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: points),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Column(children: side)),
              ])
            else ...[points, ...side],
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(child: Text(s.t('privacy'), style: Theme.of(context).textTheme.bodySmall)),
            ]),
          ],
        ),
      ),
      _AnalyzeBar(state: s, onAnalyzed: onAnalyzed),
    ]);
  }
}

class _AnalyzeBar extends StatelessWidget {
  const _AnalyzeBar({required this.state, required this.onAnalyzed});
  final AppState state;
  final VoidCallback onAnalyzed;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final n = s.filledRows.length;
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Text('${s.t('sum.points')} : $n', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(s.t('btn.analyze'), overflow: TextOverflow.ellipsis),
              onPressed: () async {
                final ok = await s.analyze(() async =>
                    await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        content: Text(s.t('confirm.sort')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('btn.cancel'))),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('btn.sort'))),
                        ],
                      ),
                    ) ??
                    false);
                if (!context.mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('toast.analyzed'))));
                  onAnalyzed();
                }
              },
            )),
          ]),
        ),
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.state});
  final AppState state;

  Future<void> _import(BuildContext context, bool pdf) async {
    final s = state;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final f = await pickFile(pdf ? const ['pdf'] : const ['csv', 'txt'], maxBytes: pdf ? maxPdfBytes : maxTextBytes);
      if (f == null) return;
      if (!pdf) {
        final rows = parseCsv(f.text);
        s.setRows(rows);
        messenger.showSnackBar(SnackBar(content: Text(s.t('toast.imported', {'n': rows.length}))));
        return;
      }
      final cert = analyserCertificat(extrairePdfLignes(f.bytes));
      if (!cert.hasText) throw const CoreError('pdf.scanned');
      if (cert.series.isEmpty) throw const CoreError('pdf.none');
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => _CertificateSheet(state: s, cert: cert, fileName: f.name),
      );
    } on CoreError catch (e) {
      final msg = e.code.startsWith('pdf.') ? s.t(e.code) : s.errorText(e);
      messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: errorColor));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.t('err.read'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final theme = Theme.of(context);
    final cols = [s.t('col.indication'), s.t('col.correction'), s.t('col.uncertainty')];
    final units = [s.metaCtl['unitI']!.text, s.metaCtl['unitC']!.text, s.metaCtl['unitU']!.text];
    return SectionCard(
      title: s.t('points.title'),
      subtitle: s.t('points.sub'),
      icon: Icons.table_chart_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(icon: const Icon(Icons.auto_awesome_outlined, size: 18), label: Text(s.t('btn.example')), onPressed: s.loadExample),
          MenuAnchor(
            builder: (c, ctl, _) => FilledButton.tonalIcon(
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(s.t('btn.import')),
              onPressed: () => ctl.isOpen ? ctl.close() : ctl.open(),
            ),
            menuChildren: [
              MenuItemButton(leadingIcon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => _import(context, true), child: Text(s.t('btn.importPdf'))),
              MenuItemButton(leadingIcon: const Icon(Icons.grid_on_outlined), onPressed: () => _import(context, false), child: Text(s.t('btn.importCsv'))),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(s.t('btn.clear')),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(content: Text(s.t('confirm.clear')), actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('btn.cancel'))),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('btn.confirm'))),
                ]),
              );
              if (ok ?? false) s.clearRows();
            },
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 28),
          for (var j = 0; j < 3; j++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(units[j].isEmpty ? cols[j] : '${cols[j]} (${units[j]})',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          const SizedBox(width: 40),
        ]),
        const SizedBox(height: 4),
        for (var i = 0; i < s.rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${i + 1}', style: mono(theme).copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))),
              for (var j = 0; j < 3; j++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: s.rows[i][j],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      style: mono(theme),
                      decoration: InputDecoration(
                        isDense: true,
                        errorText: s.badCells.contains((i, j)) ? '' : null,
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: s.t('btn.delRow'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => s.removeRow(i),
              ),
            ]),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(icon: const Icon(Icons.add), label: Text(s.t('btn.addRow')), onPressed: s.addRow),
        ),
        for (final e in s.errors) AlertBox(s.issueText(e), tone: Tone.error),
      ]),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    Widget field(String key, String label, {bool ltr = false}) => TextField(
          controller: s.metaCtl[key],
          textDirection: ltr ? TextDirection.ltr : null,
          decoration: InputDecoration(labelText: s.t(label), isDense: true, border: const OutlineInputBorder()),
        );
    Widget pair(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    const gap = SizedBox(height: 10);
    return SectionCard(
      title: s.t('meta.title'),
      icon: Icons.description_outlined,
      child: Column(children: [
        field('instrument', 'f.instrument'),
        gap,
        pair(field('identifier', 'f.identifier'), field('certificate', 'f.certificate', ltr: true)),
        gap,
        pair(field('date', 'f.date', ltr: true), field('lab', 'f.lab')),
        gap,
        pair(field('unitI', 'f.unitI'), field('unitC', 'f.unitC')),
        gap,
        pair(field('unitU', 'f.unitU'), field('k', 'f.k', ltr: true)),
        if (!s.kVerified)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(padding: const EdgeInsets.only(top: 6), child: Pill('k = 2 · ${s.t('k.verify')}', tone: Tone.warn)),
          ),
        gap,
        pair(
          DropdownButtonFormField<UncType>(
            isExpanded: true,
            initialValue: s.uncType,
            decoration: InputDecoration(labelText: s.t('f.uncType'), isDense: true, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: UncType.absolute, child: Text(s.t('unc.absolute'))),
              DropdownMenuItem(value: UncType.relative, child: Text(s.t('unc.relative'))),
            ],
            onChanged: (v) => s.setUncType(v ?? UncType.absolute),
          ),
          field('validUntil', 'f.validUntil', ltr: true),
        ),
        gap,
        DropdownButtonFormField<String>(
              isExpanded: true,
          initialValue: s.nature,
          decoration: InputDecoration(labelText: s.t('f.nature'), isDense: true, border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: '', child: Text(s.t('nature.unknown'))),
            DropdownMenuItem(value: 'U', child: Text(s.t('nature.expanded'))),
            DropdownMenuItem(value: 'u', child: Text(s.t('nature.standard'))),
          ],
          onChanged: (v) => s.setNature(v ?? ''),
        ),
      ]),
    );
  }
}

class _CriteriaCard extends StatelessWidget {
  const _CriteriaCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final fraction = s.mode == ThresholdMode.fraction;
    Widget field(String key, String label) => TextField(
          controller: s.settingsCtl[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          style: mono(Theme.of(context)),
          decoration: InputDecoration(labelText: s.t(label), isDense: true, border: const OutlineInputBorder()),
        );
    return SectionCard(
      title: s.t('crit.title'),
      icon: Icons.tune,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<ThresholdMode>(
          segments: [
            ButtonSegment(value: ThresholdMode.fraction, label: Text(s.t('mode.fraction'))),
            ButtonSegment(value: ThresholdMode.absolute, label: Text(s.t('mode.absolute'))),
          ],
          selected: {s.mode},
          onSelectionChanged: (v) => s.setMode(v.first),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: field(fraction ? 'alphaC' : 'limitC', fraction ? 'f.alphaC' : 'f.limitC')),
          const SizedBox(width: 10),
          Expanded(child: field(fraction ? 'alphaU' : 'limitU', fraction ? 'f.alphaU' : 'f.limitU')),
        ]),
        const SizedBox(height: 8),
        Text(s.t(fraction ? 'crit.helpFraction' : 'crit.helpAbsolute'), style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

/// Revue obligatoire des valeurs extraites d'un PDF avant chargement (F3).
class _CertificateSheet extends StatelessWidget {
  const _CertificateSheet({required this.state, required this.cert, required this.fileName});
  final AppState state;
  final Certificate cert;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final theme = Theme.of(context);
    final m = cert.meta;
    String n(double v) => fmtNum(v, s.lang);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (c, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(s.t('pdf.title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text([fileName, m.instrument, m.certificate, m.date].where((e) => e.isNotEmpty).join(' · '), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(s.t('pdf.sub', {'n': cert.series.length}), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          AlertBox(s.t('pdf.verify')),
          for (final serie in cert.series)
            Card(
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(serie.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                    Pill(s.t('pdf.points', {'n': serie.points.length})),
                  ]),
                  if (serie.inconsistent) ...[const SizedBox(height: 8), AlertBox(s.t('pdf.inconsistent'), tone: Tone.warn)],
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 34,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 36,
                      columnSpacing: 18,
                      columns: [
                        DataColumn(label: Text(s.t('pdf.ref')), numeric: true),
                        DataColumn(label: Text('${s.t('pdf.eq')} → I'), numeric: true),
                        DataColumn(label: Text(s.t('pdf.err')), numeric: true),
                        DataColumn(label: Text(s.t('col.correction')), numeric: true),
                        DataColumn(label: Text(s.t('col.uncertainty')), numeric: true),
                      ],
                      rows: [
                        for (final p in serie.points)
                          DataRow(
                            color: p.ok ? null : WidgetStatePropertyAll(Palette.tone(context, Tone.warn).withValues(alpha: .12)),
                            cells: [
                              DataCell(Ltr('${p.ok ? '' : '⚠ '}${n(p.line.ref)}')),
                              DataCell(Ltr(n(p.x))),
                              DataCell(Ltr(n(p.line.err))),
                              DataCell(Ltr(n(p.c), style: mono(theme).copyWith(fontWeight: FontWeight.w700))),
                              DataCell(Ltr(n(p.u), style: mono(theme).copyWith(fontWeight: FontWeight.w700))),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(s.t('btn.loadSeries')),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      if (serie.inconsistent) {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (d) => AlertDialog(content: Text(s.t('pdf.confirmInconsistent')), actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(s.t('btn.cancel'))),
                            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(s.t('btn.confirm'))),
                          ]),
                        );
                        if (!(ok ?? false)) return;
                      }
                      s.applyCertificate(serie, m, multiple: cert.series.length > 1);
                      navigator.pop();
                      messenger.showSnackBar(SnackBar(content: Text(s.t('toast.imported', {'n': serie.points.length}))));
                    },
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
