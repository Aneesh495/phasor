/*
 * OutageModel.chpl
 * Contingency outage definitions for single-branch, double-circuit, and generator trips.
 */

module OutageModel {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  enum ContingencyType {
    BranchOutage = 1,      // N-1 transmission line or transformer outage
    DoubleCircuitOutage = 2,// N-2 double-circuit tower trip
    GeneratorOutage = 3,   // N-1 sudden generation loss
    BusOutage = 4          // Bus breaker failure clearing all connected branches
  }

  record ContingencyCase {
    var id: int;
    var name: string;
    var cType: ContingencyType;
    var branchIdx1: int;
    var branchIdx2: int;
    var genIdx: int;
    var busIdx: int;

    proc init() {
      this.id = 0;
      this.name = "NONE";
      this.cType = ContingencyType.BranchOutage;
      this.branchIdx1 = -1;
      this.branchIdx2 = -1;
      this.genIdx = -1;
      this.busIdx = -1;
    }

    // N-1 branch outage constructor
    proc type branchTrip(cId: int, brIdx: int, cName: string = ""): ContingencyCase {
      var c = new ContingencyCase();
      c.id = cId;
      c.cType = ContingencyType.BranchOutage;
      c.branchIdx1 = brIdx;
      c.name = if cName != "" then cName else ("N-1 Branch " + brIdx:string);
      return c;
    }

    // N-2 double circuit trip constructor
    proc type doubleBranchTrip(cId: int, brIdx1: int, brIdx2: int, cName: string = ""): ContingencyCase {
      var c = new ContingencyCase();
      c.id = cId;
      c.cType = ContingencyType.DoubleCircuitOutage;
      c.branchIdx1 = brIdx1;
      c.branchIdx2 = brIdx2;
      c.name = if cName != "" then cName else ("N-2 Branches " + brIdx1:string + "+" + brIdx2:string);
      return c;
    }

    // N-1 generator trip constructor
    proc type generatorTrip(cId: int, gIdx: int, cName: string = ""): ContingencyCase {
      var c = new ContingencyCase();
      c.id = cId;
      c.cType = ContingencyType.GeneratorOutage;
      c.genIdx = gIdx;
      c.name = if cName != "" then cName else ("N-1 Gen " + gIdx:string);
      return c;
    }
  }
}
