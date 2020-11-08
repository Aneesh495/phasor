/*
 * TerminalUI.chpl
 * ANSI terminal real-time telemetry dashboard and grid visualization meters.
 */

module TerminalUI {
  use Math;
  use IO;
  use PhasorConstants;
  use PhasorTypes;
  use Network;
  use PowerFlowResult;

  // ANSI Escape Codes
  const ANSI_RESET: string = "\x1b[0m";
  const ANSI_BOLD: string = "\x1b[1m";
  const ANSI_RED: string = "\x1b[31m";
  const ANSI_GREEN: string = "\x1b[32m";
  const ANSI_YELLOW: string = "\x1b[33m";
  const ANSI_BLUE: string = "\x1b[34m";
  const ANSI_CYAN: string = "\x1b[36m";

  // Creates a text progress bar: [========    ]
  proc makeProgressBar(fraction: real, width: int = 20): string {
    const clamped = if fraction < 0.0 then 0.0 else if fraction > 1.0 then 1.0 else fraction;
    const filled = (clamped * width): int;
    var bar = "[";
    for i in 0..<filled do bar += "=";
    for i in filled..<width do bar += " ";
    bar += "]";
    return bar;
  }

  // Prints the system voltage profile dashboard
  proc printVoltageDashboard(net: PowerNetwork) {
    writeln(ANSI_BOLD, ANSI_CYAN, "=== SYSTEM BUS VOLTAGE RADAR ===", ANSI_RESET);
    writeln("Bus ID | Bus Name         | Voltage (pu) | Angle (deg) | Status");
    writeln("----------------------------------------------------------------");

    for b in 0..<net.numBuses {
      const bus = net.buses[b];
      const vm = bus.vMag;
      const va = bus.vAngle * RAD_TO_DEG;

      var color = ANSI_GREEN;
      var statusStr = "NORMAL";

      if vm < 0.90 || vm > 1.10 {
        color = ANSI_RED;
        statusStr = "CRITICAL";
      } else if vm < 0.95 || vm > 1.05 {
        color = ANSI_YELLOW;
        statusStr = "WARNING";
      }

      const bar = makeProgressBar((vm - 0.85) / 0.30, 10);
      writeln(" ", bus.id: string, "\t| ", bus.name, "\t| ", color, vm, " ", bar, ANSI_RESET, "\t| ", va: string, "\t| ", color, statusStr, ANSI_RESET);
    }
    writeln("----------------------------------------------------------------");
  }

  // Prints transmission branch loading table
  proc printBranchLoadingDashboard(net: PowerNetwork, pfRes: SolutionMetrics) {
    writeln(ANSI_BOLD, ANSI_CYAN, "=== TRANSMISSION LINE LOADING ===", ANSI_RESET);
    writeln("Line ID | From -> To | Flow (MVA) | Rating | Loading % | Status");
    writeln("-----------------------------------------------------------------");

    for k in 0..<net.numBranches {
      const br = net.branches[k];
      const sFlow = pfRes.mvaLoading[k];
      const rating = br.rateA;
      const pct = pfRes.percentLoad[k];

      var color = ANSI_GREEN;
      var statusStr = "NORMAL";

      if pct > 100.0 {
        color = ANSI_RED;
        statusStr = "OVERLOAD";
      } else if pct > 80.0 {
        color = ANSI_YELLOW;
        statusStr = "HIGH";
      }

      const bar = makeProgressBar(pct / 100.0, 10);
      writeln(" ", br.id: string, "\t| ", br.fromBus: string, " -> ", br.toBus: string, "\t| ", sFlow, "\t| ", rating, "\t| ", color, pct, "% ", bar, ANSI_RESET, "\t| ", color, statusStr, ANSI_RESET);
    }
    writeln("-----------------------------------------------------------------");
  }

  // Prints master executive grid status banner
  proc printGridSummary(net: PowerNetwork, pfRes: SolutionMetrics) {
    const (pGen, qGen, pLoad, qLoad) = net.summary();

    var maxLoadPct: real = 0.0;
    var maxBranchIdx: int = 0;
    for k in 0..<net.numBranches {
      if pfRes.percentLoad[k] > maxLoadPct {
        maxLoadPct = pfRes.percentLoad[k];
        maxBranchIdx = k;
      }
    }

    var voltViolations = 0;
    for b in 0..<net.numBuses {
      if pfRes.vMag[b] < DEFAULT_V_MIN || pfRes.vMag[b] > DEFAULT_V_MAX {
        voltViolations += 1;
      }
    }

    writeln(ANSI_BOLD, "=================================================================", ANSI_RESET);
    writeln(ANSI_BOLD, ANSI_GREEN, " PHASOR ENERGY MANAGEMENT SYSTEM (EMS) STATUS SUMMARY", ANSI_RESET);
    writeln(ANSI_BOLD, "=================================================================", ANSI_RESET);
    writeln(" Active Network:          ", net.name);
    writeln(" Total Generation:        ", pGen, " MW / ", qGen, " MVAR");
    writeln(" Total Load:              ", pLoad, " MW / ", qLoad, " MVAR");
    writeln(" Total Network Losses:    ", pfRes.totalLossesP, " MW (", if pGen > 0 then (pfRes.totalLossesP / pGen) * 100.0 else 0.0, "%)");
    writeln(" Max Line Loading:        ", maxLoadPct, "% on Line ", maxBranchIdx + 1);
    writeln(" Voltage Limits Violation: ", if voltViolations > 0 then ANSI_RED else ANSI_GREEN, voltViolations, ANSI_RESET);
    writeln(ANSI_BOLD, "=================================================================", ANSI_RESET);
  }
}
