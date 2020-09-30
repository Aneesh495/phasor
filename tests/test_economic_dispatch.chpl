/*
 * test_economic_dispatch.chpl
 * Unit verification for lambda-iteration optimal economic dispatch.
 */

use PhasorConstants;
use PhasorTypes;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use EconomicDispatch;

proc main() {
  writeln("=== Running Test: Economic Dispatch ===");

  var net = new PowerNetwork("ED-3Bus", 100.0, 60.0);
  net.allocate(3, 0, 3, 0, 0, 3);

  net.buses[0] = new BusNode(1, "Bus1", 138.0, BusType.Slack, 1.0, 0.0);
  net.buses[1] = new BusNode(2, "Bus2", 138.0, BusType.PV, 1.0, 0.0);
  net.buses[2] = new BusNode(3, "Bus3", 138.0, BusType.PQ, 1.0, 0.0);

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  // Three generators with distinct cost curves
  // G1: 0.005 * P^2 + 10 * P + 100
  net.generators[0] = new SynchronousGenerator(1, 1, 100.0, 0.0, 100.0, -50.0, 1.0, 250.0, 50.0);
  net.generators[0].setCostCurve(0.005, 10.0, 100.0);
  // G2: 0.008 * P^2 + 8 * P + 80
  net.generators[1] = new SynchronousGenerator(2, 2, 80.0, 0.0, 80.0, -40.0, 1.0, 200.0, 30.0);
  net.generators[1].setCostCurve(0.008, 8.0, 80.0);
  // G3: 0.010 * P^2 + 12 * P + 120
  net.generators[2] = new SynchronousGenerator(3, 3, 50.0, 0.0, 60.0, -30.0, 1.0, 150.0, 20.0);
  net.generators[2].setCostCurve(0.010, 12.0, 120.0);

  var ed = new EconomicDispatcher(maxIter=50, tolMW=0.01);
  const targetDemandMW = 350.0;
  var (res, err) = ed.dispatch(net, targetDemandMW);

  assert(err.isOk(), "Economic dispatch returned error: " + err.message);
  assert(res.converged, "Economic dispatch failed to converge");
  assert(abs(res.powerMismatchMW) < 0.05, "Power mismatch exceeded tolerance");
  assert(abs(res.totalGenMW - targetDemandMW) < 0.05, "Total generation mismatch");

  writeln("Dispatched generation profile:");
  for g in 0..<net.numGenerators {
    const gen = net.generators[g];
    const p = res.pDispatchedMW[g];
    writeln("  Gen ", gen.id, " (Bus ", gen.busId, "): ", p, " MW (limits [", gen.pMin, ", ", gen.pMax, "])");
    assert(p >= gen.pMin - 1e-4, "Gen violated lower power limit");
    assert(p <= gen.pMax + 1e-4, "Gen violated upper power limit");
  }

  writeln("System lambda: $", res.lambda, "/MWh");
  writeln("Total fuel cost: $", res.totalCostPerHour, "/h");
  writeln("Iterations: ", res.iterations);
  writeln("Solve time: ", res.elapsedMs, " ms");

  assert(res.lambda > 8.0 && res.lambda < 20.0, "Lambda clearing price outside reasonable bound");
  assert(res.totalCostPerHour > 3000.0 && res.totalCostPerHour < 6000.0, "Total cost outside reasonable bound");

  writeln("PASS: Economic dispatch verified successfully.");
}
