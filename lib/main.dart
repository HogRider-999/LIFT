import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/app_theme.dart';
import 'services/unit_service.dart';
import 'services/lang_service.dart';
import 'services/storage_service.dart';
import 'screens/training_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/pr_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await UnitService().load();
  await LangService().load();
  runApp(const LiftApp());
}

class LiftApp extends StatelessWidget {
  const LiftApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIFT',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}

class _Tab {
  final String labelKey;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
  const _Tab({required this.labelKey, required this.icon, required this.activeIcon, required this.screen});
}

const _tabs = [
  _Tab(labelKey: 'TRAIN', icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center, screen: TrainingScreen()),
  _Tab(labelKey: 'PROGRAMS', icon: Icons.library_books_outlined, activeIcon: Icons.library_books, screen: ProgramsScreen()),
  _Tab(labelKey: 'ANALYTICS', icon: Icons.analytics_outlined, activeIcon: Icons.analytics, screen: AnalyticsScreen()),
  _Tab(labelKey: 'PR', icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, screen: PRScreen()),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  final _lang = LangService();
  final _store = StorageService();

  @override
  void initState() {
    super.initState();
    _lang.addListener(_update);
  }

  @override
  void dispose() {
    _lang.removeListener(_update);
    super.dispose();
  }

  void _update() { if (mounted) setState(() {}); }

  void _goTo(int i) {
    if (_idx == i) return;
    HapticFeedback.selectionClick();
    setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: _buildAppBar(),
      body: _FadeIndexedStack(index: _idx, children: _tabs.map((t) => t.screen).toList()),
      bottomNavigationBar: _buildNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bg,
      titleSpacing: 16,
      title: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bolt, color: Colors.black, size: 18),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          layoutBuilder: (cur, prev) => Stack(
            alignment: Alignment.centerLeft,
            children: [...prev, if (cur != null) cur],
          ),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            _lang.t(_tabs[_idx].labelKey),
            key: ValueKey('${_tabs[_idx].labelKey}_${_lang.isEn}'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 2.5),
          ),
        ),
      ]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SettingsPage())),
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary, size: 20),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.5, color: AppTheme.border),
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: _tabs.asMap().entries.map((e) {
              final i = e.key;
              final tab = e.value;
              final sel = i == _idx;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _goTo(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          sel ? tab.activeIcon : tab.icon,
                          color: sel ? AppTheme.accent : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          color: sel ? AppTheme.accent : AppTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.normal,
                          letterSpacing: 1,
                        ),
                        child: Text(_lang.t(tab.labelKey)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(LangService().t('SETTINGS')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const SettingsScreen(),
    );
  }
}

class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _FadeIndexedStack({required this.index, required this.children});
  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _prevIdx = 0;

  @override
  void initState() {
    super.initState();
    _prevIdx = widget.index;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _ctrl.forward(from: 1.0);
  }

  @override
  void didUpdateWidget(_FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _prevIdx = old.index;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (i) {
        final isCurrent = i == widget.index;
        final isPrev = i == _prevIdx;
        if (!isCurrent && !isPrev) return Offstage(offstage: true, child: widget.children[i]);
        Widget child = widget.children[i];
        if (isCurrent && _ctrl.isAnimating) child = FadeTransition(opacity: _ctrl, child: child);
        else if (isPrev && _ctrl.isAnimating) child = FadeTransition(opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_ctrl), child: child);
        return Offstage(
          offstage: !isCurrent && (!isPrev || !_ctrl.isAnimating),
          child: IgnorePointer(ignoring: !isCurrent, child: child),
        );
      }),
    );
  }
}
