/*
 * test_dc_power_flow.chpl
 * Tests linearized DC power flow solver.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use PowerFlowResult;
use DCPowerFlow;

proc main() {
  var net = new PowerNetwork("DC_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  net.buses[0] = new BusNode(1, "GEN_1", 138.0, BusType.Slack);
  net.buses[1] = new BusNode(2, "GEN_2", 138.0, BusType.PV);
  net.buses[1].pGen = 50.0;
  net.buses[2] = new BusNode(3, "LOAD_3", 138.0, BusType.PQ);
  net.buses[2].pLoad = 100.0;

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 0.0, 0.0, 200.0, -100.0);
  net.generators[1] = new SynchronousGenerator(2, 2, 50.0, 0.0, 100.0, -50.0);
  net.loads[0] = new ZIPLoad(3, 100.0, 0.0);

  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.0, 0.10, 0.0, 100.0);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.0, 0.10, 0.0, 100.0);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.0, 0.20, 0.0, 100.0);

  var dc = new DCPowerFlowSolver(slackIdx=0);
  var (res, err) = dc.solve(net);

  assert(err.isOk());
  assert(res.converged);
  assert(res.iterations == 1);

  // In DC approximation, slack bus angle is 0.0 rad
  assert(abs(res.vAngleRad[0] - 0.0) < 1e-6);

  // All voltage magnitudes are exactly 1.0 pu in DC model
  for i in 0..2 {
    assert(abs(res.vMag[i] - 1.0) < 1e-6);
  }

  // Load at bus 3 is 100 MW. Inflow into bus 3 must equal 100 MW:
  // Branch 1 (2->3) + Branch 2 (1->3) flow into bus 3
  const flowInto3 = res.pFrom[1] + res.pFrom[2];
  assert(abs(flowInto3 - 100.0) < 1e-3);

  writeln("DC power flow tests passed successfully.");
}
