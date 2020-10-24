/*
 * test_result_exporter.chpl
 * Unit verification for JSON and CSV result serialization.
 */

use IO;
use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Network;
use RawParser;
use NewtonRaphson;
use ResultExporter;

proc main() {
  writeln("=== Running Test: Result Exporter ===");

  var (netOpt, parseErr) = parseRawFile("data/ieee14.raw");
  assert(parseErr.isOk(), "Failed to parse RAW file");
  var net = netOpt!;

  var nr = new NewtonRaphsonSolver(maxIter=20, tol=1.0e-5);
  var (pfRes, pfErr) = nr.solve(net);
  assert(pfErr.isOk(), "Newton-Raphson failed");
  pfRes.computeBranchFlows(net);

  // Export JSON
  const jsonPath = "build/test_pf.json";
  var jErr = exportPowerFlowJSON(net, pfRes, jsonPath);
  assert(jErr.isOk(), "JSON export failed: " + jErr.message);

  // Verify JSON file exists and has content
  var jf = open(jsonPath, ioMode.r);
  var jr = jf.reader();
  var line: string;
  var hasContent = jr.readLine(line);
  assert(hasContent, "JSON file is empty");
  jr.close();
  jf.close();

  // Export CSV
  const busCsvPath = "build/test_buses.csv";
  const branchCsvPath = "build/test_branches.csv";
  var cErr = exportPowerFlowCSV(net, pfRes, busCsvPath, branchCsvPath);
  assert(cErr.isOk(), "CSV export failed: " + cErr.message);

  // Verify CSV headers
  var bf = open(busCsvPath, ioMode.r);
  var br = bf.reader();
  var bHeader: string;
  br.readLine(bHeader);
  assert(bHeader.startsWith("bus_id"), "Bus CSV header missing");
  br.close();
  bf.close();

  writeln("PASS: Result exporter verified successfully.");
}
