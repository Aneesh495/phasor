/*
 * MeasurementJacobian.chpl
 * Assembly of measurement Jacobian H-matrix for non-linear state estimation.
 */

module MeasurementJacobian {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use SparseCSR;
  use Bus;
  use Branch;
  use Network;
  use YBus;
  use Measurement;

  record JacobianEngine {
    var numBuses: int;
    var numMeasurements: int;
    var stateDim: int; // (numBuses - 1) angles + numBuses voltages = 2*nb - 1

    proc init(nb: int, nm: int) {
      this.numBuses = nb;
      this.numMeasurements = nm;
      this.stateDim = 2 * nb - 1;
    }

    // Evaluates non-linear measurement function h(x)
    proc evaluateH(net: PowerNetwork,
                   ref ybus: ComplexCSRMatrix,
                   vMag: [] real,
                   vAngle: [] real,
                   measurements: [] GridMeasurement,
                   ref hx: [] real) {
      const nb = net.numBuses;

      for mIdx in 0..<measurements.size {
        const m = measurements[mIdx];
        if m.isSuspect {
          hx[mIdx] = 0.0;
          continue;
        }

        select m.measType {
          when MeasurementType.BusVoltageMag {
            hx[mIdx] = vMag[m.busIdx];
          }
          when MeasurementType.BusVoltageAngle {
            hx[mIdx] = vAngle[m.busIdx];
          }
          when MeasurementType.ActiveBusInjection {
            const i = m.busIdx;
            const vi = vMag[i];
            const theta_i = vAngle[i];
            var p_sum: real = 0.0;
            const startIdx = ybus.rowPtr[i];
            const endIdx = ybus.rowPtr[i + 1];

            for k in startIdx..<endIdx {
              const j = ybus.colInd[k];
              const vj = vMag[j];
              const theta_j = vAngle[j];
              const theta_ij = theta_i - theta_j;
              const G = ybus.values[k].re;
              const B = ybus.values[k].im;
              p_sum += vj * (G * cos(theta_ij) + B * sin(theta_ij));
            }
            hx[mIdx] = vi * p_sum * net.baseMVA;
          }
          when MeasurementType.ReactiveBusInjection {
            const i = m.busIdx;
            const vi = vMag[i];
            const theta_i = vAngle[i];
            var q_sum: real = 0.0;
            const startIdx = ybus.rowPtr[i];
            const endIdx = ybus.rowPtr[i + 1];

            for k in startIdx..<endIdx {
              const j = ybus.colInd[k];
              const vj = vMag[j];
              const theta_j = vAngle[j];
              const theta_ij = theta_i - theta_j;
              const G = ybus.values[k].re;
              const B = ybus.values[k].im;
              q_sum += vj * (G * sin(theta_ij) - B * cos(theta_ij));
            }
            hx[mIdx] = vi * q_sum * net.baseMVA;
          }
          when MeasurementType.ActiveBranchFlow {
            const k = m.fromBusIdx;
            const j = m.toBusIdx;
            const br = net.branches[m.branchIdx];
            const vk = ComplexPhasor.fromPolar(vMag[k], vAngle[k]);
            const vj = ComplexPhasor.fromPolar(vMag[j], vAngle[j]);
            const ySeries = br.seriesAdmittance();
            const yChargeHalf = br.halfCharging();
            const ikj = (vk - vj) * ySeries + vk * yChargeHalf;
            const skj = vk * ikj.conjugate() * net.baseMVA;
            hx[mIdx] = skj.re;
          }
          when MeasurementType.ReactiveBranchFlow {
            const k = m.fromBusIdx;
            const j = m.toBusIdx;
            const br = net.branches[m.branchIdx];
            const vk = ComplexPhasor.fromPolar(vMag[k], vAngle[k]);
            const vj = ComplexPhasor.fromPolar(vMag[j], vAngle[j]);
            const ySeries = br.seriesAdmittance();
            const yChargeHalf = br.halfCharging();
            const ikj = (vk - vj) * ySeries + vk * yChargeHalf;
            const skj = vk * ikj.conjugate() * net.baseMVA;
            hx[mIdx] = skj.im;
          }
          otherwise {
            hx[mIdx] = 0.0;
          }
        }
      }
    }

    // Numerical finite-difference assembly of measurement Jacobian H (M x N)
    proc buildJacobian(net: PowerNetwork,
                       ref ybus: ComplexCSRMatrix,
                       ref vMag: [] real,
                       ref vAngle: [] real,
                       measurements: [] GridMeasurement): [0..<measurements.size, 0..<stateDim] real {
      const nm = measurements.size;
      const nb = net.numBuses;
      const eps: real = 1.0e-6;

      var H: [0..<nm, 0..<stateDim] real = 0.0;
      var h0: [0..<nm] real;
      evaluateH(net, ybus, vMag, vAngle, measurements, h0);

      // Perturb angles theta_2 .. theta_nb (state indices 0 .. nb-2)
      for col in 0..<nb-1 {
        const busIdx = col + 1; // Slack bus is index 0
        vAngle[busIdx] += eps;
        var hPert: [0..<nm] real;
        evaluateH(net, ybus, vMag, vAngle, measurements, hPert);
        vAngle[busIdx] -= eps; // Restore

        for r in 0..<nm {
          H[r, col] = (hPert[r] - h0[r]) / eps;
        }
      }

      // Perturb voltage magnitudes V_1 .. V_nb (state indices nb-1 .. 2*nb - 2)
      for col in 0..<nb {
        const busIdx = col;
        const stateCol = (nb - 1) + col;
        vMag[busIdx] += eps;
        var hPert: [0..<nm] real;
        evaluateH(net, ybus, vMag, vAngle, measurements, hPert);
        vMag[busIdx] -= eps; // Restore

        for r in 0..<nm {
          H[r, stateCol] = (hPert[r] - h0[r]) / eps;
        }
      }

      return H;
    }
  }
}
