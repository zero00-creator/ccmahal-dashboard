import 'package:ccmahal_dashboard/update/update_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const _sha = 'a3f1c2d4e5b60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

Map<String, dynamic> release({
  String tag = 'v1.0.1',
  String? body = 'Fixes things',
  List<Map<String, dynamic>>? assets,
}) => {
  'tag_name': tag,
  'name': 'Release $tag',
  'body': body,
  'assets':
      assets ??
      [
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://github.com/zero00-creator/ccmahal-dashboard/releases/download/v1.0.1/app-release.apk',
          'size': 12345,
          'digest': 'sha256:$_sha',
        },
      ],
};

void main() {
  group('isNewerVersion', () {
    const table = <(String, String, bool)>[
      ('1.0.0', '1.0.1', true),
      ('1.0.9', '1.0.10', true),
      ('1.0.10', '1.0.9', false),
      ('1.0.0', '1.0.0', false),
      ('1.0.0+1', 'v1.0.0', false),
      ('1.0.0+5', 'v1.0.1', true),
      ('1.2.0', 'v1.10.0', true),
      ('2.0.0', 'v1.99.99', false),
      ('1.0.0', 'v2.0.0+7', true),
      ('1.0.0', 'banana', false),
      ('1.0.0', 'v1.0', false),
      ('1.0.0', 'v1.0.x', false),
      ('1.0.0', '', false),
      ('oops', 'v1.0.1', false),
    ];
    for (final (cur, latest, want) in table) {
      test('$cur vs $latest is $want', () {
        expect(isNewerVersion(cur, latest), want);
      });
    }
  });

  group('parseRelease', () {
    test('a good release', () {
      final r = parseRelease(release())!;
      expect(r.tag, 'v1.0.1');
      expect(r.notes, 'Fixes things');
      expect(r.size, 12345);
      expect(r.sha256, _sha);
      expect(r.url.host, 'github.com');
    });

    test('also reads a JSON string', () {
      expect(parseRelease('{"tag_name":"v1.0.1","assets":[]}'), isNull);
    });

    test('notes are shortened to about 300 characters', () {
      final r = parseRelease(release(body: 'x' * 1000))!;
      expect(r.notes.length, lessThanOrEqualTo(maxNotesLength + 1));
      expect(r.notes.endsWith('…'), isTrue);
    });

    test('no apk asset', () {
      expect(
        parseRelease(
          release(
            assets: [
              {
                'name': 'notes.txt',
                'browser_download_url': 'https://github.com/x/y.txt',
              },
            ],
          ),
        ),
        isNull,
      );
      expect(parseRelease(release(assets: [])), isNull);
    });

    test('untrusted hosts and plain http are refused', () {
      for (final url in [
        'https://evil.example.com/app.apk',
        'http://github.com/a/app.apk',
        'https://github.com.evil.com/app.apk',
        'https://objects.githubusercontent.com.evil.io/app.apk',
      ]) {
        expect(
          parseRelease(
            release(
              assets: [
                {'name': 'app.apk', 'browser_download_url': url},
              ],
            ),
          ),
          isNull,
          reason: url,
        );
      }
    });

    test('objects.githubusercontent.com is accepted', () {
      final r = parseRelease(
        release(
          assets: [
            {
              'name': 'app.apk',
              'browser_download_url':
                  'https://objects.githubusercontent.com/a/app.apk',
            },
          ],
        ),
      );
      expect(r, isNotNull);
      expect(r!.size, isNull);
      expect(r.sha256, isNull);
    });

    test('malformed input gives null and never throws', () {
      for (final bad in <Object?>[
        null,
        42,
        'not json',
        <String, dynamic>{},
        {'tag_name': 5, 'assets': []},
        {'tag_name': 'v1.0.1', 'assets': 'nope'},
        {
          'tag_name': 'v1.0.1',
          'assets': [7, null],
        },
        {
          'tag_name': 'v1.0.1',
          'assets': [
            {'name': 'a.apk', 'browser_download_url': 12},
          ],
        },
      ]) {
        expect(parseRelease(bad), isNull, reason: '$bad');
      }
    });

    test('a bad digest is ignored, not fatal', () {
      final r = parseRelease(
        release(
          assets: [
            {
              'name': 'a.apk',
              'browser_download_url': 'https://github.com/a/a.apk',
              'digest': 'md5:abc',
            },
          ],
        ),
      );
      expect(r, isNotNull);
      expect(r!.sha256, isNull);
    });
  });

  group('digest', () {
    test('parseDigest', () {
      expect(parseDigest('sha256:${_sha.toUpperCase()}'), _sha);
      expect(parseDigest('sha256:short'), isNull);
      expect(parseDigest(null), isNull);
      expect(parseDigest(3), isNull);
    });

    test('digestMatches is exact and case-insensitive', () {
      expect(digestMatches(_sha, _sha.toUpperCase()), isTrue);
      expect(digestMatches(_sha, '${_sha.substring(1)}0'), isFalse);
    });
  });

  group('decideUpdate', () {
    test('newer release gives UpdateInfo without the v', () {
      final u = decideUpdate('1.0.0+1', parseRelease(release()))!;
      expect(u.version, '1.0.1');
      expect(u.sha256, _sha);
    });
    test('same, older, malformed or missing gives null', () {
      expect(decideUpdate('1.0.1', parseRelease(release())), isNull);
      expect(decideUpdate('1.0.2', parseRelease(release())), isNull);
      expect(decideUpdate('x', parseRelease(release())), isNull);
      expect(decideUpdate('1.0.0', null), isNull);
      expect(
        decideUpdate('1.0.0', parseRelease(release(tag: 'latest'))),
        isNull,
      );
    });
  });

  test('the repo slug is one constant used for the URL', () {
    expect(latestReleaseUri().toString(), contains(updateRepoSlug));
  });
}
