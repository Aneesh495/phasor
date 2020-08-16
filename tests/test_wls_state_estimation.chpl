/*
 * test_wls_state_estimation.chpl
 * Tests Weighted Least Squares (WLS) AC state estimation on 3-bus network.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use Measurement;
use NewtonRaphson;
use WLSEstimator;

proc main() {
  var net = new PowerNetwork("SE_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  net.buses[0] = new BusNode(1, "B1", 138.0, BusType.Slack, 1.05, 0.0);
  net.buses[1] = new BusNode(2, "B2", 138.0, BusType.PV, 1.03, 0.0);
  net.buses[1].pGen = 40.0;
  net.buses[2] = new BusNode(3, "B3", 138.0, BusType.PQ, 1.00, 0.0);
  net.buses[2].pLoad = 60.0;
  net.buses[2].qLoad = 20.0;

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 0.0, 0.0, 200.0, -100.0, 1.05);
  net.generators[1] = new SynchronousGenerator(2, 2, 40.0, 0.0, 100.0, -50.0, 1.03);
  net.loads[0] = new ZIPLoad(3, 60.0, 20.0);

  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.01, 0.08, 0.02, 100.0);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.015, 0.12, 0.03, 100.0);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.02, 0.16, 0.04, 100.0);

  // 1. Solve power flow to obtain true state
  var nr = new NewtonRaphsonSolver(maxIter=15, tol=1.0e-6);
  var (pfRes, pfErr) = nr.solve(net);
  assert(pfErr.isOk());

  // 2. Synthesize measurements:
  // - 3 bus voltage magnitudes (V1, V2, V3)
  // - 1 PMU voltage angle at Bus 2
  // - 3 active branch flows (P12, P23, P13)
  // - 3 reactive branch flows (Q12, Q23, Q13)
  // Total = 10 measurements (state dim = 5, redundancy = 2.0)
  var meas: [0..9] GridMeasurement;

  meas[0] = new GridMeasurement(1, MeasurementType.BusVoltageMag, 0, pfRes.vMag[0], 0.005);
  meas[1] = new GridMeasurement(2, MeasurementType.BusVoltageMag, 1, pfRes.vMag[1], 0.005);
  meas[2] = new GridMeasurement(3, MeasurementType.BusVoltageMag, 2, pfRes.vMag[2], 0.005);

  meas[3] = new GridMeasurement(4, MeasurementType.BusVoltageAngle, 1, pfRes.vAngleRad[1], 0.002, pmu=true);

  meas[4] = new GridMeasurement(5, MeasurementType.ActiveBranchFlow, -1, pfRes.pFrom[0], 0.5, fromB=0, toB=1, brIdx=0);
  meas[5] = new GridMeasurement(6, MeasurementType.ActiveBranchFlow, -1, pfRes.pFrom[1], 0.5, fromB=1, toB=2, brIdx=1);
  meas[6] = new GridMeasurement(7, MeasurementType.ActiveBranchFlow, -1, pfRes.pFrom[2], 0.5, fromB=0, toB=2, brIdx=2);

  meas[7] = new GridMeasurement(8, MeasurementType.ReactiveBranchFlow, -1, pfRes.qFrom[0], 0.5, fromB=0, toB=1, brIdx=0);
  meas[8] = new GridMeasurement(9, MeasurementType.ReactiveBranchFlow, -1, pfRes.qFrom[1], 0.5, fromB=1, toB=2, brIdx=1);
  meas[9] = new GridMeasurement(10, MeasurementType.ReactiveBranchFlow, -1, pfRes.qFrom[2], 0.5, fromB=0, toB=2, brIdx=2);

  // 3. Run WLS state estimator
  var wls = new WLSSolver(maxIter=20, tol=1.0e-5);
  var (seRes, seErr) = wls.estimate(net, meas);

  assert(seErr.isOk());
  assert(seRes.converged);

  // 4. Verify estimated state matches true power flow solution within 0.1%
  for i in 0..2 {
    assert(abs(seRes.vMagEstimated[i] - pfRes.vMag[i]) < 1.0e-3);
    assert(abs(seRes.vAngleEstimated[i] - pfRes.vAngleRad[i]) < 1.0e-3);
  }

  writeln("WLS state estimation tests passed successfully.");
}
