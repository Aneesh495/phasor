/*
 * test_raw_parser.chpl
 * Unit verification for PSS/E RAW network parsing and seamless solver execution.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Network;
use RawParser;
use NewtonRaphson;

proc main() {
  writeln("=== Running Test: PSS/E RAW Parser ===");

  const rawPath = "data/ieee14.raw";
  var (netOpt, err) = parseRawFile(rawPath);

  assert(err.isOk(), "Failed to parse IEEE 14 RAW file: " + err.message);
  assert(netOpt != nil, "Parsed network is nil");

  var net = netOpt!;
  writeln("Successfully parsed network: ", net.name);
  writeln("  Buses: ", net.numBuses);
  writeln("  Branches: ", net.numBranches);
  writeln("  Generators: ", net.numGenerators);
  writeln("  Loads: ", net.numLoads);

  assert(net.numBuses == 14, "Expected 14 buses in IEEE 14");
  assert(net.numBranches == 20, "Expected 20 branches in IEEE 14");
  assert(net.numGenerators == 5, "Expected 5 generators in IEEE 14");
  assert(net.numLoads == 11, "Expected 11 loads in IEEE 14");

  // Verify bus types
  assert(net.buses[0].busType == BusType.Slack, "Bus 1 should be Slack");
  assert(net.buses[1].busType == BusType.PV, "Bus 2 should be PV");
  assert(net.buses[3].busType == BusType.PQ, "Bus 4 should be PQ");

  // Verify solving AC Newton-Raphson power flow on the parsed network
  var nr = new NewtonRaphsonSolver(maxIter=20, tol=1.0e-5);
  var (pfRes, pfErr) = nr.solve(net);

  assert(pfErr.isOk(), "Newton-Raphson solve failed on parsed network: " + pfErr.message);
  assert(pfRes.converged, "Newton-Raphson did not converge");
  pfRes.computeBranchFlows(net);

  const (pGen, qGen, pLoad, qLoad) = net.summary();
  writeln("Newton-Raphson converged in ", pfRes.iterations, " iterations (", pfRes.elapsedMs, " ms)");
  writeln("Total generation: ", pGen, " MW");
  writeln("Total load: ", pLoad, " MW");
  writeln("Total losses: ", pfRes.totalLossesP, " MW");

  assert(pGen > 200.0 && pGen < 300.0, "Total generation outside benchmark range");
  assert(pfRes.totalLossesP > 5.0 && pfRes.totalLossesP < 25.0, "Total losses outside benchmark range");

  writeln("PASS: PSS/E RAW parser and solver integration verified successfully.");
}
