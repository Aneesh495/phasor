/*
 * test_comtrade_export.chpl
 * Unit verification for IEEE C37.111 COMTRADE file export and parsing.
 */

use Math;
use IO;
use PhasorConstants;
use PhasorTypes;
use PhasorError;
use COMTRADE;

proc main() {
  writeln("=== Running Test: IEEE C37.111 COMTRADE Export ===");

  const nA = 3;
  const nD = 0;
  const nSamples = 120;
  const sampleRate = 4800.0; // 80 samples per cycle at 60 Hz

  var rec = new COMTRADERecord("SUBSTATION_A", "RELAY_01", nA, nD, nSamples, sampleRate);

  rec.analogChannels[0] = new AnalogChannelInfo(1, "VA", "A", "kV", 1.0, 0.0);
  rec.analogChannels[1] = new AnalogChannelInfo(2, "VB", "B", "kV", 1.0, 0.0);
  rec.analogChannels[2] = new AnalogChannelInfo(3, "VC", "C", "kV", 1.0, 0.0);

  const dtUs = (1.0 / sampleRate) * 1.0e6;
  const omega = TWO_PI * 60.0;

  for s in 0..<nSamples {
    const tSec = (s: real) / sampleRate;
    rec.timeUs[s] = s * dtUs;

    // Simulate 3-phase voltages with a sag on phase A between sample 40 and 80
    var sagFactor = 1.0;
    if s >= 40 && s <= 80 then sagFactor = 0.40;

    rec.analogData[s, 0] = sagFactor * 138.0 * sin(omega * tSec);
    rec.analogData[s, 1] = 138.0 * sin(omega * tSec - 2.094395); // -120 deg
    rec.analogData[s, 2] = 138.0 * sin(omega * tSec + 2.094395); // +120 deg
  }

  const cfgPath = "build/test_transient.cfg";
  const datPath = "build/test_transient.dat";

  var err = rec.exportASCII(cfgPath, datPath);
  assert(err.isOk(), "COMTRADE export failed: " + err.message);

  // Verify exported files exist and can be opened
  var cfgFile = open(cfgPath, ioMode.r);
  var cfgReader = cfgFile.reader();
  var line1: string;
  cfgReader.readLine(line1);
  writeln("COMTRADE Header: ", line1.strip());
  assert(line1.startsWith("SUBSTATION_A"), "CFG header station mismatch");

  cfgReader.close();
  cfgFile.close();

  var datFile = open(datPath, ioMode.r);
  var datReader = datFile.reader();
  var dLine: string;
  var rowCount = 0;
  while datReader.readLine(dLine) {
    if dLine.strip().size > 0 then rowCount += 1;
  }
  datReader.close();
  datFile.close();

  writeln("Exported rows in DAT: ", rowCount);
  assert(rowCount == nSamples, "DAT file row count mismatch");

  writeln("PASS: IEEE C37.111 COMTRADE export verified successfully.");
}
