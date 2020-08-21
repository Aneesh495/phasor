/*
 * ContingencyScreening.chpl
 * Massively parallel distributed N-1 and N-2 contingency screening engine.
 */

module ContingencyScreening {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Bus;
  use Branch;
  use Generator;
  use Load;
  use Network;
  use YBus;
  use SparseCSR;
  use SparseLU;
  use ShermanMorrison;
  use PowerFlowResult;
  use DCPowerFlow;
  use NewtonRaphson;
  use OutageModel;
  use PerformanceIndex;

  record ContingencyReport {
    var totalContingencies: int;
    var criticalCount: int;
    var warningCount: int;
    var secureCount: int;
    var worstContingencyId: int;
    var worstContingencyName: string;
    var worstLoadingPct: real;
    var elapsedMs: real;

    var sevDomain: domain(1);
    var severities: [sevDomain] ContingencySeverity;

    proc init(numC: int) {
      this.totalContingencies = numC;
      this.criticalCount = 0;
      this.warningCount = 0;
      this.secureCount = 0;
      this.worstContingencyId = 0;
      this.worstContingencyName = "NONE";
      this.worstLoadingPct = 0.0;
      this.elapsedMs = 0.0;
      this.sevDomain = 0..<numC;
    }
  }

  record ParallelScreeningEngine {
    var fastScreening: bool; // Use DC / Sherman-Morrison for screening before full AC solve

    proc init(fast: bool = true) {
      this.fastScreening = fast;
    }

    // Screens list of contingencies in parallel across Chapel task domains
    proc screen(net: PowerNetwork,
                contingencies: [] ContingencyCase): (ContingencyReport, GridError) {
      var timer: stopwatch;
      timer.start();

      const numC = contingencies.size;
      const nb = net.numBuses;
      const nbr = net.numBranches;

      var report = new ContingencyReport(numC);

      // Pre-extract rating and voltage limit arrays
      var rateA: [0..<nbr] real;
      for k in 0..<nbr do rateA[k] = net.branches[k].rateA;

      var vMin: [0..<nb] real;
      var vMax: [0..<nb] real;
      for i in 0..<nb {
        vMin[i] = net.buses[i].vMin;
        vMax[i] = net.buses[i].vMax;
      }

      var peEvaluator = new PerformanceIndexEvaluator();

      // Parallel execution loop: Chapel distributes across all available cores / locales
      forall cIdx in 0..<numC with (ref report) {
        const cCase = contingencies[cIdx];

        // Clone base network state for this contingency scenario
        var cNet = new PowerNetwork(cCase.name, net.baseMVA, net.frequency);
        cNet.allocate(nb, nbr, net.numGenerators, net.numLoads, net.numShunts, net.maxBusId);

        for i in 0..<nb do cNet.buses[i] = net.buses[i];
        for k in 0..<nbr do cNet.branches[k] = net.branches[k];
        for g in 0..<net.numGenerators do cNet.generators[g] = net.generators[g];
        for l in 0..<net.numLoads do cNet.loads[l] = net.loads[l];
        for s in 0..<net.numShunts do cNet.shunts[s] = net.shunts[s];
        for m in cNet.mapDomain do cNet.busIdToIndex[m] = net.busIdToIndex[m];

        // Apply outage
        select cCase.cType {
          when ContingencyType.BranchOutage {
            if cCase.branchIdx1 >= 0 && cCase.branchIdx1 < nbr {
              cNet.branches[cCase.branchIdx1].status = 0; // Trip line
            }
          }
          when ContingencyType.DoubleCircuitOutage {
            if cCase.branchIdx1 >= 0 && cCase.branchIdx1 < nbr {
              cNet.branches[cCase.branchIdx1].status = 0;
            }
            if cCase.branchIdx2 >= 0 && cCase.branchIdx2 < nbr {
              cNet.branches[cCase.branchIdx2].status = 0;
            }
          }
          when ContingencyType.GeneratorOutage {
            if cCase.genIdx >= 0 && cCase.genIdx < net.numGenerators {
              cNet.generators[cCase.genIdx].status = 0; // Trip generator
              const bIdx = cNet.getBusIndex(cNet.generators[cCase.genIdx].busId);
              if bIdx >= 0 {
                cNet.buses[bIdx].pGen = 0.0;
                cNet.buses[bIdx].qGen = 0.0;
                if cNet.buses[bIdx].busType == BusType.PV {
                  cNet.buses[bIdx].busType = BusType.PQ;
                }
              }
            }
          }
          otherwise {}
        }

        // Solve post-contingency state
        var sol: SolutionMetrics;
        if fastScreening {
          var dc = new DCPowerFlowSolver();
          var (dcRes, dcErr) = dc.solve(cNet);
          sol = dcRes;
        } else {
          var nr = new NewtonRaphsonSolver(maxIter=10, tol=1.0e-5);
          var (nrRes, nrErr) = nr.solve(cNet);
          sol = nrRes;
        }

        // Evaluate severity indices
        var sev = peEvaluator.evaluate(cCase.id, cCase.name, sol, rateA, vMin, vMax);
        report.severities[cIdx] = sev;
      }

      // Aggregate summary statistics
      var maxLoad: real = 0.0;
      var worstId: int = 0;
      var worstName: string = "NONE";

      for cIdx in 0..<numC {
        const sev = report.severities[cIdx];
        select sev.tier {
          when SeverityTier.Critical do report.criticalCount += 1;
          when SeverityTier.Warning  do report.warningCount += 1;
          when SeverityTier.Secure   do report.secureCount += 1;
        }

        if sev.maxLineLoadingPct > maxLoad {
          maxLoad = sev.maxLineLoadingPct;
          worstId = sev.contingencyId;
          worstName = sev.name;
        }
      }

      timer.stop();
      report.worstLoadingPct = maxLoad;
      report.worstContingencyId = worstId;
      report.worstContingencyName = worstName;
      report.elapsedMs = timer.elapsed() * 1000.0;

      return (report, new GridError(PhasorStatus.Success, "Contingency screening complete", "ParallelScreeningEngine"));
    }
  }
}
