import 'dart:math';

import 'package:ballistics_stokes_dart/ballistics_stokes.dart';
import 'package:test/test.dart';

/// Parametersatz für einen Wurf.
class _Case {
  final String name;
  final double v0, angle, g, h0, m, a, cw, rho;
  // Referenzwerte aus tool/reference_values.py (SciPy DOP853, unabhängig von der analytischen Lösung)
  final double time, distance, maxHeight, maxSpeed;
  // liegt der Abwurfwinkel unter dem weitenoptimalen Winkel (flache Bahn)?
  final bool flat;

  const _Case(this.name, this.v0, this.angle, this.g, this.h0, this.m, this.a, this.cw, this.rho,
      {required this.time,
      required this.distance,
      required this.maxHeight,
      required this.maxSpeed,
      this.flat = true});

  OutputBallistics run(BALLISTICS_DATA_MODE mode,
          {double? v0, double? angle, double duration = 0, double distance = 0}) =>
      calculateBallisticsStokes(
        V0: v0 ?? this.v0,
        Winkel: angle ?? this.angle,
        g: g,
        startHeight: h0,
        Masse: m,
        a: a,
        cw: cw,
        rho: rho,
        dataMode: mode,
        duration: duration,
        distance: distance,
      );

  OutputBallistics forward() => run(BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION);
}

const _cases = [
  _Case('leichter Ball', 20.0, 45.0, 9.81, 0.0, 0.01, 0.01, 1.0, 1.2,
      time: 2.348911528, distance: 17.811954266, maxHeight: 6.586911378, maxSpeed: 20.0, flat: false),
  _Case('Starthöhe 10 m', 15.0, 20.0, 9.81, 10.0, 0.05, 0.02, 0.8, 1.2,
      time: 2.090484945, distance: 24.270479758, maxHeight: 11.257950569, maxSpeed: 16.435579102),
  _Case('flacher Wurf', 30.0, 10.0, 9.81, 2.0, 0.2, 0.005, 0.47, 1.225,
      time: 1.360926452, distance: 40.011264278, maxHeight: 3.379682653, maxSpeed: 30.364047778),
  _Case('schräg nach unten', 10.0, -20.0, 9.81, 25.0, 0.02, 0.01, 1.2, 1.2,
      time: 2.276020194, distance: 14.598897053, maxHeight: 25.0, maxSpeed: 17.252382646),
  _Case('Mond', 20.0, 60.0, 1.62, 0.0, 0.01, 0.01, 1.0, 1.2,
      time: 12.350863287, distance: 16.656585711, maxHeight: 19.851739243, maxSpeed: 20.0, flat: false),
];

OutputBallistics _simple(
        {required double v0,
        required double angle,
        double g = 9.81,
        double h0 = 0,
        double m = 1,
        double a = 0,
        double cw = 0,
        double rho = 0}) =>
    calculateBallisticsStokes(
      V0: v0,
      Winkel: angle,
      g: g,
      startHeight: h0,
      Masse: m,
      a: a,
      cw: cw,
      rho: rho,
      dataMode: BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION,
    );

