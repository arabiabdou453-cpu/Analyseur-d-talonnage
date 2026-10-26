import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/data_io.dart';
import '../core/engine.dart';
import '../core/xlsx.dart';
import '../l10n/strings.dart';
import '../services/files.dart';
import '../services/report.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import 'common.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key, required this.goData});
  final VoidCallback goData;

  Future<Uint8List> _pdf(AppState s) => buildReport(
        a: s.analysis!,
        meta: s.analysisMeta!,
        history: List.of(s.history),
        warnings: s.warnings,
        tFr: (k) => tr('fr', k),
        analyzedAt: s.analyzedAt!,
        settings: s.settings,
      );

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = AppScope.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await action();
    } on CoreError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.errorText(e)), backgroundColor: errorColor));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.t('err.read')), backgroundColor: errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final a = s.analysis;
    final stem = fileStem(s.meta.certificate, s.meta.instrument);
    final session = SectionCard(
      title: s.t('rep.session'),
      icon: Icons.save_outlined,
      subtitle: s.t('rep.sessionHelp'),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.ios_share),
          label: Text(s.t('btn.saveSession')),
          onPressed: () => _run(context, () async {
            await shareBytes(Uint8List.fromList(utf8.encode(encodeSession(s.session))), '${stem}_session.json', 'application/json');
          }),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(s.t('btn.loadSession')),
          onPressed: () => _run(context, () async {
            final f = await pickFile(const ['json'], maxBytes: maxTextBytes);
            if (f == null) return;
            s.applySession(decodeSession(f.text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('toast.loaded'))));
              goData();
            }
          }),
        ),
      ]),
    );
    if (a == null) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        PageHeader(s.t('rep.h'), s.t('rep.p')),
        SizedBox(
          height: 320,
          child: EmptyState(title: s.t('rep.empty.h'), text: s.t('rep.empty.p'), action: s.t('btn.goData'), onAction: goData),
        ),
        session,
      ]);
    }
    final m = s.analysisMeta!;
    String n(double v) => fmtNum(v, s.lang);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        PageHeader(s.t('rep.h'), s.t('rep.p')),
        SectionCard(
          title: s.t('rep.h'),
          icon: Icons.picture_as_pdf_outlined,
          subtitle: [m.instrument, m.certificate].where((e) => e.isNotEmpty).join(' · '),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _row(context, s.t('model.correction'), equation('C', a.c.a, a.c.b, s.lang), a.decC.ok, s),
            _row(context, s.t('model.uncertainty'), equation('U', a.u.a, a.u.b, s.lang), a.decU.ok, s),
            const SizedBox(height: 6),
            Text('${s.t('kpi.range')} : ${n(a.lo)} → ${n(a.hi)} ${m.unitI} · ${s.t('calc.history')} : ${s.history.length}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                icon: const Icon(Icons.table_view_outlined),
                label: Text(s.t('btn.excel')),
                onPressed: () => _run(context, () async {
                  await shareBytes(
                    buildXlsx(a, m, uncType: s.uncType, kVerified: s.kVerified),
                    xlsxFileName(m),
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  );
                }),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.ios_share),
                label: Text(s.t('btn.reportPdf')),
                onPressed: () => _run(context, () async {
                  await Printing.sharePdf(bytes: await _pdf(s), filename: '${stem}_rapport.pdf');
                }),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.print_outlined),
                label: Text(s.t('btn.print')),
                onPressed: () => _run(context, () async {
                  final bytes = await _pdf(s);
                  await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${stem}_rapport.pdf');
                }),
              ),
            ]),
            const SizedBox(height: 12),
            AlertBox(s.t('rep.foot'), tone: Tone.warn),
          ]),
        ),
        session,
      ],
    );
  }

  Widget _row(BuildContext context, String label, String eq, bool ok, AppState s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Ltr(eq),
            ]),
          ),
          Pill(s.t(ok ? 'dec.ok' : 'dec.ko'), tone: ok ? Tone.ok : Tone.error),
        ]),
      );
}
