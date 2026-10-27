import 'package:flutter/material.dart';

import '../asks.dart';
import '../theme/tokens.dart';
import 'glass.dart';

String waitedText(Duration d) =>
    d.inMinutes >= 1 ? '${d.inMinutes} min' : '${d.inSeconds.clamp(0, 59)} s';

/// The content of the permission pop-up: who asks, the command, the danger
/// reason, how long it has waited, and Deny / Accept.
class AskDialogBody extends StatelessWidget {
  const AskDialogBody({
    super.key,
    required this.ask,
    required this.style,
    required this.waited,
    required this.onAnswer,
  });

  final AskInfo ask;
  final GlassStyle style;
  final Duration waited;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final big = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(minTap, 48)),
    );
    return GlassPanel(
      key: const ValueKey('ask-card'),
      style: style,
      radius: Radii.card,
      padding: const EdgeInsets.all(Space.x5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: style.accent),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  ask.label.isEmpty ? 'A session' : ask.label,
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
          const SizedBox(height: Space.x1),
          Text(
            'asks to use ${ask.tool}',
            style: TextStyle(color: style.inkMuted),
          ),
          const SizedBox(height: Space.x3),
          Container(
            padding: const EdgeInsets.all(Space.x3),
            decoration: BoxDecoration(
              color: style.ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Text(
              ask.detail,
              key: const ValueKey('ask-detail'),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: style.ink,
              ),
            ),
          ),
          if (ask.why != null) ...[
            const SizedBox(height: Space.x2),
            Text(
              'Dangerous: ${ask.why}',
              style: TextStyle(fontWeight: FontWeight.w700, color: style.error),
            ),
          ],
          const SizedBox(height: Space.x2),
          Text(
            'Waiting ${waitedText(waited)}',
            style: TextStyle(fontSize: 12, color: style.inkMuted),
          ),
          const SizedBox(height: Space.x4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('ask-deny'),
                  style: big,
                  onPressed: () => onAnswer(false),
                  child: const Text('Deny'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('ask-accept'),
                  style: big,
                  onPressed: () => onAnswer(true),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
