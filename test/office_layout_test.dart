import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/office/iso.dart';
import 'package:ccmahal_dashboard/office/layout.dart';
import 'package:flutter_test/flutter_test.dart';

AgentInfo agent(String id, int startedAt, {String status = 'running'}) =>
    AgentInfo(
      id: id,
      type: 'coder-low',
      task: 't',
      model: 'm',
      status: status,
      startedAt: startedAt,
      costUsd: 0,
      stepNote: '',
    );

void main() {
  const iso = IsoProjection(tileW: 28, tileH: 14, origin: Offset(100, 50));

  test('toScreen at (0,0) is the origin', () {
    expect(iso.toScreen(0, 0), const Offset(100, 50));
  });

  test('(1,0) moves right and down by half a tile', () {
    expect(iso.toScreen(1, 0), const Offset(114, 57));
  });

  test('(0,1) moves left and down by half a tile', () {
    expect(iso.toScreen(0, 1), const Offset(86, 57));
  });

  test('z lifts up', () {
    expect(iso.toScreen(0, 0, 10), const Offset(100, 40));
  });

  test('zero agents gives the main seat only and no overflow', () {
    final plan = planSeats(const []);
    expect(plan.seats, hasLength(1));
    expect(plan.seats.first.agent, isNull);
    expect(plan.overflow, 0);
  });

  test('twelve agents give 8 seats (1 main plus 7 agents) and overflow 5', () {
    final agents = [for (var i = 0; i < 12; i++) agent('a$i', i)];
    final plan = planSeats(agents);
    expect(plan.seats, hasLength(8));
    expect(plan.seats.where((s) => s.agent != null), hasLength(7));
    expect(plan.overflow, 5);
  });

  test('an agent keeps its seat when statuses change or the input order is shuffled', () {
    final assigner = SeatAssigner();
    Map<String, (double, double)> desks(SeatPlan p) => {
      for (final s in p.seats)
        if (s.agent != null) s.agent!.id: (s.gx, s.gy),
    };
    final before = desks(
      assigner.plan([agent('x', 1), agent('y', 2), agent('z', 3)]),
    );
    final after = desks(
      assigner.plan([
        agent('z', 3, status: 'done'),
        agent('x', 1, status: 'failed'),
        agent('y', 2),
      ]),
    );
    expect(after, before);
  });

  test('duplicate ids do not seat the same agent twice', () {
    final plan = planSeats([
      agent('same', 1),
      agent('same', 2),
      agent('other', 3),
    ]);
    final ids = plan.seats
        .where((s) => s.agent != null)
        .map((s) => s.agent!.id)
        .toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(['same', 'other']));
  });

  test('seats do not overlap', () {
    final plan = planSeats([for (var i = 0; i < 7; i++) agent('a$i', i)]);
    final spots = plan.seats.map((s) => (s.gx, s.gy)).toSet();
    expect(spots.length, plan.seats.length);
  });

  test('eight finished agents and two running ones: both running agents get a desk', () {
    final agents = [
      for (var i = 0; i < 8; i++) agent('done$i', i, status: 'done'),
      agent('run1', 100),
      agent('run2', 101),
    ];
    final ids = SeatAssigner()
        .plan(agents)
        .seats
        .where((s) => s.agent != null)
        .map((s) => s.agent!.id)
        .toSet();
    expect(ids, containsAll(['run1', 'run2']));
    expect(ids, hasLength(7));
  });

  test('removing the oldest agent does not move the others', () {
    final assigner = SeatAssigner();
    Map<String, (double, double)> desks(SeatPlan p) => {
      for (final s in p.seats)
        if (s.agent != null) s.agent!.id: (s.gx, s.gy),
    };
    final first = desks(
      assigner.plan([for (var i = 0; i < 5; i++) agent('a$i', i)]),
    );
    final second = desks(
      assigner.plan([for (var i = 1; i < 5; i++) agent('a$i', i)]),
    );
    for (final id in second.keys) {
      expect(second[id], first[id], reason: id);
    }
  });

  test('a new running agent takes the desk of the oldest finished one when the room is full', () {
    final assigner = SeatAssigner();
    final full = [for (var i = 0; i < 7; i++) agent('d$i', i, status: 'done')];
    final before = assigner.plan(full);
    final oldestDesk = before.seats.firstWhere((s) => s.agent?.id == 'd0');
    final after = assigner.plan([...full, agent('fresh', 50)]);
    final fresh = after.seats.firstWhere((s) => s.agent?.id == 'fresh');
    expect((fresh.gx, fresh.gy), (oldestDesk.gx, oldestDesk.gy));
    expect(after.seats.any((s) => s.agent?.id == 'd0'), isFalse);
    expect(after.overflow, 1);
  });

  test(
    'a finished newcomer does not displace anyone when the room is full',
    () {
      final assigner = SeatAssigner();
      final full = [for (var i = 0; i < 7; i++) agent('d$i', i)];
      assigner.plan(full);
      final after = assigner.plan([...full, agent('late', 50, status: 'done')]);
      expect(after.seats.any((s) => s.agent?.id == 'late'), isFalse);
      expect(after.overflow, 1);
    },
  );
}
