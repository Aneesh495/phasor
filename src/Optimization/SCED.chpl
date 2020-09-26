/*
 * SCED.chpl
 * Security-Constrained Economic Dispatch (SCED) incorporating transmission line thermal limits.
 */

module SCED {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Generator;
  use Branch;
  use Network;
  use Sensitivities;
  use EconomicDispatch;

  record SCEDResult {
    var converged: bool;
    var iterations: int;
    var totalCostPerHour: real;
    var redispatchCostMW: real;
    var activeConstraintsCount: int;
    var elapsedMs: real;

    var gDomain: domain(1);
    var pDispatchedMW: [gDomain] real;

    proc init(numG: int) {
      this.converged = false;
      this.iterations = 0;
      this.totalCostPerHour = 0.0;
      this.redispatchCostMW = 0.0;
      this.activeConstraintsCount = 0;
      this.elapsedMs = 0.0;
      this.gDomain = 0..<numG;
      this.pDispatchedMW = 0.0;
    }
  }

  record SCEDSolver {
    var maxIter: int;
    var toleranceMW: real;

    proc init(maxI: int = 30, tol: real = 0.10) {
      this.maxIter = maxI;
      this.toleranceMW = tol;
    }

    // Solves SCED by first solving unconstrained economic dispatch,
    // then iteratively redispatching generators along PTDF sensitivities to relieve line overloads
    proc solve(net: PowerNetwork, targetDemandMW: real): (SCEDResult, GridError) {
      var timer: stopwatch;
      timer.start();

      const numG = net.numGenerators;
      const nbr = net.numBranches;
      var result = new SCEDResult(numG);

      // Step 1: Solve base economic dispatch
      var ed = new EconomicDispatcher(maxIter=50, tolMW=0.01);
      var (baseRes, baseErr) = ed.dispatch(net, targetDemandMW);
      if !baseErr.isOk() {
        timer.stop();
        result.elapsedMs = timer.elapsed() * 1000.0;
        return (result, baseErr);
      }

      for g in 0..<numG do result.pDispatchedMW[g] = baseRes.pDispatchedMW[g];

      // Step 2: Compute PTDF sensitivity engine
      var sensEngine = new SensitivityEngine(net.numBuses, nbr, slackIdx=0);
      var (bPrime, luB) = sensEngine.buildBPrime(net);

      // Step 3: Check line loading and relieve active overloads
      var itCount: int = 0;
      var hasOverload: bool = true;

      while itCount < maxIter && hasOverload do {
        itCount += 1;
        hasOverload = false;

        for k in 0..<nbr {
          const br = net.branches[k];
          if br.status == 1 {
            // Compute line flow from dispatched generation:
            // Flow_k = sum_g ( PTDF_{k, g -> slack} * P_g )
            var flowMW: real = 0.0;
            for g in 0..<numG {
              const bIdx = net.getBusIndex(net.generators[g].busId);
              const ptdf = sensEngine.computePTDF(net, luB, k, bIdx, 0);
              flowMW += ptdf * result.pDispatchedMW[g];
            }

            const overloadMW = abs(flowMW) - br.rateA;
            if overloadMW > 0.50 {
              hasOverload = true;
              result.activeConstraintsCount += 1;

              // Redispatch generation: shift power from high-PTDF to low-PTDF generator
              var bestGenToCut: int = -1;
              var bestGenToBoost: int = -1;
              var maxPTDF: real = -1e9;
              var minPTDF: real = 1e9;

              for g in 0..<numG {
                const bIdx = net.getBusIndex(net.generators[g].busId);
                const ptdf = sensEngine.computePTDF(net, luB, k, bIdx, 0);

                if ptdf > maxPTDF && result.pDispatchedMW[g] > net.generators[g].pMin + 1.0 {
                  maxPTDF = ptdf;
                  bestGenToCut = g;
                }
                if ptdf < minPTDF && result.pDispatchedMW[g] < net.generators[g].pMax - 1.0 {
                  minPTDF = ptdf;
                  bestGenToBoost = g;
                }
              }

              if bestGenToCut >= 0 && bestGenToBoost >= 0 && (maxPTDF - minPTDF) > 0.05 {
                const deltaP = min(overloadMW / (maxPTDF - minPTDF), 10.0);
                result.pDispatchedMW[bestGenToCut] -= deltaP;
                result.pDispatchedMW[bestGenToBoost] += deltaP;
                result.redispatchCostMW += deltaP;
              }
            }
          }
        }
      }

      // Compute final production cost
      var finalCost: real = 0.0;
      for g in 0..<numG {
        finalCost += net.generators[g].fuelCost(result.pDispatchedMW[g]);
      }

      timer.stop();
      result.converged = !hasOverload;
      result.iterations = itCount;
      result.totalCostPerHour = finalCost;
      result.elapsedMs = timer.elapsed() * 1000.0;

      return (result, new GridError(PhasorStatus.Success, "SCED solved", "SCEDSolver"));
    }
  }
}
