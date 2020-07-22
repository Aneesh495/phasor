/*
 * FastDecoupled.chpl
 * Stott-Alsac Fast Decoupled Load Flow (FDLF) for sub-millisecond AC power flow.
 */

module FastDecoupled {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use SparseLU;
  use Bus;
  use Branch;
  use Network;
  use YBus;
  use PowerFlowResult;

  record FastDecoupledSolver {
    var maxIterations: int;
    var tolerance: real;

    proc init(maxIter: int = PF_MAX_ITERATIONS, tol: real = PF_TOLERANCE) {
      this.maxIterations = maxIter;
      this.tolerance = tol;
    }

    // Solves decoupled AC power flow:
    // Delta P / V = B' * Delta theta
    // Delta Q / V = B'' * Delta V
    proc solve(net: PowerNetwork): (SolutionMetrics, GridError) {
      var timer: stopwatch;
      timer.start();

      const nb = net.numBuses;
      const nbr = net.numBranches;
      var result = new SolutionMetrics(nb, nbr);

      // Build nodal admittance matrix
      var yBuilder = new YBusBuilder(nb);
      var (ybus, gbus, bbus) = yBuilder.buildYBus(net);

      // Initialize voltages
      for i in 0..<nb {
        result.vMag[i] = net.buses[i].vMag;
        result.vAngleRad[i] = net.buses[i].vAngle;
      }

      // Map non-slack buses for B' and PQ buses for B''
      var angleMap: [0..<nb] int;
      var voltMap: [0..<nb] int;
      var numAngles: int = 0;
      var numVolts: int = 0;

      for i in 0..<nb {
        if net.buses[i].busType != BusType.Slack {
          angleMap[i] = numAngles;
          numAngles += 1;
        } else {
          angleMap[i] = -1;
        }

        if net.buses[i].busType == BusType.PQ {
          voltMap[i] = numVolts;
          numVolts += 1;
        } else {
          voltMap[i] = -1;
        }
      }

      // Assemble constant B' matrix: dimension numAngles x numAngles
      var denseBPrime: [0..<numAngles, 0..<numAngles] real = 0.0;
      for br in net.branches {
        if br.status == 1 {
          const k = net.getBusIndex(br.fromBus);
          const m = net.getBusIndex(br.toBus);
          const bSeries = 1.0 / br.x; // In FDLF, B' uses inverted series reactance

          const rk = angleMap[k];
          const rm = angleMap[m];

          if rk >= 0 && rm >= 0 {
            denseBPrime[rk, rk] += bSeries;
            denseBPrime[rm, rm] += bSeries;
            denseBPrime[rk, rm] -= bSeries;
            denseBPrime[rm, rk] -= bSeries;
          } else if rk >= 0 {
            denseBPrime[rk, rk] += bSeries;
          } else if rm >= 0 {
            denseBPrime[rm, rm] += bSeries;
          }
        }
      }

      // Assemble constant B'' matrix: dimension numVolts x numVolts
      var denseBDP: [0..<numVolts, 0..<numVolts] real = 0.0;
      for br in net.branches {
        if br.status == 1 {
          const k = net.getBusIndex(br.fromBus);
          const m = net.getBusIndex(br.toBus);
          const bSeries = 1.0 / br.x;

          const vk = voltMap[k];
          const vm = voltMap[m];

          if vk >= 0 && vm >= 0 {
            denseBDP[vk, vk] += bSeries;
            denseBDP[vm, vm] += bSeries;
            denseBDP[vk, vm] -= bSeries;
            denseBDP[vm, vk] -= bSeries;
          } else if vk >= 0 {
            denseBDP[vk, vk] += bSeries;
          } else if vm >= 0 {
            denseBDP[vm, vm] += bSeries;
          }
        }
      }

      // Add shunt susceptances to B''
      for b in net.buses {
        const k = net.getBusIndex(b.id);
        const vk = voltMap[k];
        if vk >= 0 {
          denseBDP[vk, vk] += (b.bShunt / net.baseMVA);
        }
      }

      // Pre-factorize B' and B'' using LU solvers
      var luBPrime = new DenseFactorizer(numAngles);
      luBPrime.A = denseBPrime;
      for i in 0..<numAngles do luBPrime.perm[i] = i;
      var errBPrime = luBPrime.factorize();
      if !errBPrime.isOk() {
        timer.stop();
        result.elapsedMs = timer.elapsed() * 1000.0;
        return (result, errBPrime);
      }

      var luBDP = new DenseFactorizer(numVolts);
      luBDP.A = denseBDP;
      for i in 0..<numVolts do luBDP.perm[i] = i;
      var errBDP = luBDP.factorize();
      if !errBDP.isOk() {
        timer.stop();
        result.elapsedMs = timer.elapsed() * 1000.0;
        return (result, errBDP);
      }

      // FDLF Iterations: alternating P-theta and Q-V solves
      var it: int = 0;
      var converged: bool = false;

      while it < maxIterations && !converged do {
        it += 1;

        // P-theta solve:
        var pCalc: [0..<nb] real = 0.0;
        for i in 0..<nb {
          const vi = result.vMag[i];
          const theta_i = result.vAngleRad[i];
          var pi_sum: real = 0.0;

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
          }
          pCalc[i] = vi * pi_sum;
        }

        var misP_over_V: [0..<numAngles] real = 0.0;
        var maxMisP: real = 0.0;
        for i in 0..<nb {
          if angleMap[i] >= 0 {
            const pSpec = net.buses[i].netP_pu(net.baseMVA);
            const dP = pSpec - pCalc[i];
            misP_over_V[angleMap[i]] = dP / result.vMag[i];
            if abs(dP) > maxMisP then maxMisP = abs(dP);
          }
        }

        var deltaTheta: [0..<numAngles] real;
        luBPrime.solve(misP_over_V, deltaTheta);

        for i in 0..<nb {
          if angleMap[i] >= 0 {
            result.vAngleRad[i] += deltaTheta[angleMap[i]];
          }
        }

        // Q-V solve:
        var qCalc: [0..<nb] real = 0.0;
        for i in 0..<nb {
          const vi = result.vMag[i];
          const theta_i = result.vAngleRad[i];
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
            qi_sum += vj * (G * sin(theta_ij) - B * cos(theta_ij));
          }
          qCalc[i] = vi * qi_sum;
        }

