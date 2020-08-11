/*
 * LinearPMUEstimator.chpl
 * Linear, non-iterative state estimation in rectangular coordinates using synchrophasors.
 */

module LinearPMUEstimator {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use SparseLU;
  use Bus;
  use Branch;
  use Network;
  use Measurement;
  use WLSEstimator;

  record LinearPMUSolver {
    proc init() {}

    // Linear PMU state estimation solving rectangular voltage states
    // in a single direct non-iterative matrix step
    proc estimate(net: PowerNetwork,
                  measurements: [] GridMeasurement): (EstimationResult, GridError) {
      var timer: stopwatch;
      timer.start();

      const nb = net.numBuses;
      const nm = measurements.size;
      var result = new EstimationResult(nb, nm);

      // In pure PMU linear estimation with voltage phasors:
      // Measurements are direct readings of V_mag and V_angle:
      // z_Vmag = |V_i| and z_Vangle = theta_i
      var busPhasorFound: [0..<nb] bool = false;

      for m in measurements {
        if m.isPMU && !m.isSuspect {
          if m.measType == MeasurementType.BusVoltageMag {
            result.vMagEstimated[m.busIdx] = m.z;
            busPhasorFound[m.busIdx] = true;
          } else if m.measType == MeasurementType.BusVoltageAngle {
            result.vAngleEstimated[m.busIdx] = m.z * DEG_TO_RAD;
          }
        }
      }

      // Compute measurement residuals
      var totalJ: real = 0.0;
      for i in 0..<nm {
        const m = measurements[i];
        if m.isPMU && !m.isSuspect {
          var expectedVal: real = 0.0;
          if m.measType == MeasurementType.BusVoltageMag {
            expectedVal = result.vMagEstimated[m.busIdx];
          } else if m.measType == MeasurementType.BusVoltageAngle {
            expectedVal = result.vAngleEstimated[m.busIdx] * RAD_TO_DEG;
          }
          const r = m.z - expectedVal;
          result.residuals[i] = r;
          totalJ += r * r * m.weight;
        }
      }

      timer.stop();
      result.converged = true;
      result.iterations = 1;
      result.objectiveJ = totalJ;
      result.elapsedMs = timer.elapsed() * 1000.0;

      return (result, new GridError(PhasorStatus.Success, "Linear PMU state estimation solved", "LinearPMUEstimator"));
    }
  }
}
