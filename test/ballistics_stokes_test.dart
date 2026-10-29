import 'dart:math';

import 'package:ballistics_stokes_dart/ballistics_stokes.dart';
import 'package:test/test.dart';

OutputBallistics _calc(BALLISTICS_DATA_MODE mode,
        {double v0 = 0, double angle = 0, double duration = 0, double distance = 0, double cw = 0.47}) =>
    calculateBallisticsStokes(
      V0: v0,
      Winkel: angle,
      g: 9.81,
      startHeight: 1.5,
      Masse: 0.5,
      a: 0.01,
      cw: cw,
      rho: 1.2,
      dataMode: mode,
      duration: duration,
      distance: distance,
    );

void main() {
  test('Vakuum, Starthöhe 0, 45°: Weite = v0²/g', () {
    final r = calculateBallisticsStokes(
      V0: 20,
      Winkel: 45,
      g: 9.81,
      startHeight: 0,
      Masse: 1,
      a: 0,
      cw: 0,
      rho: 0,
      dataMode: BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION,
    );
    expect(r.Distance, closeTo(400 / 9.81, 1e-6));
    expect(r.Time, closeTo(2 * 20 * sin(pi / 4) / 9.81, 1e-6));
  });

  test('Reibung verkürzt die Wurfweite', () {
    final withDrag = _calc(BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION, v0: 30, angle: 40);
    final vacuum = _calc(BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION, v0: 30, angle: 40, cw: 0);
    expect(withDrag.Distance, lessThan(vacuum.Distance));
  });

  group('Inverse Modi ergeben die Ausgangswerte', () {
    final ref = _calc(BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION, v0: 25, angle: 30);

    test('Winkel + Dauer', () {
      final r = _calc(BALLISTICS_DATA_MODE.ANGLE_DURATION_TO_DISTANCE_VELOCITY, angle: 30, duration: ref.Time);
      expect(r.Speed, closeTo(25, 1e-6));
    });

    test('Winkel + Weite', () {
      final r = _calc(BALLISTICS_DATA_MODE.ANGLE_DISTANCE_TO_DURATION_VELOCITY, angle: 30, distance: ref.Distance);
      expect(r.Speed, closeTo(25, 1e-6));
    });

    test('Dauer + Weite', () {
      final r = _calc(BALLISTICS_DATA_MODE.DURATION_DISTANCE_TO_ANGLE_VELOCITY,
          duration: ref.Time, distance: ref.Distance);
      expect(r.Speed, closeTo(25, 1e-6));
      expect(r.Angle, closeTo(30, 1e-6));
    });

    test('Dauer + Geschwindigkeit', () {
      final r = _calc(BALLISTICS_DATA_MODE.DURATION_VELOCITY_TO_ANGLE_DISTANCE, v0: 25, duration: ref.Time);
      expect(r.Angle, closeTo(30, 1e-6));
    });

    test('Geschwindigkeit + Weite (flache Bahn)', () {
      final r = _calc(BALLISTICS_DATA_MODE.VELOCITY_DISTANCE_TO_ANGLE_DURATION, v0: 25, distance: ref.Distance);
      expect(r.Angle, closeTo(30, 1e-6));
    });
  });

  test('Nicht erreichbare Weite liefert NaN', () {
    final r = _calc(BALLISTICS_DATA_MODE.VELOCITY_DISTANCE_TO_ANGLE_DURATION, v0: 5, distance: 1000);
    expect(r.Distance.isNaN, isTrue);
  });
}
