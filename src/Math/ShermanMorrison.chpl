/*
 * ShermanMorrison.chpl
 * Rank-1 and rank-2 low-rank updates for ultra-fast contingency screening.
 */

module ShermanMorrison {
  use Math;
  use PhasorConstants;
  use PhasorError;
  use SparseLU;

  record ShermanMorrisonSolver {
    var n: int;

    proc init(dim: int) {
      this.n = dim;
    }

    // Solves (A + u * v^T) * x = b using pre-factored base LU solver
    // Formula: x = x0 - (w * (v^T * x0)) / (1.0 + v^T * w)
    // where A * x0 = b and A * w = u
    proc solveRank1(ref baseLU: DenseFactorizer,
                    u: [] real,
                    v: [] real,
                    b: [] real,
                    ref x: [] real): GridError {
      var x0: [0..<n] real;
      baseLU.solve(b, x0);

      var w: [0..<n] real;
      baseLU.solve(u, w);

      // Compute inner products: v^T * x0 and v^T * w
      var vDotX0: real = 0.0;
      var vDotW: real = 0.0;
      for i in 0..<n {
        vDotX0 += v[i] * x0[i];
        vDotW += v[i] * w[i];
      }

      const denom = 1.0 + vDotW;
      if abs(denom) < 1.0e-12 {
        return new GridError(
          PhasorStatus.IllConditionedMatrix,
          "Sherman-Morrison denominator near zero: grid becomes singular under outage",
          "ShermanMorrison",
          0,
          true
        );
      }

      const scalar = vDotX0 / denom;
      for i in 0..<n {
        x[i] = x0[i] - scalar * w[i];
      }

      return new GridError(PhasorStatus.Success, "Rank-1 update solved", "ShermanMorrison");
    }

    // Specialized transmission line trip update:
    // Outage of line between bus i and bus j with admittance y_km
    // Modifies matrix by -y_km * (e_i - e_j) * (e_i - e_j)^T
    proc solveBranchOutage(ref baseLU: DenseFactorizer,
                           fromBus: int,
                           toBus: int,
                           branchAdmittance: real,
                           b: [] real,
                           ref x: [] real): GridError {
      var u: [0..<n] real = 0.0;
      var v: [0..<n] real = 0.0;

      // u = sqrt(branchAdmittance) * (e_from - e_to)
      // v = -sqrt(branchAdmittance) * (e_from - e_to)
      const scale = sqrt(abs(branchAdmittance));
      const sign = if branchAdmittance >= 0.0 then 1.0 else -1.0;

      if fromBus >= 0 && fromBus < n {
        u[fromBus] = scale;
        v[fromBus] = -sign * scale;
      }
      if toBus >= 0 && toBus < n {
        u[toBus] = -scale;
        v[toBus] = sign * scale;
      }

      return solveRank1(baseLU, u, v, b, x);
    }
  }
}
