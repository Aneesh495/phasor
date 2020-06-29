/*
 * Branch.chpl
 * Transmission lines, transformers, and phase shifters pi-equivalent branch model.
 */

module Branch {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record TransmissionBranch {
    var id: int;
    var fromBus: int;
    var toBus: int;
    var circuit: string;
    var r: real;             // Series resistance in per-unit
    var x: real;             // Series reactance in per-unit
    var b: real;             // Total line charging susceptance in per-unit
    var rateA: real;         // Continuous MVA thermal rating
    var rateB: real;         // Short-term emergency MVA rating
    var rateC: real;         // Transient emergency MVA rating
    var ratio: real;         // Transformer off-nominal turns ratio (1.0 for lines)
    var phaseShiftDeg: real; // Phase shifter angle in degrees
    var phaseShiftRad: real; // Phase shifter angle in radians
    var status: int;         // 1 = in service, 0 = tripped / outage
    var branchType: BranchType;

    proc init() {
      this.id = 0;
      this.fromBus = 0;
      this.toBus = 0;
      this.circuit = "1";
      this.r = 0.0;
      this.x = 0.001;
      this.b = 0.0;
      this.rateA = 100.0;
      this.rateB = 120.0;
      this.rateC = 150.0;
      this.ratio = 1.0;
      this.phaseShiftDeg = 0.0;
      this.phaseShiftRad = 0.0;
      this.status = 1;
      this.branchType = BranchType.TransmissionLine;
    }

    proc init(brId: int,
              fromB: int,
              toB: int,
              r_pu: real,
              x_pu: real,
              b_pu: real = 0.0,
              mvaRate: real = 100.0,
              turnsRatio: real = 1.0,
              shiftDeg: real = 0.0,
              inService: int = 1,
              ckt: string = "1") {
      this.id = brId;
      this.fromBus = fromB;
      this.toBus = toB;
      this.circuit = ckt;
      this.r = r_pu;
      this.x = x_pu;
      this.b = b_pu;
      this.rateA = mvaRate;
      this.rateB = mvaRate * 1.20;
      this.rateC = mvaRate * 1.50;
      this.ratio = if turnsRatio <= 0.0 then 1.0 else turnsRatio;
      this.phaseShiftDeg = shiftDeg;
      this.phaseShiftRad = shiftDeg * DEG_TO_RAD;
      this.status = inService;

      if abs(shiftDeg) > 1e-4 {
        this.branchType = BranchType.PhaseShifter;
      } else if abs(this.ratio - 1.0) > 1e-4 {
        this.branchType = BranchType.Transformer;
      } else {
        this.branchType = BranchType.TransmissionLine;
      }
    }

    // Series complex impedance Z = r + j * x
    inline proc seriesImpedance(): ComplexPhasor {
      return new ComplexPhasor(r, x);
    }

    // Series complex admittance Y = 1 / Z = g + j * b_series
    inline proc seriesAdmittance(): ComplexPhasor {
      const denom = r * r + x * x;
      if denom < 1.0e-12 {
        return new ComplexPhasor(0.0, -1.0e6);
      }
      return new ComplexPhasor(r / denom, -x / denom);
    }

    // Half of total line charging susceptance at each terminal
    inline proc halfCharging(): ComplexPhasor {
      return new ComplexPhasor(0.0, 0.5 * b);
    }

    // Complex turns ratio: a = ratio * exp(j * phaseShift)
    inline proc complexRatio(): ComplexPhasor {
      return ComplexPhasor.fromPolar(ratio, phaseShiftRad);
    }

    // Check if line is tripped / out of service
    inline proc isTripped(): bool {
      return status == 0;
    }
  }
}
