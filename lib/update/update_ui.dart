import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/glass.dart';
import 'update_controller.dart';

/// The slim glass banner "Update available - v1.x.y". Tapping it calls [onTap]
/// (open Settings); the x hides it for the session.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.controller,
    required this.style,
    required this.onTap,
  });

  final UpdateController controller;
  final GlassStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final info = controller.info;
        if (!controller.bannerVisible || info == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.x2),
          child: GlassPanel(
            key: const ValueKey('update-banner'),
            style: style,
            radius: Radii.chip,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('update-banner-open'),
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: minTap),
                      child: Padding(
                        padding: const EdgeInsets.only(left: Space.x3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.system_update_rounded,
                              size: 18,
                              color: style.accent,
                            ),
                            const SizedBox(width: Space.x2),
                            Expanded(
                              child: Text(
                                'Update available - v${info.version}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: style.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('update-banner-dismiss'),
                  tooltip: 'Hide',
                  constraints: const BoxConstraints(
                    minWidth: minTap,
                    minHeight: minTap,
                  ),
                  onPressed: controller.dismiss,
                  icon: Icon(Icons.close_rounded, size: 18, color: style.ink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The "App updates" block in Settings. Draws nothing where updates are not
/// supported (web, other platforms).
class UpdateSection extends StatelessWidget {
  const UpdateSection({
    super.key,
    required this.controller,
    required this.style,
  });

  final UpdateController controller;
  final GlassStyle style;

  @override
  Widget build(BuildContext context) {
    if (!controller.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => GlassPanel(
        key: const ValueKey('update-section'),
        style: style,
        padding: const EdgeInsets.all(Space.x4),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    final c = controller;
    final info = c.info;
    final s = c.state;
    final muted = TextStyle(fontSize: 13, color: style.inkMuted);
    final checking = s == UpdateState.checking;
    final downloading = s == UpdateState.downloading;
    final canUpdate =
        info != null && (s == UpdateState.available || s == UpdateState.failed);
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(minTap)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App updates',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: style.ink,
          ),
        ),
        const SizedBox(height: Space.x2),
        Text(
          key: const ValueKey('update-current'),
          c.currentVersion.isEmpty
              ? 'Current version unknown'
              : 'Current version ${c.currentVersion}',
          style: muted,
        ),
        if (s == UpdateState.upToDate) ...[
          const SizedBox(height: Space.x1),
          Text(
            'You have the latest version.',
            key: const ValueKey('update-uptodate'),
            style: TextStyle(fontSize: 13, color: style.ink),
          ),
        ],
        if (s == UpdateState.failed && c.message != null) ...[
          const SizedBox(height: Space.x1),
          Text(
            c.message!,
            key: const ValueKey('update-error'),
            style: TextStyle(fontSize: 13, color: style.error),
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: Space.x3),
          Text(
            'New version ${info.version}',
            key: const ValueKey('update-new'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: style.ink,
            ),
          ),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: Space.x1),
            Text(info.notes, key: const ValueKey('update-notes'), style: muted),
          ],
        ],
        if (downloading) ...[
          const SizedBox(height: Space.x3),
          LinearProgressIndicator(
            key: const ValueKey('update-progress'),
            value: c.progress,
            color: style.accent,
          ),
          const SizedBox(height: Space.x1),
          Text('Downloading ${(c.progress * 100).round()}%', style: muted),
        ],
        const SizedBox(height: Space.x3),
        if (canUpdate)
          FilledButton(
            key: const ValueKey('update-start'),
            style: button,
            onPressed: c.startDownload,
            child: Text(s == UpdateState.failed ? 'Try again' : 'Update'),
          ),
        if (s == UpdateState.downloaded) ...[
          FilledButton(
            key: const ValueKey('update-install'),
            style: button,
            onPressed: c.install,
            child: const Text('Install'),
          ),
        ],
        if (info != null && !checking) ...[
          const SizedBox(height: Space.x2),
          Text(
            'Android asks once to allow installs from this app.',
            key: const ValueKey('update-allow-note'),
            style: muted,
          ),
        ],
        const SizedBox(height: Space.x2),
        TextButton.icon(
          key: const ValueKey('update-check'),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(minTap),
            foregroundColor: style.ink,
            alignment: Alignment.centerLeft,
          ),
          onPressed: checking || downloading ? null : c.checkManual,
          icon: checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(checking ? 'Checking...' : 'Check for updates'),
        ),
      ],
    );
  }
}
