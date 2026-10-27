import 'dart:ui';

enum Stage { dawn, day, dusk, night }

/// The light of the office at one time of day.
class Environment {
  const Environment({
    required this.stage,
    required this.dayness,
    required this.lamps,
    required this.sun,
    required this.moon,
    required this.skyTop,
    required this.skyBottom,
    required this.wall,
    required this.floor,
    required this.ambient,
  });

  final Stage stage;

  /// 0 at night, 1 in full daylight.
  final double dayness;

  /// How brightly the desk lamps burn: 1 - dayness.
  final double lamps;

  /// Position of the sun across its arc: 0 at 06:00, 1 at 18:00 (clamped).
  final double sun;

  /// Position of the moon across its arc: 0 at 18:00, 1 at 06:00 (clamped).
  final double moon;

  final Color skyTop;
  final Color skyBottom;
  final Color wall;
  final Color floor;

  /// A blue wash over the whole room at night (alpha 0 by day).
  final Color ambient;
}

const _dawnStart = 6 * 60;
const _dayStart = 8 * 60;
const _duskStart = 17 * 60;
const _nightStart = 19 * 60;

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _daynessAt(int t) {
  if (t < _dawnStart) return 0;
  if (t < _dayStart)
    return _smooth((t - _dawnStart) / (_dayStart - _dawnStart));
  if (t < _duskStart) return 1;
  if (t < _nightStart)
    return 1 - _smooth((t - _duskStart) / (_nightStart - _duskStart));
  return 0;
}

Stage _stageAt(int t) {
  if (t >= _dawnStart && t < _dayStart) return Stage.dawn;
  if (t >= _dayStart && t < _duskStart) return Stage.day;
  if (t >= _duskStart && t < _nightStart) return Stage.dusk;
  return Stage.night;
}

Color _mix(Color night, Color day, double d) => Color.lerp(night, day, d)!;

/// The environment at a local time. Pure and total: it reads only the hour
/// and the minute, so time zones and daylight-saving jumps cannot break it.
Environment environmentAt(DateTime local) {
  final t = local.hour * 60 + local.minute;
  final d = _daynessAt(t);
  final sun = ((t - _dawnStart) / (12 * 60)).clamp(0.0, 1.0).toDouble();
  final moon = (((t - 18 * 60) % 1440) / (12 * 60)).clamp(0.0, 1.0).toDouble();
  return Environment(
    stage: _stageAt(t),
    dayness: d,
    lamps: 1 - d,
    sun: sun,
    moon: moon,
    skyTop: _mix(const Color(0xFF0A1030), const Color(0xFF6FB7F2), d),
    skyBottom: _mix(const Color(0xFF2B3A78), const Color(0xFFCDEBFF), d),
    wall: _mix(const Color(0xFF4A4A66), const Color(0xFFEFE6D4), d),
    floor: _mix(const Color(0xFF5B4630), const Color(0xFFC8A77E), d),
    ambient: Color.fromARGB((92 * (1 - d)).round(), 0x0B, 0x12, 0x38),
  );
}
