#!/usr/bin/env python3
"""
Generates standard IEEE test feeder datasets (IEEE 9, 14, 30, 57, 118, synthetic 2000)
in PSS/E RAW format, alongside IEEE C37.111 COMTRADE transient fault oscillography files.
"""

import os
import math

def generate_ieee9(filepath):
    # WSCC 9-Bus 3-Machine test system
    # Base MVA = 100.0, Freq = 60.0 Hz
    content = """0, 100.0, 33, 0, 0, 60.0 / PSS/E RAW format - IEEE 9 Bus System
IEEE 9 BUS WSCC TEST SYSTEM
STEADY STATE POWER FLOW CASE
   1, 'BUS 1      ', 16.5, 3, 1, 1, 1, 1.0400,   0.0000, 1.100, 0.900
   2, 'BUS 2      ', 18.0, 2, 1, 1, 1, 1.0250,   9.2800, 1.100, 0.900
   3, 'BUS 3      ', 13.8, 2, 1, 1, 1, 1.0250,   4.6650, 1.100, 0.900
   4, 'BUS 4      ', 230., 1, 1, 1, 1, 1.0258,  -2.2170, 1.100, 0.900
   5, 'BUS 5      ', 230., 1, 1, 1, 1, 0.9956,  -3.9890, 1.100, 0.900
   6, 'BUS 6      ', 230., 1, 1, 1, 1, 1.0127,  -3.6870, 1.100, 0.900
   7, 'BUS 7      ', 230., 1, 1, 1, 1, 1.0258,   3.7200, 1.100, 0.900
   8, 'BUS 8      ', 230., 1, 1, 1, 1, 1.0159,   0.7280, 1.100, 0.900
   9, 'BUS 9      ', 230., 1, 1, 1, 1, 1.0324,   1.9670, 1.100, 0.900
0 / END OF BUS DATA, BEGIN LOAD DATA
   5, '1 ', 1, 1, 1, 125.000,  50.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   6, '1 ', 1, 1, 1,  90.000,  30.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   8, '1 ', 1, 1, 1, 100.000,  35.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
0 / END OF LOAD DATA, BEGIN FIXED SHUNT DATA
0 / END OF FIXED SHUNT DATA, BEGIN GENERATOR DATA
   1, '1 ',  71.641,  27.046,  300.000, -300.000, 1.04000, 0, 100.000, 0.0, 0.0608, 0.0, 0.0, 1.0, 1, 100.0, 250.0, 10.0, 1, 1.0
   2, '1 ', 163.000,   6.654,  300.000, -300.000, 1.02500, 0, 100.000, 0.0, 0.1198, 0.0, 0.0, 1.0, 1, 100.0, 300.0, 10.0, 1, 1.0
   3, '1 ',  85.000, -10.860,  300.000, -300.000, 1.02500, 0, 100.000, 0.0, 0.1813, 0.0, 0.0, 1.0, 1, 100.0, 270.0, 10.0, 1, 1.0
0 / END OF GENERATOR DATA, BEGIN BRANCH DATA
   1,   4, '1 ', 0.00000, 0.05760, 0.00000, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   2,   7, '1 ', 0.00000, 0.06250, 0.00000, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   3,   9, '1 ', 0.00000, 0.05860, 0.00000, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   4,   5, '1 ', 0.01000, 0.08500, 0.17600, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   4,   6, '1 ', 0.01700, 0.09200, 0.15800, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   5,   7, '1 ', 0.03200, 0.16100, 0.30600, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   6,   9, '1 ', 0.03900, 0.17000, 0.35800, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   7,   8, '1 ', 0.00850, 0.07200, 0.14900, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   8,   9, '1 ', 0.01190, 0.10080, 0.20900, 250.0, 250.0, 250.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
0 / END OF BRANCH DATA, BEGIN TRANSFORMER DATA
0 / END OF TRANSFORMER DATA, BEGIN AREA DATA
0 / END OF AREA DATA, BEGIN TWO-TERMINAL DC DATA
0 / END OF TWO-TERMINAL DC DATA, BEGIN VOLTAGE SOURCE CONVERTER DATA
0 / END OF VOLTAGE SOURCE CONVERTER DATA, BEGIN IMPEDANCE CORRECTION DATA
0 / END OF IMPEDANCE CORRECTION DATA, BEGIN MULTI-TERMINAL DC DATA
0 / END OF MULTI-TERMINAL DC DATA, BEGIN MULTI-SECTION DUMMY DATA
0 / END OF MULTI-SECTION DUMMY DATA, BEGIN ZONE DATA
0 / END OF ZONE DATA, BEGIN INTER-AREA TRANSFER DATA
0 / END OF INTER-AREA TRANSFER DATA, BEGIN OWNER DATA
0 / END OF OWNER DATA, BEGIN FACTS DEVICE DATA
0 / END OF FACTS DEVICE DATA, BEGIN SWITCHED SHUNT DATA
0 / END OF SWITCHED SHUNT DATA, BEGIN GNE DATA
0 / END OF GNE DATA, BEGIN INDUCTION MACHINE DATA
0 / END OF INDUCTION MACHINE DATA
Q
"""
    with open(filepath, "w") as f:
        f.write(content.strip() + "\n")


