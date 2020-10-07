/*
 * COMTRADE.chpl
 * IEEE C37.111 COMTRADE format parser and transient oscillography exporter.
 */

module COMTRADE {
  use Math;
  use IO;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;

  // Metadata for an analog recording channel
  record AnalogChannelInfo {
    var channelIndex: int;
    var name: string;
    var phase: string;
    var ccbm: string;
    var unit: string;
    var aMultiplier: real;
    var bOffset: real;
    var skew: real;
    var minVal: real;
    var maxVal: real;
    var primaryRatio: real;
    var secondaryRatio: real;
    var scaling: string;

    proc init(idx: int = 1,
              chName: string = "VA",
              chPhase: string = "A",
              chUnit: string = "kV",
              a: real = 1.0,
              b: real = 0.0) {
      this.channelIndex = idx;
      this.name = chName;
      this.phase = chPhase;
      this.ccbm = "LINE1";
      this.unit = chUnit;
      this.aMultiplier = a;
      this.bOffset = b;
      this.skew = 0.0;
      this.minVal = -99999.0;
      this.maxVal = 99999.0;
      this.primaryRatio = 1.0;
      this.secondaryRatio = 1.0;
      this.scaling = "P";
    }
  }

  // Complete multi-channel oscillography record
  record COMTRADERecord {
    var stationName: string;
    var deviceId: string;
    var revYear: int;
    var numAnalog: int;
    var numDigital: int;
    var sampleRateHz: real;
    var numSamples: int;

    var sDomain: domain(1);
    var timeUs: [sDomain] real;

    var aChanDomain: domain(1);
    var analogChannels: [aChanDomain] AnalogChannelInfo;

    var aDataDomain: domain(2);
    var analogData: [aDataDomain] real; // [sampleIdx, chIdx]

    proc init(station: string,
              dev: string,
              nA: int,
              nD: int,
              nSamples: int,
              sampRate: real = 4800.0) {
      this.stationName = station;
      this.deviceId = dev;
      this.revYear = 1999;
      this.numAnalog = nA;
      this.numDigital = nD;
      this.sampleRateHz = sampRate;
      this.numSamples = nSamples;

      this.sDomain = 0..<nSamples;
      this.timeUs = 0.0;

      this.aChanDomain = 0..<nA;
      this.aDataDomain = {0..<nSamples, 0..<nA};
      this.analogData = 0.0;
    }

    // Exports oscillography record to standard ASCII COMTRADE files (.cfg and .dat)
    proc exportASCII(cfgPath: string, datPath: string): GridError {
      try {
        // Write CFG file
        var cfgFile = open(cfgPath, ioMode.cw);
        var cfgWriter = cfgFile.writer();

        // Line 1: Station, Device, Revision
        cfgWriter.writeln(stationName, ",", deviceId, ",", revYear);

        // Line 2: Channels (total, analog, digital)
        const totalChannels = numAnalog + numDigital;
        cfgWriter.writeln(totalChannels, ",", numAnalog, "A,", numDigital, "D");

        // Analog channels
        for a in 0..<numAnalog {
          const ch = analogChannels[a];
          cfgWriter.writeln(ch.channelIndex, ",", ch.name, ",", ch.phase, ",", ch.ccbm, ",",
                            ch.unit, ",", ch.aMultiplier, ",", ch.bOffset, ",",
                            ch.skew, ",", ch.minVal, ",", ch.maxVal, ",",
                            ch.primaryRatio, ",", ch.secondaryRatio, ",", ch.scaling);
        }

        // Line: Nominal frequency
        cfgWriter.writeln(SYS_FREQ);

        // Line: Sample rates count
        cfgWriter.writeln(1);
        cfgWriter.writeln(sampleRateHz, ",", numSamples);

        // Timestamps (sample start and trigger)
        cfgWriter.writeln("01/01/2026,00:00:00.000000");
        cfgWriter.writeln("01/01/2026,00:00:00.000000");

        // Data file format
        cfgWriter.writeln("ASCII");
        cfgWriter.writeln(1.0); // Timestamp multiplication factor

        cfgWriter.close();
        cfgFile.close();

        // Write DAT file
        var datFile = open(datPath, ioMode.cw);
        var datWriter = datFile.writer();

        for s in 0..<numSamples {
          datWriter.write(s + 1, ",", timeUs[s]: int);
          for a in 0..<numAnalog {
            datWriter.write(",", analogData[s, a]);
          }
          datWriter.writeln();
        }

        datWriter.close();
        datFile.close();

        return new GridError(PhasorStatus.Success, "COMTRADE export succeeded", "COMTRADE");
      } catch e {
        return new GridError(PhasorStatus.IOFailure, "File I/O failure during COMTRADE export", "COMTRADE");
      }
    }
  }
}
