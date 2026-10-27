import 'paths.dart';

/// One permission question from a session on the PC (see hooks/dashboard.ts,
/// `askApp`, in the my-mod plugin). The app writes only `answer`.
class AskInfo {
  AskInfo({
    required this.sessionKey,
    required this.id,
    required this.tool,
    required this.detail,
    required this.label,
    required this.createdAt,
    required this.status,
    this.why,
    this.answeredBy,
  });

  final String sessionKey;
  final String id;
  final String tool;
  final String detail;
  final String label;
  final int createdAt;
  final String status; // pending | allowed | denied | expired
  final String? why;
  final String? answeredBy;

  bool get isPending => status == 'pending';

  /// The plugin waits five minutes; a question still pending well after that
  /// belongs to a PC that went away, so it is shown as expired.
  static const staleAfterMs = 6 * 60 * 1000;

  AskInfo withStaleCheck(int serverNow) =>
      isPending && serverNow - createdAt > staleAfterMs
      ? AskInfo(
          sessionKey: sessionKey,
          id: id,
          tool: tool,
          detail: detail,
          label: label,
          createdAt: createdAt,
          status: 'expired',
          why: why,
          answeredBy: answeredBy,
        )
      : this;

  /// The one field the app may write, and only while the ask is pending.
  String answerPath(String uid) => '${asksPath(uid)}/$sessionKey/$id/answer';
}

/// Reads `users/<uid>/asks` defensively, newest first: anything malformed is skipped.
List<AskInfo> parseAsks(Object? value) {
  final out = <AskInfo>[];
  if (value is! Map) return out;
  value.forEach((sk, byAsk) {
    if (byAsk is! Map) return;
    byAsk.forEach((id, raw) {
      if (raw is! Map) return;
      final tool = raw['tool'];
      final detail = raw['detail'];
      final status = raw['status'];
      final at = raw['createdAt'];
      if (tool is! String ||
          detail is! String ||
          status is! String ||
          at is! num)
        return;
      final why = raw['why'];
      final by = raw['answeredBy'];
      final label = raw['session'];
      out.add(
        AskInfo(
          sessionKey: '$sk',
          id: '$id',
          tool: tool,
          detail: detail,
          label: label is String ? label : '',
          createdAt: at.round(),
          status: status,
          why: why is String && why.isNotEmpty ? why : null,
          answeredBy: by is String ? by : null,
        ),
      );
    });
  });
  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}
