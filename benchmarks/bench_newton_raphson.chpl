/*
 * bench_newton_raphson.chpl
 * Benchmark for AC Newton-Raphson power flow scaling across IEEE benchmark networks.
 */

use Time;
use Math;
use PhasorConstants;
use PhasorTypes;
use Network;
use RawParser;
use NewtonRaphson;

proc benchmarkNetwork(rawPath: string, name: string, trials: int = 20) {
  var (netOpt, err) = parseRawFile(rawPath);
  if !err.isOk() || netOpt == nil {
    writeln("Skipping ", name, " (file not found)");
    return;
  }
  var net = netOpt!;

  var nr = new NewtonRaphsonSolver(maxIter=25, tol=1.0e-5);

  // Warmup
  var (wRes, wErr) = nr.solve(net);
  if !wErr.isOk() || !wRes.converged {
    writeln("Warmup failed for ", name);
    return;
  }

  var timer: stopwatch;
  timer.start();

  var iters = 0;
  for t in 1..trials {
    var (res, _) = nr.solve(net);
    iters = res.iterations;
  }

  timer.stop();
  const totalSec = timer.elapsed();
  const avgMs = (totalSec / trials) * 1000.0;
  const timePerIterMs = avgMs / iters;

  writeln("System: ", name, " (", net.numBuses, " buses, ", net.numBranches, " lines)\t| Solve: ", avgMs, " ms\t| Iters: ", iters, "\t| Per-Iter: ", timePerIterMs, " ms");
}

proc main() {
  writeln("=== Benchmarking AC Newton-Raphson Solver Scaling ===");
  benchmarkNetwork("data/ieee9.raw", "IEEE 9-Bus WSCC", trials=100);
  benchmarkNetwork("data/ieee14.raw", "IEEE 14-Bus", trials=100);
  benchmarkNetwork("data/ieee30.raw", "IEEE 30-Bus", trials=50);
  benchmarkNetwork("data/ieee118.raw", "IEEE 118-Bus", trials=20);
  writeln("Newton-Raphson benchmark completed successfully.");
}
