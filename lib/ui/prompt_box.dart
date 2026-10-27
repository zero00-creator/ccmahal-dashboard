import 'package:flutter/material.dart';

import '../cmds.dart';
import '../models.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// Sends one instruction: [target] is 'all', 'main' or an agent type. For a
/// quick action [text] is the canned sentence and [quick] names it.
typedef CmdSend = Future<void> Function(
  String target,
  String text, {
  String? quick,
});

String targetLabel(String target) => switch (target) {
  'all' => 'All',
  'main' => 'Main',
  _ => target,
};

/// "go on · failed · too old": what a sent line reads like.
String cmdStateLine(CmdInfo c) =>
    '${c.text} · ${c.status}${c.note != null ? ' · ${c.note}' : ''}';

const _quickLabels = <String, String>{
  'pause': 'Ask to pause',
  'continue': 'Ask to continue',
  'stop': 'Ask to stop',
  'status': 'Report status',
};

/// The text field, Send and (optionally) the four quick buttons for one
/// target. It holds the text and the error line, and keeps the text when a send fails.
class CmdComposer extends StatefulWidget {
  const CmdComposer({
    super.key,
    required this.keyPrefix,
    required this.target,
    required this.style,
    required this.appCmd,
    required this.offline,
    required this.queued,
    required this.onSend,
    this.showQuick = false,
  });

  final String keyPrefix;
  final String target;
  final GlassStyle style;
  final bool appCmd;
  final bool offline;
  final int queued;
  final CmdSend onSend;
  final bool showQuick;

  @override
  State<CmdComposer> createState() => _CmdComposerState();
}

class _CmdComposerState extends State<CmdComposer> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {String? quick}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSend(widget.target, text, quick: quick);
      if (quick == null) _c.clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The instruction could not be sent. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final p = widget.keyPrefix;
    final text = _c.text.trim();
    final block = cmdBlockReason(
      appCmd: widget.appCmd,
      offline: widget.offline,
      queued: widget.queued,
    );
    final tooLong = text.length > maxCmdText;
    final reason =
        block ??
        (tooLong ? 'Too long: ${text.length} of $maxCmdText characters' : null);
    final canSend = block == null && !_busy && text.isNotEmpty && !tooLong;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Text(
              reason,
              key: ValueKey('$p-reason'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: style.error,
              ),
            ),
          ),
        if (widget.showQuick)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final q in _quickLabels.entries)
                  OutlinedButton(
                    key: ValueKey('$p-quick-${q.key}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(minTap, minTap),
                      foregroundColor: style.ink,
                      side: BorderSide(color: style.inkMuted),
                    ),
                    onPressed: block == null && !_busy
                        ? () => _send(quickTexts[q.key]!, quick: q.key)
                        : null,
                    child: Text(q.value),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('$p-field'),
                controller: _c,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: style.ink, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Type an instruction',
                  hintStyle: TextStyle(color: style.inkMuted),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.x3,
                    vertical: Space.x3,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.chip),
                    borderSide: BorderSide(color: style.inkMuted),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.chip),
                    borderSide: BorderSide(color: style.inkMuted),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.chip),
                    borderSide: BorderSide(color: style.accent, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.x2),
            FilledButton(
              key: ValueKey('$p-send'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, minTap),
              ),
              onPressed: canSend ? () => _send(text) : null,
              child: Text(_busy ? 'Sending…' : 'Send'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.x2),
            child: Text(
              _error!,
              key: ValueKey('$p-error'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: style.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// The prompt box above the tab bar: an agent strip (All, Main, then each
/// agent type once), a text field and Send. Tapping a chip picks the target
/// and opens its sheet.
class PromptBox extends StatelessWidget {
  const PromptBox({
    super.key,
    required this.agents,
    required this.target,
    required this.onTarget,
    required this.style,
    required this.appCmd,
    required this.offline,
    required this.queued,
    required this.onSend,
    this.last,
    this.blurEnabled = true,
  });

  final List<AgentInfo> agents;
  final String target;
  final ValueChanged<String> onTarget;
  final GlassStyle style;
  final bool appCmd;
  final bool offline;
  final int queued;
  final CmdSend onSend;

  /// The newest command of this session, shown as one line.
  final CmdInfo? last;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    final types = <String>[];
    for (final a in agents) {
      final t = a.type.length > maxCmdTarget
          ? a.type.substring(0, maxCmdTarget)
          : a.type;
      if (t.isNotEmpty && !types.contains(t) && t != 'all' && t != 'main') {
        types.add(t);
      }
    }
    return GlassPanel(
      style: style,
      blurEnabled: blurEnabled,
      radius: Radii.card,
      padding: const EdgeInsets.all(Space.x2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: minTap,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in ['all', 'main', ...types])
                  _Chip(
                    key: ValueKey('cmd-chip-$t'),
                    label: targetLabel(t),
                    selected: t == target,
                    style: style,
                    onTap: () => onTarget(t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.x1),
          CmdComposer(
            keyPrefix: 'box',
            target: target,
            style: style,
            appCmd: appCmd,
            offline: offline,
            queued: queued,
            onSend: onSend,
          ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.x1),
              child: Text(
                cmdStateLine(last!),
                key: const ValueKey('cmd-last'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: last!.status == 'failed'
                      ? style.error
                      : style.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final GlassStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.x2),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.chip),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: minTap,
              minWidth: minTap,
            ),
            padding: const EdgeInsets.symmetric(horizontal: Space.x3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.chip),
              border: Border.all(
                color: selected ? style.accent : style.inkMuted,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: style.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The glass sheet for one target: its status, the four quick actions, a text
/// box and the last 10 instructions of the session with their state.
class AgentSheet extends StatelessWidget {
  const AgentSheet({
    super.key,
    required this.target,
    required this.status,
    required this.cmds,
    required this.style,
    required this.appCmd,
    required this.offline,
    required this.queued,
    required this.onSend,
    required this.onClose,
    this.blurEnabled = true,
  });

  final String target;
  final String status;

  /// The session's commands, newest first; only the first 10 are shown.
  final List<CmdInfo> cmds;
  final GlassStyle style;
  final bool appCmd;
  final bool offline;
  final int queued;
  final CmdSend onSend;
  final VoidCallback onClose;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    final viaMain = target != 'main' && target != 'all';
    return GlassPanel(
      style: style,
      blurEnabled: blurEnabled,
      radius: Radii.sheet,
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x3,
        Space.x4,
        Space.x4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetLabel(target),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: style.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('sheet-close'),
                  tooltip: 'Close',
                  constraints: const BoxConstraints(
                    minWidth: minTap,
                    minHeight: minTap,
                  ),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (viaMain)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x2),
                child: Text(
                  'Delivered through the main agent',
                  key: const ValueKey('sheet-via-main'),
                  style: TextStyle(fontSize: 13, color: style.inkMuted),
                ),
              ),
            const SizedBox(height: Space.x1),
            CmdComposer(
              keyPrefix: 'sheet',
              target: target,
              style: style,
              appCmd: appCmd,
              offline: offline,
              queued: queued,
              onSend: onSend,
              showQuick: true,
            ),
            if (cmds.isNotEmpty) ...[
              const SizedBox(height: Space.x3),
              Text(
                'Recent instructions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: style.ink,
                ),
              ),
              for (final c in cmds.take(10))
                Padding(
                  key: ValueKey('cmd-row-${c.id}'),
                  padding: const EdgeInsets.only(top: Space.x2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: style.ink),
                      ),
                      Text(
                        '${targetLabel(c.target)} · ${c.status}${c.note != null ? ' · ${c.note}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.status == 'failed'
                              ? style.error
                              : style.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
