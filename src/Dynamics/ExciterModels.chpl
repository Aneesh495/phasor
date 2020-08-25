/*
 * ExciterModels.chpl
 * IEEE Type 1 / DC1A Automatic Voltage Regulator (AVR) and excitation system.
 */

module ExciterModels {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record ExciterState {
    var vr: real;        // Regulator voltage
    var vf: real;        // Rate feedback stabilizing voltage
    var efd: real;       // Generator field voltage

    proc init() {
      this.vr = 1.0;
      this.vf = 0.0;
      this.efd = 1.0;
    }
  }

  record IEEEType1Exciter {
    var ka: real;        // Voltage regulator amplifier gain
    var ta: real;        // Voltage regulator amplifier time constant (s)
    var kf: real;        // Stabilizer feedback gain
    var tf: real;        // Stabilizer feedback time constant (s)
    var ke: real;        // Exciter constant
    var te: real;        // Exciter time constant (s)
    var vRef: real;      // Reference terminal voltage setpoint (pu)
    var vrMax: real;     // Regulator maximum ceiling voltage
    var vrMin: real;     // Regulator minimum ceiling voltage

    proc init(gainKa: real = 40.0,
              timeTa: real = 0.05,
              gainKf: real = 0.05,
              timeTf: real = 1.0,
              gainKe: real = 1.0,
              timeTe: real = 0.5,
              vtarget: real = 1.0) {
      this.ka = gainKa;
      this.ta = timeTa;
      this.kf = gainKf;
      this.tf = timeTf;
      this.ke = gainKe;
      this.te = timeTe;
      this.vRef = vtarget;
      this.vrMax = 5.0;
      this.vrMin = -5.0;
    }

    // Evaluates state derivatives: d(vr)/dt, d(vf)/dt, d(efd)/dt
    proc derivatives(state: ExciterState, terminalV: real): (real, real, real) {
      // Voltage error signal: vErr = vRef - terminalV - vF
      const vErr = vRef - terminalV - state.vf;

      // Amplifier: Ta * d(vr)/dt = Ka * vErr - vr
      var dVr = (ka * vErr - state.vr) / ta;

      // Exciter ceiling clamping
      if (state.vr >= vrMax && dVr > 0.0) || (state.vr <= vrMin && dVr < 0.0) {
        dVr = 0.0;
      }

      // Stabilizer rate feedback: Tf * d(vf)/dt = (Kf / Tf) * efd - vf
      const dVf = ((kf / tf) * state.efd - state.vf) / tf;

      // Exciter armature: Te * d(efd)/dt = vr - Ke * efd
      const dEfd = (state.vr - ke * state.efd) / te;

      return (dVr, dVf, dEfd);
    }
  }
}
