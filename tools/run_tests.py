#!/usr/bin/env python3
"""
Test runner for Phasor test suite.
Compiles and executes Chapel unit and integration tests with parallel execution.
"""

import os
import sys
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

CHPL = os.environ.get("CHPL", "chpl")
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

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
    os.path.join(REPO_ROOT, "src")
]

CHPL_MODULE_FLAGS = []
for d in MODULE_DIRS:
    if os.path.exists(d):
        CHPL_MODULE_FLAGS.extend(["-M", d])

# Avoid --fast during test runs to minimize LLVM compile times while verifying logic
CHPL_FLAGS = ["--warn-unstable=false"] + CHPL_MODULE_FLAGS


def run_test(test_file, build_dir):
    test_name = os.path.splitext(os.path.basename(test_file))[0]
    binary = os.path.join(build_dir, test_name)

    # Compile
    t0 = time.time()
    compile_cmd = [CHPL] + CHPL_FLAGS + [test_file, "-o", binary]
    res_compile = subprocess.run(compile_cmd, capture_output=True, text=True)
    compile_time = time.time() - t0

    if res_compile.returncode != 0:
        return {
            "name": test_name,
            "status": "COMPILE_FAIL",
            "compile_time": compile_time,
            "run_time": 0.0,
            "output": res_compile.stderr.strip()
        }

    # Execute
    t0 = time.time()
    try:
        res_run = subprocess.run([binary], capture_output=True, text=True, timeout=60)
        run_time = time.time() - t0
        status = "PASS" if res_run.returncode == 0 else "FAIL"
        output = res_run.stdout if status == "PASS" else res_run.stderr
    except subprocess.TimeoutExpired:
        run_time = time.time() - t0
        status = "TIMEOUT"
        output = "Execution timed out after 60 seconds."

    return {
        "name": test_name,
        "status": status,
        "compile_time": compile_time,
        "run_time": run_time,
        "output": output.strip()
    }


def main():
    tests_dir = os.path.join(REPO_ROOT, "tests")
    build_dir = os.path.join(REPO_ROOT, "build", "test_bins")
    os.makedirs(build_dir, exist_ok=True)

    test_files = sorted([
        os.path.join(tests_dir, f) for f in os.listdir(tests_dir)
        if f.startswith("test_") and f.endswith(".chpl")
    ])

    if not test_files:
        print("No Chapel test files found in tests/")
        sys.exit(0)

    num_workers = min(len(test_files), os.cpu_count() or 4)
    print(f"Discovered {len(test_files)} Chapel test files. Running with {num_workers} parallel workers...")
    print("=" * 65)

    passed = 0
    failed = 0
    results = []

    start_total = time.time()
    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        future_to_test = {executor.submit(run_test, tf, build_dir): tf for tf in test_files}
        for future in as_completed(future_to_test):
            res = future.result()
            results.append(res)
            name = res["name"]
            status = res["status"]
            c_time = res["compile_time"]
            r_time = res["run_time"]

            if status == "PASS":
                passed += 1
                print(f"  [PASS] {name:<35} (compile: {c_time:.2f}s, exec: {r_time:.2f}s)")
            else:
                failed += 1
                print(f"  [{status}] {name:<35} (compile: {c_time:.2f}s)")
                if res["output"]:
                    for line in res["output"].splitlines()[:10]:
                        print(f"         {line}")

    total_elapsed = time.time() - start_total
    print("=" * 65)
    print(f"Total: {len(test_files)} | Passed: {passed} | Failed: {failed} | Elapsed: {total_elapsed:.2f}s")

    if failed > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
