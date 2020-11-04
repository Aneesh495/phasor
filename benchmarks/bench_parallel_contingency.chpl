/*
 * bench_parallel_contingency.chpl
 * Benchmark for massively parallel N-1 contingency screening across all transmission lines.
 */

use Time;
use Math;
use PhasorConstants;
use PhasorTypes;
use Network;
use RawParser;
use OutageModel;
use ContingencyScreening;

proc benchmarkContingencies(rawPath: string, name: string) {
  var (netOpt, err) = parseRawFile(rawPath);
  if !err.isOk() || netOpt == nil {
    writeln("Skipping ", name, " (file not found)");
    return;
  }
  var net = netOpt!;

  var engine = new ParallelScreeningEngine(fast=true);
  var casesDomain: domain(1) = 0..<net.numBranches;
  var cases: [casesDomain] ContingencyCase;

  for k in 0..<net.numBranches {
    cases[k] = ContingencyCase.branchTrip(k + 1, k,
                                          "Line " + net.branches[k].fromBus:string + "->" + net.branches[k].toBus:string + " trip");
  }

  // Warmup
  var (_, _) = engine.screen(net, cases);

  var timer: stopwatch;
  timer.start();

  var (report, _) = engine.screen(net, cases);

  timer.stop();
  const totalMs = timer.elapsed() * 1000.0;
  const rate = (net.numBranches: real / (totalMs / 1000.0));

  writeln("System: ", name, "\t| Lines: ", net.numBranches, "\t| Time: ", totalMs, " ms\t| Rate: ", rate, " contingencies/sec");
}

proc main() {
  writeln("=== Benchmarking Parallel N-1 Contingency Screening ===");
  benchmarkContingencies("data/ieee14.raw", "IEEE 14-Bus");
  benchmarkContingencies("data/ieee30.raw", "IEEE 30-Bus");
  benchmarkContingencies("data/ieee118.raw", "IEEE 118-Bus");
  writeln("Contingency benchmark completed successfully.");
}
