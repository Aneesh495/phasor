/*
 * test_ybus_assembly.chpl
 * Tests sparse complex nodal admittance matrix assembly and sensitivity factors.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use SparseCSR;
use SparseLU;
use Bus;
use Branch;
use Network;
use YBus;
use Sensitivities;

proc main() {
  // Construct a 3-bus triangle test system:
  // Bus 1: Slack, Bus 2: PQ, Bus 3: PQ
  // Line 1-2: r=0.01, x=0.10, b=0.02
  // Line 2-3: r=0.01, x=0.10, b=0.02
  // Line 1-3: r=0.02, x=0.20, b=0.04
  var net = new PowerNetwork("Triangle_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 1, 2, 0, 3);

  net.buses[0] = new BusNode(1, "B1", 138.0, BusType.Slack);
  net.buses[1] = new BusNode(2, "B2", 138.0, BusType.PQ);
  net.buses[2] = new BusNode(3, "B3", 138.0, BusType.PQ);

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.01, 0.10, 0.02);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.01, 0.10, 0.02);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.02, 0.20, 0.04);

  var yBuilder = new YBusBuilder(3);
  var (ybus, gbus, bbus) = yBuilder.buildYBus(net);

  assert(ybus.nrows == 3);
  assert(ybus.ncols == 3);

  // Check off-diagonal elements: Y_12 should be -y_series(1-2)
  const y12 = ybus.get(0, 1);
  const ySeries12 = net.branches[0].seriesAdmittance();
  assert(abs(y12.re - (-ySeries12.re)) < 1e-4);
  assert(abs(y12.im - (-ySeries12.im)) < 1e-4);

  // Check symmetry of lines: Y_12 == Y_21
  const y21 = ybus.get(1, 0);
  assert(abs(y12.re - y21.re) < 1e-6);
  assert(abs(y12.im - y21.im) < 1e-6);

  // Test PTDF sensitivity factor calculation
  var sensEngine = new SensitivityEngine(3, 3, slackIdx=0);
  var (bPrime, luB) = sensEngine.buildBPrime(net);

  // PTDF on branch 1 (1->2) for injection at bus 1 and withdrawal at bus 2
  // By symmetry and impedance ratios, flow through path 1-2 and path 1-3-2:
  // X_{12} = 0.10, X_{13} + X_{32} = 0.20 + 0.10 = 0.30
  // Current divider: 0.30 / (0.10 + 0.30) = 0.75 of total transfer goes through branch 1!
  const ptdf1 = sensEngine.computePTDF(net, luB, 0, 0, 1);
  assert(abs(ptdf1 - 0.75) < 1e-3);

  // Branch 3 (1->3) takes remaining 0.25
  const ptdf3 = sensEngine.computePTDF(net, luB, 2, 0, 1);
  assert(abs(ptdf3 - 0.25) < 1e-3);

  // Test LODF for outage of branch 3 on branch 1
  const lodf_1_3 = sensEngine.computeLODF(net, luB, 0, 2);
  assert(lodf_1_3 > 0.0); // Outage of 1-3 shifts flow onto 1-2

  writeln("Y-Bus and sensitivity tests passed successfully.");
}
