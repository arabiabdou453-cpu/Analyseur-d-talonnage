import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_state.dart';
import 'ui/analysis_page.dart';
import 'ui/calc_page.dart';
import 'ui/common.dart';
import 'ui/data_page.dart';
import 'ui/report_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.restore();
  runApp(EtalonnageApp(state: state));
}

class EtalonnageApp extends StatelessWidget {
  const EtalonnageApp({super.key, required this.state});
  final AppState state;

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: Palette.primary, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: state.t('app.title'),
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: state.themeMode,
          locale: Locale(state.lang),
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeShell(),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final pages = [
      DataPage(onAnalyzed: () => _go(1)),
      AnalysisPage(goData: () => _go(0)),
      CalcPage(goData: () => _go(0)),
      ReportPage(goData: () => _go(0)),
    ];
    final dests = [
      (Icons.table_chart_outlined, Icons.table_chart, 'tab.data'),
      (Icons.insights_outlined, Icons.insights, 'tab.analysis'),
      (Icons.calculate_outlined, Icons.calculate, 'tab.calc'),
      (Icons.description_outlined, Icons.description, 'tab.report'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final body = IndexedStack(index: _tab, children: pages);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Palette.primary, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.speed, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('app.title'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(s.t('app.subtitle'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: s.toggleLang, child: Text(s.t('lang'))),
          IconButton(
            tooltip: s.t('theme'),
            icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => s.toggleTheme(theme.brightness),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: _go,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in dests) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(s.t(d.$3))),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: body))),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _go,
              destinations: [
                for (final d in dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: s.t(d.$3)),
              ],
            ),
    );
  }
}
