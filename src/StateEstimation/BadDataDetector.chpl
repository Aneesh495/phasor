/*
 * BadDataDetector.chpl
 * Bad data detection and identification using Chi-square test and largest normalized residual (r_N).
 */

module BadDataDetector {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Measurement;
  use WLSEstimator;

  record BadDataProcessor {
    var chi2ConfidenceThreshold: real;
    var normResidualLimit: real;

    proc init(chi2Thresh: real = BAD_DATA_CHI2_THRESHOLD, rNLimit: real = BAD_DATA_NORM_RESIDUAL_LIMIT) {
      this.chi2ConfidenceThreshold = chi2Thresh;
      this.normResidualLimit = rNLimit;
    }

    // Performs Chi-Square detection test on objective function J(x)
    // Degrees of freedom = number of active measurements - state dimension (2*nb - 1)
    proc detectChiSquare(res: EstimationResult, numActiveMeasurements: int, numBuses: int): bool {
      const stateDim = 2 * numBuses - 1;
      const dof = numActiveMeasurements - stateDim;

      if dof <= 0 then return false; // Critical measurements only (unobservable redundancy)

      // Expected value of J(x) under standard normal noise is dof
      // Approximate 99% confidence threshold = dof + 3.0 * sqrt(2.0 * dof)
      const threshold = dof: real + chi2ConfidenceThreshold * sqrt(2.0 * dof: real);
      return res.objectiveJ > threshold;
    }

    // Identifies largest normalized residual and flags rogue measurement
    proc identifyLargestResidual(ref measurements: [] GridMeasurement,
                                 ref res: EstimationResult): (int, real, GridError) {
      var maxRN: real = 0.0;
      var worstIdx: int = -1;

      for i in 0..<measurements.size {
        if !measurements[i].isSuspect {
          const rawResidual = abs(res.residuals[i]);
          // Approximate normalized residual r_N = |r_i| / sigma_i
          // (assuming diagonal dominance of residual covariance Omega)
          const rN = rawResidual / measurements[i].sigma;
          res.normalizedResiduals[i] = rN;

          if rN > maxRN {
            maxRN = rN;
            worstIdx = i;
          }
        }
      }

      if worstIdx >= 0 && maxRN > normResidualLimit {
        // Flag measurement as suspect
        measurements[worstIdx].isSuspect = true;
        return (worstIdx, maxRN, new GridError(
          PhasorStatus.BadDataDetected,
          "Bad measurement detected at ID " + measurements[worstIdx].id:string + " with normalized residual " + maxRN:string,
          "BadDataDetector",
          measurements[worstIdx].id,
          false
        ));
      }

      return (-1, maxRN, new GridError(PhasorStatus.Success, "No bad data detected", "BadDataDetector"));
    }
  }
}
