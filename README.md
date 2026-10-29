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

Die Tests in `test/ballistics_stokes_test.dart` decken ab:

- **Referenzwerte** für fünf Würfe (u. a. mit Starthöhe, schräg nach unten, Mond-Gravitation).
  Sie stammen aus `tool/reference_values.py`, das die Bewegungsgleichungen mit SciPy (DOP853)
  numerisch integriert, also unabhängig von der analytischen Lösung. Neu erzeugen mit
  `python3 tool/reference_values.py` (benötigt `numpy` und `scipy`).
- **Inverse Modi**: Jeder der fünf Rückrechnungs-Modi muss die Ausgangswerte wieder liefern.
  Liegt eine Referenzbahn auf dem steilen Ast, wird geprüft, dass die flache Lösung gleicher Weite kommt.
- **Vakuum**: Wurfparabel-Formeln für `cw = 0`, `A = 0` oder `rho = 0`.
- **Physik**: Näherung für schwache Reibung `R ≈ R_vak · (1 − 4/3 · v₀·sinα / v_T)`,
  Grenzgeschwindigkeit beim freien Fall, senkrechter Wurf, Reibung verkürzt Weite und Gipfelhöhe,
  schwerere Körper fliegen weiter, optimaler Winkel unter 45°.
- **Unlösbare Eingaben** liefern `NaN`.

## Vergleichsrechner und Quellen

Online-Rechner mit **linearer** (Stokes-)Reibung sind selten, die meisten Tools rechnen quadratisch.
Zum Gegenprüfen eignen sich daher vor allem der Vakuumfall und eine eigene Integration der Differentialgleichung.

| Quelle | Modell | Nutzen für den Vergleich |
|---|---|---|
| [Computational Solution to the Problems of Projectile Motion under Significant Linear Drag Effect (SCIRP)](https://www.scirp.org/journal/paperinformation?paperid=124404) | linear, `F = −b·v` | Geschlossene Lösungen für x(t), y(t), Bahnkurve y(x) und Näherung der Wurfweite für schwache Reibung |
| [GeoGebra: Wurf mit Differenzengleichungen](https://www.geogebra.org/m/MsVRs4pn) | Reibung über einen Schieberegler `k`, Modell nicht dokumentiert | Visueller Vergleich der Bahnform |
| [rechner-portal.de: Schiefer-Wurf-Rechner](https://rechner-portal.de/elektronik-physik/mechanik-physik/schiefer-wurf-rechner) | Vakuum, mit Abwurfhöhe und eigenem g | Vergleich für `cw = 0`; hat ebenfalls Rückrechnung von Winkel/Geschwindigkeit aus einer Zielweite |
| [8gwifi Projectile Motion Simulator](https://8gwifi.org/projectile-motion-simulator.jsp) | quadratisch, `½·ρ·Cd·A·v²`, mit Starthöhe | Vakuumfall; quadratische Reibung als obere Abschätzung des Reibungseinflusses |
| [calculate.co.nz: Projectile Motion with Air Drag](https://www.calculate.co.nz/projectile-motion-air-drag-calculator.php) | quadratisch, `k·v²` | wie oben |
| [Uni Kassel, Virtuelles Physiklabor: Schiefer Wurf](https://www.uni-kassel.de/fb10/institute/physik/forschungsgruppen/oberflaechenphysik/virtuelles-physiklabor/mechanik/schiefer-wurf.html) | quadratisch (Newton-Reibung, cw = 1) | Vergleich mit Newton-Reibung |
| [Omni Calculator: Stokes'sches Gesetz](https://www.omnicalculator.com/de/physik/stokessches-gesetz-rechner) | Stokes-Sinkgeschwindigkeit | Wer `k = 6πηr` statt `½·cw·ρ·A` verwenden will |

**Eigene Gegenrechnung** ohne Online-Rechner, z. B. in Wolfram Alpha oder Mathematica:

```
NDSolve[{x''[t] == -k/m x'[t], y''[t] == -k/m y'[t] - g,
         x[0] == 0, y[0] == h0, x'[0] == v0 Cos[a], y'[0] == v0 Sin[a]}, {x, y}, {t, 0, 100}]
```

Oder mit `tool/reference_values.py`, das genau das mit SciPy tut.
