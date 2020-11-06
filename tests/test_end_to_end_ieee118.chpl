/*
 * test_end_to_end_ieee118.chpl
 * Bulk grid stress test: IEEE 118-bus network solving and parallel contingency screening.
 */

use Math;
use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use RawParser;
use NewtonRaphson;
use OutageModel;
use ContingencyScreening;

proc main() {
  writeln("=== Running End-to-End Test: IEEE 118-Bus Bulk Power Grid ===");

  var (netOpt, parseErr) = parseRawFile("data/ieee118.raw");
  assert(parseErr.isOk() && netOpt != nil, "Failed to parse IEEE 118: " + parseErr.message);
  var net = netOpt!;

  writeln("Parsed IEEE 118-Bus System:");
  writeln("  Buses:      ", net.numBuses);
  writeln("  Branches:   ", net.numBranches);
  writeln("  Generators: ", net.numGenerators);
  writeln("  Loads:      ", net.numLoads);

  assert(net.numBuses == 118, "Expected 118 buses");
  assert(net.numBranches == 141, "Expected 141 branches");

  // Step 1: AC Newton-Raphson Power Flow
  var nr = new NewtonRaphsonSolver(maxIter=25, tol=1.0e-5);
  var (pfRes, pfErr) = nr.solve(net);

  assert(pfErr.isOk(), "Newton-Raphson failed: " + pfErr.message);
  assert(pfRes.converged, "Newton-Raphson did not converge on IEEE 118");
  pfRes.computeBranchFlows(net);

  const (pGen, qGen, pLoad, qLoad) = net.summary();
  writeln("AC Power Flow converged in ", pfRes.iterations, " iterations (", pfRes.elapsedMs, " ms)");
  writeln("  Total Generation: ", pGen, " MW / ", qGen, " MVAR");
  writeln("  Total Load:       ", pLoad, " MW / ", qLoad, " MVAR");
  writeln("  Total Losses:     ", pfRes.totalLossesP, " MW");

  assert(pGen > 2000.0 && pGen < 3000.0, "IEEE 118 generation outside expected range");
  assert(pfRes.totalLossesP > 50.0 && pfRes.totalLossesP < 200.0, "Losses outside expected range");

  // Step 2: Massively parallel N-1 contingency screening across 141 branches
  var engine = new ParallelScreeningEngine(fast=true);
  var casesDomain: domain(1) = 0..<net.numBranches;
  var cases: [casesDomain] ContingencyCase;

  for k in 0..<net.numBranches {
    cases[k] = ContingencyCase.branchTrip(k + 1, k,
                                          "Line " + net.branches[k].fromBus:string + "->" + net.branches[k].toBus:string + " trip");
  }

  writeln("Launching parallel N-1 contingency screening on ", net.numBranches, " transmission lines...");
  var (report, contErr) = engine.screen(net, cases);
  assert(contErr.isOk(), "Screening error: " + contErr.message);

  writeln("Screening completed in ", report.elapsedMs, " ms");
  writeln("  Total Screened:         ", report.totalContingencies);
  writeln("  Critical Contingencies: ", report.criticalCount);
  writeln("  Warning Contingencies:  ", report.warningCount);
  writeln("  Secure Contingencies:   ", report.secureCount);
  writeln("  Worst Line Outage:      ", report.worstContingencyName, " (Loading: ", report.worstLoadingPct, "%)");

  assert(report.totalContingencies == 141, "Contingency count mismatch");
  assert(report.worstLoadingPct > 100.0, "Worst contingency should exceed thermal threshold");

  writeln("PASS: IEEE 118-Bus bulk power grid stress drill verified successfully.");
}