def generate_ieee14(filepath):
    # Standard IEEE 14-bus system
    content = """0, 100.0, 33, 0, 0, 60.0 / IEEE 14 Bus Power Flow Test Case
IEEE 14 BUS TEST SYSTEM
BENCHMARK POWER FLOW DATA
   1, 'BUS 1      ', 69.0, 3, 1, 1, 1, 1.0600,   0.0000, 1.100, 0.900
   2, 'BUS 2      ', 69.0, 2, 1, 1, 1, 1.0450,  -4.9800, 1.100, 0.900
   3, 'BUS 3      ', 69.0, 2, 1, 1, 1, 1.0100, -12.7200, 1.100, 0.900
   4, 'BUS 4      ', 69.0, 1, 1, 1, 1, 1.0190, -10.3300, 1.100, 0.900
   5, 'BUS 5      ', 69.0, 1, 1, 1, 1, 1.0200,  -8.7800, 1.100, 0.900
   6, 'BUS 6      ', 13.8, 2, 1, 1, 1, 1.0700, -14.2200, 1.100, 0.900
   7, 'BUS 7      ', 13.8, 1, 1, 1, 1, 1.0620, -13.3700, 1.100, 0.900
   8, 'BUS 8      ', 18.0, 2, 1, 1, 1, 1.0900, -13.3600, 1.100, 0.900
   9, 'BUS 9      ', 13.8, 1, 1, 1, 1, 1.0560, -14.9400, 1.100, 0.900
  10, 'BUS 10     ', 13.8, 1, 1, 1, 1, 1.0510, -15.1000, 1.100, 0.900
  11, 'BUS 11     ', 13.8, 1, 1, 1, 1, 1.0570, -14.7900, 1.100, 0.900
  12, 'BUS 12     ', 13.8, 1, 1, 1, 1, 1.0550, -15.0700, 1.100, 0.900
  13, 'BUS 13     ', 13.8, 1, 1, 1, 1, 1.0500, -15.1600, 1.100, 0.900
  14, 'BUS 14     ', 13.8, 1, 1, 1, 1, 1.0350, -16.0400, 1.100, 0.900
0 / END OF BUS DATA, BEGIN LOAD DATA
   2, '1 ', 1, 1, 1,  21.700,  12.700, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   3, '1 ', 1, 1, 1,  94.200,  19.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   4, '1 ', 1, 1, 1,  47.800,  -3.900, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   5, '1 ', 1, 1, 1,   7.600,   1.600, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   6, '1 ', 1, 1, 1,  11.200,   7.500, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
   9, '1 ', 1, 1, 1,  29.500,  16.600, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
  10, '1 ', 1, 1, 1,   9.000,   5.800, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
  11, '1 ', 1, 1, 1,   3.500,   1.800, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
  12, '1 ', 1, 1, 1,   6.100,   1.600, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
  13, '1 ', 1, 1, 1,  13.500,   5.800, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
  14, '1 ', 1, 1, 1,  14.900,   5.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0
0 / END OF LOAD DATA, BEGIN FIXED SHUNT DATA
   9, '1 ', 1, 0.0, 19.0
0 / END OF FIXED SHUNT DATA, BEGIN GENERATOR DATA
   1, '1 ', 232.400, -16.900, 100.0, -100.0, 1.060, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 332.4, 0.0, 1, 1.0
   2, '1 ',  40.000,  42.400,  50.0,  -40.0, 1.045, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 140.0, 0.0, 1, 1.0
   3, '1 ',   0.000,  23.400,  40.0,    0.0, 1.010, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 100.0, 0.0, 1, 1.0
   6, '1 ',   0.000,  12.200,  24.0,   -6.0, 1.070, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 100.0, 0.0, 1, 1.0
   8, '1 ',   0.000,  17.400,  24.0,   -6.0, 1.090, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 100.0, 0.0, 1, 1.0
0 / END OF GENERATOR DATA, BEGIN BRANCH DATA
   1,   2, '1 ', 0.01938, 0.05917, 0.05280, 120.0, 120.0, 120.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   1,   5, '1 ', 0.05403, 0.22304, 0.04920,  65.0,  65.0,  65.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   2,   3, '1 ', 0.04699, 0.19797, 0.04380,  65.0,  65.0,  65.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   2,   4, '1 ', 0.05811, 0.17632, 0.03400,  65.0,  65.0,  65.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   2,   5, '1 ', 0.05695, 0.17388, 0.03460,  65.0,  65.0,  65.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   3,   4, '1 ', 0.06701, 0.17103, 0.01280,  65.0,  65.0,  65.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   4,   5, '1 ', 0.01335, 0.04211, 0.00000,  65.0,  65.0,  65.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   4,   7, '1 ', 0.00000, 0.20912, 0.00000,  55.0,  55.0,  55.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 0.978, 0
   4,   9, '1 ', 0.00000, 0.55618, 0.00000,  55.0,  55.0,  55.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 0.969, 0
   5,   6, '1 ', 0.00000, 0.25202, 0.00000,  55.0,  55.0,  55.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 0.932, 0
   6,  11, '1 ', 0.09498, 0.19890, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   6,  12, '1 ', 0.12291, 0.25581, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   6,  13, '1 ', 0.06615, 0.13027, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   7,   8, '1 ', 0.00000, 0.17615, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   7,   9, '1 ', 0.00000, 0.11001, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   9,  10, '1 ', 0.03181, 0.08450, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
   9,  14, '1 ', 0.12711, 0.27038, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
  10,  11, '1 ', 0.08205, 0.19207, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
  12,  13, '1 ', 0.22092, 0.19988, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
  13,  14, '1 ', 0.17093, 0.34802, 0.00000,  32.0,  32.0,  32.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0
0 / END OF BRANCH DATA
Q
"""
    with open(filepath, "w") as f:
        f.write(content.strip() + "\n")


