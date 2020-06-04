/*
 * PhasorTypes.chpl
 * Core electrical and computational types for power flow, estimation, and dynamics.
 */

module PhasorTypes {
  use Math;
  use PhasorConstants;

  // Bus operational classification in power flow formulation
  enum BusType {
    Slack = 1,      // Reference bus: voltage magnitude and phase angle fixed
    PV = 2,         // Voltage controlled generator bus: P and |V| specified
    PQ = 3,         // Load bus: active and reactive power demand specified
    Isolated = 4    // Disconnected / out of service bus
  }

  // Branch physical classification
  enum BranchType {
    TransmissionLine = 1,
    Transformer = 2,
    PhaseShifter = 3
  }

  // Measurement classification for state estimation
  enum MeasurementType {
    BusVoltageMag = 1,
    BusVoltageAngle = 2,
    ActiveBranchFlow = 3,
    ReactiveBranchFlow = 4,
    ActiveBusInjection = 5,
    ReactiveBusInjection = 6,
    PMUVoltagePhasor = 7,
    PMUCurrentPhasor = 8
  }

  // Complex phasor representation with rectangular and polar coordinates
  record ComplexPhasor {
    var re: real;
    var im: real;

    proc init() {
      this.re = 0.0;
      this.im = 0.0;
    }

    proc init(r: real, i: real) {
      this.re = r;
      this.im = i;
    }

    proc init(r: real) {
      this.re = r;
      this.im = 0.0;
    }

    // Polar constructor: magnitude and angle in radians
    proc type fromPolar(mag: real, angle_rad: real): ComplexPhasor {
      return new ComplexPhasor(mag * cos(angle_rad), mag * sin(angle_rad));
    }

    // Polar constructor: magnitude and angle in degrees
    proc type fromPolarDeg(mag: real, angle_deg: real): ComplexPhasor {
      const rad = angle_deg * DEG_TO_RAD;
      return new ComplexPhasor(mag * cos(rad), mag * sin(rad));
    }

    inline proc magnitude(): real {
      return sqrt(re * re + im * im);
    }

    inline proc magnitudeSq(): real {
      return re * re + im * im;
    }

    inline proc angle(): real {
      return atan2(im, re);
    }

    inline proc angleDeg(): real {
      return atan2(im, re) * RAD_TO_DEG;
    }

    inline proc conjugate(): ComplexPhasor {
      return new ComplexPhasor(re, -im);
    }

    inline proc rotate(theta_rad: real): ComplexPhasor {
      const c = cos(theta_rad);
      const s = sin(theta_rad);
      return new ComplexPhasor(re * c - im * s, re * s + im * c);
    }

    proc toString(): string {
      return "( " + re:string + " + " + im:string + "j )";
    }

    proc toPolarString(): string {
      return magnitude():string + " /_ " + angleDeg():string + " deg";
    }
  }

  // Complex phasor arithmetic operators
  inline operator +(a: ComplexPhasor, b: ComplexPhasor): ComplexPhasor {
    return new ComplexPhasor(a.re + b.re, a.im + b.im);
  }

  inline operator -(a: ComplexPhasor, b: ComplexPhasor): ComplexPhasor {
    return new ComplexPhasor(a.re - b.re, a.im - b.im);
  }

  inline operator -(a: ComplexPhasor): ComplexPhasor {
    return new ComplexPhasor(-a.re, -a.im);
  }

  inline operator *(a: ComplexPhasor, b: ComplexPhasor): ComplexPhasor {
    return new ComplexPhasor(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
  }

  inline operator *(a: ComplexPhasor, s: real): ComplexPhasor {
    return new ComplexPhasor(a.re * s, a.im * s);
  }

  inline operator *(s: real, a: ComplexPhasor): ComplexPhasor {
    return new ComplexPhasor(a.re * s, a.im * s);
  }

  inline operator /(a: ComplexPhasor, s: real): ComplexPhasor {
    return new ComplexPhasor(a.re / s, a.im / s);
  }

  inline operator /(a: ComplexPhasor, b: ComplexPhasor): ComplexPhasor {
    const denom = b.re * b.re + b.im * b.im;
    return new ComplexPhasor(
      (a.re * b.re + a.im * b.im) / denom,
      (a.im * b.re - a.re * b.im) / denom
    );
  }

  inline operator ==(a: ComplexPhasor, b: ComplexPhasor): bool {
    return a.re == b.re && a.im == b.im;
  }

  inline operator !=(a: ComplexPhasor, b: ComplexPhasor): bool {
    return !(a == b);
  }

  // Per-unit electrical quantity representation
  record PerUnit {
    var value_pu: real;
    var base_val: real;

    proc init(val_pu: real, base: real = 100.0) {
      this.value_pu = val_pu;
      this.base_val = base;
    }

    inline proc actualValue(): real {
      return value_pu * base_val;
    }

    inline proc setFromActual(actual: real) {
      this.value_pu = actual / base_val;
    }
  }
}
