/*
 * Measurement.chpl
 * Grid measurement telemetry records with standard deviations and covariance weighting.
 */

module Measurement {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record GridMeasurement {
    var id: int;
    var measType: MeasurementType;
    var busIdx: int;          // Associated bus index (-1 if branch flow)
    var fromBusIdx: int;      // For branch flow measurements
    var toBusIdx: int;        // For branch flow measurements
    var branchIdx: int;       // Branch index (-1 if bus measurement)
    var z: real;              // Raw measurement value
    var sigma: real;          // Standard deviation
    var weight: real;         // W_ii = 1.0 / (sigma * sigma)
    var isPMU: bool;          // True if high-speed synchrophasor
    var isSuspect: bool;      // True if rejected by bad data detection

    proc init() {
      this.id = 0;
      this.measType = MeasurementType.BusVoltageMag;
      this.busIdx = 0;
      this.fromBusIdx = -1;
      this.toBusIdx = -1;
      this.branchIdx = -1;
      this.z = 1.0;
      this.sigma = 0.01;
      this.weight = 10000.0;
      this.isPMU = false;
      this.isSuspect = false;
    }

    proc init(mId: int,
              mType: MeasurementType,
              bIdx: int,
              val: real,
              stdDev: real = 0.01,
              fromB: int = -1,
              toB: int = -1,
              brIdx: int = -1,
              pmu: bool = false) {
      this.id = mId;
      this.measType = mType;
      this.busIdx = bIdx;
      this.fromBusIdx = fromB;
      this.toBusIdx = toB;
      this.branchIdx = brIdx;
      this.z = val;
      this.sigma = if stdDev <= 0.0 then 0.01 else stdDev;
      this.weight = 1.0 / (this.sigma * this.sigma);
      this.isPMU = pmu;
      this.isSuspect = false;
    }
  }
}
