/*
 * PerformanceIndex.chpl
 * Contingency ranking severity metrics: active power overload (PI_P) and voltage violation (PI_V).
 */

module PerformanceIndex {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PowerFlowResult;

  enum SeverityTier {
    Secure = 1,     // No overloads or voltage violations
    Warning = 2,    // Line loading between 90% and 100%, or minor voltage sag
    Critical = 3    // Thermal limit exceeded (> 100%) or severe voltage collapse risk
  }

  record ContingencySeverity {
    var contingencyId: int;
    var name: string;
    var piP: real;            // Active power overload index
    var piV: real;            // Voltage violation index
    var maxLineLoadingPct: real;
    var worstLineIdx: int;
    var worstBusIdx: int;
    var minBusVoltage: real;
    var tier: SeverityTier;
    var isIslanded: bool;

    proc init() {
      this.contingencyId = 0;
      this.name = "NONE";
      this.piP = 0.0;
      this.piV = 0.0;
      this.maxLineLoadingPct = 0.0;
      this.worstLineIdx = -1;
      this.worstBusIdx = -1;
      this.minBusVoltage = 1.0;
      this.tier = SeverityTier.Secure;
      this.isIslanded = false;
    }
  }

  record PerformanceIndexEvaluator {
    var powerExponentM: int; // Exponent m in (P/P_max)^(2*m)
    var voltExponentN: int;  // Exponent n in (Delta V / Delta V_max)^(2*n)

    proc init(expM: int = 1, expN: int = 1) {
      this.powerExponentM = expM;
      this.voltExponentN = expN;
    }

    // Evaluates thermal overload PI_P and voltage security PI_V from post-contingency result
    proc evaluate(cId: int,
                  cName: string,
                  res: SolutionMetrics,
                  rateA: [] real,
                  vMin: [] real,
                  vMax: [] real): ContingencySeverity {
      var sev = new ContingencySeverity();
      sev.contingencyId = cId;
      sev.name = cName;

      // 1. Evaluate PI_P = sum( (P_k / RateA_k)^(2*m) )
      var sumPIP: real = 0.0;
      var maxLoad: real = 0.0;
      var worstLine: int = -1;

      for k in 0..<res.numBranches {
        const rating = rateA[k];
        if rating > 0.0 {
          const flow = res.mvaLoading[k];
          const ratio = flow / rating;
          const pct = ratio * 100.0;

          if pct > maxLoad {
            maxLoad = pct;
            worstLine = k;
          }

          // Penalize overloads heavily
          if ratio > 1.0 {
            sumPIP += (ratio ** (2 * powerExponentM));
          } else if ratio > 0.90 {
            sumPIP += 0.1 * (ratio ** (2 * powerExponentM));
          }
        }
      }

      sev.piP = sumPIP;
      sev.maxLineLoadingPct = maxLoad;
      sev.worstLineIdx = worstLine;

      // 2. Evaluate PI_V = sum( ( |V_i - V_nom| / Delta V_max )^(2*n) )
      var sumPIV: real = 0.0;
      var minV: real = 2.0;
      var worstBus: int = -1;

      for i in 0..<res.numBuses {
        const vm = res.vMag[i];
        if vm < minV {
          minV = vm;
          worstBus = i;
        }

        const vNom: real = 1.0;
        const maxDev: real = 0.10; // +/- 10% allowed

        if vm < vMin[i] {
          const sag = (vMin[i] - vm) / maxDev;
          sumPIV += (sag ** (2 * voltExponentN));
        } else if vm > vMax[i] {
          const swell = (vm - vMax[i]) / maxDev;
          sumPIV += (swell ** (2 * voltExponentN));
        }
      }

      sev.piV = sumPIV;
      sev.minBusVoltage = minV;
      sev.worstBusIdx = worstBus;

      // 3. Classify into Severity Tier
      if maxLoad > 100.0 || minV < 0.90 {
        sev.tier = SeverityTier.Critical;
      } else if maxLoad > 90.0 || minV < 0.94 {
        sev.tier = SeverityTier.Warning;
      } else {
        sev.tier = SeverityTier.Secure;
      }

      return sev;
    }
  }
}
