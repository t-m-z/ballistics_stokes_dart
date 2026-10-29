"""Unabhängige Referenzwerte für die Dart-Tests.

Integriert die Bewegungsgleichungen
    m*x'' = -k*x'
    m*y'' = -k*y' - m*g,   k = 0.5*cw*rho*A
numerisch mit SciPy (DOP853, Event bei y = 0), ohne die analytische Lösung zu nutzen.

Aufruf:  python3 tool/reference_values.py
"""
import math

import numpy as np
from scipy.integrate import solve_ivp

CASES = [
    # name,               v0,   angle, g,     h0,  m,     A,     cw,   rho
    ("leichter Ball",     20.0, 45.0, 9.81,  0.0, 0.01,  0.01,  1.0,  1.2),
    ("Starthöhe 10 m",    15.0, 20.0, 9.81, 10.0, 0.05,  0.02,  0.8,  1.2),
    ("flacher Wurf",      30.0, 10.0, 9.81,  2.0, 0.2,   0.005, 0.47, 1.225),
    ("schräg nach unten", 10.0, -20.0, 9.81, 25.0, 0.02, 0.01,  1.2,  1.2),
    ("Mond",              20.0, 60.0, 1.62,  0.0, 0.01,  0.01,  1.0,  1.2),
]


def simulate(v0, angle, g, h0, m, A, cw, rho):
    k = 0.5 * cw * rho * A
    a = math.radians(angle)

    def rhs(_, s):
        x, y, vx, vy = s
        return [vx, vy, -k / m * vx, -k / m * vy - g]

    def ground(_, s):
        return s[1]

    ground.terminal = True
    ground.direction = -1

    sol = solve_ivp(rhs, (0, 1e4), [0, h0, v0 * math.cos(a), v0 * math.sin(a)],
                    method="DOP853", events=ground, rtol=1e-12, atol=1e-12, dense_output=True)
    t_land = sol.t_events[0][0]
    x, _, vx, vy = sol.y_events[0][0]
    ts = np.linspace(0, t_land, 20001)
    ys = sol.sol(ts)
    max_h = ys[1].max()
    max_v = np.hypot(ys[2], ys[3]).max()
    return t_land, x, max_h, max_v


for name, *p in CASES:
    t, d, h, vmax = simulate(*p)
    print(f"{name:18s} {p}  Time={t:.9f}  Distance={d:.9f}  maxHeight={h:.9f}  maxSpeed={vmax:.9f}")
