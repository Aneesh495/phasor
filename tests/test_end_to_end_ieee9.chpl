/*
 * test_end_to_end_ieee9.chpl
 * End-to-end integration test: WSCC 9-bus dynamic transient stability and COI frequency.
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
use MachineModels;
use TransientSimulator;
use FrequencyDynamics;

proc main() {
  writeln("=== Running End-to-End Test: WSCC 9-Bus Dynamic Stability ===");

  var (netOpt, parseErr) = parseRawFile("data/ieee9.raw");
  assert(parseErr.isOk(), "Failed to parse IEEE 9 RAW file: " + parseErr.message);
  var net = netOpt!;

  // Step 1: Pre-fault AC power flow initialization
  var nr = new NewtonRaphsonSolver(maxIter=20, tol=1.0e-5);
  var (pfRes, pfErr) = nr.solve(net);
  assert(pfErr.isOk() && pfRes.converged, "Pre-fault power flow failed");
  pfRes.computeBranchFlows(net);

  writeln("Pre-fault power flow solved in ", pfRes.iterations, " iterations.");
  writeln("  Total Generation: ", net.summary()[0], " MW");
  writeln("  Total Losses:     ", pfRes.totalLossesP, " MW");

  // Step 2: Configure synchronous machine inertia parameters
  net.generators[0].H = 23.64;
  net.generators[1].H = 6.40;
  net.generators[2].H = 3.01;

  // Step 3: Inject short-circuit fault at t=0.20s, cleared at t=0.28s (80 ms clearing)
  writeln("Simulating 80 ms fault using 4th-order Runge-Kutta...");
  var sim = new MultiMachineSimulator(stepSize=0.002, simDuration=2.0, tFlt=0.20, tClr=0.28);
  var (stabRes, simErr) = sim.simulate(net);
  assert(simErr.isOk(), "Transient simulation failed: " + simErr.message);

  writeln("Simulation completed: ", stabRes.timeStepsTaken, " time-steps (", stabRes.elapsedMs, " ms)");
  writeln("  System Stable:             ", stabRes.isStable);
  writeln("  Max Rotor Angle Spread:    ", stabRes.maxRotorSeparationDeg, " deg");

  assert(stabRes.isStable, "System lost synchronism under 80 ms clearing!");
  assert(stabRes.maxRotorSeparationDeg < 90.0, "Rotor angle separation exceeded stability boundary");

  // Step 4: Verify Center of Inertia (COI) frequency tracking
  var freqAnalyzer = new FrequencyAnalyzer();
  var inertias: [0..<3] real = [23.64, 6.40, 3.01];
  var metrics = freqAnalyzer.analyzeCOI(stabRes, inertias, numG=3);

  writeln("COI Initial Frequency: ", metrics.initialFreqHz, " Hz");
  writeln("COI Nadir Frequency:   ", metrics.nadirFreqHz, " Hz");
  writeln("Max RoCoF:             ", metrics.maxRoCoF_Hz_per_s, " Hz/s");

  assert(metrics.initialFreqHz == 60.0, "Initial COI frequency should be 60 Hz");
  assert(metrics.nadirFreqHz > 58.0 && metrics.nadirFreqHz <= 60.0, "COI nadir outside normal transient bounds");
  assert(metrics.maxRoCoF_Hz_per_s > 0.0, "Max RoCoF should be positive during fault");

  writeln("PASS: WSCC 9-Bus dynamic transient stability drill verified successfully.");
}
