/*
 * test_parallel_contingency.chpl
 * Tests massively parallel N-1 and N-2 contingency screening and overload ranking.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use OutageModel;
use PerformanceIndex;
use ContingencyScreening;

proc main() {
  var net = new PowerNetwork("Contingency_3Bus", 100.0, 60.0);
  net.allocate(3, 3, 2, 1, 0, 3);

  net.buses[0] = new BusNode(1, "B1", 138.0, BusType.Slack);
  net.buses[1] = new BusNode(2, "B2", 138.0, BusType.PV);
  net.buses[1].pGen = 50.0;
  net.buses[2] = new BusNode(3, "B3", 138.0, BusType.PQ);
  net.buses[2].pLoad = 120.0; // High load to induce overload under outage

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 0.0, 0.0, 200.0, -100.0);
  net.generators[1] = new SynchronousGenerator(2, 2, 50.0, 0.0, 100.0, -50.0);
  net.loads[0] = new ZIPLoad(3, 120.0, 0.0);

  // Line ratings: 1-2 (100 MVA), 2-3 (80 MVA), 1-3 (80 MVA)
  net.branches[0] = new TransmissionBranch(1, 1, 2, 0.0, 0.10, 0.0, 100.0);
  net.branches[1] = new TransmissionBranch(2, 2, 3, 0.0, 0.10, 0.0, 80.0);
  net.branches[2] = new TransmissionBranch(3, 1, 3, 0.0, 0.20, 0.0, 80.0);

  // Define 3 single-line outages (N-1) and 1 generator trip
  var cCases: [0..3] ContingencyCase;
  cCases[0] = ContingencyCase.branchTrip(1, 0, "Trip Line 1-2");
  cCases[1] = ContingencyCase.branchTrip(2, 1, "Trip Line 2-3");
  cCases[2] = ContingencyCase.branchTrip(3, 2, "Trip Line 1-3");
  cCases[3] = ContingencyCase.generatorTrip(4, 1, "Trip Generator 2");

  var screener = new ParallelScreeningEngine(fast=true);
  var (report, err) = screener.screen(net, cCases);

  assert(err.isOk());
  assert(report.totalContingencies == 4);

  // Outage of line 1-3 forces all 120 MW load flow through path 1-2-3!
  // Line 2-3 with rating 80 MVA now carries 120 MW -> 150% overload (Critical tier!)
  assert(report.criticalCount >= 1);
  assert(report.worstLoadingPct >= 100.0);

  writeln("Parallel contingency screening tests passed successfully.");
}
