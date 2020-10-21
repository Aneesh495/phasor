/*
 * ResultExporter.chpl
 * JSON and CSV telemetry and simulation result exporters.
 */

module ResultExporter {
  use Math;
  use IO;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Network;
  use PowerFlowResult;
  use ContingencyScreening;

  // Exports power flow solution to JSON format
  proc exportPowerFlowJSON(net: PowerNetwork, pfRes: SolutionMetrics, filepath: string): GridError {
    try {
      var f = open(filepath, ioMode.cw);
      var w = f.writer();

      const (pGen, qGen, pLoad, qLoad) = net.summary();

      var maxLoadPct: real = 0.0;
      for k in 0..<net.numBranches {
        if pfRes.percentLoad[k] > maxLoadPct then maxLoadPct = pfRes.percentLoad[k];
      }

      w.writeln("{");
      w.writeln("  \"network\": \"", net.name, "\",");
      w.writeln("  \"converged\": ", pfRes.converged, ",");
      w.writeln("  \"iterations\": ", pfRes.iterations, ",");
      w.writeln("  \"elapsedMs\": ", pfRes.elapsedMs, ",");
      w.writeln("  \"totalGenMW\": ", pGen, ",");
      w.writeln("  \"totalLoadMW\": ", pLoad, ",");
      w.writeln("  \"totalLossMW\": ", pfRes.totalLossesP, ",");
      w.writeln("  \"maxBranchLoadingPct\": ", maxLoadPct, ",");

      // Buses
      w.writeln("  \"buses\": [");
      for b in 0..<net.numBuses {
        const bus = net.buses[b];
        const vaDeg = pfRes.vAngleRad[b] * RAD_TO_DEG;
        w.write("    {\"id\": ", bus.id, ", \"vm\": ", pfRes.vMag[b], ", \"va\": ", vaDeg, "}");
        if b < net.numBuses - 1 then w.writeln(","); else w.writeln();
      }
      w.writeln("  ],");

      // Branches
      w.writeln("  \"branches\": [");
      for k in 0..<net.numBranches {
        const br = net.branches[k];
        w.write("    {\"id\": ", br.id, ", \"from\": ", br.fromBus, ", \"to\": ", br.toBus,
                ", \"sFlowMVA\": ", pfRes.mvaLoading[k], ", \"percentLoad\": ", pfRes.percentLoad[k], "}");
        if k < net.numBranches - 1 then w.writeln(","); else w.writeln();
      }
      w.writeln("  ]");
      w.writeln("}");

      w.close();
      f.close();
      return new GridError(PhasorStatus.Success, "Power flow exported to JSON", "ResultExporter");
    } catch e {
      return new GridError(PhasorStatus.IOFailure, "Failed to write JSON output", "ResultExporter");
    }
  }

  // Exports power flow solution to CSV format (bus and branch tables)
  proc exportPowerFlowCSV(net: PowerNetwork, pfRes: SolutionMetrics, busCsv: string, branchCsv: string): GridError {
    try {
      // Bus table
      var fb = open(busCsv, ioMode.cw);
      var wb = fb.writer();
      wb.writeln("bus_id,name,vm_pu,va_deg,p_gen_mw,q_gen_mvar,p_load_mw,q_load_mvar");
      for b in 0..<net.numBuses {
        const bus = net.buses[b];
        const vaDeg = pfRes.vAngleRad[b] * RAD_TO_DEG;
        wb.writeln(bus.id, ",", bus.name, ",", pfRes.vMag[b], ",", vaDeg, ",",
                   bus.pGen, ",", bus.qGen, ",", bus.pLoad, ",", bus.qLoad);
      }
      wb.close();
      fb.close();

      // Branch table
      var fl = open(branchCsv, ioMode.cw);
      var wl = fl.writer();
      wl.writeln("branch_id,from_bus,to_bus,p_from_mw,q_from_mvar,p_to_mw,q_to_mvar,s_flow_mva,loading_pct");
      for k in 0..<net.numBranches {
        const br = net.branches[k];
        wl.writeln(br.id, ",", br.fromBus, ",", br.toBus, ",", pfRes.pFrom[k], ",",
                   pfRes.qFrom[k], ",", pfRes.pTo[k], ",", pfRes.qTo[k], ",",
                   pfRes.mvaLoading[k], ",", pfRes.percentLoad[k]);
      }
      wl.close();
      fl.close();

      return new GridError(PhasorStatus.Success, "Power flow exported to CSV", "ResultExporter");
    } catch e {
      return new GridError(PhasorStatus.IOFailure, "Failed to write CSV output", "ResultExporter");
    }
  }

  // Exports contingency screening report to JSON
  proc exportContingencyJSON(rep: ContingencyReport, filepath: string): GridError {
    try {
      var f = open(filepath, ioMode.cw);
      var w = f.writer();

      w.writeln("{");
      w.writeln("  \"totalScreened\": ", rep.totalEvaluated, ",");
      w.writeln("  \"violatingCount\": ", rep.violatingCount, ",");
      w.writeln("  \"maxActivePIP\": ", rep.maxActivePIP, ",");
      w.writeln("  \"maxVoltagePIV\": ", rep.maxVoltagePIV, ",");
      w.writeln("  \"worstContingencyId\": ", rep.worstContingencyId, ",");
      w.writeln("  \"elapsedMs\": ", rep.elapsedMs, ",");
      w.writeln("  \"contingencies\": [");

      for c in 0..<rep.totalEvaluated {
        const eval = rep.evaluations[c];
        w.write("    {\"id\": ", eval.outage.id, ", \"desc\": \"", eval.outage.description,
                "\", \"hasViolation\": ", eval.hasViolation,
                ", \"piP\": ", eval.piP, ", \"piV\": ", eval.piV,
                ", \"maxLIndex\": ", eval.maxLIndex, "}");
        if c < rep.totalEvaluated - 1 then w.writeln(","); else w.writeln();
      }

      w.writeln("  ]");
      w.writeln("}");

      w.close();
      f.close();
      return new GridError(PhasorStatus.Success, "Contingency report exported to JSON", "ResultExporter");
    } catch e {
      return new GridError(PhasorStatus.IOFailure, "Failed to write contingency JSON", "ResultExporter");
    }
  }
}
