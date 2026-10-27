import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// The glass tab bar at the bottom: Office, Agents, Alerts, Settings.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.style,
    this.blurEnabled = true,
    this.alertCount = 0,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final GlassStyle style;
  final bool blurEnabled;

  /// Open permission questions: shown as a badge on Alerts.
  final int alertCount;

  static const _tabs = [
    (Icons.home_rounded, 'Office'),
    (Icons.groups_rounded, 'Agents'),
    (Icons.notifications_rounded, 'Alerts'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: style,
      blurEnabled: blurEnabled,
      radius: Radii.sheet,
      padding: const EdgeInsets.all(Space.x1),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: _tabs[i].$2,
                child: InkWell(
                  key: ValueKey('tab-$i'),
                  borderRadius: BorderRadius.circular(Radii.sheet - 4),
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: Motion.scaled(context, Motion.quick),
                    constraints: const BoxConstraints(
                      minHeight: 56,
                      minWidth: minTap,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.sheet - 4),
                      color: i == index
                          ? style.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_tabs[i].$2 == 'Alerts' && alertCount > 0)
                          Badge(
                            key: const ValueKey('alert-badge'),
                            label: Text('$alertCount'),
                            child: Icon(
                              _tabs[i].$1,
                              size: 22,
                              color: i == index ? style.accent : style.inkMuted,
                            ),
                          )
                        else
                          Icon(
                            _tabs[i].$1,
                            size: 22,
                            color: i == index ? style.accent : style.inkMuted,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == index ? style.accent : style.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
