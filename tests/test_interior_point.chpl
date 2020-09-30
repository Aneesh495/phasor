/*
 * test_interior_point.chpl
 * Unit verification for Primal-Dual Interior Point Method quadratic programming solver.
 */

use PhasorConstants;
use PhasorTypes;
use InteriorPoint;

proc main() {
  writeln("=== Running Test: Interior Point Method Solver ===");

  const n = 2;
  const m = 0;
  var qp = new QuadraticProgram(n, m);

  // Objective: f(x1, x2) = x1^2 + 2 * x2^2 - 4 * x1 - 8 * x2
  // Q = [[2, 0], [0, 4]], c = [-4, -8]
  qp.Q[0, 0] = 2.0;
  qp.Q[1, 1] = 4.0;
  qp.c[0] = -4.0;
  qp.c[1] = -8.0;

  qp.xLower[0] = 0.0;
  qp.xUpper[0] = 10.0;
  qp.xLower[1] = 0.0;
  qp.xUpper[1] = 10.0;

  var solver = new PrimalDualIPMSolver(maxI=100, tolerance=1e-4, mu=1.0);
  var x: [0..<n] real;

  var (success, objVal) = solver.solve(qp, x);

  assert(success, "IPM solver failed to complete");
  writeln("IPM Solution: x1 = ", x[0], ", x2 = ", x[1]);
  writeln("Objective value: ", objVal);

  // Analytical optimum: x1 = 2.0, x2 = 2.0, obj = -12.0
  assert(abs(x[0] - 2.0) < 0.15, "x1 outside tolerance of analytical optimum");
  assert(abs(x[1] - 2.0) < 0.15, "x2 outside tolerance of analytical optimum");
  assert(abs(objVal - (-12.0)) < 0.25, "Objective outside tolerance of analytical minimum");

  writeln("PASS: Interior Point Method QP verified successfully.");
}
