/*
 * EconomicDispatch.chpl
 * Optimal economic generation dispatch minimizing total fuel cost via lambda-iteration.
 */

module EconomicDispatch {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Generator;
  use Network;

  record DispatchResult {
    var converged: bool;
    var iterations: int;
    var lambda: real;             // System marginal clearing price ($/MWh)
    var totalCostPerHour: real;   // Total system production cost ($/h)
    var totalGenMW: real;         // Total active power generated
    var powerMismatchMW: real;    // Residual power balance mismatch
    var elapsedMs: real;

    var gDomain: domain(1);
    var pDispatchedMW: [gDomain] real;

    proc init(numG: int) {
      this.converged = false;
      this.iterations = 0;
      this.lambda = 0.0;
      this.totalCostPerHour = 0.0;
      this.totalGenMW = 0.0;
      this.powerMismatchMW = 0.0;
      this.elapsedMs = 0.0;
      this.gDomain = 0..<numG;
      this.pDispatchedMW = 0.0;
    }
  }

  record EconomicDispatcher {
    var maxIterations: int;
    var toleranceMW: real;

    proc init(maxIter: int = 50, tolMW: real = 0.01) {
      this.maxIterations = maxIter;
      this.toleranceMW = tolMW;
    }

    // Solves equal incremental cost lambda-iteration economic dispatch
    // dC_i / dP_i = 2 * a_i * P_i + b_i = lambda  =>  P_i = (lambda - b_i) / (2 * a_i)
    proc dispatch(net: PowerNetwork, targetDemandMW: real): (DispatchResult, GridError) {
      var timer: stopwatch;
      timer.start();

      const numG = net.numGenerators;
      var result = new DispatchResult(numG);

      // Bounds for lambda bracket search
      var lambdaMin: real = 1e9;
      var lambdaMax: real = -1e9;

      for g in 0..<numG {
        const gen = net.generators[g];
        if gen.status == 1 {
          const lMin = gen.marginalCost(gen.pMin);
          const lMax = gen.marginalCost(gen.pMax);
          if lMin < lambdaMin then lambdaMin = lMin;
          if lMax > lambdaMax then lambdaMax = lMax;
        }
      }

      lambdaMin -= 5.0;
      lambdaMax += 5.0;

      var itCount: int = 0;
      var converged: bool = false;
      var midLambda: real = 0.5 * (lambdaMin + lambdaMax);

      while itCount < maxIterations && !converged do {
        itCount += 1;
        midLambda = 0.5 * (lambdaMin + lambdaMax);

        var sumP: real = 0.0;
        for g in 0..<numG {
          const gen = net.generators[g];
          if gen.status == 1 {
            // Unconstrained optimal point: P = (lambda - b) / (2 * a)
            var pOpt = (midLambda - gen.costB) / (2.0 * gen.costA);
            // Clamp to capability limits
            pOpt = gen.clampP(pOpt);
            result.pDispatchedMW[g] = pOpt;
            sumP += pOpt;
          } else {
            result.pDispatchedMW[g] = 0.0;
          }
        }

        const mismatch = sumP - targetDemandMW;
        result.totalGenMW = sumP;
        result.powerMismatchMW = mismatch;

        if abs(mismatch) < toleranceMW {
          converged = true;
          break;
        }

        if mismatch > 0.0 {
          lambdaMax = midLambda; // Too much generation: lower price
        } else {
          lambdaMin = midLambda; // Insufficient generation: raise price
        }
      }

      // Compute total production cost
      var totalCost: real = 0.0;
      for g in 0..<numG {
        if net.generators[g].status == 1 {
          totalCost += net.generators[g].fuelCost(result.pDispatchedMW[g]);
        }
      }

      timer.stop();
      result.converged = converged;
      result.iterations = itCount;
      result.lambda = midLambda;
      result.totalCostPerHour = totalCost;
      result.elapsedMs = timer.elapsed() * 1000.0;

      return (result, new GridError(PhasorStatus.Success, "Economic dispatch solved", "EconomicDispatcher"));
    }
  }
}
