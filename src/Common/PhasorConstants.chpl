/*
 * PhasorConstants.chpl
 * Fundamental physical, electrical, and numerical parameters for Phasor engine.
 */

module PhasorConstants {
  // Standard power grid operating frequency (Hertz)
  config const SYS_FREQ: real = 60.0;

  // Angular electrical frequency (rad/s)
  const OMEGA_SYS: real = 2.0 * 3.14159265358979323846 * SYS_FREQ;

  // Standard system base power rating (Mega Volt-Amperes)
  config const BASE_MVA: real = 100.0;

  // Mathematical constants
  const PI: real = 3.14159265358979323846;
  const TWO_PI: real = 2.0 * PI;
  const HALF_PI: real = 0.5 * PI;
  const DEG_TO_RAD: real = PI / 180.0;
  const RAD_TO_DEG: real = 180.0 / PI;

  // Power flow convergence tolerances
  config const PF_TOLERANCE: real = 1.0e-6;
  config const PF_MAX_ITERATIONS: int = 40;

  // State estimation convergence tolerances and thresholds
  config const SE_TOLERANCE: real = 1.0e-5;
  config const SE_MAX_ITERATIONS: int = 30;
  config const BAD_DATA_CHI2_THRESHOLD: real = 3.0;
  config const BAD_DATA_NORM_RESIDUAL_LIMIT: real = 3.0;

  // Voltage security boundaries (in per-unit)
  config const DEFAULT_V_MIN: real = 0.90;
  config const DEFAULT_V_MAX: real = 1.10;
  config const DEFAULT_V_EMERGENCY_MIN: real = 0.85;
  config const DEFAULT_V_EMERGENCY_MAX: real = 1.15;

  // Machine dynamics constants
  config const DYNAMICS_DT: real = 0.001; // 1 millisecond time-step
  config const DYNAMICS_T_END: real = 5.0; // 5.0 seconds simulation window
  config const SPEED_BASE_PU: real = 1.0;

  // IEEE C37.118 framing constants
  const C37_SYNC_DATA: uint(16) = 0xAA01;
  const C37_SYNC_HEADER: uint(16) = 0xAA11;
  const C37_SYNC_CFG1: uint(16) = 0xAA21;
  const C37_SYNC_CFG2: uint(16) = 0xAA31;
  const C37_SYNC_CFG3: uint(16) = 0xAA41;
  const C37_SYNC_CMD: uint(16) = 0xAA51;
}
