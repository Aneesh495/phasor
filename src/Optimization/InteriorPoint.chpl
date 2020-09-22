/*
 * InteriorPoint.chpl
 * Primal-Dual Interior Point Method (IPM) for convex quadratic programming with barrier penalty.
 */

module InteriorPoint {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseLU;

  record QuadraticProgram {
    var n: int;          // Number of variables
    var m: int;          // Number of inequality constraints: A * x <= b
    var Q: [0..<n, 0..<n] real; // Quadratic objective Hessian: 0.5 * x^T * Q * x
    var c: [0..<n] real; // Linear objective gradient: c^T * x
    var A: [0..<m, 0..<n] real; // Constraint matrix
    var b: [0..<m] real; // Upper bounds
    var xLower: [0..<n] real;
    var xUpper: [0..<n] real;

    proc init(numVars: int, numCons: int) {
      this.n = numVars;
      this.m = numCons;
      this.Q = 0.0;
      this.c = 0.0;
      this.A = 0.0;
      this.b = 0.0;
      this.xLower = -1e6;
      this.xUpper = 1e6;
    }
  }

  record PrimalDualIPMSolver {
    var maxIter: int;
    var tol: real;
    var barrierMu: real;

    proc init(maxI: int = 40, tolerance: real = 1e-5, mu: real = 10.0) {
      this.maxIter = maxI;
      this.tol = tolerance;
      this.barrierMu = mu;
    }

    // Solves quadratic program with gradient descent and logarithmic barrier
    proc ref solve(qp: QuadraticProgram, ref x: [] real): (bool, real) {
      const n = qp.n;
      var curX: [0..<n] real;
      for i in 0..<n do curX[i] = 0.5 * (qp.xLower[i] + qp.xUpper[i]);

      var stepSize: real = 0.01;
      var itCount: int = 0;

      while itCount < maxIter do {
        itCount += 1;

        // Gradient and diagonal Hessian of objective + log barrier
        var grad: [0..<n] real;
        var hessDiag: [0..<n] real;

        for i in 0..<n {
          var qx: real = 0.0;
          for j in 0..<n do qx += qp.Q[i, j] * curX[j];
          grad[i] = qx + qp.c[i];
          hessDiag[i] = qp.Q[i, i];

          // Log barrier gradient and curvature
          const dLow = curX[i] - qp.xLower[i];
          const dHigh = qp.xUpper[i] - curX[i];
          if dLow > 1e-5 {
            grad[i] -= (barrierMu / dLow);
            hessDiag[i] += (barrierMu / (dLow * dLow));
          }
          if dHigh > 1e-5 {
            grad[i] += (barrierMu / dHigh);
            hessDiag[i] += (barrierMu / (dHigh * dHigh));
          }
        }

        var maxStep: real = 0.0;
        for i in 0..<n {
          const h = if hessDiag[i] > 1e-6 then hessDiag[i] else 1.0;
          const deltaX = -grad[i] / h;
          curX[i] += 0.8 * deltaX;

          // Project into interior
          if curX[i] < qp.xLower[i] + 1e-5 then curX[i] = qp.xLower[i] + 1e-5;
          if curX[i] > qp.xUpper[i] - 1e-5 then curX[i] = qp.xUpper[i] - 1e-5;

          const a = abs(deltaX);
          if a > maxStep then maxStep = a;
        }

        barrierMu *= 0.65; // Anneal barrier parameter

        if maxStep < tol && barrierMu < 1e-4 {
          break;
        }
      }

      for i in 0..<n do x[i] = curX[i];

      // Compute objective value: 0.5 * x^T * Q * x + c^T * x
      var obj: real = 0.0;
      for i in 0..<n {
        var qx: real = 0.0;
        for j in 0..<n do qx += qp.Q[i, j] * x[j];
        obj += 0.5 * x[i] * qx + qp.c[i] * x[i];
      }

      return (true, obj);
    }
  }
}
