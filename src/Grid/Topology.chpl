/*
 * Topology.chpl
 * Disjoint-Set Union-Find (DSU) grid topology processor and electrical island detector.
 */

module Topology {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Bus;
  use Branch;

  record DisjointSet {
    var numNodes: int;
    var parentDomain: domain(1);
    var parent: [parentDomain] int;
    var rankDomain: domain(1);
    var rank: [rankDomain] int;

    proc init(n: int) {
      this.numNodes = n;
      this.parentDomain = 0..<n;
      this.parent = [i in 0..<n] i;
      this.rankDomain = 0..<n;
      this.rank = 0;
    }

    // Find root representative with path compression
    proc ref find(x: int): int {
      if x < 0 || x >= numNodes then return x;
      if parent[x] != x {
        parent[x] = find(parent[x]);
      }
      return parent[x];
    }

    // Union two components by rank
    proc ref unionNodes(x: int, y: int): bool {
      const rootX = find(x);
      const rootY = find(y);

      if rootX == rootY then return false; // Already in same component

      if rank[rootX] < rank[rootY] {
        parent[rootX] = rootY;
      } else if rank[rootX] > rank[rootY] {
        parent[rootY] = rootX;
      } else {
        parent[rootY] = rootX;
        rank[rootX] += 1;
      }
      return true;
    }

    // Check if two nodes belong to the same connected component
    proc ref connected(x: int, y: int): bool {
      return find(x) == find(y);
    }
  }

  record GridIsland {
    var id: int;
    var rootBusIndex: int;
    var busCount: int;
    var hasSlack: bool;
    var totalPGen: real;
    var totalPLoad: real;
  }

  record TopologyProcessor {
    var numBuses: int;
    var dsu: DisjointSet;

    proc init(nb: int) {
      this.numBuses = nb;
      this.dsu = new DisjointSet(nb);
    }

    // Builds connected electrical islands from bus and branch records
    proc ref analyzeTopology(buses: [] BusNode,
                             branches: [] TransmissionBranch,
                             busIdToIndex: [] int): (int, GridError) {
      // Re-initialize DSU
      for i in 0..<numBuses {
        dsu.parent[i] = i;
        dsu.rank[i] = 0;
      }

      // Connect buses through in-service branches
      for br in branches {
        if br.status == 1 {
          const u = busIdToIndex[br.fromBus];
          const v = busIdToIndex[br.toBus];
          if u >= 0 && u < numBuses && v >= 0 && v < numBuses {
            dsu.unionNodes(u, v);
          }
        }
      }

      // Count unique islands and verify reference slack bus in each energized island
      var islandRoots: [0..<numBuses] bool = false;
      var hasSlackInIsland: [0..<numBuses] bool = false;
      var islandBusCount: [0..<numBuses] int = 0;

      for i in 0..<numBuses {
        const root = dsu.find(i);
        islandRoots[root] = true;
        islandBusCount[root] += 1;
        if buses[i].busType == BusType.Slack {
          hasSlackInIsland[root] = true;
        }
      }

      var numIslands: int = 0;
      var hasUnslackIsland: bool = false;

      for i in 0..<numBuses {
        if islandRoots[i] && islandBusCount[i] > 1 {
          numIslands += 1;
          if !hasSlackInIsland[i] {
            hasUnslackIsland = true;
          }
        }
      }

      if hasUnslackIsland {
        return (numIslands, new GridError(
          PhasorStatus.TopologicalIslandDetected,
          "Electrical island detected without reference slack bus",
          "TopologyProcessor",
          0,
          true
        ));
      }

      return (numIslands, new GridError(PhasorStatus.Success, "Topology healthy", "TopologyProcessor"));
    }
  }
}
