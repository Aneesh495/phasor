/*
 * Main.chpl
 * Master unified CLI entry point for the Phasor Energy Management System.
 */

module Main {
  use Math;
  use Time;
  use IO;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Bus;
  use Branch;
  use Generator;
  use Load;
  use Network;
  use RawParser;
  use NewtonRaphson;
  use FastDecoupled;
  use DCPowerFlow;
  use Measurement;
  use WLSEstimator;
  use BadDataDetector;
  use OutageModel;
  use PerformanceIndex;
  use VoltageCollapseIndex;
  use ContingencyScreening;
  use MachineModels;
  use TransientSimulator;
  use FrequencyDynamics;
  use EconomicDispatch;
  use SCED;
  use TerminalUI;
  use ResultExporter;

  proc printUsage() {
    writeln("Usage: phasor <command> [options]");
    writeln();
    writeln("Commands:");
    writeln("  solve <raw_file>       Solve AC/DC power flow (Newton-Raphson, Fast-Decoupled, DC)");
    writeln("  estimate <raw_file>    Run AC Weighted Least Squares state estimation and bad data processing");
    writeln("  contingency <raw_file> Execute massively parallel N-1 contingency security screening");
    writeln("  dynamic <raw_file>     Simulate multi-machine transient stability and frequency dynamics");
    writeln("  dispatch <raw_file>    Run economic dispatch or security-constrained economic dispatch (SCED)");
    writeln("  version                Display version and platform information");
    writeln("  help                   Show this help message");
    writeln();
    writeln("Options:");
    writeln("  --case=<path>          Network file path (optional alternative to positional file argument)");
    writeln("  --method=<nr|fdf|dc>   Power flow algorithm (default: nr)");
    writeln("  --export-json=<file>   Path to export solution in JSON format");
    writeln("  --demand=<MW>          Target active power demand for economic dispatch");
    writeln("  --security             Enable security-constrained branch thermal limits");
  }

  proc extractRawPath(args: [] string): string {
    var path = "";
    for i in 1..<args.size {
      if args[i].startsWith("--case=") {
        var parts = args[i].split("=");
        if parts.size > 1 then return parts[1];
      } else if !args[i].startsWith("--") && path.size == 0 {
        path = args[i];
      }
    }
    return path;
  }

  proc runSolve(args: [] string) {
    const rawPath = extractRawPath(args);
    if rawPath.size == 0 {
      writeln("Error: Missing RAW network file path.");
      writeln("Usage: phasor solve <raw_file> [--method=nr|fdf|dc] [--export-json=<file>]");
      return;
    }

    var method = "nr";
    var jsonPath = "";

    for i in 1..<args.size {
      if args[i].startsWith("--method=") {
        var parts = args[i].split("=");
        if parts.size > 1 then method = parts[1];
      } else if args[i].startsWith("--export-json=") {
        var parts = args[i].split("=");
        if parts.size > 1 then jsonPath = parts[1];
      }
    }

    var (netOpt, err) = parseRawFile(rawPath);
    if !err.isOk() || netOpt == nil {
      writeln("Error: Failed to load network from ", rawPath, ": ", err.message);
      return;
    }

    var net = netOpt!;
    writeln("Loaded network: ", net.name, " (", net.numBuses, " buses, ", net.numBranches, " branches)");

    if method == "dc" {
      var dc = new DCPowerFlowSolver(slackIdx=0);
      var (res, pfErr) = dc.solve(net);
      if !pfErr.isOk() {
        writeln("Error solving DC power flow: ", pfErr.message);
        return;
      }
      writeln("DC Power Flow solved in ", res.elapsedMs, " ms.");
      writeln("Total transmission losses: ", res.totalLossesP, " MW");
    } else if method == "fdf" {
      var fdf = new FastDecoupledSolver(maxIter=PF_MAX_ITERATIONS, tol=PF_TOLERANCE);
      var (res, pfErr) = fdf.solve(net);
      if !pfErr.isOk() {
        writeln("Error solving Fast Decoupled power flow: ", pfErr.message);
        return;
      }
      res.computeBranchFlows(net);
      printGridSummary(net, res);
      printVoltageDashboard(net);
      printBranchLoadingDashboard(net, res);
      if jsonPath.size > 0 then exportPowerFlowJSON(net, res, jsonPath);
    } else {
      var nr = new NewtonRaphsonSolver(maxIter=PF_MAX_ITERATIONS, tol=PF_TOLERANCE);
      var (res, pfErr) = nr.solve(net);
      if !pfErr.isOk() {
        writeln("Error solving Newton-Raphson power flow: ", pfErr.message);
        return;
      }
      res.computeBranchFlows(net);
      printGridSummary(net, res);
      printVoltageDashboard(net);
      printBranchLoadingDashboard(net, res);
      if jsonPath.size > 0 then exportPowerFlowJSON(net, res, jsonPath);
    }
  }

