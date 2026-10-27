import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/office/mood.dart';
import 'package:flutter_test/flutter_test.dart';

SessionInfo session({
  String status = 'idle',
  int pending = 0,
  int seenAt = 100000,
}) => SessionInfo.fromMap('k', {
  'status': status,
  'seenAt': seenAt,
  'gate': {'pending': pending},
});

void main() {
  test('a running agent is working', () {
    expect(
      moodOf(agentStatus: 'running', sessionOffline: false),
      CrabMood.working,
    );
  });

  test('failed is failed and done is done', () {
    expect(
      moodOf(agentStatus: 'failed', sessionOffline: false),
      CrabMood.failed,
    );
    expect(moodOf(agentStatus: 'done', sessionOffline: false), CrabMood.done);
  });

  test('an unknown agent status reads as done, not as a crash', () {
    expect(moodOf(agentStatus: 'weird', sessionOffline: false), CrabMood.done);
  });

  test('an offline session shows every agent idle', () {
    for (final s in ['running', 'failed', 'done']) {
      expect(moodOf(agentStatus: s, sessionOffline: true), CrabMood.idle);
    }
  });

  test('main waits when a question is pending and the session is live', () {
    expect(
      mainMoodOf(session(status: 'running', pending: 1), 100000),
      CrabMood.waiting,
    );
  });

  test('main works when the session runs', () {
    expect(mainMoodOf(session(status: 'running'), 100000), CrabMood.working);
  });

  test(
    'main is idle otherwise, and when offline even with a pending question',
    () {
      expect(mainMoodOf(session(), 100000), CrabMood.idle);
      expect(
        mainMoodOf(session(status: 'running', pending: 2), 100000 + 120000),
        CrabMood.idle,
      );
    },
  );

  test('main is idle for an ended session', () {
    expect(
      mainMoodOf(session(status: 'ended', pending: 1), 100000),
      CrabMood.idle,
    );
  });
}
