#!/usr/bin/env python3
"""
phasor_cli.py
Interactive CLI orchestrator for the Phasor Energy Management System.
Manages network solving, contingency screening, and live PMU streaming.
"""

import argparse
import os
import subprocess
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BIN_PHASOR = os.path.join(REPO_ROOT, "bin", "phasor")


def ensure_binary():
    """Verifies that the compiled Chapel phasor binary is ready."""
    if not os.path.exists(BIN_PHASOR):
        print("phasor binary not found. Compiling...")
        cmd = ["make", "phasor"]
        res = subprocess.run(cmd, cwd=REPO_ROOT)
        if res.returncode != 0:
            print("Error: Compilation failed.")
            sys.exit(1)


def cmd_solve(args):
    ensure_binary()
    cmd = [BIN_PHASOR, "solve", args.raw_file, f"--method={args.method}"]
    if args.json:
        cmd.append(f"--export-json={args.json}")
    subprocess.run(cmd, cwd=REPO_ROOT)


def cmd_contingency(args):
    ensure_binary()
    cmd = [BIN_PHASOR, "contingency", args.raw_file]
    subprocess.run(cmd, cwd=REPO_ROOT)


def cmd_estimate(args):
    ensure_binary()
    cmd = [BIN_PHASOR, "estimate", args.raw_file]
    subprocess.run(cmd, cwd=REPO_ROOT)


def cmd_dynamic(args):
    ensure_binary()
    cmd = [BIN_PHASOR, "dynamic", args.raw_file]
    subprocess.run(cmd, cwd=REPO_ROOT)


def cmd_dispatch(args):
    ensure_binary()
    cmd = [BIN_PHASOR, "dispatch", args.raw_file, f"--demand={args.demand}"]
    if args.security:
        cmd.append("--security")
    subprocess.run(cmd, cwd=REPO_ROOT)


def cmd_test(_args):
    print("Executing comprehensive Chapel test harness...")
    cmd = [sys.executable, os.path.join(REPO_ROOT, "tools", "run_tests.py")]
    res = subprocess.run(cmd, cwd=REPO_ROOT)
    sys.exit(res.returncode)


def main():
    parser = argparse.ArgumentParser(
        description="Phasor Synchrophasor Telemetry & Power Grid Stability Kernel CLI"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Solve
    p_solve = subparsers.add_parser("solve", help="Solve AC or DC power flow")
    p_solve.add_argument("raw_file", help="Path to PSS/E RAW network file")
    p_solve.add_argument("--method", choices=["nr", "fdf", "dc"], default="nr")
    p_solve.add_argument("--json", help="Path to export JSON results")
    p_solve.set_defaults(func=cmd_solve)

    # Contingency
    p_cont = subparsers.add_parser("contingency", help="Run parallel N-1 contingency screening")
    p_cont.add_argument("raw_file", help="Path to PSS/E RAW network file")
    p_cont.set_defaults(func=cmd_contingency)

    # Estimate
    p_est = subparsers.add_parser("estimate", help="Run AC WLS state estimation")
    p_est.add_argument("raw_file", help="Path to PSS/E RAW network file")
    p_est.set_defaults(func=cmd_estimate)

    # Dynamic
    p_dyn = subparsers.add_parser("dynamic", help="Run multi-machine transient stability simulation")
    p_dyn.add_argument("raw_file", help="Path to PSS/E RAW network file")
    p_dyn.set_defaults(func=cmd_dynamic)

    # Dispatch
    p_disp = subparsers.add_parser("dispatch", help="Run optimal economic generation dispatch")
    p_disp.add_argument("raw_file", help="Path to PSS/E RAW network file")
    p_disp.add_argument("--demand", type=float, default=250.0, help="Target demand in MW")
    p_disp.add_argument("--security", action="store_true", help="Enable SCED thermal limits")
    p_disp.set_defaults(func=cmd_dispatch)

    # Test
    p_test = subparsers.add_parser("test", help="Run full automated verification test suite")
    p_test.set_defaults(func=cmd_test)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
