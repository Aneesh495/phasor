/*
 * C37_118.chpl
 * High-performance IEEE C37.118-2011 binary synchrophasor protocol encoder and decoder.
 */

module C37_118 {
  use Math;
  use CTypes;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;

  // Reinterprets IEEE 754 32-bit float bit pattern as 32-bit unsigned integer
  inline proc floatToBits(f: real(32)): uint(32) {
    var val = f;
    var vptr: c_ptr(void) = c_ptrTo(val);
    var ptr: c_ptr(uint(32)) = vptr: c_ptr(uint(32));
    return ptr.deref();
  }

  // Reinterprets 32-bit unsigned integer bit pattern as IEEE 754 32-bit float
  inline proc bitsToFloat(u: uint(32)): real(32) {
    var val = u;
    var vptr: c_ptr(void) = c_ptrTo(val);
    var ptr: c_ptr(real(32)) = vptr: c_ptr(real(32));
    return ptr.deref();
  }

  // Computes IEEE C37.118-2011 Annex C standard CRC-CCITT (polynomial 0x1021, init 0xFFFF)
  proc computeCRCCCITT(buf: [] uint(8), startIdx: int, length: int): uint(16) {
    var crc: uint(16) = 0xFFFF;
    for i in 0..<length {
      const b: uint(16) = buf[startIdx + i]: uint(16);
      crc ^= (b << 8);
      for bit in 0..7 {
        if (crc & 0x8000) != 0 {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = (crc << 1);
        }
      }
    }
    return crc;
  }

  // Single phasor measurement channel within a synchrophasor frame
  record PMUPhasorValue {
    var magnitude: real; // Volts or Amperes (primary or secondary)
    var angleDeg: real;  // Phase angle in degrees [-180, +180]
    var isCurrent: bool; // False for voltage, true for current

    proc init(mag: real = 0.0, ang: real = 0.0, isCurr: bool = false) {
      this.magnitude = mag;
      this.angleDeg = ang;
      this.isCurrent = isCurr;
    }

    // Converts polar representation to rectangular ComplexPhasor
    proc toComplex(): ComplexPhasor {
      return ComplexPhasor.fromPolar(magnitude, angleDeg * DEG_TO_RAD);
    }
  }

  // Decoded synchrophasor data frame
  record PMUDataFrame {
    var syncWord: uint(16);
    var frameSize: uint(16);
    var idCode: uint(16);
    var soc: uint(32);          // Second of Century (UTC UNIX epoch seconds)
    var fracSec: uint(32);      // Fraction-of-second (bits 0-23) and Time Quality (bits 24-31)
    var stat: uint(16);         // Status word
    var freqHz: real;           // Measured frequency in Hertz
    var dfreqHzPerSec: real;    // Rate of change of frequency (RoCoF) in Hz/s

    var numPhasors: int;
    var phasorDomain: domain(1);
    var phasors: [phasorDomain] PMUPhasorValue;

    var numAnalogs: int;
    var analogDomain: domain(1);
    var analogs: [analogDomain] real;

    var numDigitals: int;
    var digitalDomain: domain(1);
    var digitals: [digitalDomain] uint(16);

    proc init(nP: int = 1, nA: int = 0, nD: int = 0) {
      this.syncWord = C37_SYNC_DATA;
      this.frameSize = 0;
      this.idCode = 1;
      this.soc = 0;
      this.fracSec = 0;
      this.stat = 0;
      this.freqHz = SYS_FREQ;
      this.dfreqHzPerSec = 0.0;
      this.numPhasors = nP;
      this.phasorDomain = 0..<nP;
      this.numAnalogs = nA;
      this.analogDomain = 0..<nA;
      this.numDigitals = nD;
      this.digitalDomain = 0..<nD;
    }

    // Status word bitfield inspection
    inline proc isDataValid(): bool {
      // Bit 15: 0 = Good data, 1 = PMU error / invalid
      return (stat & 0x8000) == 0;
    }

    inline proc isTimeSynchronized(): bool {
      // Bit 13: 0 = Time synchronized to UTC traceable source, 1 = Clock unlocked
      return (stat & 0x2000) == 0;
    }

    inline proc getTimeQuality(): uint(8) {
      // FracSec bits 24-27: Time quality indicator code
      return ((fracSec >> 24) & 0x0F): uint(8);
    }
  }

