/*
 * ComplexMath.chpl
 * High-performance complex phasor algebra, norms, and coordinate transformations.
 */

module ComplexMath {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  // Unwraps phase angle in radians to prevent branch cut jumps
  proc unwrapPhase(phase_rad: real, prev_phase_rad: real): real {
    var diff = phase_rad - prev_phase_rad;
    while diff > PI {
      diff -= TWO_PI;
    }
    while diff < -PI {
      diff += TWO_PI;
    }
    return prev_phase_rad + diff;
  }

  // Normalizes phase angle to (-PI, PI]
  inline proc normalizeAngle(angle_rad: real): real {
    var a = angle_rad;
    while a <= -PI {
      a += TWO_PI;
    }
    while a > PI {
      a -= TWO_PI;
    }
    return a;
  }

  // Complex vector dot product: sum(conj(x[i]) * y[i])
  proc complexDotProduct(x: [] ComplexPhasor, y: [] ComplexPhasor): ComplexPhasor {
    var sum = new ComplexPhasor(0.0, 0.0);
    for i in x.domain {
      const prod = x[i].conjugate() * y[i];
      sum = sum + prod;
    }
    return sum;
  }

  // Maximum absolute element norm (infinity norm) for real vector
  proc vectorNormInf(v: [] real): real {
    var maxVal: real = 0.0;
    for x in v {
      const a = abs(x);
      if a > maxVal then maxVal = a;
    }
    return maxVal;
  }

  // Euclidean norm (L2 norm) for real vector
  proc vectorNorm2(v: [] real): real {
    var sumSq: real = 0.0;
    for x in v {
      sumSq += x * x;
    }
    return sqrt(sumSq);
  }

  // Complex vector infinity norm: max(|z[i]|)
  proc complexVectorNormInf(v: [] ComplexPhasor): real {
    var maxMag: real = 0.0;
    for z in v {
      const m = z.magnitude();
      if m > maxMag then maxMag = m;
    }
    return maxMag;
  }

  // Symmetrical components transformation: Positive, Negative, Zero sequence
  record SymmetricalComponents {
    var zero: ComplexPhasor;
    var positive: ComplexPhasor;
    var negative: ComplexPhasor;

    proc type fromThreePhase(va: ComplexPhasor, vb: ComplexPhasor, vc: ComplexPhasor): SymmetricalComponents {
      // Fortescue transformation: a = 1 /_ 120 deg = -0.5 + j * sqrt(3)/2
      const a = ComplexPhasor.fromPolarDeg(1.0, 120.0);
      const aSq = ComplexPhasor.fromPolarDeg(1.0, 240.0);
      const oneThird: real = 1.0 / 3.0;

      const v0 = (va + vb + vc) * oneThird;
      const v1 = (va + a * vb + aSq * vc) * oneThird;
      const v2 = (va + aSq * vb + a * vc) * oneThird;

      return new SymmetricalComponents(v0, v1, v2);
    }
  }
}
