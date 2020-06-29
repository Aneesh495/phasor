/*
 * Bus.chpl
 * Electrical bus node model with voltage states, generation, load, and limits.
 */

module Bus {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record BusNode {
    var id: int;
    var name: string;
    var baseKV: real;
    var busType: BusType;
    var vMag: real;         // Voltage magnitude in per unit (pu)
    var vAngle: real;       // Voltage angle in radians
    var pGen: real;         // Active generation in MW
    var qGen: real;         // Reactive generation in MVAR
    var pLoad: real;        // Active load in MW
    var qLoad: real;        // Reactive load in MVAR
    var gShunt: real;       // Shunt conductance in MW at 1.0 pu
    var bShunt: real;       // Shunt susceptance in MVAR at 1.0 pu
    var vMin: real;         // Minimum voltage limit in pu
    var vMax: real;         // Maximum voltage limit in pu
    var area: int;
    var zone: int;
    var inService: bool;

    proc init() {
      this.id = 0;
      this.name = "UNKNOWN";
      this.baseKV = 138.0;
      this.busType = BusType.PQ;
      this.vMag = 1.0;
      this.vAngle = 0.0;
      this.pGen = 0.0;
      this.qGen = 0.0;
      this.pLoad = 0.0;
      this.qLoad = 0.0;
      this.gShunt = 0.0;
      this.bShunt = 0.0;
      this.vMin = DEFAULT_V_MIN;
      this.vMax = DEFAULT_V_MAX;
      this.area = 1;
      this.zone = 1;
      this.inService = true;
    }

    proc init(busId: int,
              bName: string,
              kv: real,
              bType: BusType,
              vm: real = 1.0,
              va_deg: real = 0.0,
              vmin: real = DEFAULT_V_MIN,
              vmax: real = DEFAULT_V_MAX) {
      this.id = busId;
      this.name = bName;
      this.baseKV = kv;
      this.busType = bType;
      this.vMag = vm;
      this.vAngle = va_deg * DEG_TO_RAD;
      this.pGen = 0.0;
      this.qGen = 0.0;
      this.pLoad = 0.0;
      this.qLoad = 0.0;
      this.gShunt = 0.0;
      this.bShunt = 0.0;
      this.vMin = vmin;
      this.vMax = vmax;
      this.area = 1;
      this.zone = 1;
      this.inService = true;
    }

    // Net active power injection in per unit (P_gen - P_load)
    inline proc netP_pu(baseMVA: real = BASE_MVA): real {
      return (pGen - pLoad) / baseMVA;
    }

    // Net reactive power injection in per unit (Q_gen - Q_load)
    inline proc netQ_pu(baseMVA: real = BASE_MVA): real {
      return (qGen - qLoad) / baseMVA;
    }

    // Returns complex voltage phasor: V = |V| * exp(j * theta)
    inline proc voltagePhasor(): ComplexPhasor {
      return ComplexPhasor.fromPolar(vMag, vAngle);
    }

    // Check if voltage violates operational security bounds
    inline proc isVoltageViolated(): bool {
      return (vMag < vMin) || (vMag > vMax);
    }
  }
}