  proc runEstimate(args: [] string) {
    const rawPath = extractRawPath(args);
    if rawPath.size == 0 {
      writeln("Error: Missing RAW network file path.");
      writeln("Usage: phasor estimate <raw_file>");
      return;
    }

    var (netOpt, err) = parseRawFile(rawPath);
    if !err.isOk() || netOpt == nil {
      writeln("Error: Failed to load network from ", rawPath, ": ", err.message);
      return;
    }

    var net = netOpt!;
    writeln("Loaded network: ", net.name, " (", net.numBuses, " buses, ", net.numBranches, " branches)");

    // Solve base AC power flow to synthesize telemetry measurements
    var nr = new NewtonRaphsonSolver(maxIter=PF_MAX_ITERATIONS, tol=PF_TOLERANCE);
    var (nrRes, nrErr) = nr.solve(net);
    if !nrErr.isOk() {
      writeln("Error: Base power flow failed for measurement synthesis: ", nrErr.message);
      return;
    }

    // Synthesize SCADA and PMU measurements: voltage magnitude and angles
    const numMeas = net.numBuses * 2;
    var meas: [0..<numMeas] GridMeasurement;

    for b in 0..<net.numBuses {
      meas[b] = new GridMeasurement(b + 1, MeasurementType.BusVoltageMag, b, nrRes.vMag[b], 0.005);
      meas[net.numBuses + b] = new GridMeasurement(net.numBuses + b + 1, MeasurementType.BusVoltageAngle, b, nrRes.vAngleRad[b], 0.002, pmu=true);
    }

    writeln("Synthesized ", numMeas, " telemetry measurements (SCADA magnitudes + PMU angles).");
    writeln("Executing AC Weighted Least Squares (WLS) state estimator...");

    var wls = new WLSSolver(maxIter=25, tol=1.0e-5);
    var (seRes, seErr) = wls.estimate(net, meas);
    if !seErr.isOk() {
      writeln("Error in state estimation: ", seErr.message);
      return;
    }

    writeln("=================================================================");
    writeln(" AC STATE ESTIMATION CONVERGENCE REPORT");
    writeln("=================================================================");
    writeln(" Convergence Status:        ", if seRes.converged then "CONVERGED" else "FAILED");
    writeln(" Iterations:                ", seRes.iterations);
    writeln(" Objective Chi-Square:      ", seRes.objectiveJ);
    writeln(" Max State Delta:           ", seRes.maxDeltaX);
    writeln(" Execution Time:            ", seRes.elapsedMs, " ms");
    writeln("=================================================================");
  }

  proc runContingency(args: [] string) {
    const rawPath = extractRawPath(args);
    if rawPath.size == 0 {
      writeln("Error: Missing RAW network file path.");
      writeln("Usage: phasor contingency <raw_file>");
      return;
    }

    var (netOpt, err) = parseRawFile(rawPath);
    if !err.isOk() || netOpt == nil {
      writeln("Error: Failed to load network from ", rawPath, ": ", err.message);
      return;
    }

    var net = netOpt!;
    writeln("Running parallel N-1 contingency screening across ", net.numBranches, " lines...");

    var engine = new ParallelScreeningEngine(fast=true);
    var casesDomain: domain(1) = 0..<net.numBranches;
    var cases: [casesDomain] ContingencyCase;

    for k in 0..<net.numBranches {
      cases[k] = ContingencyCase.branchTrip(k + 1, k,
                                            "Line " + net.branches[k].fromBus:string + "->" + net.branches[k].toBus:string + " trip");
    }

    var (report, cErr) = engine.screen(net, cases);

    writeln("=================================================================");
    writeln(" CONTINGENCY SCREENING REPORT (Parallel Distributed Execution)");
    writeln("=================================================================");
    writeln(" Screened Contingencies:    ", report.totalContingencies);
    writeln(" Critical Contingencies:    ", report.criticalCount);
    writeln(" Warning Contingencies:     ", report.warningCount);
    writeln(" Secure Contingencies:      ", report.secureCount);
    writeln(" Worst Contingency:         ", report.worstContingencyName, " (ID ", report.worstContingencyId, ")");
    writeln(" Max Line Loading:          ", report.worstLoadingPct, "%");
    writeln(" Execution Time:            ", report.elapsedMs, " ms");
    writeln("=================================================================");
  }

