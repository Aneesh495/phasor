/*
 * test_voltage_collapse_l_index.chpl
 * Tests Kessel-Glavitsch L-index calculation for proximity to voltage collapse.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use YBus;
use NewtonRaphson;
use VoltageCollapseIndex;

proc main() {
  var net = new PowerNetwork("LIndex_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  net.buses[0] = new BusNode(1, "GEN_1", 138.0, BusType.Slack, 1.05, 0.0);
  net.buses[1] = new BusNode(2, "GEN_2", 138.0, BusType.PV, 1.03, 0.0);
  net.buses[1].pGen = 40.0;
  // Bus 3 is a load bus
  net.buses[2] = new BusNode(3, "LOAD_3", 138.0, BusType.PQ, 1.00, 0.0);
  net.buses[2].pLoad = 50.0;
  net.buses[2].qLoad = 20.0;

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 0.0, 0.0, 200.0, -100.0, 1.05);
  net.generators[1] = new SynchronousGenerator(2, 2, 40.0, 0.0, 100.0, -50.0, 1.03);
  net.loads[0] = new ZIPLoad(3, 50.0, 20.0);

  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.01, 0.08, 0.02, 100.0);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.015, 0.12, 0.03, 100.0);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.02, 0.16, 0.04, 100.0);

  var nr = new NewtonRaphsonSolver(maxIter=15, tol=1.0e-6);
  var (res, errNR) = nr.solve(net);
  assert(errNR.isOk());

  var yBuilder = new YBusBuilder(3);
  var (ybus, gbus, bbus) = yBuilder.buildYBus(net);

  var vcAnalyzer = new VoltageCollapseAnalyzer(3);
  var lIndices: [0..2] real;
  var (maxL, worstBus) = vcAnalyzer.computeLIndices(net, ybus, res, lIndices);

  // Load bus 3 has the highest L-index
  assert(worstBus == 2);
  // Healthy operating grid: L-index is well below 1.0 (typically 0.05 .. 0.35)
  assert(lIndices[2] > 0.0);
  assert(lIndices[2] < 0.60);

  // Generators have 0 collapse index
  assert(lIndices[0] == 0.0);
  assert(lIndices[1] == 0.0);

  writeln("Voltage collapse L-index tests passed successfully.");
}
