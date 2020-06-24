/*
 * test_sparse_csr.chpl
 * Tests Compressed Sparse Row matrix creation, SpMV, and transpose.
 */

use PhasorConstants;
use PhasorTypes;
use SparseCSR;

proc main() {
  // Define 3x3 sparse matrix:
  // [ 10.0   0.0   20.0 ]
  // [  0.0  30.0    0.0 ]
  // [ 40.0   0.0   50.0 ]
  var rPtr: [0..3] int = [0, 2, 3, 5];
  var cInd: [0..4] int = [0, 2, 1, 0, 2];
  var vals: [0..4] real = [10.0, 20.0, 30.0, 40.0, 50.0];

  var A = new SparseCSRMatrix(3, 3, rPtr, cInd, vals);

  assert(A.nrows == 3);
  assert(A.ncols == 3);
  assert(A.nnz == 5);
  assert(abs(A.get(0, 0) - 10.0) < 1e-6);
  assert(abs(A.get(0, 1) - 0.0) < 1e-6);
  assert(abs(A.get(0, 2) - 20.0) < 1e-6);
  assert(abs(A.get(1, 1) - 30.0) < 1e-6);
  assert(abs(A.get(2, 2) - 50.0) < 1e-6);

  // Test SpMV: y = A * x, where x = [1.0, 2.0, 3.0]
  // Expected y: [ 10*1 + 20*3, 30*2, 40*1 + 50*3 ] = [ 70.0, 60.0, 190.0 ]
  var x: [0..2] real = [1.0, 2.0, 3.0];
  var y: [0..2] real;
  A.matVec(x, y);

  assert(abs(y[0] - 70.0) < 1e-6);
  assert(abs(y[1] - 60.0) < 1e-6);
  assert(abs(y[2] - 190.0) < 1e-6);

  // Test Transpose:
  // A^T should have:
  // [ 10.0   0.0  40.0 ]
  // [  0.0  30.0   0.0 ]
  // [ 20.0   0.0  50.0 ]
  var At = A.transpose();
  assert(abs(At.get(0, 2) - 40.0) < 1e-6);
  assert(abs(At.get(2, 0) - 20.0) < 1e-6);
  assert(abs(At.get(1, 1) - 30.0) < 1e-6);

  var yT: [0..2] real;
  At.matVec(x, yT);
  // Expected yT: [ 10*1 + 40*3, 30*2, 20*1 + 50*3 ] = [ 130.0, 60.0, 170.0 ]
  assert(abs(yT[0] - 130.0) < 1e-6);
  assert(abs(yT[1] - 60.0) < 1e-6);
  assert(abs(yT[2] - 170.0) < 1e-6);

  writeln("Sparse CSR tests passed successfully.");
}
