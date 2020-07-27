/*
 * PowerFlowResult.chpl
 * Encapsulates AC and DC power flow solution states, mismatches, and branch flows.
 */

module PowerFlowResult {
  use Math;
  use PhasorConstants;
  use PhasorTypes;
  use Bus;
  use Branch;
  use Network;

  record SolutionMetrics {
    var converged: bool;
    var iterations: int;
    var maxMismatchP: real;
    var maxMismatchQ: real;
    var elapsedMs: real;

    var numBuses: int;
    var numBranches: int;

    var vDomain: domain(1);
    var vMag: [vDomain] real;
    var vAngleRad: [vDomain] real;

    var brDomain: domain(1);
    var pFrom: [brDomain] real;      // Active power flow from bus (MW)
    var qFrom: [brDomain] real;      // Reactive power flow from bus (MVAR)
    var pTo: [brDomain] real;        // Active power flow to bus (MW)
    var qTo: [brDomain] real;        // Reactive power flow to bus (MVAR)
    var mvaLoading: [brDomain] real; // Apparent power loading in MVA
    var percentLoad: [brDomain] real;// Percent of thermal rating RateA

    var totalLossesP: real;          // Total active transmission losses in MW
    var totalLossesQ: real;          // Total reactive transmission losses in MVAR

    proc init(nb: int, nbr: int) {
      this.converged = false;
      this.iterations = 0;
      this.maxMismatchP = 0.0;
      this.maxMismatchQ = 0.0;
      this.elapsedMs = 0.0;
      this.numBuses = nb;
      this.numBranches = nbr;
      this.vDomain = 0..<nb;
      this.vMag = 1.0;
      this.vAngleRad = 0.0;
      this.brDomain = 0..<nbr;
      this.pFrom = 0.0;
      this.qFrom = 0.0;
      this.pTo = 0.0;
      this.qTo = 0.0;
      this.mvaLoading = 0.0;
      this.percentLoad = 0.0;
      this.totalLossesP = 0.0;
      this.totalLossesQ = 0.0;
    }

    // Computes all branch terminal flows and total network losses from bus voltages
    proc ref computeBranchFlows(net: PowerNetwork) {
      totalLossesP = 0.0;
      totalLossesQ = 0.0;

      for i in 0..<net.numBranches {
        const br = net.branches[i];
        if br.status == 0 {
          pFrom[i] = 0.0;
          qFrom[i] = 0.0;
          pTo[i] = 0.0;
          qTo[i] = 0.0;
          mvaLoading[i] = 0.0;
          percentLoad[i] = 0.0;
          continue;
        }

        const k = net.getBusIndex(br.fromBus);
        const m = net.getBusIndex(br.toBus);

        const vk = ComplexPhasor.fromPolar(vMag[k], vAngleRad[k]);
        const vm = ComplexPhasor.fromPolar(vMag[m], vAngleRad[m]);

        const ySeries = br.seriesAdmittance();
        const yChargeHalf = br.halfCharging();
        const a = br.complexRatio();

        // Terminal current from bus k:
        // I_km = (V_k / a - V_m) * (ySeries / a*) + (V_k / a) * yChargeHalf / a*
        const aMagSq = a.magnitudeSq();
        const aConj = a.conjugate();

        const ikm = (vk / a - vm) * (ySeries / aConj) + (vk / a) * (yChargeHalf / aConj);
        const skm = vk * ikm.conjugate() * net.baseMVA;

        pFrom[i] = skm.re;
        qFrom[i] = skm.im;

        // Terminal current to bus m:
        // I_mk = (V_m - V_k / a) * ySeries + V_m * yChargeHalf
        const imk = (vm - (vk / a)) * ySeries + vm * yChargeHalf;
        const smk = vm * imk.conjugate() * net.baseMVA;

        pTo[i] = smk.re;
        qTo[i] = smk.im;

        const sFromMag = skm.magnitude();
        const sToMag = smk.magnitude();
        const maxFlow = if sFromMag > sToMag then sFromMag else sToMag;

        mvaLoading[i] = maxFlow;
        percentLoad[i] = (maxFlow / br.rateA) * 100.0;

        totalLossesP += (skm.re + smk.re);
        totalLossesQ += (skm.im + smk.im);
      }
    }
  }
}
