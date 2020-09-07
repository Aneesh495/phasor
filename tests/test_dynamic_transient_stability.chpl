/*
 * test_dynamic_transient_stability.chpl
 * Tests multi-machine transient stability simulation and Critical Clearing Time (CCT).
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use Bus;
use Branch;
use Generator;
use Load;
use Network;
use MachineModels;
use TransientSimulator;

proc main() {
  // Construct WSCC 3-machine 9-bus test system
  var net = new PowerNetwork("Dynamic_3Mach", 100.0, 60.0);
  net.allocate(9, 9, 3, 3, 0, 9);

  net.buses[0] = new BusNode(1, "GEN_1", 16.5, BusType.Slack, 1.04, 0.0);
  net.buses[1] = new BusNode(2, "GEN_2", 18.0, BusType.PV, 1.025, 9.28);
  net.buses[2] = new BusNode(3, "GEN_3", 13.8, BusType.PV, 1.025, 4.66);

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  // Machine 1: H = 23.64 s
  net.generators[0] = new SynchronousGenerator(1, 1, 71.6, 27.0, 300.0, -300.0, 1.04);
  net.generators[0].H = 23.64;

  // Machine 2: H = 6.4 s
  net.generators[1] = new SynchronousGenerator(2, 2, 163.0, 6.7, 300.0, -300.0, 1.025);
  net.generators[1].H = 6.4;

  // Machine 3: H = 3.01 s
  net.generators[2] = new SynchronousGenerator(3, 3, 85.0, -10.8, 300.0, -300.0, 1.025);
  net.generators[2].H = 3.01;

  // Case 1: Short clearing time (fault at t=0.20s, cleared at t=0.28s, clearing time = 80 ms)
  // Grid should remain transiently stable (rotor separation < 180 degrees)
  var simStable = new MultiMachineSimulator(stepSize=0.002, simDuration=1.5, tFlt=0.20, tClr=0.28);
  var (resStable, errStable) = simStable.simulate(net);

  assert(errStable.isOk());
  assert(resStable.isStable);
  assert(!resStable.criticalClearingTimeExceeded);
  assert(resStable.maxRotorSeparationDeg < 180.0);

  // Case 2: Prolonged fault clearing time (fault at t=0.20s, cleared at t=0.75s, clearing time = 550 ms)
  // Rotor acceleration causes generator pole slip (transient instability)
  var simUnstable = new MultiMachineSimulator(stepSize=0.002, simDuration=1.5, tFlt=0.20, tClr=0.75);
  var (resUnstable, errUnstable) = simUnstable.simulate(net);

  assert(errUnstable.isOk());
  assert(!resUnstable.isStable); // Generator pole slipped
  assert(resUnstable.criticalClearingTimeExceeded);
  assert(resUnstable.maxRotorSeparationDeg >= 180.0);

  writeln("Multi-machine dynamic transient stability tests passed successfully.");
}
