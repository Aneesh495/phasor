/*
 * test_fast_decoupled.chpl
 * Tests Stott-Alsac Fast Decoupled Load Flow convergence against Newton-Raphson.
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
use FastDecoupled;

proc main() {
  var net = new PowerNetwork("FDLF_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  net.buses[0] = new BusNode(1, "GEN_1", 138.0, BusType.Slack, 1.05, 0.0);
  net.buses[1] = new BusNode(2, "GEN_2", 138.0, BusType.PV, 1.03, 0.0);
  net.buses[1].pGen = 40.0;
  net.buses[2] = new BusNode(3, "LOAD_3", 138.0, BusType.PQ, 1.00, 0.0);
  net.buses[2].pLoad = 60.0;
  net.buses[2].qLoad = 25.0;

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 0.0, 0.0, 200.0, -100.0, 1.05);
  net.generators[1] = new SynchronousGenerator(2, 2, 40.0, 0.0, 100.0, -50.0, 1.03);
  net.loads[0] = new ZIPLoad(3, 60.0, 25.0);

  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.01, 0.08, 0.02, 100.0);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.015, 0.12, 0.03, 100.0);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.02, 0.16, 0.04, 100.0);

  // Solve with Newton-Raphson as benchmark
  var nr = new NewtonRaphsonSolver(maxIter=15, tol=1.0e-6);
  var (resNR, errNR) = nr.solve(net);
  assert(errNR.isOk());

  // Solve with Fast Decoupled Load Flow
  var fdlf = new FastDecoupledSolver(maxIter=25, tol=1.0e-5);
  var (resFDLF, errFDLF) = fdlf.solve(net);
  assert(errFDLF.isOk());
  assert(resFDLF.converged);

  // Compare solution states: voltages and angles should agree within 1%
  for i in 0..2 {
    assert(abs(resNR.vMag[i] - resFDLF.vMag[i]) < 0.01);
    assert(abs(resNR.vAngleRad[i] - resFDLF.vAngleRad[i]) < 0.01);
  }

  writeln("Fast Decoupled power flow tests passed successfully.");
}
