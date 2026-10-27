import 'package:ccmahal_dashboard/ui/offline_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the notice says it cannot reach the database, hides raw errors, and its buttons work',
    (tester) async {
      var retried = 0, signedOut = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineNotice(
            onRetry: () => retried++,
            onSignOut: () => signedOut++,
          ),
        ),
      );
      expect(find.textContaining("Can't reach the database"), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('retry')));
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      expect([retried, signedOut], [1, 1]);
      expect(
        tester.getSize(find.byKey(const ValueKey('retry'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('sign-out'))).height,
        greaterThanOrEqualTo(44),
      );
    },
  );
}
