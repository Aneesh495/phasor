/*
 * Shunt.chpl
 * Switched shunt capacitor and reactor banks for reactive power and voltage control.
 */

module Shunt {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  record SwitchedShunt {
    var id: int;
    var busId: int;
    var status: int;          // 1 = in service, 0 = bypassed
    var targetV: real;        // Regulated target voltage in pu
    var vDeadband: real;      // Deadband around target voltage (pu)
    var numSteps: int;        // Number of available discrete switching steps
    var currentStep: int;     // Active engaged step
    var bPerStep: real;       // Susceptance per step in MVAR at 1.0 pu
    var gFixed: real;         // Fixed shunt conductance (MW at 1.0 pu)
    var bFixed: real;         // Fixed shunt susceptance (MVAR at 1.0 pu)

    proc init() {
      this.id = 0;
      this.busId = 0;
      this.status = 1;
      this.targetV = 1.0;
      this.vDeadband = 0.02;
      this.numSteps = 4;
      this.currentStep = 0;
      this.bPerStep = 10.0;
      this.gFixed = 0.0;
      this.bFixed = 0.0;
    }

    proc init(sId: int,
              bId: int,
              steps: int,
              mvarStep: real,
              gFix: real = 0.0,
              bFix: real = 0.0,
              vTarg: real = 1.0,
              deadband: real = 0.02,
              inService: int = 1) {
      this.id = sId;
      this.busId = bId;
      this.status = inService;
      this.targetV = vTarg;
      this.vDeadband = deadband;
      this.numSteps = steps;
      this.currentStep = 0;
      this.bPerStep = mvarStep;
      this.gFixed = gFix;
      this.bFixed = bFix;
    }

    // Total effective susceptance in MVAR at 1.0 pu
    inline proc totalB(): real {
      if status == 0 then return 0.0;
      return bFixed + (currentStep: real * bPerStep);
    }

    // Total effective conductance in MW at 1.0 pu
    inline proc totalG(): real {
      if status == 0 then return 0.0;
      return gFixed;
    }

    // Adjusts step to regulate bus voltage towards target
    proc ref adjustStep(measuredV: real) {
      if status == 0 then return;
      if measuredV < (targetV - vDeadband) && currentStep < numSteps {
        currentStep += 1; // Inject more capacitive reactive power to raise voltage
      } else if measuredV > (targetV + vDeadband) && currentStep > 0 {
        currentStep -= 1; // Decrease capacitive injection to lower voltage
      }
    }
  }
}