  // Serializes a PMUDataFrame into big-endian IEEE C37.118 floating-point binary wire format
  proc serializeDataFrame(frame: PMUDataFrame, ref buf: [] uint(8)): int {
    // Header: SYNC (2) + FRAMESIZE (2) + IDCODE (2) + SOC (4) + FRACSEC (4) = 14 bytes
    // Per PMU: STAT (2) + PHASORS (numPhasors * 8) + FREQ (4) + DFREQ (4) + ANALOGS (numAnalogs * 4) + DIGITALS (numDigitals * 2)
    // Footer: CHK (2 bytes)
    const pmuBytes = 2 + frame.numPhasors * 8 + 4 + 4 + frame.numAnalogs * 4 + frame.numDigitals * 2;
    const totalBytes: uint(16) = (14 + pmuBytes + 2): uint(16);

    // Byte 0-1: SYNC
    buf[0] = ((frame.syncWord >> 8) & 0xFF): uint(8);
    buf[1] = (frame.syncWord & 0xFF): uint(8);

    // Byte 2-3: FRAMESIZE
    buf[2] = ((totalBytes >> 8) & 0xFF): uint(8);
    buf[3] = (totalBytes & 0xFF): uint(8);

    // Byte 4-5: IDCODE
    buf[4] = ((frame.idCode >> 8) & 0xFF): uint(8);
    buf[5] = (frame.idCode & 0xFF): uint(8);

    // Byte 6-9: SOC
    buf[6] = ((frame.soc >> 24) & 0xFF): uint(8);
    buf[7] = ((frame.soc >> 16) & 0xFF): uint(8);
    buf[8] = ((frame.soc >> 8) & 0xFF): uint(8);
    buf[9] = (frame.soc & 0xFF): uint(8);

    // Byte 10-13: FRACSEC
    buf[10] = ((frame.fracSec >> 24) & 0xFF): uint(8);
    buf[11] = ((frame.fracSec >> 16) & 0xFF): uint(8);
    buf[12] = ((frame.fracSec >> 8) & 0xFF): uint(8);
    buf[13] = (frame.fracSec & 0xFF): uint(8);

    // Byte 14-15: STAT
    buf[14] = ((frame.stat >> 8) & 0xFF): uint(8);
    buf[15] = (frame.stat & 0xFF): uint(8);

    var offset: int = 16;

    // Phasors (floating-point rectangular format: Real(32) + Imag(32))
    for p in 0..<frame.numPhasors {
      const c = frame.phasors[p].toComplex();
      const real32 = c.re: real(32);
      const imag32 = c.im: real(32);

      const rBits = floatToBits(real32);
      const iBits = floatToBits(imag32);

      buf[offset + 0] = ((rBits >> 24) & 0xFF): uint(8);
      buf[offset + 1] = ((rBits >> 16) & 0xFF): uint(8);
      buf[offset + 2] = ((rBits >> 8) & 0xFF): uint(8);
      buf[offset + 3] = (rBits & 0xFF): uint(8);

      buf[offset + 4] = ((iBits >> 24) & 0xFF): uint(8);
      buf[offset + 5] = ((iBits >> 16) & 0xFF): uint(8);
      buf[offset + 6] = ((iBits >> 8) & 0xFF): uint(8);
      buf[offset + 7] = (iBits & 0xFF): uint(8);

      offset += 8;
    }

    // FREQ deviation from nominal (32-bit float in Hz)
    const fDev = (frame.freqHz - SYS_FREQ): real(32);
    const fBits = floatToBits(fDev);
    buf[offset + 0] = ((fBits >> 24) & 0xFF): uint(8);
    buf[offset + 1] = ((fBits >> 16) & 0xFF): uint(8);
    buf[offset + 2] = ((fBits >> 8) & 0xFF): uint(8);
    buf[offset + 3] = (fBits & 0xFF): uint(8);
    offset += 4;

    // DFREQ RoCoF (32-bit float in Hz/s)
    const df = frame.dfreqHzPerSec: real(32);
    const dfBits = floatToBits(df);
    buf[offset + 0] = ((dfBits >> 24) & 0xFF): uint(8);
    buf[offset + 1] = ((dfBits >> 16) & 0xFF): uint(8);
    buf[offset + 2] = ((dfBits >> 8) & 0xFF): uint(8);
    buf[offset + 3] = (dfBits & 0xFF): uint(8);
    offset += 4;

    // Analogs
    for a in 0..<frame.numAnalogs {
      const aVal = frame.analogs[a]: real(32);
      const aBits = floatToBits(aVal);
      buf[offset + 0] = ((aBits >> 24) & 0xFF): uint(8);
      buf[offset + 1] = ((aBits >> 16) & 0xFF): uint(8);
      buf[offset + 2] = ((aBits >> 8) & 0xFF): uint(8);
      buf[offset + 3] = (aBits & 0xFF): uint(8);
      offset += 4;
    }

    // Digitals
    for d in 0..<frame.numDigitals {
      const dVal = frame.digitals[d];
      buf[offset + 0] = ((dVal >> 8) & 0xFF): uint(8);
      buf[offset + 1] = (dVal & 0xFF): uint(8);
      offset += 2;
    }

    // Checksum: CRC-CCITT over all bytes excluding CHK itself
    const crc = computeCRCCCITT(buf, 0, offset);
    buf[offset + 0] = ((crc >> 8) & 0xFF): uint(8);
    buf[offset + 1] = (crc & 0xFF): uint(8);
    offset += 2;

    return offset;
  }

