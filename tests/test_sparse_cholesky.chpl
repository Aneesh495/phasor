/*
 * test_sparse_cholesky.chpl
 * Tests Cholesky decomposition on symmetric positive-definite normal equations.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use SparseCSR;
use SparseCholesky;

proc main() {
  // Symmetric positive definite 3x3 matrix:
  // [  4.0  12.0 -16.0 ]
  // [ 12.0  37.0 -43.0 ]
  // [-16.0 -43.0  98.0 ]
  // Expected L:
  // [  2.0   0.0   0.0 ]
  // [  6.0   1.0   0.0 ]
  // [ -8.0   5.0   3.0 ]
  var rPtr: [0..3] int = [0, 3, 6, 9];
  var cInd: [0..8] int = [0, 1, 2,  0, 1, 2,  0, 1, 2];
  var vals: [0..8] real = [4.0, 12.0, -16.0,  12.0, 37.0, -43.0,  -16.0, -43.0, 98.0];

  var A = new SparseCSRMatrix(3, 3, rPtr, cInd, vals);
  var chol = new CholeskyFactorizer(3);
  chol.loadFromCSR(A);

  var err = chol.factorize();
  assert(err.isOk());

  // Check factorized elements
  assert(abs(chol.L[0, 0] - 2.0) < 1e-6);
  assert(abs(chol.L[1, 0] - 6.0) < 1e-6);
  assert(abs(chol.L[1, 1] - 1.0) < 1e-6);
  assert(abs(chol.L[2, 0] - (-8.0)) < 1e-6);
  assert(abs(chol.L[2, 1] - 5.0) < 1e-6);
  assert(abs(chol.L[2, 2] - 3.0) < 1e-6);

  // Solve A * x = b, where b = [ 4.0, 24.0, 52.0 ]
  // Exact solution: x = [ 19.0, -4.0, 1.0 ]
  // 4*19 + 12*(-4) - 16*1 = 76 - 48 - 16 = 12 (adjust b)
  // Let x = [ 1.0, 1.0, 1.0 ]
  // b = [ 4+12-16, 12+37-43, -16-43+98 ] = [ 0.0, 6.0, 39.0 ]
  var b: [0..2] real = [0.0, 6.0, 39.0];
  var x: [0..2] real;
  chol.solve(b, x);

  assert(abs(x[0] - 1.0) < 1e-6);
  assert(abs(x[1] - 1.0) < 1e-6);
  assert(abs(x[2] - 1.0) < 1e-6);

  writeln("Sparse Cholesky tests passed successfully.");
}
