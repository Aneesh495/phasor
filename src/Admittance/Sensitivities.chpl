/*
 * Sensitivities.chpl
 * Sensitivity analysis computing PTDF and LODF matrices for real-time security.
 */

module Sensitivities {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use SparseLU;
  use Network;

  record SensitivityEngine {
    var numBuses: int;
    var numBranches: int;
    var slackIndex: int;

    proc init(nb: int, nbr: int, slackIdx: int = 0) {
      this.numBuses = nb;
      this.numBranches = nbr;
      this.slackIndex = slackIdx;
    }

    // Computes the DC B_bus matrix (excluding slack bus row and column)
    proc buildBPrime(net: PowerNetwork): (SparseCSRMatrix, DenseFactorizer) {
      const nRed = numBuses - 1;
      var denseB: [0..<nRed, 0..<nRed] real = 0.0;

      // Map from full bus index to reduced index (omitting slack)
      var redMap: [0..<numBuses] int;
      var curIdx: int = 0;
      for i in 0..<numBuses {
        if i == slackIndex {
          redMap[i] = -1;
        } else {
          redMap[i] = curIdx;
          curIdx += 1;
        }
      }

      for br in net.branches {
        if br.status == 1 {
          const k = net.getBusIndex(br.fromBus);
          const m = net.getBusIndex(br.toBus);
          const bSeries = 1.0 / br.x; // Invert reactance (neglect resistance in DC model)

          const rk = redMap[k];
          const rm = redMap[m];

          if rk >= 0 && rm >= 0 {
            denseB[rk, rk] += bSeries;
            denseB[rm, rm] += bSeries;
            denseB[rk, rm] -= bSeries;
            denseB[rm, rk] -= bSeries;
          } else if rk >= 0 {
            denseB[rk, rk] += bSeries;
          } else if rm >= 0 {
            denseB[rm, rm] += bSeries;
          }
        }
      }

      // Convert to CSR
      var rPtr: [0..nRed] int;
      rPtr[0] = 0;
      for r in 0..<nRed {
        var count: int = 0;
        for c in 0..<nRed {
          if abs(denseB[r, c]) > 1.0e-9 then count += 1;
        }
        rPtr[r + 1] = rPtr[r] + count;
      }
      const nnz = rPtr[nRed];

      var cInd: [0..<nnz] int;
      var vals: [0..<nnz] real;
      var idx: int = 0;
      for r in 0..<nRed {
        for c in 0..<nRed {
          if abs(denseB[r, c]) > 1.0e-9 {
            cInd[idx] = c;
            vals[idx] = denseB[r, c];
            idx += 1;
          }
        }
      }

      var bPrimeCSR = new SparseCSRMatrix(nRed, nRed, rPtr, cInd, vals);
      var lu = new DenseFactorizer(nRed);
      lu.loadFromCSR(bPrimeCSR);
      var err = lu.factorize();

      return (bPrimeCSR, lu);
    }

    // Computes PTDF of branch brIdx for power transfer from bus i to bus j
    // PTDF_{l, i->j} = (X_ki - X_kj - X_mi + X_mj) / x_l
    proc computePTDF(net: PowerNetwork,
                    ref lu: DenseFactorizer,
                    brIdx: int,
                    srcBus: int,
                    dstBus: int): real {
      const br = net.branches[brIdx];
      const k = net.getBusIndex(br.fromBus);
      const m = net.getBusIndex(br.toBus);
      const nRed = numBuses - 1;

      // Construct injection vector: +1 at srcBus, -1 at dstBus
      var pInj: [0..<nRed] real = 0.0;
      var curIdx: int = 0;
      for i in 0..<numBuses {
        if i != slackIndex {
          if i == srcBus then pInj[curIdx] = 1.0;
          if i == dstBus then pInj[curIdx] = -1.0;
          curIdx += 1;
        }
      }

      var thetaRed: [0..<nRed] real;
      lu.solve(pInj, thetaRed);

      // Reconstruct full theta with theta[slack] = 0.0
      var thetaFull: [0..<numBuses] real = 0.0;
      curIdx = 0;
      for i in 0..<numBuses {
        if i == slackIndex {
          thetaFull[i] = 0.0;
        } else {
          thetaFull[i] = thetaRed[curIdx];
          curIdx += 1;
        }
      }

      // Flow change on branch: (theta_k - theta_m) / x_br
      return (thetaFull[k] - thetaFull[m]) / br.x;
    }

    // Computes Line Outage Distribution Factor (LODF) of monitored branch l
    // under the outage of line k
    // LODF_{l, k} = PTDF_{l, from(k) -> to(k)} / (1.0 - PTDF_{k, from(k) -> to(k)})
    proc computeLODF(net: PowerNetwork,
                     ref lu: DenseFactorizer,
                     monitoredBrIdx: int,
                     outageBrIdx: int): real {
      const outBr = net.branches[outageBrIdx];
      const k = net.getBusIndex(outBr.fromBus);
      const m = net.getBusIndex(outBr.toBus);

      const ptdf_l = computePTDF(net, lu, monitoredBrIdx, k, m);
      const ptdf_k = computePTDF(net, lu, outageBrIdx, k, m);

      const denom = 1.0 - ptdf_k;
      if abs(denom) < 1.0e-6 {
        return 0.0; // Islanding or radial disconnect
      }
      return ptdf_l / denom;
    }
  }
}
