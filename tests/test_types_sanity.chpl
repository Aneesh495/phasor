/*
 * test_types_sanity.chpl
 * Verifies basic phasor and per-unit math.
 */

use PhasorTypes;
use PhasorConstants;
use PhasorError;

proc main() {
  var v1 = ComplexPhasor.fromPolar(1.0, 0.0);
  var v2 = ComplexPhasor.fromPolarDeg(1.0, 90.0);
  var vSum = v1 + v2;

  assert(abs(v1.re - 1.0) < 1e-6);
  assert(abs(v1.im - 0.0) < 1e-6);
  assert(abs(v2.re - 0.0) < 1e-6);
  assert(abs(v2.im - 1.0) < 1e-6);

  var vProd = v1 * v2;
  assert(abs(vProd.re - 0.0) < 1e-6);
  assert(abs(vProd.im - 1.0) < 1e-6);

  var pu = new PerUnit(1.05, 100.0);
  assert(abs(pu.actualValue() - 105.0) < 1e-6);

  var err = new GridError(PhasorStatus.Success, "All clear");
  assert(err.isOk());

  writeln("Types sanity test passed successfully.");
}
