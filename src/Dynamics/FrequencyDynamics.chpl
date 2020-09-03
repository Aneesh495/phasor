/*
 * FrequencyDynamics.chpl
 * Center of Inertia (COI) frequency tracking, RoCoF, and dynamic frequency response.
 */

module FrequencyDynamics {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use TransientSimulator;

  record FrequencyMetrics {
    var initialFreqHz: real;
    var nadirFreqHz: real;        // Lowest frequency point reached (Hz)
    var nadirTimeSec: real;       // Time of nadir (s)
    var settlingFreqHz: real;     // Post-contingency quasi-steady-state frequency (Hz)
    var maxRoCoF_Hz_per_s: real;  // Maximum absolute Rate of Change of Frequency (Hz/s)
    var timeToNadirSec: real;

    proc init() {
      this.initialFreqHz = SYS_FREQ;
      this.nadirFreqHz = SYS_FREQ;
      this.nadirTimeSec = 0.0;
      this.settlingFreqHz = SYS_FREQ;
      this.maxRoCoF_Hz_per_s = 0.0;
      this.timeToNadirSec = 0.0;
    }
  }

  record FrequencyAnalyzer {
    proc init() {}

    // Computes Center of Inertia (COI) frequency trajectory and RoCoF
    // f_COI(t) = sum(H_i * f_i(t)) / sum(H_i)
    proc analyzeCOI(res: TransientResult, inertias: [] real, numG: int): FrequencyMetrics {
      var metrics = new FrequencyMetrics();
      const numSteps = res.timeStepsTaken;

      var sumH: real = 0.0;
      for g in 0..<min(numG, inertias.size) do sumH += inertias[g];
      if sumH <= 0.0 then sumH = 1.0;

      var minF: real = SYS_FREQ;
      var minFTime: real = 0.0;
      var maxRocof: real = 0.0;
      var prevFCOI: real = SYS_FREQ;

      for step in 0..<numSteps {
        const t = res.timeArray[step];
        var weightedSpeed: real = 0.0;

        for g in 0..<min(numG, 3) {
          const speedPu = res.speedPuArray[step, g];
          const hVal = if g < inertias.size then inertias[g] else 4.0;
          weightedSpeed += hVal * speedPu;
        }

        const fCOI = (weightedSpeed / sumH) * SYS_FREQ;

        if fCOI < minF {
          minF = fCOI;
          minFTime = t;
        }

        // Compute RoCoF: df_COI / dt
        if step > 0 {
          const dtStep = t - res.timeArray[step - 1];
          if dtStep > 1e-6 {
            const rocof = abs(fCOI - prevFCOI) / dtStep;
            if rocof > maxRocof then maxRocof = rocof;
          }
        }
        prevFCOI = fCOI;
      }

      metrics.nadirFreqHz = minF;
      metrics.nadirTimeSec = minFTime;
      metrics.settlingFreqHz = prevFCOI;
      metrics.maxRoCoF_Hz_per_s = maxRocof;
      metrics.timeToNadirSec = minFTime;

      return metrics;
    }
  }
}
