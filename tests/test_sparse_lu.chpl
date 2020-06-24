/*
 * test_sparse_lu.chpl
 * Tests direct linear solve via LU factorization with partial pivoting.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use SparseCSR;
use SparseLU;

proc main() {
  // Test system:
  // [ 2.0  1.0 -1.0 ] [ x0 ] = [  8.0 ]
  // [-3.0 -1.0  2.0 ] [ x1 ] = [ -11.0 ]
  // [-2.0  1.0  2.0 ] [ x2 ] = [ -3.0 ]
  // Exact solution: x = [ 2.0, 3.0, -1.0 ]
  var rPtr: [0..3] int = [0, 3, 6, 9];
  var cInd: [0..8] int = [0, 1, 2,  0, 1, 2,  0, 1, 2];
  var vals: [0..8] real = [2.0, 1.0, -1.0,  -3.0, -1.0, 2.0,  -2.0, 1.0, 2.0];

  var A = new SparseCSRMatrix(3, 3, rPtr, cInd, vals);
  var lu = new DenseFactorizer(3);
  lu.loadFromCSR(A);

  var err = lu.factorize();
  assert(err.isOk());

  var b: [0..2] real = [8.0, -11.0, -3.0];
  var x: [0..2] real;
  lu.solve(b, x);

  assert(abs(x[0] - 2.0) < 1e-6);
  assert(abs(x[1] - 3.0) < 1e-6);
  assert(abs(x[2] - (-1.0)) < 1e-6);

  writeln("Sparse LU solver tests passed successfully.");
}
