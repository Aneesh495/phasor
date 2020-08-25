/*
 * VoltageCollapseIndex.chpl
 * Kessel-Glavitsch L-index for dynamic proximity to voltage collapse.
 */

module VoltageCollapseIndex {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use Bus;
  use Branch;
  use Network;
  use YBus;
  use SparseCSR;
  use PowerFlowResult;

  record VoltageCollapseAnalyzer {
    var numBuses: int;

    proc init(nb: int) {
      this.numBuses = nb;
    }

    // Computes L-index for all load buses (PQ buses)
    // L_j = | 1.0 - sum_{i in Generators} ( F_ji * (V_i / V_j) ) |
    // where F_LG = - [Y_LL]^-1 * [Y_LG]
    // An L-index value approaching 1.0 indicates impending voltage collapse
    proc computeLIndices(net: PowerNetwork,
                         ref ybus: ComplexCSRMatrix,
                         res: SolutionMetrics,
                         ref lIndices: [] real): (real, int) {
      const nb = net.numBuses;

      // Classify generator buses (PV + Slack) vs load buses (PQ)
      var genBuses: [0..<nb] bool = false;
      var loadBuses: [0..<nb] bool = false;

      for i in 0..<nb {
        if net.buses[i].busType == BusType.Slack || net.buses[i].busType == BusType.PV {
          genBuses[i] = true;
        } else if net.buses[i].busType == BusType.PQ {
          loadBuses[i] = true;
        }
      }

      var maxL: real = 0.0;
      var worstBus: int = -1;

      // For each load bus j, calculate L_j
      for j in 0..<nb {
        if loadBuses[j] {
          const vj = ComplexPhasor.fromPolar(res.vMag[j], res.vAngleRad[j]);
          var sumGenCoupling = new ComplexPhasor(0.0, 0.0);

          const startIdx = ybus.rowPtr[j];
          const endIdx = ybus.rowPtr[j + 1];

          // Diagonal Y_jj
          var yjj = ybus.get(j, j);

          for k in startIdx..<endIdx {
            const i = ybus.colInd[k];
            if genBuses[i] && i != j {
              const yji = ybus.values[k];
              const vi = ComplexPhasor.fromPolar(res.vMag[i], res.vAngleRad[i]);

              // Coupling ratio: F_ji approximation = -(Y_ji / Y_jj)
              const f_ji = -(yji / yjj);
              sumGenCoupling = sumGenCoupling + (f_ji * (vi / vj));
            }
          }

          // L_j = | 1.0 - sumGenCoupling |
          const onePhasor = new ComplexPhasor(1.0, 0.0);
          const diffPhasor = onePhasor - sumGenCoupling;
          const Lj = diffPhasor.magnitude();

          lIndices[j] = Lj;

          if Lj > maxL {
            maxL = Lj;
            worstBus = j;
          }
        } else {
          lIndices[j] = 0.0; // Generators have zero collapse risk (voltage controlled)
        }
      }

      return (maxL, worstBus);
    }
  }
}
