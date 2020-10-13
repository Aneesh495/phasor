/*
 * test_c37_118_parser.chpl
 * Unit verification for IEEE C37.118-2011 binary synchrophasor framing and CRC-CCITT.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use C37_118;

proc main() {
  writeln("=== Running Test: IEEE C37.118 Synchrophasor Framing ===");

  const numPhasors = 2;
  var frame = new PMUDataFrame(nP=numPhasors, nA=0, nD=0);
  frame.syncWord = C37_SYNC_DATA;
  frame.idCode = 42;
  frame.soc = 1772928000;      // Realistic timestamp
  frame.fracSec = 0x00010000;  // 1/60th of a second
  frame.stat = 0x0000;         // Valid, synchronized data
  frame.freqHz = 60.05;        // +50 mHz deviation
  frame.dfreqHzPerSec = -0.15; // -150 mHz/s RoCoF

  // Bus 1 voltage phasor: 138.0 kV at 15.0 degrees
  frame.phasors[0] = new PMUPhasorValue(138.0, 15.0, false);
  // Line 1 current phasor: 450.0 A at -30.0 degrees
  frame.phasors[1] = new PMUPhasorValue(450.0, -30.0, true);

  // Allocate wire buffer
  var wireBuf: [0..<256] uint(8) = 0;
  const wireBytes = serializeDataFrame(frame, wireBuf);

  writeln("Serialized frame size: ", wireBytes, " bytes");
  assert(wireBytes > 20, "Serialized frame too small");

  // Verify wire header bytes
  assert(wireBuf[0] == 0xAA && wireBuf[1] == 0x01, "Invalid SYNC word");
  assert(wireBuf[4] == 0x00 && wireBuf[5] == 42, "Invalid IDCODE word");

  // Slice active frame bytes and parse
  var activeBuf: [0..<wireBytes] uint(8);
  for i in 0..<wireBytes do activeBuf[i] = wireBuf[i];

  var (parsedFrame, parseErr) = parseDataFrame(activeBuf, numPhasors);
  assert(parseErr.isOk(), "Failed to parse C37.118 frame: " + parseErr.message);

  assert(parsedFrame.idCode == 42, "Parsed IDCODE mismatch");
  assert(parsedFrame.soc == 1772928000, "Parsed SOC timestamp mismatch");
  assert(parsedFrame.fracSec == 0x00010000, "Parsed FRACSEC mismatch");
  assert(parsedFrame.isDataValid(), "Parsed frame marked data invalid");
  assert(parsedFrame.isTimeSynchronized(), "Parsed frame marked time unlocked");

  writeln("Parsed Frequency: ", parsedFrame.freqHz, " Hz");
  writeln("Parsed RoCoF: ", parsedFrame.dfreqHzPerSec, " Hz/s");
  assert(abs(parsedFrame.freqHz - 60.05) < 0.001, "Parsed frequency mismatch");
  assert(abs(parsedFrame.dfreqHzPerSec - (-0.15)) < 0.001, "Parsed RoCoF mismatch");

  writeln("Parsed Phasor 0: ", parsedFrame.phasors[0].magnitude, " kV, ", parsedFrame.phasors[0].angleDeg, " deg");
  writeln("Parsed Phasor 1: ", parsedFrame.phasors[1].magnitude, " A, ", parsedFrame.phasors[1].angleDeg, " deg");

  assert(abs(parsedFrame.phasors[0].magnitude - 138.0) < 0.05, "Phasor 0 magnitude error");
  assert(abs(parsedFrame.phasors[0].angleDeg - 15.0) < 0.05, "Phasor 0 angle error");
  assert(abs(parsedFrame.phasors[1].magnitude - 450.0) < 0.05, "Phasor 1 magnitude error");
  assert(abs(parsedFrame.phasors[1].angleDeg - (-30.0)) < 0.05, "Phasor 1 angle error");

  // Corrupt checksum test
  activeBuf[wireBytes - 1] ^= 0xFF;
  var (corruptFrame, corruptErr) = parseDataFrame(activeBuf, numPhasors);
  assert(!corruptErr.isOk(), "Corrupted frame failed to trigger CRC checksum error");
  writeln("Verified CRC rejection on corrupted frame: ", corruptErr.message);

  writeln("PASS: IEEE C37.118 Framing and CRC verified successfully.");
}
