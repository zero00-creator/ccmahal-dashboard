import 'package:flutter/material.dart';

import '../asks.dart';
import '../theme/tokens.dart';
import 'ask_dialog.dart';
import 'glass.dart';

String _outcome(AskInfo a) {
  final where = a.answeredBy == 'terminal' ? 'terminal' : 'app';
  switch (a.status) {
    case 'allowed':
      return 'Allowed in the $where';
    case 'denied':
      return 'Denied in the $where';
    default:
      return 'No answer in time; the terminal asked';
  }
}

/// The Alerts tab: open questions first, with buttons, then the recent ones.
class AlertsTab extends StatelessWidget {
  const AlertsTab({
    super.key,
    required this.asks,
    required this.style,
    required this.waitedNow,
    required this.onAnswer,
    this.sending = const {},
    this.embedded = false,
  });

  /// Inside a collapsible panel: no title, no bottom room for the tab bar,
  /// and the list takes only the height it needs.
  final bool embedded;

  final List<AskInfo> asks;
  final GlassStyle style;

  /// The server clock in ms, for how long each question has waited.
  final int waitedNow;

  /// Questions already answered from here ("sessionKey/id"): no buttons, just a note.
  final Set<String> sending;
  final void Function(AskInfo ask, bool allow) onAnswer;

  @override
  Widget build(BuildContext context) {
    final open = asks.where((a) => a.isPending).toList();
    final done = asks.where((a) => !a.isPending).take(20).toList();
    final big = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(minTap, minTap)),
    );
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: embedded
          ? const EdgeInsets.all(Space.x3)
          : const EdgeInsets.fromLTRB(Space.x4, Space.x4, Space.x4, 100),
      children: [
        if (!embedded) ...[
          Text(
            'Alerts',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: style.ink,
            ),
          ),
          const SizedBox(height: Space.x3),
        ],
        if (asks.isEmpty)
          Text(
            'Nothing waiting for you.',
            style: TextStyle(color: style.inkMuted),
          )
        else ...[
          for (final a in open)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: GlassPanel(
                style: style,
                padding: const EdgeInsets.all(Space.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a.label.isEmpty ? 'A session' : a.label} · ${a.tool}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: style.ink,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      a.detail,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: style.ink,
                      ),
                    ),
                    if (a.why != null)
                      Text(
                        'Dangerous: ${a.why}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: style.error,
                        ),
                      ),
                    Text(
                      'Waiting ${waitedText(Duration(milliseconds: (waitedNow - a.createdAt).clamp(0, 1 << 40)))}',
                      style: TextStyle(fontSize: 12, color: style.inkMuted),
                    ),
                    const SizedBox(height: Space.x3),
                    if (sending.contains('${a.sessionKey}/${a.id}'))
                      Text(
                        'Answer sent. Waiting for the computer to pick it up.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: style.ink,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: ValueKey('alert-deny-${a.id}'),
                              style: big,
                              onPressed: () => onAnswer(a, false),
                              child: const Text('Deny'),
                            ),
                          ),
                          const SizedBox(width: Space.x3),
                          Expanded(
                            child: FilledButton(
                              key: ValueKey('alert-accept-${a.id}'),
                              style: big,
                              onPressed: () => onAnswer(a, true),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (done.isNotEmpty) ...[
            const SizedBox(height: Space.x2),
            Text(
              'Recent',
              style: TextStyle(fontSize: 13, color: style.inkMuted),
            ),
            for (final a in done)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x2),
                child: Text(
                  '${a.label.isEmpty ? 'A session' : a.label} · ${a.tool}: ${a.detail}\n${_outcome(a)}',
                  style: TextStyle(fontSize: 13, color: style.ink),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