        var misQ_over_V: [0..<numVolts] real = 0.0;
        var maxMisQ: real = 0.0;
        for i in 0..<nb {
          if voltMap[i] >= 0 {
            const qSpec = net.buses[i].netQ_pu(net.baseMVA);
            const dQ = qSpec - qCalc[i];
            misQ_over_V[voltMap[i]] = dQ / result.vMag[i];
            if abs(dQ) > maxMisQ then maxMisQ = abs(dQ);
          }
        }

        var deltaV: [0..<numVolts] real;
        luBDP.solve(misQ_over_V, deltaV);

        for i in 0..<nb {
          if voltMap[i] >= 0 {
            result.vMag[i] += deltaV[voltMap[i]];
          }
        }

        result.maxMismatchP = maxMisP * net.baseMVA;
        result.maxMismatchQ = maxMisQ * net.baseMVA;

        if maxMisP < tolerance && maxMisQ < tolerance {
          converged = true;
          break;
        }
      }

      timer.stop();
      result.converged = converged;
      result.iterations = it;
      result.elapsedMs = timer.elapsed() * 1000.0;

      result.computeBranchFlows(net);

      if !converged {
        return (result, new GridError(
          PhasorStatus.ConvergenceFailure,
          "Fast Decoupled power flow failed to converge within " + maxIterations:string + " iterations",
          "FastDecoupled",
          0,
          true
        ));
      }

      return (result, new GridError(PhasorStatus.Success, "Fast Decoupled converged", "FastDecoupled"));
    }
  }
}
