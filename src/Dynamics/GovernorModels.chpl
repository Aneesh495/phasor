/*
 * GovernorModels.chpl
 * IEEEG1 turbine-governor speed control and primary frequency droop regulation.
 */

module GovernorModels {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record GovernorState {
    var pValve: real;    // Steam valve / hydro gate position
    var pMech: real;     // Mechanical shaft power output

    proc init() {
      this.pValve = 1.0;
      this.pMech = 1.0;
    }
  }

  record TurbineGovernor {
    var rDroop: real;    // Speed droop regulation (typical 0.04 to 0.05, or 4-5%)
    var ts: real;        // Main servo valve time constant (s)
    var tc: real;        // Turbine high-pressure chest time constant (s)
    var pMax: real;      // Maximum turbine output limit
    var pMin: real;      // Minimum turbine output limit
    var pRef: real;      // Base dispatch power reference

    proc init(droop: real = 0.05,
              timeTs: real = 0.1,
              timeTc: real = 0.3,
              pmax: real = 1.20,
              pmin: real = 0.0,
              pref: real = 1.0) {
      this.rDroop = droop;
      this.ts = timeTs;
      this.tc = timeTc;
      this.pMax = pmax;
      this.pMin = pmin;
      this.pRef = pref;
    }

    // Evaluates governor state derivatives: d(pValve)/dt and d(pMech)/dt
    // Speed error: deltaOmega = 1.0 - omega_pu
    // Target valve: pTarget = pRef + (1.0 - omega_pu) / R_droop
    proc derivatives(state: GovernorState, omega_pu: real): (real, real) {
      const speedDev = 1.0 - omega_pu;
      var pTarget = pRef + (speedDev / rDroop);

      // Clamp target to turbine valve physical limits
      if pTarget > pMax then pTarget = pMax;
      if pTarget < pMin then pTarget = pMin;

      // Servo valve dynamics: Ts * d(pValve)/dt = pTarget - pValve
      const dPValve = (pTarget - state.pValve) / ts;

      // Turbine chest expansion: Tc * d(pMech)/dt = pValve - pMech
      const dPMech = (state.pValve - state.pMech) / tc;

      return (dPValve, dPMech);
    }
  }
}
