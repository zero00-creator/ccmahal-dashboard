import 'package:flutter/material.dart';

import '../asks.dart';
import '../auth/auth_service.dart';
import '../cmds.dart';
import '../environment.dart';
import '../models.dart';
import '../office/office_view.dart';
import '../session_order.dart';
import '../sprites.dart';
import '../theme/tokens.dart';
import '../update/update_controller.dart';
import '../update/update_ui.dart';
import 'alerts_tab.dart';
import 'ask_dialog.dart';
import 'collapsible_panel.dart';
import 'coworkers.dart';
import 'prompt_box.dart';
import 'sessions_drawer.dart';
import 'stats_strip.dart';
import 'settings_tab.dart';
import 'status.dart';
import 'tab_bar.dart';
import 'top_card.dart';

String _stageLabel(Stage s) => switch (s) {
  Stage.dawn => 'Dawn',
  Stage.day => 'Day',
  Stage.dusk => 'Dusk',
  Stage.night => 'Night',
};

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The live screen: three tabs (Office, Agents, Settings) under a glass tab
/// bar, and the sessions panel on the left edge. It holds no Firebase: the
/// page that owns the streams passes the data in.
class LiveView extends StatefulWidget {
  const LiveView({
    super.key,
    required this.sessions,
    required this.serverNow,
    required this.sprites,
    required this.now,
    required this.user,
    required this.onSetPluginPassword,
    this.onSignOut,
    this.asks = const [],
    this.onAnswer,
    this.appAsk = false,
    this.onAppAskChanged,
    this.cmds = const [],
    this.appCmd = false,
    this.onSendCmd,
    this.onAppCmdChanged,
    this.updates,
  });

  /// The in-app updater; null (or unsupported) shows no banner and no section.
  final UpdateController? updates;

  final List<SessionInfo> sessions;
  final int serverNow;
  final SpriteSet sprites;

  /// The phone's own clock: the office light follows it.
  final DateTime now;

  final AuthUser user;
  final Future<void> Function(String password) onSetPluginPassword;

  /// Shown as a button at the end of the sessions panel and in Settings.
  final VoidCallback? onSignOut;

  /// Permission questions from the PC, and what to do with an answer.
  final List<AskInfo> asks;
  final Future<void> Function(AskInfo ask, bool allow)? onAnswer;
  final bool appAsk;
  final ValueChanged<bool>? onAppAskChanged;

  /// Instructions typed in the app, the "Send instructions from here" switch,
  /// and how to send one (session key, target, text, quick action).
  final List<CmdInfo> cmds;
  final bool appCmd;
  final Future<void> Function(
    String sessionKey,
    String target,
    String text, {
    String? quick,
  })?
  onSendCmd;
  final ValueChanged<bool>? onAppCmdChanged;

