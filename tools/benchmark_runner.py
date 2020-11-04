#!/usr/bin/env python3
"""
benchmark_runner.py
Compiles and executes performance benchmarks for SpMV, Newton-Raphson, and Contingency screening.
"""

import os
import subprocess
import sys
import time

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUILD_DIR = os.path.join(REPO_ROOT, "build", "bench_bins")
os.makedirs(BUILD_DIR, exist_ok=True)

MODULE_DIRS = [
    os.path.join(REPO_ROOT, "src", "Common"),
    os.path.join(REPO_ROOT, "src", "Math"),
    os.path.join(REPO_ROOT, "src", "Grid"),
    os.path.join(REPO_ROOT, "src", "Admittance"),
    os.path.join(REPO_ROOT, "src", "PowerFlow"),
    os.path.join(REPO_ROOT, "src", "StateEstimation"),
    os.path.join(REPO_ROOT, "src", "Contingency"),
    os.path.join(REPO_ROOT, "src", "Dynamics"),
    os.path.join(REPO_ROOT, "src", "Optimization"),
    os.path.join(REPO_ROOT, "src", "Telemetry"),
    os.path.join(REPO_ROOT, "src", "IO"),
]

CHPL_MODULE_FLAGS = []
for d in MODULE_DIRS:
    if os.path.exists(d):
        CHPL_MODULE_FLAGS.extend(["-M", d])


def compile_and_run(bench_file):
    name = os.path.splitext(os.path.basename(bench_file))[0]
    bin_path = os.path.join(BUILD_DIR, name)

    print(f"Compiling {name} with optimization flags...")
    cmd_build = ["chpl", "--fast"] + CHPL_MODULE_FLAGS + [bench_file, "-o", bin_path]
    res_b = subprocess.run(cmd_build, cwd=REPO_ROOT, capture_output=True, text=True)
    if res_b.returncode != 0:
        print(f"Error compiling {name}:\n{res_b.stderr}")
        return False

    print(f"Running {name}...")
    res_r = subprocess.run([bin_path], cwd=REPO_ROOT, capture_output=True, text=True)
    if res_r.returncode != 0:
        print(f"Error running {name}:\n{res_r.stderr}")
        return False

    print(res_r.stdout)
    return True


def main():
    benchmarks = [
        os.path.join(REPO_ROOT, "benchmarks", "bench_sparse_spmv.chpl"),
        os.path.join(REPO_ROOT, "benchmarks", "bench_newton_raphson.chpl"),
        os.path.join(REPO_ROOT, "benchmarks", "bench_parallel_contingency.chpl"),
    ]

    all_passed = True
    for b in benchmarks:
        if os.path.exists(b):
            success = compile_and_run(b)
            if not success:
                all_passed = False

    if all_passed:
        print("All performance benchmarks executed successfully.")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