  proc runDynamic(args: [] string) {
    const rawPath = extractRawPath(args);
    if rawPath.size == 0 {
      writeln("Error: Missing RAW network file path.");
      writeln("Usage: phasor dynamic <raw_file>");
      return;
    }

    var (netOpt, err) = parseRawFile(rawPath);
    if !err.isOk() || netOpt == nil {
      writeln("Error: Failed to load network from ", rawPath, ": ", err.message);
      return;
    }

    var net = netOpt!;
    writeln("Loaded network: ", net.name, " (", net.numBuses, " buses, ", net.numGenerators, " generators)");
    writeln("Executing multi-machine transient stability simulation (4th-order Runge-Kutta)...");

    var sim = new MultiMachineSimulator(stepSize=0.002, simDuration=1.5, tFlt=0.20, tClr=0.28);
    var (res, dErr) = sim.simulate(net);
    if !dErr.isOk() {
      writeln("Error during transient simulation: ", dErr.message);
      return;
    }

    writeln("=================================================================");
    writeln(" TRANSIENT STABILITY SIMULATION REPORT");
    writeln("=================================================================");
    writeln(" Stability Status:          ", if res.isStable then "TRANSIENTLY STABLE" else "UNSTABLE (POLE SLIP)");
    writeln(" Critical Clearing Bound:   ", if res.criticalClearingTimeExceeded then "EXCEEDED" else "PRESERVED");
    writeln(" Max Rotor Separation:      ", res.maxRotorSeparationDeg, " deg");
    writeln(" Worst Machine ID:          ", res.worstMachineId);
    writeln(" Timesteps Evaluated:       ", res.timeStepsTaken);
    writeln(" Execution Time:            ", res.elapsedMs, " ms");
    writeln("=================================================================");
  }

  proc runDispatch(args: [] string) {
    const rawPath = extractRawPath(args);
    if rawPath.size == 0 {
      writeln("Error: Missing RAW network file path.");
      writeln("Usage: phasor dispatch <raw_file> [--demand=MW] [--security]");
      return;
    }

    var (netOpt, err) = parseRawFile(rawPath);
    if !err.isOk() || netOpt == nil {
      writeln("Error: Failed to load network from ", rawPath, ": ", err.message);
      return;
    }

    var net = netOpt!;
    const (pGen, qGen, pLoad, qLoad) = net.summary();

    var targetDemand = pLoad;
    var useSecurity = false;

    for i in 1..<args.size {
      if args[i].startsWith("--demand=") {
        var parts = args[i].split("=");
        if parts.size > 1 then targetDemand = try! parts[1]: real;
      } else if args[i] == "--security" {
        useSecurity = true;
      }
    }

    if useSecurity {
      writeln("Solving Security-Constrained Economic Dispatch (SCED) for ", targetDemand, " MW target demand...");
      var sced = new SCEDSolver(maxI=30, tol=0.10);
      var (res, sErr) = sced.solve(net, targetDemand);
      if !sErr.isOk() {
        writeln("Error in SCED: ", sErr.message);
        return;
      }
      writeln("SCED Converged: ", res.converged, " (", res.iterations, " iterations, ", res.elapsedMs, " ms)");
      writeln("Total generation cost: $", res.totalCostPerHour, "/h");
      writeln("Redispatched power: ", res.redispatchCostMW, " MW");
      for g in 0..<net.numGenerators {
        writeln("  Gen ", net.generators[g].id, " (Bus ", net.generators[g].busId, "): ", res.pDispatchedMW[g], " MW");
      }
    } else {
      writeln("Solving lambda-iteration Economic Dispatch for ", targetDemand, " MW target demand...");
      var ed = new EconomicDispatcher(maxIter=50, tolMW=0.01);
      var (res, dErr) = ed.dispatch(net, targetDemand);
      if !dErr.isOk() {
        writeln("Error in Economic Dispatch: ", dErr.message);
        return;
      }
      writeln("Economic Dispatch Converged: ", res.converged, " (", res.iterations, " iterations, ", res.elapsedMs, " ms)");
      writeln("System marginal clearing price lambda: $", res.lambda, "/MWh");
      writeln("Total production cost: $", res.totalCostPerHour, "/h");
      for g in 0..<net.numGenerators {
        writeln("  Gen ", net.generators[g].id, " (Bus ", net.generators[g].busId, "): ", res.pDispatchedMW[g], " MW");
      }
    }
  }

  proc main(args: [] string) {
    if args.size < 2 {
      printUsage();
      return;
    }

    const cmd = args[1];
    var subArgs: [0..<args.size - 1] string;
    for i in 1..<args.size do subArgs[i - 1] = args[i];

    select cmd {
      when "solve" { runSolve(subArgs); }
      when "estimate" { runEstimate(subArgs); }
      when "contingency" { runContingency(subArgs); }
      when "dynamic" { runDynamic(subArgs); }
      when "dispatch" { runDispatch(subArgs); }
      when "version", "--version", "-v" {
        writeln("Phasor Synchrophasor Telemetry & Power Grid Stability Kernel v1.0.0");
        writeln("Compiled with Chapel 2.10.0 (LLVM 22.1.8) on darwin-arm64");
      }
      when "help", "--help", "-h" {
        printUsage();
      }
      otherwise {
        writeln("Unknown command: '", cmd, "'");
        printUsage();
      }
    }
  }
}
