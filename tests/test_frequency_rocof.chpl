/*
 * test_frequency_rocof.chpl
 * Tests Center of Inertia (COI) frequency tracking and Rate of Change of Frequency (RoCoF).
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
use FrequencyDynamics;

proc main() {
  var net = new PowerNetwork("Freq_3Mach", 100.0, 60.0);
  net.allocate(3, 3, 3, 1, 0, 3);

  net.buses[0] = new BusNode(1, "GEN_1", 16.5, BusType.Slack);
  net.buses[1] = new BusNode(2, "GEN_2", 18.0, BusType.PV);
  net.buses[2] = new BusNode(3, "GEN_3", 13.8, BusType.PV);

  net.busIdToIndex[1] = 0;
  net.busIdToIndex[2] = 1;
  net.busIdToIndex[3] = 2;

  net.generators[0] = new SynchronousGenerator(1, 1, 100.0, 20.0, 50.0, -50.0);
  net.generators[0].H = 10.0;
  net.generators[1] = new SynchronousGenerator(2, 2, 80.0, 15.0, 40.0, -40.0);
  net.generators[1].H = 5.0;
  net.generators[2] = new SynchronousGenerator(3, 3, 60.0, 10.0, 30.0, -30.0);
  net.generators[2].H = 3.0;

  var sim = new MultiMachineSimulator(stepSize=0.002, simDuration=1.0, tFlt=0.20, tClr=0.32);
  var (res, err) = sim.simulate(net);
  assert(err.isOk());

  var inertias: [0..2] real = [10.0, 5.0, 3.0];
  var freqAnalyzer = new FrequencyAnalyzer();
  var metrics = freqAnalyzer.analyzeCOI(res, inertias, numG=3);

  // Initial frequency starts at 60.0 Hz
  assert(metrics.initialFreqHz == 60.0);
  // RoCoF must be positive during or after fault
  assert(metrics.maxRoCoF_Hz_per_s > 0.0);

  writeln("Frequency dynamics and RoCoF tests passed successfully.");
}