void main() {
  group('Referenzwerte (numerische Integration mit SciPy)', () {
    for (final c in _cases) {
      test(c.name, () {
        final r = c.forward();
        expect(r.Time, closeTo(c.time, 1e-6), reason: 'Time');
        expect(r.Distance, closeTo(c.distance, 1e-6), reason: 'Distance');
        expect(r.maxHeight, closeTo(c.maxHeight, 1e-6), reason: 'maxHeight');
        expect(r.maxSpeed, closeTo(c.maxSpeed, 1e-3), reason: 'maxSpeed');
        expect(r.Speed, closeTo(c.v0, 1e-12), reason: 'Speed = Abwurfgeschwindigkeit');
        expect(r.Angle, closeTo(c.angle, 1e-12), reason: 'Angle = Abwurfwinkel');
      });
    }
  });

  group('Inverse Modi ergeben die Ausgangswerte', () {
    for (final c in _cases) {
      group(c.name, () {
        test('Winkel + Dauer -> v0', () {
          final r = c.run(BALLISTICS_DATA_MODE.ANGLE_DURATION_TO_DISTANCE_VELOCITY, duration: c.time);
          expect(r.Speed, closeTo(c.v0, 1e-5));
          expect(r.Distance, closeTo(c.distance, 1e-5));
        });

        test('Winkel + Weite -> v0', () {
          final r = c.run(BALLISTICS_DATA_MODE.ANGLE_DISTANCE_TO_DURATION_VELOCITY, distance: c.distance);
          expect(r.Speed, closeTo(c.v0, 1e-5));
          expect(r.Time, closeTo(c.time, 1e-5));
        });

        test('Dauer + Weite -> Winkel, v0', () {
          final r = c.run(BALLISTICS_DATA_MODE.DURATION_DISTANCE_TO_ANGLE_VELOCITY,
              duration: c.time, distance: c.distance);
          expect(r.Speed, closeTo(c.v0, 1e-5));
          expect(r.Angle, closeTo(c.angle, 1e-5));
        });

        test('Dauer + v0 -> Winkel', () {
          final r = c.run(BALLISTICS_DATA_MODE.DURATION_VELOCITY_TO_ANGLE_DISTANCE, duration: c.time);
          expect(r.Angle, closeTo(c.angle, 1e-5));
          expect(r.Distance, closeTo(c.distance, 1e-5));
        });

        test('v0 + Weite -> Winkel (flache Bahn)', () {
          final r = c.run(BALLISTICS_DATA_MODE.VELOCITY_DISTANCE_TO_ANGLE_DURATION, distance: c.distance);
          expect(r.Distance, closeTo(c.distance, 1e-5));
          if (c.flat) {
            expect(r.Angle, closeTo(c.angle, 1e-5));
          } else {
            // steile Referenzbahn: geliefert wird die flache Lösung gleicher Weite
            expect(r.Angle, lessThan(c.angle));
            expect(r.Time, lessThan(c.time));
          }
        });
      });
    }
  });

  group('Vakuum (cw = 0)', () {
    test('Starthöhe 0, 45°: Weite = v0²/g, Dauer = 2·v0·sinα/g', () {
      final r = _simple(v0: 20, angle: 45);
      expect(r.Distance, closeTo(400 / 9.81, 1e-9));
      expect(r.Time, closeTo(2 * 20 * sin(pi / 4) / 9.81, 1e-9));
      expect(r.maxHeight, closeTo(pow(20 * sin(pi / 4), 2) / (2 * 9.81), 1e-9));
    });

    test('Wurfparabel mit Starthöhe', () {
      const v0 = 12.0, h0 = 3.0, g = 9.81;
      final al = 35 * pi / 180;
      final vy0 = v0 * sin(al);
      final t = (vy0 + sqrt(vy0 * vy0 + 2 * g * h0)) / g;
      final r = _simple(v0: v0, angle: 35, h0: h0);
      expect(r.Time, closeTo(t, 1e-9));
      expect(r.Distance, closeTo(v0 * cos(al) * t, 1e-9));
    });

    test('a = 0 bzw. rho = 0 schaltet die Reibung ebenfalls ab', () {
      final ref = _simple(v0: 20, angle: 45);
      expect(_simple(v0: 20, angle: 45, cw: 1, rho: 1.2, a: 0).Distance, closeTo(ref.Distance, 1e-12));
      expect(_simple(v0: 20, angle: 45, cw: 1, rho: 0, a: 0.01).Distance, closeTo(ref.Distance, 1e-12));
    });
  });

  group('Physikalische Plausibilität', () {
    test('Näherung für schwache Reibung: R ≈ R_vak · (1 − 4/3 · v0·sinα / vT)', () {
      // Quelle: Computational Solution to the Problems of Projectile Motion under
      // Significant Linear Drag Effect (SCIRP), Näherung für v0 << vT
      const v0 = 20.0, g = 9.81, m = 1.0, a = 0.001, cw = 1.0, rho = 1.2;
      final k = 0.5 * cw * rho * a;
      final vT = g * m / k;
      final al = pi / 4;
      final rVac = v0 * v0 * sin(2 * al) / g;
      final approx = rVac * (1 - 4 / 3 * v0 * sin(al) / vT);
      final r = _simple(v0: v0, angle: 45, m: m, a: a, cw: cw, rho: rho);
      expect((r.Distance - approx).abs() / approx, lessThan(1e-5));
      expect(r.Distance, lessThan(rVac));
    });

    test('Freier Fall aus großer Höhe erreicht die Grenzgeschwindigkeit vT = m·g/k', () {
      const m = 0.01, a = 0.01, cw = 1.0, rho = 1.2, g = 9.81;
      final vT = m * g / (0.5 * cw * rho * a);
      final r = _simple(v0: 0, angle: -90, h0: 5000, m: m, a: a, cw: cw, rho: rho);
      expect(r.maxSpeed, closeTo(vT, 1e-6));
      expect(r.Distance.abs(), lessThan(1e-9));
    });

    test('Senkrechter Wurf: keine Weite, Rückkehr langsamer als Abwurf', () {
      final r = _simple(v0: 15, angle: 90, m: 0.01, a: 0.01, cw: 1, rho: 1.2);
      expect(r.Distance.abs(), lessThan(1e-9));
      expect(r.maxSpeed, closeTo(15, 1e-9));
    });

    test('Reibung verkürzt Weite und Gipfelhöhe', () {
      for (final c in _cases) {
        final drag = c.forward();
        final vac = _simple(v0: c.v0, angle: c.angle, g: c.g, h0: c.h0);
        expect(drag.Distance, lessThan(vac.Distance), reason: c.name);
        expect(drag.maxHeight, lessThanOrEqualTo(vac.maxHeight + 1e-12), reason: c.name);
      }
    });

    test('Schwerere Körper fliegen weiter', () {
      double d(double m) => _simple(v0: 20, angle: 40, m: m, a: 0.01, cw: 1, rho: 1.2).Distance;
      expect(d(0.01), lessThan(d(0.05)));
      expect(d(0.05), lessThan(d(1.0)));
    });

    test('Mit Reibung liegt der optimale Winkel unter 45° (hier ≈ 34,17°)', () {
      double d(double w) => _simple(v0: 20, angle: w, m: 0.01, a: 0.01, cw: 1, rho: 1.2).Distance;
      expect(d(34.17), greaterThan(d(45)));
      expect(d(34.17), greaterThan(d(30)));
      expect(d(34.17), closeTo(18.899791951, 1e-6));
    });

    test('Bei zwei möglichen Bahnen wird die flache geliefert', () {
      const c = _Case('steil', 20.0, 70.0, 9.81, 0.0, 0.01, 0.01, 1.0, 1.2,
          time: 0, distance: 0, maxHeight: 0, maxSpeed: 0);
      final steep = c.forward();
      final r = c.run(BALLISTICS_DATA_MODE.VELOCITY_DISTANCE_TO_ANGLE_DURATION, distance: steep.Distance);
      expect(r.Angle, lessThan(34.18));
      expect(r.Distance, closeTo(steep.Distance, 1e-6));
      expect(r.Time, lessThan(steep.Time));
    });
  });

  group('Unlösbare Eingaben liefern NaN', () {
    final c = _cases.first; // maximale Weite ≈ 18,9 m

    test('Weite größer als die Maximalweite', () {
      final r = c.run(BALLISTICS_DATA_MODE.VELOCITY_DISTANCE_TO_ANGLE_DURATION, distance: 19.0);
      expect(r.Distance.isNaN, isTrue);
      expect(r.Angle.isNaN, isTrue);
    });

    test('Dauer <= 0 bei Dauer + Weite', () {
      final r = c.run(BALLISTICS_DATA_MODE.DURATION_DISTANCE_TO_ANGLE_VELOCITY, duration: 0, distance: 10);
      expect(r.Speed.isNaN, isTrue);
    });

    test('Dauer länger als beim senkrechten Wurf', () {
      final vertical = c.run(BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION, angle: 90);
      final r = c.run(BALLISTICS_DATA_MODE.DURATION_VELOCITY_TO_ANGLE_DISTANCE, duration: vertical.Time + 1);
      expect(r.Angle.isNaN, isTrue);
    });
  });
}
