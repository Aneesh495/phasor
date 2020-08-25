/*
 * MachineModels.chpl
 * Synchronous generator electromechanical dynamic models: classical 2nd-order and 4th-order two-axis.
 */

module MachineModels {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record ClassicalMachineState {
    var delta: real;      // Rotor angle in radians
    var omega: real;      // Rotor angular speed in rad/s
    var omega_pu: real;   // Rotor angular speed in per-unit (1.0 = nominal)
    var pMech: real;      // Mechanical power input in per-unit
    var pElec: real;      // Electrical power output in per-unit
    var eInternal: real;  // Constant voltage behind transient reactance (E')

    proc init() {
      this.delta = 0.0;
      this.omega = OMEGA_SYS;
      this.omega_pu = 1.0;
      this.pMech = 1.0;
      this.pElec = 1.0;
      this.eInternal = 1.05;
    }
  }

  record TwoAxisMachineState {
    var delta: real;      // Rotor angle in radians
    var omega: real;      // Rotor speed in rad/s
    var omega_pu: real;
    var eqPrime: real;    // Q-axis transient voltage
    var edPrime: real;    // D-axis transient voltage
    var efd: real;        // Field excitation voltage
    var pMech: real;
    var pElec: real;
    var id: real;         // D-axis armature current
    var iq: real;         // Q-axis armature current

    proc init() {
      this.delta = 0.0;
      this.omega = OMEGA_SYS;
      this.omega_pu = 1.0;
      this.eqPrime = 1.0;
      this.edPrime = 0.0;
      this.efd = 1.0;
      this.pMech = 1.0;
      this.pElec = 1.0;
      this.id = 0.0;
      this.iq = 1.0;
    }
  }

  record ClassicalMachine {
    var id: int;
    var busIdx: int;
    var H: real;          // Inertia constant (MW-s / MVA)
    var D: real;          // Damping coefficient (pu-torque / pu-speed)
    var xdPrime: real;    // Transient reactance

    proc init() {
      this.id = 0;
      this.busIdx = 0;
      this.H = 4.0;
      this.D = 1.0;
      this.xdPrime = 0.20;
    }

    proc init(mId: int, bIdx: int, hVal: real = 4.0, dVal: real = 1.0, xdp: real = 0.20) {
      this.id = mId;
      this.busIdx = bIdx;
      this.H = hVal;
      this.D = dVal;
      this.xdPrime = xdp;
    }

    // Computes derivatives d(delta)/dt and d(omega)/dt
    // d(delta)/dt = omega - omega_sys
    // 2*H * d(omega_pu)/dt = P_mech - P_elec - D * (omega_pu - 1.0)
    proc derivatives(state: ClassicalMachineState): (real, real) {
      const dDelta = state.omega - OMEGA_SYS;
      const speedDev = state.omega_pu - 1.0;
      const accelPower = state.pMech - state.pElec - (D * speedDev);
      const dOmegaPu = accelPower / (2.0 * H);
      const dOmega = dOmegaPu * OMEGA_SYS;

      return (dDelta, dOmega);
    }
  }
}
