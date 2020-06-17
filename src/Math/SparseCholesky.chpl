/*
 * SparseCholesky.chpl
 * Cholesky factorization (A = L * L^T) for symmetric positive-definite normal equations.
 */

module SparseCholesky {
  use Math;
  use PhasorConstants;
  use PhasorError;
  use SparseCSR;

  record CholeskyFactorizer {
    var n: int;
    var lDomain: domain(2);
    var L: [lDomain] real;
    var isFactored: bool;

    proc init(dim: int) {
      this.n = dim;
      this.lDomain = {0..<dim, 0..<dim};
      this.L = 0.0;
      this.isFactored = false;
    }

    // Load from symmetric matrix represented by SparseCSR
    proc ref loadFromCSR(ref csr: SparseCSRMatrix) {
      this.L = 0.0;
      for r in 0..<csr.nrows {
        const startIdx = csr.rowPtr[r];
        const endIdx = csr.rowPtr[r + 1];
        for k in startIdx..<endIdx {
          const c = csr.colInd[k];
          if r < n && c < n {
            this.L[r, c] = csr.values[k];
          }
        }
      }
      this.isFactored = false;
    }

    // Perform Cholesky factorization in-place: L stores lower triangular factor
    proc ref factorize(): GridError {
      for i in 0..<n {
        for j in 0..i {
          var sum: real = L[i, j];

          for k in 0..<j {
            sum -= L[i, k] * L[j, k];
          }

          if i == j {
            if sum <= 0.0 {
              return new GridError(
                PhasorStatus.IllConditionedMatrix,
                "Matrix is not positive definite at index " + i:string + " (diag=" + sum:string + ")",
                "SparseCholesky",
                i,
                true
              );
            }
            L[i, j] = sqrt(sum);
          } else {
            L[i, j] = sum / L[j, j];
            L[j, i] = 0.0; // Clear upper triangle
          }
        }
      }

      this.isFactored = true;
      return new GridError(PhasorStatus.Success, "Cholesky factorization successful", "SparseCholesky");
    }

    // Solve (L * L^T) * x = b
    proc solve(b: [] real, ref x: [] real) {
      var y: [0..<n] real;

      // Forward solve: L * y = b
      for i in 0..<n {
        var sum: real = b[i];
        for k in 0..<i {
          sum -= L[i, k] * y[k];
        }
        y[i] = sum / L[i, i];
      }

      // Backward solve: L^T * x = y
      for i in 0..<n by -1 {
        var sum: real = y[i];
        for k in i+1..<n {
          sum -= L[k, i] * x[k];
        }
        x[i] = sum / L[i, i];
      }
    }
  }
}
