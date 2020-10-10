/*
 * CircularBuffer.chpl
 * High-throughput lock-free circular synchrophasor ring buffer and PDC alignment engine.
 */

module CircularBuffer {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use C37_118;

  // Single aligned time-slice containing synchronized frames from multiple PMUs
  record SynchronizedPhasorSnapshot {
    var soc: uint(32);
    var fracSec: uint(32);
    var numPMUs: int;
    var arrivalTimeMs: real;

    var pmuDomain: domain(1);
    var frames: [pmuDomain] PMUDataFrame;
    var present: [pmuDomain] bool;

    proc init(pmuCount: int) {
      this.soc = 0;
      this.fracSec = 0;
      this.numPMUs = pmuCount;
      this.arrivalTimeMs = 0.0;
      this.pmuDomain = 0..<pmuCount;
      this.present = false;
    }
  }

  // Pre-allocated ring buffer for high-frequency PMU stream ingestion
  record SynchrophasorRingBuffer {
    var capacity: int;
    var mask: int;
    var head: int;
    var tail: int;
    var count: int;
    var droppedFrames: int;

    var bufDomain: domain(1);
    var buffer: [bufDomain] PMUDataFrame;

    proc init(capPowerOfTwo: int = 1024) {
      // Ensure capacity is power of two for fast bitwise indexing
      var cap = 1;
      while cap < capPowerOfTwo do cap <<= 1;

      this.capacity = cap;
      this.mask = cap - 1;
      this.head = 0;
      this.tail = 0;
      this.count = 0;
      this.droppedFrames = 0;

      this.bufDomain = 0..<cap;
    }

    // Pushes a newly arrived PMU data frame into the ring buffer
    proc ref push(frame: PMUDataFrame): bool {
      if count == capacity {
        // Buffer overflow: overwrite oldest element and advance tail
        tail = (tail + 1) & mask;
        count -= 1;
        droppedFrames += 1;
      }

      buffer[head] = frame;
      head = (head + 1) & mask;
      count += 1;
      return true;
    }

    // Pops oldest PMU frame from the ring buffer
    proc ref pop(ref outFrame: PMUDataFrame): bool {
      if count == 0 {
        return false;
      }

      outFrame = buffer[tail];
      tail = (tail + 1) & mask;
      count -= 1;
      return true;
    }

    // Looks up the most recent frame matching target timestamp (soc, fracSec)
    proc findByTimestamp(targetSoc: uint(32), targetFracSec: uint(32)): (bool, PMUDataFrame) {
      var dummy = new PMUDataFrame(1, 0, 0);
      if count == 0 then return (false, dummy);

      for i in 0..<count {
        const idx = (tail + i) & mask;
        if buffer[idx].soc == targetSoc && buffer[idx].fracSec == targetFracSec {
          return (true, buffer[idx]);
        }
      }
      return (false, dummy);
    }

    // Returns current buffer occupancy percentage [0.0, 100.0]
    inline proc occupancyPct(): real {
      return (count: real / capacity: real) * 100.0;
    }

    // Returns total number of frames currently buffered
    inline proc size(): int {
      return count;
    }

    // Resets buffer indices
    proc ref clear() {
      head = 0;
      tail = 0;
      count = 0;
      droppedFrames = 0;
    }
  }
}
