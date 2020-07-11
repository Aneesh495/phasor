/*
 * Network.chpl
 * Unified power grid network container and per-unit normalization.
 */

module Network {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Bus;
  use Branch;
  use Generator;
  use Load;
  use Shunt;
  use Topology;

  class PowerNetwork {
    var name: string;
    var baseMVA: real;
    var frequency: real;

    var numBuses: int;
    var numBranches: int;
    var numGenerators: int;
    var numLoads: int;
    var numShunts: int;

    var busDomain: domain(1);
    var buses: [busDomain] BusNode;

    var branchDomain: domain(1);
    var branches: [branchDomain] TransmissionBranch;

    var genDomain: domain(1);
    var generators: [genDomain] SynchronousGenerator;

    var loadDomain: domain(1);
    var loads: [loadDomain] ZIPLoad;

    var shuntDomain: domain(1);
    var shunts: [shuntDomain] SwitchedShunt;

    // ID mapping table (maps raw bus ID to contiguous index 0..<numBuses)
    var maxBusId: int;
    var mapDomain: domain(1);
    var busIdToIndex: [mapDomain] int;

    proc init(netName: string = "PowerNetwork", sBase: real = BASE_MVA, freq: real = SYS_FREQ) {
      this.name = netName;
      this.baseMVA = sBase;
      this.frequency = freq;
      this.numBuses = 0;
      this.numBranches = 0;
      this.numGenerators = 0;
      this.numLoads = 0;
      this.numShunts = 0;
      this.busDomain = 0..<0;
      this.branchDomain = 0..<0;
      this.genDomain = 0..<0;
      this.loadDomain = 0..<0;
      this.shuntDomain = 0..<0;
      this.maxBusId = 0;
      this.mapDomain = 0..<0;
    }

    // Set network component sizes and allocate arrays
    proc allocate(nb: int, nbr: int, ng: int, nl: int, ns: int, maxId: int) {
      this.numBuses = nb;
      this.numBranches = nbr;
      this.numGenerators = ng;
      this.numLoads = nl;
      this.numShunts = ns;
      this.maxBusId = maxId;

      this.busDomain = 0..<nb;
      this.branchDomain = 0..<nbr;
      this.genDomain = 0..<ng;
      this.loadDomain = 0..<nl;
      this.shuntDomain = 0..<ns;

      this.mapDomain = 0..maxId;
      for i in mapDomain do this.busIdToIndex[i] = -1;
    }

    // Maps bus ID to 0-based contiguous internal index
    proc getBusIndex(busId: int): int {
      if busId < 0 || busId > maxBusId then return -1;
      return busIdToIndex[busId];
    }

    // Computes total generation and load in MW and MVAR
    proc summary(): (real, real, real, real) {
      var totalPGen: real = 0.0;
      var totalQGen: real = 0.0;
      var totalPLoad: real = 0.0;
      var totalQLoad: real = 0.0;

      for g in generators {
        if g.status == 1 {
          totalPGen += g.pGen;
          totalQGen += g.qGen;
        }
      }

      for l in loads {
        if l.status == 1 {
          totalPLoad += l.pNom;
          totalQLoad += l.qNom;
        }
      }

      return (totalPGen, totalQGen, totalPLoad, totalQLoad);
    }
  }
}
