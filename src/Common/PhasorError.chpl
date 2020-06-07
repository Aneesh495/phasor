/*
 * PhasorError.chpl
 * Structured diagnostic codes and exception handling for Phasor engine.
 */

module PhasorError {
  enum PhasorStatus {
    Success = 0,
    ConvergenceFailure = 1,
    IllConditionedMatrix = 2,
    BadDataDetected = 3,
    TopologicalIslandDetected = 4,
    ContingencyViolation = 5,
    InvalidInput = 6,
    IOFailure = 7
  }

  record GridError {
    var status: PhasorStatus;
    var message: string;
    var subsystem: string;
    var entityId: int;
    var isFatal: bool;

    proc init() {
      this.status = PhasorStatus.Success;
      this.message = "OK";
      this.subsystem = "None";
      this.entityId = 0;
      this.isFatal = false;
    }

    proc init(stat: PhasorStatus, msg: string, sub: string = "Core", id: int = 0, fatal: bool = false) {
      this.status = stat;
      this.message = msg;
      this.subsystem = sub;
      this.entityId = id;
      this.isFatal = fatal;
    }

    proc isOk(): bool {
      return status == PhasorStatus.Success;
    }

    proc toString(): string {
      return "[" + subsystem + ":" + status:string + "] " + message + " (Entity: " + entityId:string + ")";
    }
  }
}
