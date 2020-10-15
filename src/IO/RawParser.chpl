/*
 * RawParser.chpl
 * High-performance parser for PSS/E RAW format power network models.
 */

module RawParser {
  use Math;
  use IO;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Bus;
  use Branch;
  use Generator;
  use Load;
  use Shunt;
  use Network;

  // Splits a comma-delimited raw line, trimming whitespace and single quotes
  proc parseTokens(line: string): [] string {
    // Strip trailing comments (anything after '/')
    var parts = line.split("/");
    var cleaned = parts[0].strip();

    if cleaned.size == 0 {
      var empty: [0..<0] string;
      return empty;
    }

    var tokens = cleaned.split(",");
    for i in 0..<tokens.size {
      var tok = tokens[i].strip();
      if tok.startsWith("'") && tok.endsWith("'") && tok.size >= 2 {
        tok = tok.strip("'").strip();
      }
      tokens[i] = tok;
    }
    return tokens;
  }

  // Parses a PSS/E RAW file into an owned PowerNetwork instance
  proc parseRawFile(filepath: string): (owned PowerNetwork?, GridError) {
    try {
      // Pass 1: Count components to pre-allocate network arrays
      var fCount = open(filepath, ioMode.r);
      var rCount = fCount.reader();
      var line: string;

      // Skip 3 header lines
      for h in 1..3 do rCount.readLine(line);

      var busCount = 0;
      var loadCount = 0;
      var shuntCount = 0;
      var genCount = 0;
      var branchCount = 0;
      var maxBusId = 0;

      var section = 1; // 1=Bus, 2=Load, 3=Shunt, 4=Gen, 5=Branch

      while rCount.readLine(line) {
        const trimmed = line.strip();
        if trimmed.size == 0 || trimmed.startsWith("Q") || trimmed.startsWith("q") then break;

        if trimmed.startsWith("0 /") || trimmed == "0" {
          section += 1;
          continue;
        }

        const toks = parseTokens(trimmed);
        if toks.size == 0 then continue;

        select section {
          when 1 {
            busCount += 1;
            const bId = toks[0]: int;
            if bId > maxBusId then maxBusId = bId;
          }
          when 2 { loadCount += 1; }
          when 3 { shuntCount += 1; }
          when 4 { genCount += 1; }
          when 5 { branchCount += 1; }
        }
      }

      rCount.close();
      fCount.close();

      // Allocate network container
      var net = new owned PowerNetwork("ParsedNetwork", BASE_MVA, SYS_FREQ);
      net.allocate(busCount, branchCount, genCount, loadCount, shuntCount, maxBusId);

      // Pass 2: Populate records
      var fData = open(filepath, ioMode.r);
      var rData = fData.reader();

      // Line 1 contains baseMVA and system frequency
      rData.readLine(line);
      const hToks = parseTokens(line);
      if hToks.size >= 2 {
        net.baseMVA = hToks[1]: real;
      }
      if hToks.size >= 6 {
        net.frequency = hToks[5]: real;
      }

      // Skip header lines 2 and 3
      rData.readLine(line);
      rData.readLine(line);

      section = 1;
      var bIdx = 0;
      var lIdx = 0;
      var sIdx = 0;
      var gIdx = 0;
      var brIdx = 0;

      while rData.readLine(line) {
        const trimmed = line.strip();
        if trimmed.size == 0 || trimmed.startsWith("Q") || trimmed.startsWith("q") then break;

        if trimmed.startsWith("0 /") || trimmed == "0" {
          section += 1;
          continue;
        }

        const toks = parseTokens(trimmed);
        if toks.size == 0 then continue;

        select section {
          when 1 { // Bus
            if bIdx < busCount {
              const id = toks[0]: int;
              const name = if toks.size > 1 then toks[1] else "BUS_" + id: string;
              const kv = if toks.size > 2 then toks[2]: real else 138.0;
              const typeCode = if toks.size > 3 then toks[3]: int else 1;
              const vm = if toks.size > 7 then toks[7]: real else 1.0;
              const va = if toks.size > 8 then toks[8]: real else 0.0;

              var bType = BusType.PQ;
              if typeCode == 3 then bType = BusType.Slack;
              else if typeCode == 2 then bType = BusType.PV;

              net.buses[bIdx] = new BusNode(id, name, kv, bType, vm, va);
              net.busIdToIndex[id] = bIdx;
              bIdx += 1;
            }
          }
          when 2 { // Load
            if lIdx < loadCount {
              const busId = toks[0]: int;
              const pl = if toks.size > 5 then toks[5]: real else 0.0;
              const ql = if toks.size > 6 then toks[6]: real else 0.0;

              net.loads[lIdx] = new ZIPLoad(busId, pl, ql);
              const bInternal = net.getBusIndex(busId);
              if bInternal >= 0 {
                net.buses[bInternal].pLoad += pl;
                net.buses[bInternal].qLoad += ql;
              }
              lIdx += 1;
            }
          }
          when 3 { // Shunt
            if sIdx < shuntCount {
              const busId = toks[0]: int;
              const qShunt = if toks.size > 4 then toks[4]: real else 0.0;
              net.shunts[sIdx] = new SwitchedShunt(sIdx + 1, busId, 1, qShunt);
              sIdx += 1;
            }
          }
          when 4 { // Generator
            if gIdx < genCount {
              const busId = toks[0]: int;
              const pg = if toks.size > 2 then toks[2]: real else 0.0;
              const qg = if toks.size > 3 then toks[3]: real else 0.0;
              const qmax = if toks.size > 4 then toks[4]: real else 100.0;
              const qmin = if toks.size > 5 then toks[5]: real else -100.0;
              const vs = if toks.size > 6 then toks[6]: real else 1.0;
              const mbase = if toks.size > 8 then toks[8]: real else 100.0;
              const stat = if toks.size > 14 then toks[14]: int else 1;
              const pmax = if toks.size > 16 then toks[16]: real else 500.0;
              const pmin = if toks.size > 17 then toks[17]: real else 0.0;

              net.generators[gIdx] = new SynchronousGenerator(gIdx + 1, busId, pg, qg, qmax, qmin, vs, pmax, pmin, mbase, stat);
              const bInternal = net.getBusIndex(busId);
              if bInternal >= 0 {
                net.buses[bInternal].pGen += pg;
                net.buses[bInternal].qGen += qg;
              }
              gIdx += 1;
            }
          }
          when 5 { // Branch
            if brIdx < branchCount {
              const fromB = toks[0]: int;
              const toB = toks[1]: int;
              const r = if toks.size > 3 then toks[3]: real else 0.01;
              const x = if toks.size > 4 then toks[4]: real else 0.10;
              const b = if toks.size > 5 then toks[5]: real else 0.0;
              const rateA = if toks.size > 6 then toks[6]: real else 100.0;
              const rateB = if toks.size > 7 then toks[7]: real else 100.0;
              const rateC = if toks.size > 8 then toks[8]: real else 100.0;
              const stat = if toks.size > 13 then toks[13]: int else 1;
              const ratio = if toks.size > 17 then toks[17]: real else 1.0;

              var brType = BranchType.TransmissionLine;
              if abs(ratio - 1.0) > 1.0e-4 then brType = BranchType.Transformer;

              net.branches[brIdx] = new TransmissionBranch(brIdx + 1, fromB, toB, r, x, b, rateA, ratio, 0.0, stat);
              brIdx += 1;
            }
          }
        }
      }

      rData.close();
      fData.close();

      return (net, new GridError(PhasorStatus.Success, "PSS/E RAW file parsed successfully", "RawParser"));
    } catch e {
      var nilNet: owned PowerNetwork? = nil;
      return (nilNet, new GridError(PhasorStatus.IOFailure, "Failed to parse RAW file", "RawParser"));
    }
  }
}
