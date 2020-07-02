/*
 * Generator.chpl
 * Synchronous generator model with capability limits, fuel costs, and electromechanical dynamics.
 */

module Generator {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record SynchronousGenerator {
    var id: int;
    var busId: int;
    var pGen: real;          // Active power output in MW
    var qGen: real;          // Reactive power output in MVAR
    var pMin: real;          // Minimum active power in MW
    var pMax: real;          // Maximum active power in MW
    var qMin: real;          // Minimum reactive power in MVAR
    var qMax: real;          // Maximum reactive power in MVAR
    var vSet: real;          // Target regulated terminal voltage in pu
    var mBase: real;         // Machine MVA base rating
    var status: int;         // 1 = online, 0 = tripped

    // Economic dispatch quadratic cost curve: C(P) = a * P^2 + b * P + c ($/h)
    var costA: real;
    var costB: real;
    var costC: real;
    var rampRate: real;      // Maximum ramp rate in MW/minute

    // Electromechanical dynamic simulation parameters
    var H: real;             // Generator inertia constant in seconds (MW-s/MVA)
    var D: real;             // Damping coefficient in pu-torque/pu-speed
    var xdPrime: real;       // Direct-axis transient reactance in pu
    var xqPrime: real;       // Quadrature-axis transient reactance in pu
    var td0Prime: real;      // Direct-axis open-circuit transient time constant (s)
    var tq0Prime: real;      // Quadrature-axis open-circuit transient time constant (s)

    proc init() {
      this.id = 0;
      this.busId = 0;
      this.pGen = 0.0;
      this.qGen = 0.0;
      this.pMin = 0.0;
      this.pMax = 500.0;
      this.qMin = -200.0;
      this.qMax = 200.0;
      this.vSet = 1.0;
      this.mBase = 100.0;
      this.status = 1;
      this.costA = 0.005;
      this.costB = 20.0;
      this.costC = 100.0;
      this.rampRate = 10.0;
      this.H = 4.0;
      this.D = 1.0;
      this.xdPrime = 0.20;
      this.xqPrime = 0.40;
      this.td0Prime = 6.0;
      this.tq0Prime = 1.0;
    }

    proc init(genId: int,
              bId: int,
              pg: real,
              qg: real,
              qmax: real,
              qmin: real,
              vtarget: real = 1.0,
              pmax: real = 500.0,
              pmin: real = 0.0,
              baseMva: real = 100.0,
              inService: int = 1) {
      this.id = genId;
      this.busId = bId;
      this.pGen = pg;
      this.qGen = qg;
      this.pMin = pmin;
      this.pMax = pmax;
      this.qMin = qmin;
      this.qMax = qmax;
      this.vSet = vtarget;
      this.mBase = baseMva;
      this.status = inService;
      this.costA = 0.005;
      this.costB = 20.0;
      this.costC = 100.0;
      this.rampRate = 10.0;
      this.H = 4.0;
      this.D = 1.0;
      this.xdPrime = 0.20;
      this.xqPrime = 0.40;
      this.td0Prime = 6.0;
      this.tq0Prime = 1.0;
    }

    // Evaluates fuel cost for active power generation P: C(P) = a * P^2 + b * P + c
    inline proc fuelCost(p: real): real {
      return costA * p * p + costB * p + costC;
    }

    // Evaluates incremental fuel cost (marginal cost): dC/dP = 2 * a * P + b
    inline proc marginalCost(p: real): real {
      return 2.0 * costA * p + costB;
    }

    // Clamps active power to within physical capability limits
    inline proc clampP(p: real): real {
      if p < pMin then return pMin;
      if p > pMax then return pMax;
      return p;
    }

    // Clamps reactive power to within capability limits
    inline proc clampQ(q: real): real {
      if q < qMin then return qMin;
      if q > qMax then return qMax;
      return q;
    }

    // Check if reactive power output is at or exceeding capability limits
    inline proc isAtQLimit(): bool {
      return (qGen <= qMin + 1e-4) || (qGen >= qMax - 1e-4);
    }
  }
}
