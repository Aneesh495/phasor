/*
 * test_sherman_morrison.chpl
 * Tests rank-1 Sherman-Morrison updates against direct factorization.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use SparseCSR;
use SparseLU;
use ShermanMorrison;

proc main() {
  // Base 3x3 matrix A:
  // [ 4.0  1.0  0.0 ]
  // [ 1.0  4.0  1.0 ]
  // [ 0.0  1.0  4.0 ]
  var rPtrA: [0..3] int = [0, 2, 5, 7];
  var cIndA: [0..6] int = [0, 1,  0, 1, 2,  1, 2];
  var valsA: [0..6] real = [4.0, 1.0,  1.0, 4.0, 1.0,  1.0, 4.0];
  var A = new SparseCSRMatrix(3, 3, rPtrA, cIndA, valsA);

  var baseLU = new DenseFactorizer(3);
  baseLU.loadFromCSR(A);
  var errLU = baseLU.factorize();
  assert(errLU.isOk());

  // Rank-1 perturbation: u = [1.0, 0.0, 2.0]^T, v = [0.5, 1.0, 0.0]^T
  // Perturbation matrix u * v^T:
  // [ 0.5  1.0  0.0 ]
  // [ 0.0  0.0  0.0 ]
  // [ 1.0  2.0  0.0 ]
  // Perturbed matrix A_new = A + u * v^T:
  // [ 4.5  2.0  0.0 ]
  // [ 1.0  4.0  1.0 ]
  // [ 1.0  3.0  4.0 ]
  var u: [0..2] real = [1.0, 0.0, 2.0];
  var v: [0..2] real = [0.5, 1.0, 0.0];
  var b: [0..2] real = [6.5, 6.0, 8.0];

  var sm = new ShermanMorrisonSolver(3);
  var xSM: [0..2] real;
  var errSM = sm.solveRank1(baseLU, u, v, b, xSM);
  assert(errSM.isOk());

  // Solve directly with LU on A_new to compare
  var rPtrNew: [0..3] int = [0, 2, 5, 8];
  var cIndNew: [0..7] int = [0, 1,  0, 1, 2,  0, 1, 2];
  var valsNew: [0..7] real = [4.5, 2.0,  1.0, 4.0, 1.0,  1.0, 3.0, 4.0];
  var ANew = new SparseCSRMatrix(3, 3, rPtrNew, cIndNew, valsNew);

  var luDirect = new DenseFactorizer(3);
  luDirect.loadFromCSR(ANew);
  var errDir = luDirect.factorize();
  assert(errDir.isOk());

  var xDirect: [0..2] real;
  luDirect.solve(b, xDirect);

  // Compare Sherman-Morrison solution with direct LU solution
  for i in 0..2 {
    assert(abs(xSM[i] - xDirect[i]) < 1e-6);
  }

  writeln("Sherman-Morrison rank-1 update tests passed successfully.");
}
