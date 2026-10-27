import 'package:ccmahal_dashboard/cmds.dart';
import 'package:ccmahal_dashboard/paths.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> raw({
  String status = 'queued',
  int at = 1000,
  String target = 'main',
  String text = 'hello',
  String? quick,
  String? note,
}) => {
  'v': 1,
  'target': target,
  'text': text,
  'createdAt': at,
  'status': status,
  'quick': ?quick,
  'note': ?note,
};

void main() {
  test('cmd paths build the per-person paths and refuse a bad key', () {
    expect(cmdsPath('u1'), 'users/u1/cmd');
    expect(cmdPath('u1', 's-1'), 'users/u1/cmd/s-1');
    expect(appCmdPath('u1'), 'users/u1/prefs/appCmd');
    expect(() => cmdsPath('a/b'), throwsArgumentError);
    expect(() => cmdPath('u1', 'a.b'), throwsArgumentError);
    expect(() => cmdPath('u1', ''), throwsArgumentError);
    expect(() => appCmdPath(''), throwsArgumentError);
  });

  test('parseCmds reads the nested map, newest first, and skips junk', () {
    final list = parseCmds({
      's1': {
        'old': raw(at: 1000, status: 'delivered'),
        'new': raw(at: 3000, quick: 'pause'),
        'junk': 'nope',
        'nostatus': {'v': 1, 'target': 'main', 'text': 'x', 'createdAt': 5},
        'badstatus': raw(status: 'weird'),
      },
      's2': {'mid': raw(at: 2000, status: 'failed', note: 'too old')},
      'bad': 5,
    });
    expect(list.map((c) => c.id), ['new', 'mid', 'old']);
    expect(list.first.sessionKey, 's1');
    expect(list.first.quick, 'pause');
    expect(list.first.status, 'queued');
    expect(list[1].note, 'too old');
    expect(list.last.text, 'hello');
    expect(parseCmds(null), isEmpty);
    expect(parseCmds('x'), isEmpty);
  });

  test('an unknown quick value is dropped, not trusted', () {
    final c = parseCmds({
      's1': {'a': raw(quick: 'explode')},
    }).single;
    expect(c.quick, isNull);
  });

  test('a queued command older than ten minutes reads as failed: too old', () {
    final c = parseCmds({
      's1': {'a': raw(at: 1000)},
    }).single;
    expect(c.withStaleCheck(1000 + 9 * 60 * 1000).status, 'queued');
    final old = c.withStaleCheck(1000 + 11 * 60 * 1000);
    expect(old.status, 'failed');
    expect(old.note, 'too old');
    final done = parseCmds({
      's1': {'a': raw(at: 1000, status: 'delivered')},
    }).single;
    expect(done.withStaleCheck(1 << 40).status, 'delivered');
  });

  test('buildCmdEntry makes the entry the rules accept', () {
    final e = buildCmdEntry(target: 'main', text: '  do it  ', queued: 0)!;
    expect(e, {
      'v': 1,
      'target': 'main',
      'text': 'do it',
      'createdAt': {'.sv': 'timestamp'},
      'status': 'queued',
    });
    expect(e.containsKey('quick'), isFalse);
  });

  test('text is trimmed and must be 1 to 500 characters', () {
    expect(buildCmdEntry(target: 'main', text: '   ', queued: 0), isNull);
    expect(buildCmdEntry(target: 'main', text: '', queued: 0), isNull);
    expect(
      buildCmdEntry(target: 'main', text: 'a' * 500, queued: 0),
      isNotNull,
    );
    expect(buildCmdEntry(target: 'main', text: 'a' * 501, queued: 0), isNull);
    expect(
      buildCmdEntry(target: 'main', text: ' ${'a' * 500} ', queued: 0),
      isNotNull,
    );
  });

  test('target must be 1 to 40 characters', () {
    expect(buildCmdEntry(target: '', text: 'x', queued: 0), isNull);
    expect(buildCmdEntry(target: 'a' * 40, text: 'x', queued: 0), isNotNull);
    expect(buildCmdEntry(target: 'a' * 41, text: 'x', queued: 0), isNull);
  });

  test('a ninth queued command in a session is refused', () {
    expect(buildCmdEntry(target: 'main', text: 'x', queued: 7), isNotNull);
    expect(buildCmdEntry(target: 'main', text: 'x', queued: 8), isNull);
    expect(maxQueued, 8);
  });

  test('quick actions are canned text and set the quick field', () {
    const expected = {
      'pause': 'please pause after the current step',
      'continue': 'please continue',
      'stop': 'please stop after the current step and wait for me',
      'status': 'please report your status in one short message',
    };
    expected.forEach((q, t) {
      final e = buildCmdEntry(
        target: 'all',
        text: 'ignored',
        quick: q,
        queued: 0,
      )!;
      expect(e['text'], t);
      expect(e['quick'], q);
      expect(quickTexts[q], t);
    });
    expect(
      buildCmdEntry(target: 'all', text: 'x', quick: 'nope', queued: 0),
      isNull,
    );
  });

  test('the block reason says why sending is off', () {
    expect(
      cmdBlockReason(appCmd: false, offline: false, queued: 0),
      'Turn on instructions in Settings',
    );
    expect(
      cmdBlockReason(appCmd: true, offline: true, queued: 0),
      'This session is offline',
    );
    expect(
      cmdBlockReason(appCmd: true, offline: false, queued: 8),
      contains('8'),
    );
    expect(cmdBlockReason(appCmd: true, offline: false, queued: 7), isNull);
    // the switch is the first reason given
    expect(
      cmdBlockReason(appCmd: false, offline: true, queued: 8),
      'Turn on instructions in Settings',
    );
  });
}
