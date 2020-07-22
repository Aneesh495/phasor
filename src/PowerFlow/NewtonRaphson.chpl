/*
 * NewtonRaphson.chpl
 * Full non-linear AC Newton-Raphson power flow solver with PV-PQ bus switching.
 */

module NewtonRaphson {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use SparseLU;
  use Bus;
  use Branch;
  use Generator;
  use Network;
  use YBus;
  use PowerFlowResult;

  record NewtonRaphsonSolver {
    var maxIterations: int;
    var tolerance: real;
    var enforceQLimits: bool;

    proc init(maxIter: int = PF_MAX_ITERATIONS, tol: real = PF_TOLERANCE, qLim: bool = true) {
      this.maxIterations = maxIter;
      this.tolerance = tol;
      this.enforceQLimits = qLim;
    }

    // Executes full AC Newton-Raphson power flow on the power network
    proc solve(net: PowerNetwork): (SolutionMetrics, GridError) {
      var timer: stopwatch;
      timer.start();

      const nb = net.numBuses;
      const nbr = net.numBranches;
      var result = new SolutionMetrics(nb, nbr);

      // Build nodal admittance matrix
      var yBuilder = new YBusBuilder(nb);
      var (ybus, gbus, bbus) = yBuilder.buildYBus(net);

      // Initialize voltage state vector from bus records (flat start or warm start)
      for i in 0..<nb {
        result.vMag[i] = net.buses[i].vMag;
        result.vAngleRad[i] = net.buses[i].vAngle;
      }

      // Track bus types (allowing dynamic PV to PQ conversion)
      var currentBusTypes: [0..<nb] BusType;
      for i in 0..<nb do currentBusTypes[i] = net.buses[i].busType;

      var it: int = 0;
      var converged: bool = false;

      while it < maxIterations && !converged do {
        it += 1;

        // 1. Calculate active and reactive power injections: P_i(V, theta) and Q_i(V, theta)
        var pCalc: [0..<nb] real = 0.0;
        var qCalc: [0..<nb] real = 0.0;

        for i in 0..<nb {
          const vi = result.vMag[i];
          const theta_i = result.vAngleRad[i];
          var pi_sum: real = 0.0;
          var qi_sum: real = 0.0;

          const startIdx = ybus.rowPtr[i];
          const endIdx = ybus.rowPtr[i + 1];

          for k in startIdx..<endIdx {
            const j = ybus.colInd[k];
            const vj = result.vMag[j];
            const theta_j = result.vAngleRad[j];
            const theta_ij = theta_i - theta_j;

            const G = ybus.values[k].re;
            const B = ybus.values[k].im;

            pi_sum += vj * (G * cos(theta_ij) + B * sin(theta_ij));
            qi_sum += vj * (G * sin(theta_ij) - B * cos(theta_ij));
          }

          pCalc[i] = vi * pi_sum;
          qCalc[i] = vi * qi_sum;
        }

        // 2. Check generator reactive power capability limits (PV -> PQ switching)
        if enforceQLimits {
          for gen in net.generators {
            if gen.status == 1 {
              const bIdx = net.getBusIndex(gen.busId);
              if bIdx >= 0 && currentBusTypes[bIdx] == BusType.PV {
                const qNetActual = qCalc[bIdx] * net.baseMVA + net.buses[bIdx].qLoad;
                if qNetActual > gen.qMax {
                  currentBusTypes[bIdx] = BusType.PQ;
                  net.buses[bIdx].qGen = gen.qMax;
                } else if qNetActual < gen.qMin {
                  currentBusTypes[bIdx] = BusType.PQ;
                  net.buses[bIdx].qGen = gen.qMin;
                }
              }
            }
          }
        }

        // 3. Map state indices:
        // Angles solved for all non-slack buses (busType != Slack)
        // Voltage magnitudes solved only for load buses (busType == PQ)
        var angleMap: [0..<nb] int;
        var voltMap: [0..<nb] int;
        var numAngles: int = 0;
        var numVolts: int = 0;

        for i in 0..<nb {
          if currentBusTypes[i] != BusType.Slack {
            angleMap[i] = numAngles;
            numAngles += 1;
          } else {
            angleMap[i] = -1;
          }

          if currentBusTypes[i] == BusType.PQ {
            voltMap[i] = numVolts;
            numVolts += 1;
          } else {
            voltMap[i] = -1;
          }
        }

        const jacDim = numAngles + numVolts;

        // 4. Compute power mismatches: Delta P and Delta Q
        var mismatch: [0..<jacDim] real = 0.0;
        var maxMisP: real = 0.0;
        var maxMisQ: real = 0.0;

        for i in 0..<nb {
          const pSpec = net.buses[i].netP_pu(net.baseMVA);
          const qSpec = net.buses[i].netQ_pu(net.baseMVA);

          if angleMap[i] >= 0 {
            const dP = pSpec - pCalc[i];
            mismatch[angleMap[i]] = dP;
            if abs(dP) > maxMisP then maxMisP = abs(dP);
          }

          if voltMap[i] >= 0 {
            const dQ = qSpec - qCalc[i];
            mismatch[numAngles + voltMap[i]] = dQ;
            if abs(dQ) > maxMisQ then maxMisQ = abs(dQ);
          }
        }

        result.maxMismatchP = maxMisP * net.baseMVA;
        result.maxMismatchQ = maxMisQ * net.baseMVA;

        // Convergence check: maximum mismatch below specified tolerance
        if maxMisP < tolerance && maxMisQ < tolerance {
          converged = true;
          break;
        }

        // 5. Assemble full 2N x 2N Jacobian matrix
        var denseJ: [0..<jacDim, 0..<jacDim] real = 0.0;

        for i in 0..<nb {
          const vi = result.vMag[i];
          const theta_i = result.vAngleRad[i];
          const aRow = angleMap[i];
          const vRow = if voltMap[i] >= 0 then numAngles + voltMap[i] else -1;

          const startIdx = ybus.rowPtr[i];
          const endIdx = ybus.rowPtr[i + 1];

          for k in startIdx..<endIdx {
            const j = ybus.colInd[k];
            const vj = result.vMag[j];
            const theta_j = result.vAngleRad[j];
            const theta_ij = theta_i - theta_j;

            const G = ybus.values[k].re;
            const B = ybus.values[k].im;

            const aCol = angleMap[j];
            const vCol = if voltMap[j] >= 0 then numAngles + voltMap[j] else -1;

            if i != j {
              // Off-diagonal Jacobian sub-blocks
              const dP_dTheta = vi * vj * (G * sin(theta_ij) - B * cos(theta_ij));
              const dP_dV     = vi * (G * cos(theta_ij) + B * sin(theta_ij));
              const dQ_dTheta = -vi * vj * (G * cos(theta_ij) + B * sin(theta_ij));
              const dQ_dV     = vi * (G * sin(theta_ij) - B * cos(theta_ij));

              if aRow >= 0 && aCol >= 0 then denseJ[aRow, aCol] = dP_dTheta;
              if aRow >= 0 && vCol >= 0 then denseJ[aRow, vCol] = dP_dV;
              if vRow >= 0 && aCol >= 0 then denseJ[vRow, aCol] = dQ_dTheta;
              if vRow >= 0 && vCol >= 0 then denseJ[vRow, vCol] = dQ_dV;
            } else {
              // Diagonal Jacobian sub-blocks
              const Bii = B;
              const Gii = G;

              const dP_dTheta = -qCalc[i] - Bii * vi * vi;
              const dP_dV     = (pCalc[i] / vi) + Gii * vi;
              const dQ_dTheta = pCalc[i] - Gii * vi * vi;
              const dQ_dV     = (qCalc[i] / vi) - Bii * vi;

              if aRow >= 0 then denseJ[aRow, aRow] = dP_dTheta;
              if aRow >= 0 && vRow >= 0 then denseJ[aRow, vRow] = dP_dV;
              if vRow >= 0 && aRow >= 0 then denseJ[vRow, aRow] = dQ_dTheta;
              if vRow >= 0 then denseJ[vRow, vRow] = dQ_dV;
            }
          }
        }

        // 6. Convert Jacobian to SparseCSR and solve J * Delta x = Mismatch
        var rPtrJ: [0..jacDim] int;
        rPtrJ[0] = 0;
        for r in 0..<jacDim {
          var count: int = 0;
          for c in 0..<jacDim {
            if abs(denseJ[r, c]) > 1.0e-12 then count += 1;
          }
          rPtrJ[r + 1] = rPtrJ[r] + count;
        }
        const nnzJ = rPtrJ[jacDim];

        var cIndJ: [0..<nnzJ] int;
        var valsJ: [0..<nnzJ] real;
        var offset: int = 0;

        for r in 0..<jacDim {
          for c in 0..<jacDim {
            if abs(denseJ[r, c]) > 1.0e-12 {
              cIndJ[offset] = c;
              valsJ[offset] = denseJ[r, c];
              offset += 1;
            }
          }
        }

        var jacCSR = new SparseCSRMatrix(jacDim, jacDim, rPtrJ, cIndJ, valsJ);
        var factorizer = new DenseFactorizer(jacDim);
        factorizer.loadFromCSR(jacCSR);
        var errFact = factorizer.factorize();

        if !errFact.isOk() {
          timer.stop();
          result.elapsedMs = timer.elapsed() * 1000.0;
          return (result, errFact);
        }

        var deltaX: [0..<jacDim] real;
        factorizer.solve(mismatch, deltaX);

        // 7. Update state vector: theta += Delta theta, V += Delta V
        for i in 0..<nb {
          if angleMap[i] >= 0 {
            result.vAngleRad[i] += deltaX[angleMap[i]];
          }
          if voltMap[i] >= 0 {
            result.vMag[i] += deltaX[numAngles + voltMap[i]];
          }
        }
      }

      timer.stop();
      result.converged = converged;
      result.iterations = it;
      result.elapsedMs = timer.elapsed() * 1000.0;

      // Compute branch flows and losses
      result.computeBranchFlows(net);

      if !converged {
        return (result, new GridError(
          PhasorStatus.ConvergenceFailure,
          "Newton-Raphson power flow failed to converge within " + maxIterations:string + " iterations",
          "NewtonRaphson",
          0,
          true
        ));
      }

      return (result, new GridError(PhasorStatus.Success, "Newton-Raphson converged", "NewtonRaphson"));
    }
  }
}
