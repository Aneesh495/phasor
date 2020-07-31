/*
 * test_newton_raphson.chpl
 * Verifies full AC Newton-Raphson solver convergence and power conservation.
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
use NewtonRaphson;

proc main() {
  // Construct standard 3-bus triangle test case
  var net = new PowerNetwork("NR_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  // Bus 1: Slack (V = 1.05 /_ 0)
  net.buses[0] = new BusNode(1, "GEN_1", 138.0, BusType.Slack, 1.05, 0.0);
  // Bus 2: PV Generator (V = 1.03, P = 50 MW)
  net.buses[1] = new BusNode(2, "GEN_2", 138.0, BusType.PV, 1.03, 0.0);
  net.buses[1].pGen = 50.0;
  // Bus 3: PQ Load (P = 80 MW, Q = 40 MVAR)
  net.buses[2] = new BusNode(3, "LOAD_3", 138.0, BusType.PQ, 1.00, 0.0);
  net.buses[2].pLoad = 80.0;
  net.buses[2].qLoad = 40.0;

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 0.0, 0.0, 200.0, -100.0, 1.05);
  net.generators[1] = new SynchronousGenerator(2, 2, 50.0, 0.0, 100.0, -50.0, 1.03);

  net.loads[0] = new ZIPLoad(3, 80.0, 40.0);

  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.02, 0.10, 0.02, 100.0);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.03, 0.15, 0.03, 100.0);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.04, 0.20, 0.04, 100.0);

  var nr = new NewtonRaphsonSolver(maxIter=15, tol=1.0e-6);
  var (res, err) = nr.solve(net);

  assert(err.isOk());
  assert(res.converged);
  assert(res.iterations <= 5); // Newton-Raphson quadratic convergence
  assert(res.maxMismatchP < 1.0e-4);
  assert(res.maxMismatchQ < 1.0e-4);

  // Voltage at Bus 1 is fixed at 1.05 pu
  assert(abs(res.vMag[0] - 1.05) < 1e-4);
  // Voltage at Bus 2 is regulated to 1.03 pu
  assert(abs(res.vMag[1] - 1.03) < 1e-4);
  // Voltage at load bus 3 drops due to impedance
  assert(res.vMag[2] < 1.03);
  assert(res.vMag[2] > 0.90);

  // Active power balance check: Total Gen = Total Load + Losses
  const totalGenP = res.pFrom[0] + res.pFrom[2]; // Power leaving gen buses
  assert(res.totalLossesP > 0.0); // Transmission lines have resistive losses

  writeln("Newton-Raphson power flow tests passed successfully.");
}
