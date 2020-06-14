/*
 * SparseLU.chpl
 * Direct linear solver using LU factorization with partial pivoting.
 */

module SparseLU {
  use Math;
  use PhasorConstants;
  use PhasorError;
  use SparseCSR;

  record DenseFactorizer {
    var n: int;
    var aDomain: domain(2);
    var A: [aDomain] real;
    var permDomain: domain(1);
    var perm: [permDomain] int;
    var isFactored: bool;

    proc init(dim: int) {
      this.n = dim;
      this.aDomain = {0..<dim, 0..<dim};
      this.A = 0.0;
      this.permDomain = 0..<dim;
      this.perm = [i in 0..<dim] i;
      this.isFactored = false;
    }

    // Initialize from SparseCSR matrix
    proc ref loadFromCSR(ref csr: SparseCSRMatrix) {
      this.A = 0.0;
      for r in 0..<csr.nrows {
        const startIdx = csr.rowPtr[r];
        const endIdx = csr.rowPtr[r + 1];
        for k in startIdx..<endIdx {
          const c = csr.colInd[k];
          if r < n && c < n {
            this.A[r, c] = csr.values[k];
          }
        }
      }
      for i in 0..<n do this.perm[i] = i;
      this.isFactored = false;
    }

    // Gaussian Elimination with Partial Pivoting (PA = LU)
    proc ref factorize(): GridError {
      for k in 0..<n {
        // Find pivot in column k
        var maxVal: real = abs(A[k, k]);
        var maxRow: int = k;
        for i in k+1..<n {
          const val = abs(A[i, k]);
          if val > maxVal {
            maxVal = val;
            maxRow = i;
          }
        }

        if maxVal < 1.0e-12 {
          return new GridError(
            PhasorStatus.IllConditionedMatrix,
            "Singular or near-singular pivot detected at index " + k:string,
            "SparseLU",
            k,
            true
          );
        }

        // Swap rows if necessary
        if maxRow != k {
          for j in 0..<n {
            const tmp = A[k, j];
            A[k, j] = A[maxRow, j];
            A[maxRow, j] = tmp;
          }
          const pTmp = perm[k];
          perm[k] = perm[maxRow];
          perm[maxRow] = pTmp;
        }

        // Compute multipliers and eliminate below pivot
        const pivot = A[k, k];
        for i in k+1..<n {
          const factor = A[i, k] / pivot;
          A[i, k] = factor; // Store L multiplier in place
          for j in k+1..<n {
            A[i, j] -= factor * A[k, j];
          }
        }
      }

      this.isFactored = true;
      return new GridError(PhasorStatus.Success, "Factorization complete", "SparseLU");
    }

    // Solve Ax = b via forward and backward substitution
    proc solve(b: [] real, ref x: [] real) {
      var y: [0..<n] real;

      // Forward substitution: Ly = P*b
      for i in 0..<n {
        var sum: real = b[perm[i]];
        for j in 0..<i {
          sum -= A[i, j] * y[j];
        }
        y[i] = sum;
      }

      // Backward substitution: Ux = y
      for i in 0..<n by -1 {
        var sum: real = y[i];
        for j in i+1..<n {
          sum -= A[i, j] * x[j];
        }
        x[i] = sum / A[i, i];
      }
    }
  }
}
