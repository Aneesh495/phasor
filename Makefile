# Phasor Energy Management System (EMS) and Dynamic Stability Kernel
# Makefile for building, testing, linting, and benchmarking

CHPL ?= chpl
CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -Iinclude
CHPL_FLAGS ?= --fast
CHPL_FLAGS += --warn-unstable=false
CHPL_FLAGS += -M src/Common -M src/Math -M src/Grid -M src/Admittance -M src/PowerFlow -M src/StateEstimation -M src/Contingency -M src/Dynamics -M src/Optimization -M src/Telemetry -M src/IO

.PHONY: all phasor c_accel test bench lint check clean

all: phasor c_accel

phasor:
	@mkdir -p bin build
	@echo "==> Building native Chapel phasor executable..."
	$(CHPL) $(CHPL_FLAGS) src/Main.chpl -o bin/phasor

c_accel:
	@mkdir -p build
	@echo "==> Building C acceleration and shared-memory bridge..."
	$(CC) $(CFLAGS) -c c_src/phasor_fast_crc.c -o build/phasor_fast_crc.o
	$(CC) $(CFLAGS) -c c_src/phasor_shared_mem.c -o build/phasor_shared_mem.o
	ar rcs build/libphasor_c.a build/phasor_fast_crc.o build/phasor_shared_mem.o
	$(CC) $(CFLAGS) c_src/test_c_accel.c build/libphasor_c.a -o build/test_c_accel

test:
	@echo "==> Running automated Chapel test harness..."
	@python3 tools/run_tests.py

bench:
	@echo "==> Running high-performance benchmark suite..."
	@python3 tools/benchmark_runner.py

lint:
	@echo "==> Verifying typography invariants (zero em dash)..."
	@python3 tools/lint_no_em_dash.py

check: lint test
	@echo "==> All verification checks PASSED successfully."

clean:
	@rm -rf build/ bin/ *.o *.a
	@find . -type d -name "__pycache__" -exec rm -rf {} +
