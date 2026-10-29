# ballistics_stokes_dart

Berechnet ballistische Daten für den schiefen Wurf mit **Stokes'scher (linearer) Reibung** `F = -k·v`.
Der Reibungskoeffizient wird aus Luftwiderstandsbeiwert, Luftdichte und Stirnfläche gebildet:

```
k   = ½ · cw · ρ · A
τ   = m / k          (Zeitkonstante)
v_T = g · τ          (Grenzgeschwindigkeit)

x(t) = v₀ₓ · τ · (1 − e^(−t/τ))
y(t) = h₀ + τ · (v₀ᵧ + v_T) · (1 − e^(−t/τ)) − v_T · t
```

Für `k = 0` wird automatisch der Wurf im Vakuum gerechnet.

> Hinweis: Physikalisch korrekte Stokes-Reibung wäre `k = 6πηr` (Viskosität, Radius).
> `½·cw·ρ·A` als lineare Konstante ist eine Näherung, wie sie viele Online-Rechner verwenden.

## Verwendung

```dart
import 'package:ballistics_stokes_dart/ballistics_stokes.dart';

final r = calculateBallisticsStokes(
  V0: 25,          // m/s
  Winkel: 30,      // Grad
  g: 9.81,
  startHeight: 1.5,
  Masse: 0.5,      // kg
  a: 0.01,         // Stirnfläche m²
  cw: 0.47,
  rho: 1.2,        // kg/m³
  dataMode: BALLISTICS_DATA_MODE.ANGLE_VELOCITY_TO_DISTANCE_DURATION,
);
print('Weite: ${r.Distance} m, Dauer: ${r.Time} s');
```

## Modi

| Modus | Eingaben | Berechnet |
|---|---|---|
| `ANGLE_VELOCITY_TO_DISTANCE_DURATION` | `Winkel`, `V0` | Weite, Dauer |
| `ANGLE_DURATION_TO_DISTANCE_VELOCITY` | `Winkel`, `duration` | Weite, v₀ |
| `ANGLE_DISTANCE_TO_DURATION_VELOCITY` | `Winkel`, `distance` | Dauer, v₀ |
| `DURATION_DISTANCE_TO_ANGLE_VELOCITY` | `duration`, `distance` | Winkel, v₀ (geschlossen) |
| `DURATION_VELOCITY_TO_ANGLE_DISTANCE` | `duration`, `V0` | Winkel, Weite |
| `VELOCITY_DISTANCE_TO_ANGLE_DURATION` | `V0`, `distance` | Winkel, Dauer (flache Bahn) |

Ausgabe (`OutputBallistics`): `Time` [s], `Distance` [m], `maxHeight` [m], `Speed` = Abwurfgeschwindigkeit [m/s],
`maxSpeed` = maximale Geschwindigkeit entlang der Bahn [m/s], `Angle` = Abwurfwinkel [°].
Ist eine Aufgabe nicht lösbar, sind alle Werte `NaN`.

## Tests

```
dart pub get
dart test
```
