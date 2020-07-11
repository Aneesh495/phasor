/*
 * test_network_topology.chpl
 * Verifies grid components, ZIP load, generator capability, and DSU topology islanding.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Shunt;
use Topology;
use Network;

proc main() {
  // Test Bus model
  var b1 = new BusNode(1, "SUB_A", 138.0, BusType.Slack, 1.05, 0.0);
  assert(abs(b1.vMag - 1.05) < 1e-6);
  assert(abs(b1.voltagePhasor().re - 1.05) < 1e-6);
  assert(!b1.isVoltageViolated());

  // Test Branch model
  var br1 = new TransmissionBranch(1, 1, 2, 0.01, 0.05, 0.02, 100.0);
  assert(br1.branchType == BranchType.TransmissionLine);
  assert(!br1.isTripped());
  var ySeries = br1.seriesAdmittance();
  assert(abs(ySeries.re - (0.01 / (0.01*0.01 + 0.05*0.05))) < 1e-4);

  // Test Generator model
  var gen1 = new SynchronousGenerator(1, 1, 100.0, 20.0, 50.0, -50.0, 1.05, 200.0, 10.0);
  assert(abs(gen1.clampP(250.0) - 200.0) < 1e-6);
  assert(abs(gen1.clampP(5.0) - 10.0) < 1e-6);
  assert(!gen1.isAtQLimit());

  // Test ZIP Load model
  // 50% constant power, 50% constant impedance: P(V) = P0 * (0.5 * V^2 + 0.5)
  var load1 = new ZIPLoad(2, 100.0, 40.0, 0.5, 0.0, 0.5, 0.5, 0.0, 0.5);
  // At V = 0.9 pu: P = 100 * (0.5 * 0.81 + 0.5) = 100 * 0.905 = 90.5 MW
  assert(abs(load1.activePower(0.9) - 90.5) < 1e-4);

  // Test Topology Processor & Islanding:
  // Create 3-bus network: Bus 1 (Slack), Bus 2 (PQ), Bus 3 (PQ)
  // Branch 1: 1 - 2 (in service)
  // Branch 2: 2 - 3 (tripped)
  var buses: [0..2] BusNode;
  buses[0] = new BusNode(1, "B1", 138.0, BusType.Slack);
  buses[1] = new BusNode(2, "B2", 138.0, BusType.PQ);
  buses[2] = new BusNode(3, "B3", 138.0, BusType.PQ);

  var branches: [0..1] TransmissionBranch;
  branches[0] = new TransmissionBranch(1, 1, 2, 0.01, 0.05, inService=1);
  branches[1] = new TransmissionBranch(2, 2, 3, 0.01, 0.05, inService=0); // Tripped line

  var idMap: [0..3] int;
  idMap[1] = 0;
  idMap[2] = 1;
  idMap[3] = 2;

  var topo = new TopologyProcessor(3);
  var (numIslands, errTopo) = topo.analyzeTopology(buses, branches, idMap);

  // Component 1-2 has Slack. Component 3 is an isolated single bus.
  assert(topo.dsu.connected(0, 1));
  assert(!topo.dsu.connected(0, 2));

  writeln("Network and topology tests passed successfully.");
}
