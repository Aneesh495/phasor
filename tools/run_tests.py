#!/usr/bin/env python3
"""
Test runner for Phasor test suite.
Compiles and executes Chapel unit and integration tests with detailed reporting.
"""

import os
import sys
import subprocess
import time

CHPL = os.environ.get("CHPL", "chpl")
CHPL_FLAGS = ["--fast", "--warn-unstable=false"]


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
    res_run = subprocess.run([binary], capture_output=True, text=True, timeout=60)
    run_time = time.time() - t0

    status = "PASS" if res_run.returncode == 0 else "FAIL"
    output = res_run.stdout if status == "PASS" else res_run.stderr

    return {
        "name": test_name,
        "status": status,
        "compile_time": compile_time,
        "run_time": run_time,
        "output": output.strip()
    }


def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    tests_dir = os.path.join(repo_root, "tests")
    build_dir = os.path.join(repo_root, "build", "test_bins")
    os.makedirs(build_dir, exist_ok=True)

    test_files = sorted([
        os.path.join(tests_dir, f) for f in os.listdir(tests_dir)
        if f.startswith("test_") and f.endswith(".chpl")
    ])

    if not test_files:
        print("No Chapel test files found in tests/")
        sys.exit(0)

    print(f"Discovered {len(test_files)} Chapel test files.")
    print("=" * 65)

    passed = 0
    failed = 0

    for tf in test_files:
        res = run_test(tf, build_dir)
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

    print("=" * 65)
    print(f"Total: {len(test_files)} | Passed: {passed} | Failed: {failed}")

    if failed > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
