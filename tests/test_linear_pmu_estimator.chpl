/*
 * test_linear_pmu_estimator.chpl
 * Tests linear PMU state estimator with direct synchronized phasor telemetry.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Network;
use Measurement;
use WLSEstimator;
use LinearPMUEstimator;

proc main() {
  var net = new PowerNetwork("PMU_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 1, 1, 0, 3);

  net.buses[0] = new BusNode(1, "SUB_1", 138.0, BusType.Slack);
  net.buses[1] = new BusNode(2, "SUB_2", 138.0, BusType.PV);
  net.buses[2] = new BusNode(3, "SUB_3", 138.0, BusType.PQ);

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  // Synchrophasor measurements from PMUs at all 3 substations:
  // Substation 1: V = 1.04 pu /_ 0.0 deg
  // Substation 2: V = 1.02 pu /_ -3.5 deg
  // Substation 3: V = 0.98 pu /_ -7.2 deg
  var meas: [0..5] GridMeasurement;
  meas[0] = new GridMeasurement(1, MeasurementType.BusVoltageMag, 0, 1.04, 0.001, pmu=true);
  meas[1] = new GridMeasurement(2, MeasurementType.BusVoltageAngle, 0, 0.0, 0.01, pmu=true);

  meas[2] = new GridMeasurement(3, MeasurementType.BusVoltageMag, 1, 1.02, 0.001, pmu=true);
  meas[3] = new GridMeasurement(4, MeasurementType.BusVoltageAngle, 1, -3.5, 0.01, pmu=true);

  meas[4] = new GridMeasurement(5, MeasurementType.BusVoltageMag, 2, 0.98, 0.001, pmu=true);
  meas[5] = new GridMeasurement(6, MeasurementType.BusVoltageAngle, 2, -7.2, 0.01, pmu=true);

  var linearSolver = new LinearPMUSolver();
  var (res, err) = linearSolver.estimate(net, meas);

  assert(err.isOk());
  assert(res.converged);
  assert(res.iterations == 1);

  assert(abs(res.vMagEstimated[0] - 1.04) < 1e-4);
  assert(abs(res.vMagEstimated[1] - 1.02) < 1e-4);
  assert(abs(res.vMagEstimated[2] - 0.98) < 1e-4);

  assert(abs(res.vAngleEstimated[0] - 0.0) < 1e-4);
  assert(abs(res.vAngleEstimated[1] - (-3.5 * DEG_TO_RAD)) < 1e-4);
  assert(abs(res.vAngleEstimated[2] - (-7.2 * DEG_TO_RAD)) < 1e-4);

  writeln("Linear PMU state estimation tests passed successfully.");
}
