/*
 * WLSEstimator.chpl
 * Weighted Least Squares (WLS) AC power grid state estimator.
 */

module WLSEstimator {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use SparseCholesky;
  use SparseLU;
  use Bus;
  use Branch;
  use Network;
  use YBus;
  use Measurement;
  use MeasurementJacobian;

  record EstimationResult {
    var converged: bool;
    var iterations: int;
    var objectiveJ: real;
    var maxDeltaX: real;
    var elapsedMs: real;

    var numBuses: int;
    var numMeasurements: int;

    var vDomain: domain(1);
    var vMagEstimated: [vDomain] real;
    var vAngleEstimated: [vDomain] real;

    var resDomain: domain(1);
    var residuals: [resDomain] real;
    var normalizedResiduals: [resDomain] real;

    proc init(nb: int, nm: int) {
      this.converged = false;
      this.iterations = 0;
      this.objectiveJ = 0.0;
      this.maxDeltaX = 0.0;
      this.elapsedMs = 0.0;
      this.numBuses = nb;
      this.numMeasurements = nm;
      this.vDomain = 0..<nb;
      this.vMagEstimated = 1.0;
      this.vAngleEstimated = 0.0;
      this.resDomain = 0..<nm;
      this.residuals = 0.0;
      this.normalizedResiduals = 0.0;
    }
  }

  record WLSSolver {
    var maxIterations: int;
    var tolerance: real;

    proc init(maxIter: int = SE_MAX_ITERATIONS, tol: real = SE_TOLERANCE) {
      this.maxIterations = maxIter;
      this.tolerance = tol;
    }

    // Solves non-linear AC state estimation via Gauss-Newton Normal Equations
    proc estimate(net: PowerNetwork,
                  measurements: [] GridMeasurement): (EstimationResult, GridError) {
      var timer: stopwatch;
      timer.start();

      const nb = net.numBuses;
      const nm = measurements.size;
      const stateDim = 2 * nb - 1;

      var result = new EstimationResult(nb, nm);
      var yBuilder = new YBusBuilder(nb);
      var (ybus, gbus, bbus) = yBuilder.buildYBus(net);

      // Initialize state: flat start (V = 1.0, theta = 0.0)
      for i in 0..<nb {
        result.vMagEstimated[i] = 1.0;
        result.vAngleEstimated[i] = 0.0;
      }

      var jacEngine = new JacobianEngine(nb, nm);
      var itCount: int = 0;
      var converged: bool = false;

      while itCount < maxIterations && !converged do {
        itCount += 1;

        // 1. Evaluate measurement function h(x)
        var hx: [0..<nm] real;
        jacEngine.evaluateH(net, ybus, result.vMagEstimated, result.vAngleEstimated, measurements, hx);

        // 2. Compute residual vector: Delta z = z - h(x) and objective J(x)
        var deltaZ: [0..<nm] real;
        var J: real = 0.0;

        for m in 0..<nm {
          if !measurements[m].isSuspect {
            const r = measurements[m].z - hx[m];
            deltaZ[m] = r;
            result.residuals[m] = r;
            J += r * r * measurements[m].weight;
          } else {
            deltaZ[m] = 0.0;
            result.residuals[m] = 0.0;
          }
        }
        result.objectiveJ = J;

        // 3. Assemble Jacobian H (nm x stateDim)
        var H = jacEngine.buildJacobian(net, ybus, result.vMagEstimated, result.vAngleEstimated, measurements);

        // 4. Form Normal Equations Gain Matrix: G = H^T * W * H and Right Hand Side: g = H^T * W * Delta z
        var G: [0..<stateDim, 0..<stateDim] real = 0.0;
        var rhs: [0..<stateDim] real = 0.0;

        for i in 0..<stateDim {
          var sumRHS: real = 0.0;
          for m in 0..<nm {
            if !measurements[m].isSuspect {
              sumRHS += H[m, i] * measurements[m].weight * deltaZ[m];
            }
          }
          rhs[i] = sumRHS;

          for j in 0..<stateDim {
            var sumG: real = 0.0;
            for m in 0..<nm {
              if !measurements[m].isSuspect {
                sumG += H[m, i] * measurements[m].weight * H[m, j];
              }
            }
            G[i, j] = sumG;
          }
        }

        // 5. Solve G * Delta x = rhs using LU factorization with partial pivoting
        var factorizer = new DenseFactorizer(stateDim);
        factorizer.A = G;
        for i in 0..<stateDim do factorizer.perm[i] = i;
        var errFact = factorizer.factorize();

        if !errFact.isOk() {
          timer.stop();
          result.elapsedMs = timer.elapsed() * 1000.0;
          return (result, errFact);
        }

        var deltaX: [0..<stateDim] real;
        factorizer.solve(rhs, deltaX);

        // 6. Check maximum update magnitude
        var maxUpd: real = 0.0;
        for i in 0..<stateDim {
          const a = abs(deltaX[i]);
          if a > maxUpd then maxUpd = a;
        }
        result.maxDeltaX = maxUpd;

        // 7. Update state estimates
        // Update angles theta_2 .. theta_nb (state indices 0 .. nb-2)
        for col in 0..<nb-1 {
          result.vAngleEstimated[col + 1] += deltaX[col];
        }

        // Update voltage magnitudes V_1 .. V_nb (state indices nb-1 .. 2*nb - 2)
        for col in 0..<nb {
          result.vMagEstimated[col] += deltaX[(nb - 1) + col];
        }

        if maxUpd < tolerance {
          converged = true;
          break;
        }
      }

      timer.stop();
      result.converged = converged;
      result.iterations = itCount;
      result.elapsedMs = timer.elapsed() * 1000.0;

      if !converged {
        return (result, new GridError(
          PhasorStatus.ConvergenceFailure,
          "WLS State Estimator did not converge within " + maxIterations:string + " iterations",
          "WLSEstimator",
          0,
          true
        ));
      }

      return (result, new GridError(PhasorStatus.Success, "State estimation converged", "WLSEstimator"));
    }
  }
}
