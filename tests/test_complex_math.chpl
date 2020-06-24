/*
 * test_complex_math.chpl
 * Tests phase unwrapping, vector norms, and symmetrical components.
 */

use PhasorConstants;
use PhasorTypes;
use ComplexMath;

proc main() {
  // Test phase unwrap across branch cut
  const p1 = 3.10;
  const p2 = -3.10; // Jump of ~6.20 rad (across +/- PI)
  const unwrapped = unwrapPhase(p2, p1);
  assert(abs(unwrapped - (p1 + (TWO_PI - 6.20))) < 1e-4);

  // Test angle normalization
  const bigAngle = 4.0 * PI + 0.5;
  const normA = normalizeAngle(bigAngle);
  assert(abs(normA - 0.5) < 1e-6);

  // Test vector norms
  var rv: [0..2] real = [3.0, -4.0, 1.0];
  assert(abs(vectorNormInf(rv) - 4.0) < 1e-6);
  assert(abs(vectorNorm2(rv) - sqrt(26.0)) < 1e-6);

  // Test Symmetrical Components under balanced condition
  // Balanced 3-phase voltages: Va = 1 /_ 0, Vb = 1 /_ -120, Vc = 1 /_ +120
  const va = ComplexPhasor.fromPolarDeg(1.0, 0.0);
  const vb = ComplexPhasor.fromPolarDeg(1.0, -120.0);
  const vc = ComplexPhasor.fromPolarDeg(1.0, 120.0);
  const sym = SymmetricalComponents.fromThreePhase(va, vb, vc);

  // For balanced set: Zero sequence = 0, Negative sequence = 0, Positive sequence = 1.0
  assert(sym.zero.magnitude() < 1e-5);
  assert(sym.negative.magnitude() < 1e-5);
  assert(abs(sym.positive.magnitude() - 1.0) < 1e-5);

  writeln("Complex math tests passed successfully.");
}
