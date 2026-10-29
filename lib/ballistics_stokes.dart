import 'dart:math';

enum BALLISTICS_DATA_MODE {
  ANGLE_DURATION_TO_DISTANCE_VELOCITY,
  ANGLE_VELOCITY_TO_DISTANCE_DURATION,
  ANGLE_DISTANCE_TO_DURATION_VELOCITY,
  DURATION_DISTANCE_TO_ANGLE_VELOCITY,
  DURATION_VELOCITY_TO_ANGLE_DISTANCE,
  VELOCITY_DISTANCE_TO_ANGLE_DURATION,
}

class OutputBallistics {
  final double Time;
  final double Distance;
  final double maxHeight;
  final double Speed;
  final double maxSpeed;
  final double Angle;

  OutputBallistics({
    required this.Time,
    required this.Distance,
    required this.maxHeight,
    required this.Speed,
    required this.maxSpeed,
    required this.Angle,
  });
}

/// Schiefer Wurf mit Stokes'scher (linearer) Reibung: F_R = -k * v
///
/// Reibungskoeffizient: k   = 0.5 * cw * rho * A   (als lineare Konstante, kg/s)
/// Zeitkonstante:       tau = m / k
/// Grenzgeschwindigkeit vT  = g * tau
///
/// Analytische Lösung von  m*x'' = -k*x'  und  m*y'' = -k*y' - m*g :
///   x(t)  = vx0 * tau * (1 - e^(-t/tau))
///   y(t)  = h0 + tau * (vy0 + vT) * (1 - e^(-t/tau)) - vT * t
///   vx(t) = vx0 * e^(-t/tau)
///   vy(t) = (vy0 + vT) * e^(-t/tau) - vT
///
/// Ist k = 0, wird automatisch der Wurf im Vakuum gerechnet.
///
/// Eingaben je nach [dataMode]:
///   ANGLE_VELOCITY_TO_DISTANCE_DURATION : Winkel, V0
///   ANGLE_DURATION_TO_DISTANCE_VELOCITY : Winkel, duration
///   ANGLE_DISTANCE_TO_DURATION_VELOCITY : Winkel, distance
///   DURATION_DISTANCE_TO_ANGLE_VELOCITY : duration, distance
///   DURATION_VELOCITY_TO_ANGLE_DISTANCE : duration, V0
///   VELOCITY_DISTANCE_TO_ANGLE_DURATION : V0, distance  (liefert die flache Bahn)
///
/// Ausgabe: Time = Flugdauer [s], Distance = Wurfweite [m], maxHeight [m],
///          Speed = Abwurfgeschwindigkeit [m/s], maxSpeed = max. Geschwindigkeit
///          entlang der Bahn [m/s], Angle = Abwurfwinkel [°].
/// Ist eine Aufgabe nicht lösbar, sind alle Werte NaN.
OutputBallistics calculateBallisticsStokes(
    {required double V0,
    required double Winkel,
    required double g,
    required double startHeight,
    required double Masse,
    required double a,
    required double cw,
    required double rho,
    required BALLISTICS_DATA_MODE dataMode,
    double duration = 0.0,
    double distance = 0.0}) {
  final double k = 0.5 * cw * rho * a;
  final _Model model = _Model(
    g: g,
    h0: startHeight,
    tau: (k > 0 && Masse > 0) ? Masse / k : double.infinity,
  );

  const double deg = pi / 180.0;
  double v0 = double.nan;
  double alpha = double.nan; // rad

  switch (dataMode) {
    case BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION:
      v0 = V0;
      alpha = Winkel * deg;
      break;

    case BALLISTICS_DATA_MODE.ANGLE_DURATION_TO_DISTANCE_VELOCITY:
      alpha = Winkel * deg;
      v0 = _solve((v) => model.fly(v, alpha).time - duration, 0.0, 10.0);
      break;

    case BALLISTICS_DATA_MODE.ANGLE_DISTANCE_TO_DURATION_VELOCITY:
      alpha = Winkel * deg;
      v0 = _solve((v) => model.fly(v, alpha).distance - distance, 0.0, 10.0);
      break;

    case BALLISTICS_DATA_MODE.DURATION_DISTANCE_TO_ANGLE_VELOCITY:
      {
        // geschlossen lösbar: x(T) = D und y(T) = 0 nach vx0, vy0 auflösen
        if (duration <= 0) return _invalid();
        double vx0, vy0;
        if (model.drag) {
          final double c = model.tau * (1 - exp(-duration / model.tau));
          final double vT = g * model.tau;
          vx0 = distance / c;
          vy0 = (vT * duration - startHeight) / c - vT;
        } else {
          vx0 = distance / duration;
          vy0 = (0.5 * g * duration * duration - startHeight) / duration;
        }
        v0 = sqrt(vx0 * vx0 + vy0 * vy0);
        alpha = atan2(vy0, vx0);
      }
      break;

    case BALLISTICS_DATA_MODE.DURATION_VELOCITY_TO_ANGLE_DISTANCE:
      // Flugdauer wächst monoton mit dem Winkel (-90° … +90°)
      v0 = V0;
      alpha = _bisect((al) => model.fly(V0, al).time - duration, -pi / 2, pi / 2);
      break;

    case BALLISTICS_DATA_MODE.VELOCITY_DISTANCE_TO_ANGLE_DURATION:
      // Weite ist nicht monoton im Winkel: Optimum suchen, dann flache Lösung
      {
        v0 = V0;
        final double alphaOpt = _goldenMax((al) => model.fly(V0, al).distance, -pi / 2, pi / 2);
        alpha = _bisect((al) => model.fly(V0, al).distance - distance, -pi / 2, alphaOpt);
      }
      break;
  }

  if (v0.isNaN || alpha.isNaN || v0 < 0) return _invalid();

  final _Flight f = model.fly(v0, alpha);
  return OutputBallistics(
    Time: f.time,
    Distance: f.distance,
    maxHeight: f.maxHeight,
    Speed: v0,
    maxSpeed: f.maxSpeed,
    Angle: alpha / deg,
  );
}