  // Parses a binary byte buffer into a PMUDataFrame
  proc parseDataFrame(buf: [] uint(8),
                      numPhasors: int,
                      numAnalogs: int = 0,
                      numDigitals: int = 0): (PMUDataFrame, GridError) {
    var frame = new PMUDataFrame(numPhasors, numAnalogs, numDigitals);

    if buf.size < 16 {
      return (frame, new GridError(PhasorStatus.InvalidInput, "Buffer too small for C37.118 frame header", "C37_118"));
    }

    // Parse Header
    frame.syncWord = ((buf[0]: uint(16)) << 8) | (buf[1]: uint(16));
    frame.frameSize = ((buf[2]: uint(16)) << 8) | (buf[3]: uint(16));
    frame.idCode = ((buf[4]: uint(16)) << 8) | (buf[5]: uint(16));

    frame.soc = ((buf[6]: uint(32)) << 24) |
                ((buf[7]: uint(32)) << 16) |
                ((buf[8]: uint(32)) << 8)  |
                (buf[9]: uint(32));

    frame.fracSec = ((buf[10]: uint(32)) << 24) |
                    ((buf[11]: uint(32)) << 16) |
                    ((buf[12]: uint(32)) << 8)  |
                    (buf[13]: uint(32));

    // Verify CRC
    const expectedLength = frame.frameSize: int;
    if buf.size < expectedLength {
      return (frame, new GridError(PhasorStatus.InvalidInput, "Buffer shorter than declared frame size", "C37_118"));
    }

    const wireCrc = ((buf[expectedLength - 2]: uint(16)) << 8) | (buf[expectedLength - 1]: uint(16));
    const calcCrc = computeCRCCCITT(buf, 0, expectedLength - 2);

    if wireCrc != calcCrc {
      return (frame, new GridError(PhasorStatus.BadDataDetected, "C37.118 CRC-CCITT checksum mismatch", "C37_118"));
    }

    // Parse STAT
    frame.stat = ((buf[14]: uint(16)) << 8) | (buf[15]: uint(16));

    var offset: int = 16;

    // Phasors
    for p in 0..<numPhasors {
      const rBits: uint(32) = ((buf[offset + 0]: uint(32)) << 24) |
                              ((buf[offset + 1]: uint(32)) << 16) |
                              ((buf[offset + 2]: uint(32)) << 8)  |
                              (buf[offset + 3]: uint(32));

      const iBits: uint(32) = ((buf[offset + 4]: uint(32)) << 24) |
                              ((buf[offset + 5]: uint(32)) << 16) |
                              ((buf[offset + 6]: uint(32)) << 8)  |
                              (buf[offset + 7]: uint(32));

      const rVal = bitsToFloat(rBits);
      const iVal = bitsToFloat(iBits);

      const cPhasor = new ComplexPhasor(rVal: real(64), iVal: real(64));
      frame.phasors[p] = new PMUPhasorValue(cPhasor.magnitude(), cPhasor.angleDeg());

      offset += 8;
    }

    // FREQ
    const fBits: uint(32) = ((buf[offset + 0]: uint(32)) << 24) |
                            ((buf[offset + 1]: uint(32)) << 16) |
                            ((buf[offset + 2]: uint(32)) << 8)  |
                            (buf[offset + 3]: uint(32));
    const fDev = bitsToFloat(fBits);
    frame.freqHz = SYS_FREQ + (fDev: real(64));
    offset += 4;

    // DFREQ
    const dfBits: uint(32) = ((buf[offset + 0]: uint(32)) << 24) |
                             ((buf[offset + 1]: uint(32)) << 16) |
                             ((buf[offset + 2]: uint(32)) << 8)  |
                             (buf[offset + 3]: uint(32));
    const df = bitsToFloat(dfBits);
    frame.dfreqHzPerSec = df: real(64);
    offset += 4;

    return (frame, new GridError(PhasorStatus.Success, "C37.118 frame parsed successfully", "C37_118"));
  }
}
