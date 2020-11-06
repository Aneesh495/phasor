/*
 * test_end_to_end_ieee14.chpl
 * Full pipeline integration: RAW parsing, AC power flow, state estimation, and N-1 contingency.
 */

use Math;
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
use OutageModel;
use ContingencyScreening;
use ResultExporter;

proc main() {
  writeln("=== Running End-to-End Test: IEEE 14-Bus Full Lifecycle ===");

  // Stage 1: Ingest RAW network model
  var (netOpt, parseErr) = parseRawFile("data/ieee14.raw");
  assert(parseErr.isOk() && netOpt != nil, "Ingest failed: " + parseErr.message);
  var net = netOpt!;
  assert(net.numBuses == 14 && net.numBranches == 20, "Network topology mismatch");

  // Stage 2: Multi-engine power flow cross-verification
  var nr = new NewtonRaphsonSolver(maxIter=20, tol=1.0e-5);
  var (nrRes, nrErr) = nr.solve(net);
  assert(nrErr.isOk() && nrRes.converged, "Newton-Raphson failed");
  nrRes.computeBranchFlows(net);

  var fdf = new FastDecoupledSolver(maxIter=30, tol=1.0e-4);
  var (fdfRes, fdfErr) = fdf.solve(net);
  assert(fdfErr.isOk() && fdfRes.converged, "Fast Decoupled failed");

  var dc = new DCPowerFlowSolver(slackIdx=0);
  var (dcRes, dcErr) = dc.solve(net);
  assert(dcErr.isOk() && dcRes.converged, "DC power flow failed");

  writeln("Power flow convergence verified across NR, FDF, and DC engines.");
  writeln("  NR Loss:  ", nrRes.totalLossesP, " MW");
  writeln("  FDF Loss: ", fdfRes.totalLossesP, " MW");
  assert(abs(nrRes.totalLossesP - fdfRes.totalLossesP) < 0.20, "NR and FDF loss mismatch");

  // Stage 3: Synthesize measurements and perform AC State Estimation
  // 14 bus voltage magnitudes + 14 bus voltage angles (from PMUs)
  var meas: [0..<28] GridMeasurement;

  for b in 0..<14 {
    meas[b] = new GridMeasurement(b + 1, MeasurementType.BusVoltageMag, b, nrRes.vMag[b], 0.005);
    meas[14 + b] = new GridMeasurement(15 + b, MeasurementType.BusVoltageAngle, b, nrRes.vAngleRad[b], 0.002, pmu=true);
  }

  var wls = new WLSSolver(maxIter=20, tol=1.0e-5);
  var (seRes, seErr) = wls.estimate(net, meas);
  assert(seErr.isOk() && seRes.converged, "State estimation failed: " + seErr.message);

  var maxVoltDiff: real = 0.0;
  for b in 0..<14 {
    const diff = abs(seRes.vMagEstimated[b] - nrRes.vMag[b]);
    if diff > maxVoltDiff then maxVoltDiff = diff;
  }
  writeln("State estimation converged in ", seRes.iterations, " iterations (max error: ", maxVoltDiff, " pu)");
  assert(maxVoltDiff < 0.005, "Estimated voltage diverged from ground truth");

  // Stage 4: Parallel N-1 Contingency Screening
  var engine = new ParallelScreeningEngine(fast=true);
  var casesDomain: domain(1) = 0..<20;
  var cases: [casesDomain] ContingencyCase;

  for k in 0..<20 {
    cases[k] = ContingencyCase.branchTrip(k + 1, k,
                                          "Line " + net.branches[k].fromBus:string + "->" + net.branches[k].toBus:string + " trip");
  }

  var (report, contErr) = engine.screen(net, cases);
  assert(contErr.isOk(), "Contingency screening error: " + contErr.message);
  assert(report.totalContingencies == 20, "Total contingencies count mismatch");
  writeln("Parallel contingency screening complete: ", report.totalContingencies, " lines in ", report.elapsedMs, " ms");

  // Stage 5: Export results to JSON
  var jErr = exportPowerFlowJSON(net, nrRes, "build/e2e_ieee14.json");
  assert(jErr.isOk(), "JSON export failed: " + jErr.message);

  writeln("PASS: IEEE 14-Bus full lifecycle pipeline verified successfully.");
}