// ---------------------------------------------------------------------------

class _Flight {
  final double time, distance, maxHeight, maxSpeed;
  _Flight(this.time, this.distance, this.maxHeight, this.maxSpeed);
}

class _Model {
  final double g, h0, tau; // tau = infinity -> keine Reibung
  _Model({required this.g, required this.h0, required this.tau});

  bool get drag => tau.isFinite;

  double x(double t, double vx0) => drag ? vx0 * tau * (1 - exp(-t / tau)) : vx0 * t;

  double y(double t, double vy0) => drag
      ? h0 + tau * (vy0 + g * tau) * (1 - exp(-t / tau)) - g * tau * t
      : h0 + vy0 * t - 0.5 * g * t * t;

  double vx(double t, double vx0) => drag ? vx0 * exp(-t / tau) : vx0;

  double vy(double t, double vy0) => drag ? (vy0 + g * tau) * exp(-t / tau) - g * tau : vy0 - g * t;

  double peakTime(double vy0) {
    if (vy0 <= 0) return 0.0;
    return drag ? tau * log(1 + vy0 / (g * tau)) : vy0 / g;
  }

  _Flight fly(double v0, double alpha) {
    final double vx0 = v0 * cos(alpha);
    final double vy0 = v0 * sin(alpha);

    final double tPeak = peakTime(vy0);
    final double maxHeight = y(tPeak, vy0);

    // Aufschlagzeit y(t) = 0 per Bisektion
    double tLand = 0.0;
    if (maxHeight > 0) {
      double hi = max(tPeak, 1e-3);
      int guard = 0;
      while (y(hi, vy0) > 0 && guard++ < 200) {
        hi *= 2;
      }
      tLand = _bisect((t) => y(t, vy0), tPeak, hi);
    }

    double speed(double t) => sqrt(pow(vx(t, vx0), 2) + pow(vy(t, vy0), 2));
    double maxSpeed = max(v0, speed(tLand));
    const int steps = 500;
    for (int i = 1; i < steps; i++) {
      maxSpeed = max(maxSpeed, speed(tLand * i / steps));
    }

    return _Flight(tLand, x(tLand, vx0), maxHeight, maxSpeed);
  }
}

/// Nullstelle von f auf [lo, hi] (Vorzeichenwechsel vorausgesetzt), sonst NaN.
double _bisect(double Function(double) f, double lo, double hi) {
  double flo = f(lo);
  final double fhi = f(hi);
  if (flo == 0) return lo;
  if (fhi == 0) return hi;
  if (flo.sign == fhi.sign) return double.nan;
  for (int i = 0; i < 200; i++) {
    final double mid = 0.5 * (lo + hi);
    final double fmid = f(mid);
    if (fmid.sign == flo.sign) {
      lo = mid;
      flo = fmid;
    } else {
      hi = mid;
    }
    if ((hi - lo).abs() < 1e-12) break;
  }
  return 0.5 * (lo + hi);
}

/// Sucht von [lo] aus ein Intervall mit Vorzeichenwechsel (hi wird verdoppelt)
/// und bestimmt darin die Nullstelle.
double _solve(double Function(double) f, double lo, double hi) {
  final double flo = f(lo);
  for (int i = 0; i < 60; i++) {
    if (f(hi).sign != flo.sign) return _bisect(f, lo, hi);
    hi *= 2;
  }
  return double.nan;
}

/// Maximum einer unimodalen Funktion per Goldenem Schnitt.
double _goldenMax(double Function(double) f, double lo, double hi) {
  const double r = 0.6180339887498949;
  double c = hi - r * (hi - lo);
  double d = lo + r * (hi - lo);
  for (int i = 0; i < 200 && (hi - lo).abs() > 1e-10; i++) {
    if (f(c) > f(d)) {
      hi = d;
    } else {
      lo = c;
    }
    c = hi - r * (hi - lo);
    d = lo + r * (hi - lo);
  }
  return 0.5 * (lo + hi);
}

OutputBallistics _invalid() => OutputBallistics(
      Time: double.nan,
      Distance: double.nan,
      maxHeight: double.nan,
      Speed: double.nan,
      maxSpeed: double.nan,
      Angle: double.nan,
    );