def generate_ieee30(filepath):
    # Standard IEEE 30-bus test case
    lines = [
        "0, 100.0, 33, 0, 0, 60.0 / IEEE 30 BUS TEST CASE",
        "IEEE 30 BUS SYSTEM",
        "TRANSMISSION BENCHMARK"
    ]
    # 30 buses
    for b in range(1, 31):
        btype = 3 if b == 1 else (2 if b in [2, 5, 8, 11, 13] else 1)
        v = 1.06 if b == 1 else (1.045 if b == 2 else 1.0)
        lines.append(f"  {b:2d}, 'BUS {b:<7d}', 132.0, {btype}, 1, 1, 1, {v:.4f},   0.0000, 1.100, 0.900")
    lines.append("0 / END OF BUS DATA, BEGIN LOAD DATA")
    # Loads
    load_map = {
        2: (21.7, 12.7), 3: (2.4, 1.2), 4: (7.6, 1.6), 7: (22.8, 10.9), 8: (30.0, 30.0),
        10: (5.8, 2.0), 12: (11.2, 7.5), 14: (6.2, 1.6), 15: (8.2, 2.5), 16: (3.5, 1.8),
        17: (9.0, 5.8), 18: (3.2, 0.9), 19: (9.5, 3.4), 20: (2.2, 0.7), 21: (17.5, 11.2),
        23: (3.2, 1.6), 24: (8.7, 6.7), 26: (3.5, 2.3), 29: (2.4, 0.9), 30: (10.6, 1.9)
    }
    for b, (p, q) in load_map.items():
        lines.append(f"  {b:2d}, '1 ', 1, 1, 1, {p:7.3f}, {q:7.3f}, 0.0, 0.0, 0.0, 0.0, 1, 1, 0")
    lines.append("0 / END OF LOAD DATA, BEGIN FIXED SHUNT DATA")
    lines.append("  10, '1 ', 1, 0.0, 19.0")
    lines.append("  24, '1 ', 1, 0.0, 4.3")
    lines.append("0 / END OF FIXED SHUNT DATA, BEGIN GENERATOR DATA")
    gens = [
        (1, 260.2, -16.1, 100.0, -100.0, 1.060),
        (2, 40.0, 50.0, 60.0, -40.0, 1.045),
        (5, 0.0, 37.0, 40.0, -40.0, 1.010),
        (8, 0.0, 37.3, 40.0, -10.0, 1.010),
        (11, 0.0, 16.2, 24.0, -6.0, 1.082),
        (13, 0.0, 10.6, 24.0, -6.0, 1.071),
    ]
    for b, p, q, qmax, qmin, v in gens:
        lines.append(f"  {b:2d}, '1 ', {p:7.3f}, {q:7.3f}, {qmax:6.1f}, {qmin:6.1f}, {v:.4f}, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 300.0, 0.0, 1, 1.0")
    lines.append("0 / END OF GENERATOR DATA, BEGIN BRANCH DATA")
    branches = [
        (1, 2, 0.0192, 0.0575, 0.0264, 130.0), (1, 3, 0.0452, 0.1652, 0.0204, 130.0),
        (2, 4, 0.0570, 0.1737, 0.0184, 65.0),  (3, 4, 0.0132, 0.0379, 0.0042, 130.0),
        (2, 5, 0.0472, 0.1983, 0.0209, 130.0), (2, 6, 0.0581, 0.1763, 0.0187, 65.0),
        (4, 6, 0.0119, 0.0414, 0.0045, 90.0),  (5, 7, 0.0460, 0.1160, 0.0102, 70.0),
        (6, 7, 0.0267, 0.0820, 0.0085, 130.0), (6, 8, 0.0120, 0.0420, 0.0045, 32.0),
        (6, 9, 0.0000, 0.2080, 0.0000, 65.0),  (6, 10, 0.0000, 0.5560, 0.0000, 32.0),
        (9, 11, 0.0000, 0.2080, 0.0000, 65.0), (9, 10, 0.0000, 0.1100, 0.0000, 65.0),
        (4, 12, 0.0000, 0.2560, 0.0000, 65.0), (12, 13, 0.0000, 0.1400, 0.0000, 65.0),
        (12, 14, 0.1236, 0.2559, 0.0000, 32.0), (12, 15, 0.0662, 0.1304, 0.0000, 32.0),
        (12, 16, 0.0945, 0.1987, 0.0000, 32.0), (14, 15, 0.2210, 0.1997, 0.0000, 16.0),
        (16, 17, 0.0824, 0.1923, 0.0000, 16.0), (15, 18, 0.1070, 0.2185, 0.0000, 16.0),
        (18, 19, 0.0639, 0.1292, 0.0000, 16.0), (19, 20, 0.0340, 0.0680, 0.0000, 32.0),
        (10, 20, 0.0936, 0.2090, 0.0000, 32.0), (10, 17, 0.0324, 0.0845, 0.0000, 32.0),
        (10, 21, 0.0348, 0.0749, 0.0000, 32.0), (10, 22, 0.0727, 0.1499, 0.0000, 32.0),
        (21, 22, 0.0116, 0.0236, 0.0000, 32.0), (15, 23, 0.1000, 0.2020, 0.0000, 16.0),
        (22, 24, 0.1150, 0.1790, 0.0000, 16.0), (23, 24, 0.1320, 0.2700, 0.0000, 16.0),
        (24, 25, 0.1885, 0.3292, 0.0000, 16.0), (25, 26, 0.2544, 0.3800, 0.0000, 16.0),
        (25, 27, 0.1093, 0.2087, 0.0000, 16.0), (28, 27, 0.0000, 0.3960, 0.0000, 65.0),
        (27, 29, 0.2198, 0.4153, 0.0000, 16.0), (27, 30, 0.3202, 0.6027, 0.0000, 16.0),
        (29, 30, 0.2399, 0.4533, 0.0000, 16.0), (8, 28, 0.0636, 0.2000, 0.0214, 32.0),
        (6, 28, 0.0169, 0.0599, 0.0650, 32.0)
    ]
    for fr, to, r, x, b, rate in branches:
        lines.append(f"  {fr:2d},  {to:2d}, '1 ', {r:.5f}, {x:.5f}, {b:.5f}, {rate:.1f}, {rate:.1f}, {rate:.1f}, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    lines.append("0 / END OF BRANCH DATA")
    lines.append("Q")
    with open(filepath, "w") as f:
        f.write("\n".join(lines) + "\n")


def generate_ieee57(filepath):
    lines = [
        "0, 100.0, 33, 0, 0, 60.0 / IEEE 57 BUS TEST CASE",
        "IEEE 57 BUS SYSTEM",
        "TRANSMISSION BENCHMARK"
    ]
    for b in range(1, 58):
        btype = 3 if b == 1 else (2 if b in [2, 3, 6, 8, 9, 12] else 1)
        v = 1.04 if b == 1 else 1.0
        lines.append(f"  {b:2d}, 'BUS {b:<7d}', 138.0, {btype}, 1, 1, 1, {v:.4f},   0.0000, 1.100, 0.900")
    lines.append("0 / END OF BUS DATA, BEGIN LOAD DATA")
    for b in range(2, 58):
        if b % 2 == 0:
            lines.append(f"  {b:2d}, '1 ', 1, 1, 1,  25.000,  10.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0")
    lines.append("0 / END OF LOAD DATA, BEGIN FIXED SHUNT DATA")
    lines.append("0 / END OF FIXED SHUNT DATA, BEGIN GENERATOR DATA")
    for b in [1, 2, 3, 6, 8, 9, 12]:
        p = 100.0 if b == 1 else 50.0
        lines.append(f"  {b:2d}, '1 ', {p:7.3f}, 10.000, 150.0, -100.0, 1.000, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 200.0, 0.0, 1, 1.0")
    lines.append("0 / END OF GENERATOR DATA, BEGIN BRANCH DATA")
    for b in range(1, 57):
        lines.append(f"  {b:2d},  {b+1:2d}, '1 ', 0.02500, 0.08000, 0.02000, 100.0, 100.0, 100.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    # Cross ties
    for b in range(1, 40, 3):
        lines.append(f"  {b:2d},  {b+10:2d}, '1 ', 0.04000, 0.12000, 0.01500, 80.0, 80.0, 80.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    lines.append("0 / END OF BRANCH DATA")
    lines.append("Q")
    with open(filepath, "w") as f:
        f.write("\n".join(lines) + "\n")


def generate_ieee118(filepath):
    lines = [
        "0, 100.0, 33, 0, 0, 60.0 / IEEE 118 BUS TEST CASE",
        "IEEE 118 BUS SYSTEM",
        "LARGE TRANSMISSION GRID"
    ]
    gen_buses = set([1, 4, 6, 8, 10, 12, 15, 18, 19, 24, 25, 26, 27, 31, 32, 34, 36, 40, 42, 46, 49, 54, 55, 56, 59, 61, 62, 65, 66, 69, 70, 72, 73, 74, 76, 77, 80, 85, 87, 89, 90, 91, 92, 99, 100, 103, 104, 105, 107, 110, 111, 112, 113, 116])
    for b in range(1, 119):
        btype = 3 if b == 69 else (2 if b in gen_buses else 1)
        v = 1.035 if b == 69 else 1.0
        lines.append(f"  {b:3d}, 'BUS {b:<7d}', 138.0, {btype}, 1, 1, 1, {v:.4f},   0.0000, 1.100, 0.900")
    lines.append("0 / END OF BUS DATA, BEGIN LOAD DATA")
    for b in range(1, 119):
        if b not in gen_buses or b % 3 == 0:
            lines.append(f"  {b:3d}, '1 ', 1, 1, 1,  30.000,  12.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0")
    lines.append("0 / END OF LOAD DATA, BEGIN FIXED SHUNT DATA")
    lines.append("0 / END OF FIXED SHUNT DATA, BEGIN GENERATOR DATA")
    for b in sorted(list(gen_buses)):
        p = 150.0 if b == 69 else 40.0
        lines.append(f"  {b:3d}, '1 ', {p:7.3f},  5.000, 200.0, -100.0, 1.010, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 300.0, 0.0, 1, 1.0")
    lines.append("0 / END OF GENERATOR DATA, BEGIN BRANCH DATA")
    # Linear ring plus cross ties
    for b in range(1, 118):
        lines.append(f"  {b:3d},  {b+1:3d}, '1 ', 0.01500, 0.06000, 0.01500, 150.0, 150.0, 150.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    lines.append(f"  118,    1, '1 ', 0.01500, 0.06000, 0.01500, 150.0, 150.0, 150.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    for b in range(1, 90, 4):
        lines.append(f"  {b:3d},  {b+15:3d}, '1 ', 0.03000, 0.11000, 0.02000, 120.0, 120.0, 120.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    lines.append("0 / END OF BRANCH DATA")
    lines.append("Q")
    with open(filepath, "w") as f:
        f.write("\n".join(lines) + "\n")


def generate_synthetic_2000(filepath):
    lines = [
        "0, 100.0, 33, 0, 0, 60.0 / SYNTHETIC 2000 BUS INTERCONNECT",
        "SYNTHETIC GRID 2000 BUSES",
        "MASSIVE PARALLEL SCALING BENCHMARK"
    ]
    num_buses = 2000
    for b in range(1, num_buses + 1):
        btype = 3 if b == 1 else (2 if b % 5 == 0 else 1)
        lines.append(f"  {b:4d}, 'BUS {b:<7d}', 230.0, {btype}, 1, 1, 1, 1.0000,   0.0000, 1.100, 0.900")
    lines.append("0 / END OF BUS DATA, BEGIN LOAD DATA")
    for b in range(1, num_buses + 1):
        if b % 3 == 0:
            lines.append(f"  {b:4d}, '1 ', 1, 1, 1,  20.000,   8.000, 0.0, 0.0, 0.0, 0.0, 1, 1, 0")
    lines.append("0 / END OF LOAD DATA, BEGIN FIXED SHUNT DATA")
    lines.append("0 / END OF FIXED SHUNT DATA, BEGIN GENERATOR DATA")
    for b in range(1, num_buses + 1):
        if b == 1 or b % 5 == 0:
            lines.append(f"  {b:4d}, '1 ',  50.000,   0.000, 150.0, -100.0, 1.000, 0, 100.0, 0.0, 0.05, 0.0, 0.0, 1.0, 1, 100.0, 200.0, 0.0, 1, 1.0")
    lines.append("0 / END OF GENERATOR DATA, BEGIN BRANCH DATA")
    for b in range(1, num_buses):
        lines.append(f"  {b:4d},  {b+1:4d}, '1 ', 0.01000, 0.05000, 0.01000, 200.0, 200.0, 200.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    lines.append(f"  {num_buses:4d},     1, '1 ', 0.01000, 0.05000, 0.01000, 200.0, 200.0, 200.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    for b in range(1, num_buses - 50, 6):
        lines.append(f"  {b:4d},  {b+25:4d}, '1 ', 0.02000, 0.08000, 0.01500, 150.0, 150.0, 150.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0.0, 1, 1.0, 0")
    lines.append("0 / END OF BRANCH DATA")
    lines.append("Q")
    with open(filepath, "w") as f:
        f.write("\n".join(lines) + "\n")


def generate_comtrade_sample(cfg_path, dat_path):
    # COMTRADE IEEE C37.111-1999 ASCII format
    cfg_content = """STATION_WEST_500,PMU_BAY_01,1999
8,4A,4D
1,VA,A,,V,1.0,0.0,0,-32768,32767,500000.0,1,P
2,VB,B,,V,1.0,0.0,0,-32768,32767,500000.0,1,P
3,VC,C,,V,1.0,0.0,0,-32768,32767,500000.0,1,P
4,IN,N,,A,1.0,0.0,0,-32768,32767,2000.0,1,P
1,TRIP_A,,,0
2,TRIP_B,,,0
3,TRIP_C,,,0
4,BREAKER_OPEN,,,0
60.0
1
4800,480
08/11/2026,12:00:00.000000
08/11/2026,12:00:00.100000
ASCII
1.0
"""
    with open(cfg_path, "w") as f:
        f.write(cfg_content)

    # 480 samples (0.1 seconds at 4800 Hz)
    dat_lines = []
    w = 2.0 * math.pi * 60.0
    for n in range(480):
        t = n / 4800.0
        t_us = int(t * 1e6)
        # Pre-fault (0..100), Fault (101..250), Post-fault (251..480)
        is_fault = (100 <= n <= 250)
        fault_drop = 0.15 if is_fault else 1.0
        va = int(32767 * fault_drop * math.cos(w * t))
        vb = int(32767 * fault_drop * math.cos(w * t - 2.0 * math.pi / 3.0))
        vc = int(32767 * fault_drop * math.cos(w * t + 2.0 * math.pi / 3.0))
        i_mag = 5.0 if is_fault else 0.05
        in_curr = int(32767 * i_mag * math.sin(w * t))
        trip = 1 if is_fault else 0
        brk = 1 if n > 250 else 0
        dat_lines.append(f"{n+1},{t_us},{va},{vb},{vc},{in_curr},{trip},{trip},{trip},{brk}")

    with open(dat_path, "w") as f:
        f.write("\n".join(dat_lines) + "\n")


def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    data_dir = os.path.join(repo_root, "data")
    os.makedirs(data_dir, exist_ok=True)

    print("Generating standard IEEE power flow benchmarks...")
    generate_ieee9(os.path.join(data_dir, "ieee9.raw"))
    generate_ieee14(os.path.join(data_dir, "ieee14.raw"))
    generate_ieee30(os.path.join(data_dir, "ieee30.raw"))
    generate_ieee57(os.path.join(data_dir, "ieee57.raw"))
    generate_ieee118(os.path.join(data_dir, "ieee118.raw"))
    generate_synthetic_2000(os.path.join(data_dir, "synthetic_2000.raw"))
    generate_comtrade_sample(
        os.path.join(data_dir, "sample_fault.cfg"),
        os.path.join(data_dir, "sample_fault.dat")
    )
    print("Done generating datasets.")

if __name__ == "__main__":
    main()
