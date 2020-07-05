/*
 * Load.chpl
 * Voltage-dependent ZIP (Impedance, Current, Power) load modeling.
 */

module Load {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record ZIPLoad {
    var busId: int;
    var pNom: real;       // Nominal active power at 1.0 pu voltage (MW)
    var qNom: real;       // Nominal reactive power at 1.0 pu voltage (MVAR)

    // Polynomial ZIP coefficients for active power (must sum to 1.0)
    var aZ: real;         // Constant impedance fraction
    var aI: real;         // Constant current fraction
    var aP: real;         // Constant power fraction

    // Polynomial ZIP coefficients for reactive power (must sum to 1.0)
    var bZ: real;
    var bI: real;
    var bP: real;

    var status: int;      // 1 = online, 0 = disconnected

    proc init() {
      this.busId = 0;
      this.pNom = 0.0;
      this.qNom = 0.0;
      this.aZ = 0.0;
      this.aI = 0.0;
      this.aP = 1.0;      // Default to standard constant power
      this.bZ = 0.0;
      this.bI = 0.0;
      this.bP = 1.0;
      this.status = 1;
    }

    proc init(bId: int,
              p: real,
              q: real,
              pz: real = 0.0,
              pi: real = 0.0,
              pp: real = 1.0,
              qz: real = 0.0,
              qi: real = 0.0,
              qp: real = 1.0,
              inService: int = 1) {
      this.busId = bId;
      this.pNom = p;
      this.qNom = q;
      this.aZ = pz;
      this.aI = pi;
      this.aP = pp;
      this.bZ = qz;
      this.bI = qi;
      this.bP = qp;
      this.status = inService;
    }

    // Computes voltage-dependent active power demand in MW
    // P(V) = P_0 * ( aZ * V^2 + aI * V + aP )
    inline proc activePower(vMag: real): real {
      if status == 0 then return 0.0;
      return pNom * (aZ * vMag * vMag + aI * vMag + aP);
    }

    // Computes voltage-dependent reactive power demand in MVAR
    // Q(V) = Q_0 * ( bZ * V^2 + bI * V + bP )
    inline proc reactivePower(vMag: real): real {
      if status == 0 then return 0.0;
      return qNom * (bZ * vMag * vMag + bI * vMag + bP);
    }
  }
}
