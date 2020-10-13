/*
 * test_circular_buffer.chpl
 * Unit verification for synchrophasor ring buffer and PDC timestamp alignment.
 */

use PhasorConstants;
use PhasorTypes;
use PhasorError;
use C37_118;
use CircularBuffer;

proc main() {
  writeln("=== Running Test: Synchrophasor Ring Buffer ===");

  var ring = new SynchrophasorRingBuffer(capPowerOfTwo=16);
  assert(ring.capacity == 16, "Capacity should be rounded to 16");
  assert(ring.size() == 0, "Initial buffer should be empty");

  // Push 10 frames
  for i in 0..<10 {
    var frame = new PMUDataFrame(nP=1, nA=0, nD=0);
    frame.idCode = 101;
    frame.soc = 1772928000;
    frame.fracSec = (i * 1000): uint(32);
    frame.freqHz = 60.0 + (i: real) * 0.01;
    frame.phasors[0] = new PMUPhasorValue(138.0 + (i: real), 0.0);
    ring.push(frame);
  }

  assert(ring.size() == 10, "Ring buffer size mismatch");
  assert(ring.droppedFrames == 0, "No frames should be dropped yet");

  // Pop 5 frames and verify FIFO ordering
  for i in 0..<5 {
    var popped: PMUDataFrame;
    var ok = ring.pop(popped);
    assert(ok, "Pop failed");
    assert(popped.fracSec == (i * 1000): uint(32), "FIFO order violated");
  }

  assert(ring.size() == 5, "Ring buffer size after pop mismatch");

  // Push 20 more frames to exceed capacity and verify overwrite behavior
  for i in 10..<30 {
    var frame = new PMUDataFrame(nP=1, nA=0, nD=0);
    frame.idCode = 101;
    frame.soc = 1772928000;
    frame.fracSec = (i * 1000): uint(32);
    ring.push(frame);
  }

  assert(ring.size() == ring.capacity, "Buffer should be full at capacity");
  assert(ring.droppedFrames > 0, "Overwritten frames should be counted as dropped");
  writeln("Recorded dropped frames on buffer saturation: ", ring.droppedFrames);

  // Timestamp alignment lookup
  var (found, matchedFrame) = ring.findByTimestamp(1772928000, 25000);
  assert(found, "Failed to find frame with timestamp (1772928000, 25000)");
  assert(matchedFrame.fracSec == 25000, "Matched frame fracSec mismatch");

  var (notFound, _) = ring.findByTimestamp(1772928000, 999999);
  assert(!notFound, "Non-existent timestamp incorrectly found");

  writeln("PASS: Synchrophasor Ring Buffer verified successfully.");
}
