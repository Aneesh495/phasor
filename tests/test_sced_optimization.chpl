/*
 * test_sced_optimization.chpl
 * Unit verification for Security-Constrained Economic Dispatch with PTDF limits.
 */

use PhasorConstants;
use PhasorTypes;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use SCED;

proc main() {
  writeln("=== Running Test: Security-Constrained Economic Dispatch ===");

  var net = new PowerNetwork("SCED-3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  net.buses[0] = new BusNode(1, "Bus1", 138.0, BusType.Slack, 1.0, 0.0);
  net.buses[1] = new BusNode(2, "Bus2", 138.0, BusType.PV, 1.0, 0.0);
  net.buses[2] = new BusNode(3, "Bus3", 138.0, BusType.PQ, 1.0, 0.0);

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  // Branch 1-2, 1-3, 2-3
  // Set tight rateA on Branch 1-2 to trigger security constraint redispatch
  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.01, 0.10, 0.02, 120.0, 150.0, 180.0);
  net.branches[1] = new TransmissionBranch(2, 1, 3, 0.01, 0.15, 0.02, 200.0, 220.0, 250.0);
  net.branches[2] = new TransmissionBranch(3, 2, 3, 0.01, 0.12, 0.02, 200.0, 220.0, 250.0);

  // G1 at Bus 1 (cheap generator)
  net.generators[0] = new SynchronousGenerator(1, 1, 150.0, 0.0, 100.0, -50.0, 1.0, 300.0, 20.0);
  net.generators[0].setCostCurve(0.004, 8.0, 50.0);
  // G2 at Bus 2 (more expensive generator)
  net.generators[1] = new SynchronousGenerator(2, 2, 100.0, 0.0, 80.0, -40.0, 1.0, 250.0, 20.0);
  net.generators[1].setCostCurve(0.009, 14.0, 80.0);

  // Load at Bus 3
  net.loads[0] = new ZIPLoad(3, 220.0, 50.0);

  var sced = new SCEDSolver(maxI=30, tol=0.10);
  const targetDemandMW = 220.0;
  var (res, err) = sced.solve(net, targetDemandMW);

  assert(err.isOk(), "SCED returned error: " + err.message);
  writeln("SCED Result: converged = ", res.converged, ", iterations = ", res.iterations);
  writeln("Total generation cost: $", res.totalCostPerHour, "/h");
  writeln("Redispatched MW: ", res.redispatchCostMW, " MW");
  writeln("Active constraints: ", res.activeConstraintsCount);
  writeln("Execution time: ", res.elapsedMs, " ms");

  for g in 0..<net.numGenerators {
    writeln("  Gen ", net.generators[g].id, " at Bus ", net.generators[g].busId, ": ", res.pDispatchedMW[g], " MW");
    assert(res.pDispatchedMW[g] >= net.generators[g].pMin - 1e-4, "Generator below pMin");
    assert(res.pDispatchedMW[g] <= net.generators[g].pMax + 1e-4, "Generator above pMax");
  }

  const sumGen = res.pDispatchedMW[0] + res.pDispatchedMW[1];
  assert(abs(sumGen - targetDemandMW) < 0.20, "Total dispatched generation does not match target demand");

  writeln("PASS: Security-Constrained Economic Dispatch verified successfully.");
}
