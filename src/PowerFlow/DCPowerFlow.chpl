/*
 * DCPowerFlow.chpl
 * Linearized DC power flow for high-throughput dispatch and screening.
 */

module DCPowerFlow {
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
  use PowerFlowResult;

  record DCPowerFlowSolver {
    var slackIndex: int;

    proc init(slackIdx: int = 0) {
      this.slackIndex = slackIdx;
    }

    // Solves linear DC power flow: P_inj = B_bus * theta
    proc solve(net: PowerNetwork): (SolutionMetrics, GridError) {
      var timer: stopwatch;
      timer.start();

      const nb = net.numBuses;
      const nbr = net.numBranches;
      var result = new SolutionMetrics(nb, nbr);

      const nRed = nb - 1;
      var denseB: [0..<nRed, 0..<nRed] real = 0.0;

      // Reduced bus index map omitting slack
      var redMap: [0..<nb] int;
      var curIdx: int = 0;
      for i in 0..<nb {
        if i == slackIndex {
          redMap[i] = -1;
        } else {
          redMap[i] = curIdx;
          curIdx += 1;
        }
      }

      for br in net.branches {
        if br.status == 1 {
          const k = net.getBusIndex(br.fromBus);
          const m = net.getBusIndex(br.toBus);
          const bSeries = 1.0 / br.x;

          const rk = redMap[k];
          const rm = redMap[m];

          if rk >= 0 && rm >= 0 {
            denseB[rk, rk] += bSeries;
            denseB[rm, rm] += bSeries;
            denseB[rk, rm] -= bSeries;
            denseB[rm, rk] -= bSeries;
          } else if rk >= 0 {
            denseB[rk, rk] += bSeries;
          } else if rm >= 0 {
            denseB[rm, rm] += bSeries;
          }
        }
      }

      // Reduced active power injection vector
      var pInjRed: [0..<nRed] real = 0.0;
      curIdx = 0;
      for i in 0..<nb {
        if i != slackIndex {
          pInjRed[curIdx] = net.buses[i].netP_pu(net.baseMVA);
          curIdx += 1;
        }
      }

      var lu = new DenseFactorizer(nRed);
      lu.A = denseB;
      for i in 0..<nRed do lu.perm[i] = i;
      var errLU = lu.factorize();

      if !errLU.isOk() {
        timer.stop();
        result.elapsedMs = timer.elapsed() * 1000.0;
        return (result, errLU);
      }

      var thetaRed: [0..<nRed] real;
      lu.solve(pInjRed, thetaRed);

      // Reconstruct full voltage states (V = 1.0 pu everywhere in DC approximation)
      curIdx = 0;
      for i in 0..<nb {
        result.vMag[i] = 1.0;
        if i == slackIndex {
          result.vAngleRad[i] = 0.0;
        } else {
          result.vAngleRad[i] = thetaRed[curIdx];
          curIdx += 1;
        }
      }

      // Calculate DC branch flows: P_km = (theta_k - theta_m) / x_km * BaseMVA
      for i in 0..<nbr {
        const br = net.branches[i];
        if br.status == 1 {
          const k = net.getBusIndex(br.fromBus);
          const m = net.getBusIndex(br.toBus);
          const flow = (result.vAngleRad[k] - result.vAngleRad[m]) / br.x * net.baseMVA;
          result.pFrom[i] = flow;
          result.pTo[i] = -flow;
          result.mvaLoading[i] = abs(flow);
          result.percentLoad[i] = (abs(flow) / br.rateA) * 100.0;
        }
      }

      timer.stop();
      result.converged = true;
      result.iterations = 1;
      result.elapsedMs = timer.elapsed() * 1000.0;

      return (result, new GridError(PhasorStatus.Success, "DC power flow solved", "DCPowerFlow"));
    }
  }
}