  @override
  State<LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<LiveView> {
  final _scaffold = GlobalKey<ScaffoldState>();
  String? _selected;
  int _tab = 0;
  String _target =
      'all'; // who the prompt box talks to: all | main | an agent type
  bool _sheetOpen = false; // the glass sheet for [_target]
  bool _alertsOpen = false; // desktop layout: the Alerts panel
  bool _settingsOpen = false; // desktop layout: the Settings panel
  final _seenAsks =
      <String>{}; // questions already popped up (answered or dismissed)
  final _sent = <String>{}; // questions answered from here: the buttons give way to "Answer sent"
  String? _openAsk; // the question the pop-up shows now
  Route<void>? _askRoute;

  String _keyOf(AskInfo a) => '${a.sessionKey}/${a.id}';

  /// Sends an answer; when it cannot be sent the question stays open and the person is told.
  Future<void> _answer(AskInfo ask, bool allow) async {
    final key = _keyOf(ask);
    setState(() => _sent.add(key));
    try {
      await widget.onAnswer?.call(ask, allow);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sent.remove(key));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Your answer could not be sent. The question may have run out of time; try again.',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _syncPopup();
  }

  @override
  void didUpdateWidget(LiveView old) {
    super.didUpdateWidget(old);
    _syncPopup();
  }

  List<AskInfo> get _asks => [
    for (final a in widget.asks) a.withStaleCheck(widget.serverNow),
  ];

  /// Closes the pop-up when its question is no longer open, and opens one for a new question.
  void _syncPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final open = _asks.where((a) => a.isPending).toList();
      if (_openAsk != null && !open.any((a) => _keyOf(a) == _openAsk)) {
        final route = _askRoute;
        if (route != null && route.isActive)
          Navigator.of(context).removeRoute(route);
        _askRoute = null;
        _openAsk = null;
      }
      if (_openAsk != null) return;
      final fresh = open.where(
        (a) => !_seenAsks.contains(_keyOf(a)) && !_sent.contains(_keyOf(a)),
      );
      if (fresh.isEmpty) return;
      final ask = fresh.first;
      _seenAsks.add(_keyOf(ask));
      _openAsk = _keyOf(ask);
      final style = glassFor(environmentAt(widget.now).dayness);
      showDialog<void>(
        context: context,
        builder: (context) {
          _askRoute = ModalRoute.of(context) as Route<void>?;
          return LayoutBuilder(
            builder: (context, box) {
              final card = AskDialogBody(
                ask: ask,
                style: style,
                waited: Duration(
                  milliseconds: (widget.serverNow - ask.createdAt).clamp(
                    0,
                    1 << 40,
                  ),
                ),
                onAnswer: (allow) {
                  Navigator.of(context).pop();
                  _answer(ask, allow);
                },
              );
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(Space.x4),
                // On a wide window the pop-up is a centred card, not a full-width bar.
                child: box.maxWidth >= wideBreakpoint
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: askDialogMaxWidth,
                        ),
                        child: card,
                      )
                    : card,
              );
            },
          );
        },
      ).then((_) {
        if (_openAsk == _keyOf(ask)) _openAsk = null;
        _askRoute = null;
      });
    });
  }

  /// Everything about the selected session that the prompt box, the agent
  /// sheet, the top card and the office need; the phone and the desktop
  /// layout build their widgets from the same values.
  _Live _liveOf(SessionInfo s, Environment env) {
    final cmds = [
      for (final c in widget.cmds)
        if (c.sessionKey == s.key) c.withStaleCheck(widget.serverNow),
    ];
    final offline = const {
      'offline',
      'ended',
    }.contains(s.liveStatus(widget.serverNow));
    final types = {for (final a in s.agents) a.type};
    final target =
        (_target == 'all' || _target == 'main' || types.contains(_target))
        ? _target
        : 'all';
    Future<void> send(String t, String text, {String? quick}) async {
      final f = widget.onSendCmd;
      if (f == null) return;
      await f(s.key, t, text, quick: quick);
    }

    String statusOf() {
      if (target == 'all') return 'Everyone in this session';
      if (target == 'main') {
        final live = s.liveStatus(widget.serverNow);
        return s.pending > 0 ? 'waiting for you' : live;
      }
      final a = s.agents.where((a) => a.type == target).firstOrNull;
      if (a == null) return 'not in this session';
      return [a.status, if (a.stepNote.isNotEmpty) a.stepNote].join(' · ');
    }

    final running = s.agents.where((a) => a.isRunning).length;
    final subtitle = [
      _stageLabel(env.stage),
      '$running working',
      if (s.pending > 0) '${s.pending} waiting',
      money(s.costUsd),
    ].join('  ·  ');
    return _Live(
      session: s,
      cmds: cmds,
      queued: cmds.where((c) => c.isQueued).length,
      offline: offline,
      target: target,
      send: send,
      statusOf: statusOf,
      subtitle: subtitle,
    );
  }

  void _pick(String t) => setState(() {
    _target = t;
    _sheetOpen = true;
  });

  @override
  Widget build(BuildContext context) {
    final env = environmentAt(widget.now);
    final style = glassFor(env.dayness);
    final visible = visibleSessions(widget.sessions, widget.serverNow);
    final bg = Color.lerp(
      const Color(0xFF1B1D36),
      const Color(0xFFE9D3AC),
      env.dayness,
    )!;
    final current = visible.isEmpty
        ? null
        : visible.firstWhere(
            (s) => s.key == _selected,
            orElse: () => visible.first,
          );
    final live = current == null ? null : _liveOf(current, env);
    final alertCount = _asks
        .where((a) => a.isPending && !_sent.contains(_keyOf(a)))
        .length;

    void select(String k) => setState(() {
      _selected = k;
      _target = 'all';
      _sheetOpen = false;
    });

    final drawer = SessionsDrawer(
      sessions: visible,
      selectedKey: current?.key,
      serverNow: widget.serverNow,
      style: style,
      sprites: widget.sprites,
      onSelect: (k) {
        select(k);
        Navigator.of(context).maybePop();
      },
      onSignOut: widget.onSignOut,
    );

    Widget menuButton() => IconButton(
      tooltip: 'Sessions',
      constraints: const BoxConstraints(minWidth: minTap, minHeight: minTap),
      onPressed: () => _scaffold.currentState?.openDrawer(),
      icon: Icon(Icons.menu_rounded, color: style.ink),
    );

    Widget emptyNote() => Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x5),
        child: Text(
          'No session yet. Start one with the dashboard setting on.',
          textAlign: TextAlign.center,
          style: TextStyle(color: style.ink),
        ),
      ),
    );

    Widget emptyOffice() => Stack(
      children: [
        Positioned(top: Space.x2, left: Space.x2, child: menuButton()),
        emptyNote(),
      ],
    );

    // The pieces both layouts use.
    Widget topCard(_Live l, {VoidCallback? onMenu, double scale = 1}) =>
        TopCard(
          scale: scale,
          title: l.session.title.isNotEmpty
              ? l.session.title
              : l.session.project,
          subtitle: l.subtitle,
          env: env,
          timeLabel: _clock(widget.now),
          onMenu: onMenu,
        );

    Widget officeView(_Live l) => OfficeView(
      session: l.session,
      sprites: widget.sprites,
      env: env,
      serverNow: widget.serverNow,
      onTarget: _pick,
    );

    Widget agentSheet(_Live l) => AgentSheet(
      target: l.target,
      status: l.statusOf(),
      cmds: l.cmds,
      style: style,
      appCmd: widget.appCmd,
      offline: l.offline,
      queued: l.queued,
      onSend: l.send,
      onClose: () => setState(() => _sheetOpen = false),
    );

    Widget promptBox(_Live l) => PromptBox(
      agents: l.session.agents,
      target: l.target,
      onTarget: _pick,
      style: style,
      appCmd: widget.appCmd,
      offline: l.offline,
      queued: l.queued,
      onSend: l.send,
      last: l.cmds.firstOrNull,
    );

    Widget alertsTab({bool embedded = false}) => AlertsTab(
      asks: _asks,
      style: style,
      waitedNow: widget.serverNow,
      sending: _sent,
      onAnswer: _answer,
      embedded: embedded,
    );

    Widget settingsTab({bool embedded = false}) => SettingsTab(
      user: widget.user,
      style: style,
      onSignOut: widget.onSignOut ?? () {},
      onSetPluginPassword: widget.onSetPluginPassword,
      appAsk: widget.appAsk,
      onAppAskChanged: widget.onAppAskChanged,
      appCmd: widget.appCmd,
      onAppCmdChanged: widget.onAppCmdChanged,
      embedded: embedded,
      updates: widget.updates,
    );

    Widget updateBanner(VoidCallback onTap) {
      final u = widget.updates;
      if (u == null || !u.supported) return const SizedBox.shrink();
      return UpdateBanner(controller: u, style: style, onTap: onTap);
    }

    Widget office() {
      final l = live;
      if (l == null) return emptyOffice();
      return Stack(
        children: [
          Positioned.fill(
            child: Align(alignment: Alignment.topCenter, child: officeView(l)),
          ),
          Positioned(
            top: Space.x3,
            left: Space.x3,
            right: Space.x3,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    updateBanner(() => setState(() => _tab = 3)),
                    topCard(
                      l,
                      onMenu: () => _scaffold.currentState?.openDrawer(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The coworkers sheet and the prompt box float above the tab bar;
          // the agent sheet takes their place while it is open.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                    child: _sheetOpen
                        ? LayoutBuilder(
                            builder: (context, box) => ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: box.maxHeight * 0.8,
                              ),
                              child: agentSheet(l),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: CoworkersSheet(
                                  agents: l.session.agents,
                                  sprites: widget.sprites,
                                  style: style,
                                ),
                              ),
                              promptBox(l),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget agents() => Column(
      children: [
        Row(
          children: [
            menuButton(),
            Expanded(
              child: Text(
                current == null
                    ? 'Agents'
                    : (current.title.isNotEmpty
                          ? current.title
                          : current.project),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: style.ink,
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 88),
            child: AgentsList(
              agents: current?.agents ?? const [],
              sprites: widget.sprites,
              style: style,
            ),
          ),
        ),
      ],
    );

    final body = switch (_tab) {
      1 => agents(),
      2 => alertsTab(),
      3 => Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: settingsTab(),
      ),
      _ => office(),
    };

    // Desktop: sessions panel | top card over the office | right column.
    Widget wide(double windowWidth) {
      final l = live;
      // One factor scales the desktop text above 1400 px.
      final scale = uiScaleFor(windowWidth);
      final centre = l == null
          ? emptyNote()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                updateBanner(() => setState(() => _settingsOpen = true)),
                StatsStrip(
                  session: l.session,
                  serverNow: widget.serverNow,
                  env: env,
                  scale: scale,
                ),
                const SizedBox(height: Space.x2),
                topCard(l, scale: scale),
                const SizedBox(height: Space.x2),
                Expanded(child: officeView(l)),
              ],
            );
      final right = LayoutBuilder(
        builder: (context, box) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: l == null
                  ? const SizedBox.shrink()
                  : _sheetOpen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Flexible(child: agentSheet(l))],
                    )
                  : CoworkersPanel(
                      agents: l.session.agents,
                      sprites: widget.sprites,
                      style: style,
                    ),
            ),
            if (l != null && !_sheetOpen) ...[
              const SizedBox(height: Space.x2),
              promptBox(l),
            ],
            const SizedBox(height: Space.x2),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CollapsiblePanel(
                      id: 'alerts',
                      title: 'Alerts',
                      icon: Icons.notifications_rounded,
                      open: _alertsOpen,
                      onToggle: () =>
                          setState(() => _alertsOpen = !_alertsOpen),
                      style: style,
                      badgeCount: alertCount,
                      child: alertsTab(embedded: true),
                    ),
                    const SizedBox(height: Space.x2),
                    CollapsiblePanel(
                      id: 'settings',
                      title: 'Settings',
                      icon: Icons.settings_rounded,
                      open: _settingsOpen,
                      onToggle: () =>
                          setState(() => _settingsOpen = !_settingsOpen),
                      style: style,
                      child: settingsTab(embedded: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.all(Space.x2),
        child: Row(
          children: [
            SizedBox(
              key: const ValueKey('sessions-panel'),
              width: sessionsPanelWidth,
              child: SessionsPanel(
                sessions: visible,
                selectedKey: current?.key,
                serverNow: widget.serverNow,
                style: style,
                sprites: widget.sprites,
                onSelect: select,
                onSignOut: widget.onSignOut,
                outerPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(child: centre),
            const SizedBox(width: Space.x2),
            SizedBox(
              key: const ValueKey('right-column'),
              width: sidePanelWidthFor(windowWidth),
              child: right,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= wideBreakpoint) {
          return Scaffold(
            key: _scaffold,
            backgroundColor: bg,
            body: SafeArea(child: wide(box.maxWidth)),
          );
        }
        return Scaffold(
          key: _scaffold,
          backgroundColor: bg,
          drawerEdgeDragWidth: 48,
          drawerScrimColor: Colors.black.withValues(alpha: 0.35),
          drawer: drawer,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                Positioned(
                  left: Space.x3,
                  right: Space.x3,
                  bottom: Space.x2,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: GlassTabBar(
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                        style: style,
                        alertCount: alertCount,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The selected session with what the prompt box and the agent sheet need.
class _Live {
  const _Live({
    required this.session,
    required this.cmds,
    required this.queued,
    required this.offline,
    required this.target,
    required this.send,
    required this.statusOf,
    required this.subtitle,
  });

  final SessionInfo session;
  final List<CmdInfo> cmds;
  final int queued;
  final bool offline;
  final String target;
  final Future<void> Function(String target, String text, {String? quick}) send;
  final String Function() statusOf;
  final String subtitle;
}
