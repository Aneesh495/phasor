/*
 * YBus.chpl
 * Sparse complex nodal admittance matrix (Y_bus = G + jB) builder.
 */

module YBus {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use Bus;
  use Branch;
  use Network;

  record YBusBuilder {
    var numBuses: int;

    proc init(nb: int) {
      this.numBuses = nb;
    }

    // Constructs the complex nodal admittance matrix as a ComplexCSRMatrix
    proc buildYBus(net: PowerNetwork): (ComplexCSRMatrix, SparseCSRMatrix, SparseCSRMatrix) {
      const nb = net.numBuses;
      var denseY: [0..<nb, 0..<nb] ComplexPhasor = new ComplexPhasor(0.0, 0.0);

      // 1. Process all in-service transmission branches
      for br in net.branches {
        if br.status == 1 {
          const k = net.getBusIndex(br.fromBus);
          const m = net.getBusIndex(br.toBus);

          if k >= 0 && k < nb && m >= 0 && m < nb {
            const ySeries = br.seriesAdmittance();
            const yChargingHalf = br.halfCharging();
            const a = br.complexRatio();
            const aMagSq = a.magnitudeSq();

            if abs(br.ratio - 1.0) < 1e-5 && abs(br.phaseShiftRad) < 1e-5 {
              // Standard transmission line
              // Diagonal additions: Y_kk += y_km + j*(b/2), Y_mm += y_km + j*(b/2)
              denseY[k, k] = denseY[k, k] + ySeries + yChargingHalf;
              denseY[m, m] = denseY[m, m] + ySeries + yChargingHalf;

              // Off-diagonal additions: Y_km -= y_km, Y_mk -= y_km
              denseY[k, m] = denseY[k, m] - ySeries;
              denseY[m, k] = denseY[m, k] - ySeries;
            } else {
              // Transformer with off-nominal turns ratio or phase shift
              // Y_kk += y_km / |a|^2
              denseY[k, k] = denseY[k, k] + (ySeries / aMagSq);
              // Y_mm += y_km
              denseY[m, m] = denseY[m, m] + ySeries;

              // Y_km -= y_km / a*
              const aConj = a.conjugate();
              denseY[k, m] = denseY[k, m] - (ySeries / aConj);
              // Y_mk -= y_km / a
              denseY[m, k] = denseY[m, k] - (ySeries / a);
            }
          }
        }
      }

      // 2. Add bus shunt admittances (loads and capacitor banks)
      for b in net.buses {
        const k = net.getBusIndex(b.id);
        if k >= 0 && k < nb {
          const gShuntPu = b.gShunt / net.baseMVA;
          const bShuntPu = b.bShunt / net.baseMVA;
          denseY[k, k] = denseY[k, k] + new ComplexPhasor(gShuntPu, bShuntPu);
        }
      }

      // 3. Count non-zeros and assemble CSR structures
      var nnz: int = 0;
      var rPtr: [0..nb] int;
      rPtr[0] = 0;

      for r in 0..<nb {
        var count: int = 0;
        for c in 0..<nb {
          if denseY[r, c].magnitudeSq() > 1.0e-12 {
            count += 1;
          }
        }
        rPtr[r + 1] = rPtr[r] + count;
      }
      nnz = rPtr[nb];

      var cInd: [0..<nnz] int;
      var valsComplex: [0..<nnz] ComplexPhasor;
      var valsG: [0..<nnz] real;
      var valsB: [0..<nnz] real;

      var idx: int = 0;
      for r in 0..<nb {
        for c in 0..<nb {
          const yVal = denseY[r, c];
          if yVal.magnitudeSq() > 1.0e-12 {
            cInd[idx] = c;
            valsComplex[idx] = yVal;
            valsG[idx] = yVal.re;
            valsB[idx] = yVal.im;
            idx += 1;
          }
        }
      }

      var ybusCSR = new ComplexCSRMatrix(nb, nb, rPtr, cInd, valsComplex);
      var gbusCSR = new SparseCSRMatrix(nb, nb, rPtr, cInd, valsG);
      var bbusCSR = new SparseCSRMatrix(nb, nb, rPtr, cInd, valsB);

      return (ybusCSR, gbusCSR, bbusCSR);
    }
  }
}
