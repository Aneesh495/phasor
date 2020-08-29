/*
 * TransientSimulator.chpl
 * Multi-machine non-linear transient stability simulation via 4th-order Runge-Kutta (RK4).
 */

module TransientSimulator {
  use Math;
  use Time;
  use PhasorConstants;
  use PhasorTypes;
  use PhasorError;
  use Bus;
  use Branch;
  use Generator;
  use Network;
  use MachineModels;
  use ExciterModels;
  use GovernorModels;

  record TransientResult {
    var isStable: bool;
    var criticalClearingTimeExceeded: bool;
    var maxRotorSeparationDeg: real;
    var worstMachineId: int;
    var simulationTimeSec: real;
    var timeStepsTaken: int;
    var elapsedMs: real;

    var stepDomain: domain(1);
    var timeArray: [stepDomain] real;
    var step2DDomain: domain(2);
    var angleDegArray: [step2DDomain] real; // Rotor angles of machines
    var speedPuArray: [step2DDomain] real;  // Rotor speeds of machines

    proc init(numSteps: int) {
      this.isStable = true;
      this.criticalClearingTimeExceeded = false;
      this.maxRotorSeparationDeg = 0.0;
      this.worstMachineId = 0;
      this.simulationTimeSec = 0.0;
      this.timeStepsTaken = numSteps;
      this.elapsedMs = 0.0;
      this.stepDomain = 0..<numSteps;
      this.timeArray = 0.0;
      this.step2DDomain = {0..<numSteps, 0..2};
      this.angleDegArray = 0.0;
      this.speedPuArray = 1.0;
    }
  }

  record MultiMachineSimulator {
    var dt: real;
    var tEnd: real;
    var faultTime: real;
    var clearTime: real;
    var faultBusIdx: int;

    proc init(stepSize: real = DYNAMICS_DT,
              simDuration: real = 2.0,
              tFlt: real = 0.20,
              tClr: real = 0.35,
              fltBus: int = 2) {
      this.dt = stepSize;
      this.tEnd = simDuration;
      this.faultTime = tFlt;
      this.clearTime = tClr;
      this.faultBusIdx = fltBus;
    }

    // Simulates multi-machine transient stability using classical generator models and RK4
    proc simulate(net: PowerNetwork): (TransientResult, GridError) {
      var timer: stopwatch;
      timer.start();

      const numSteps = (tEnd / dt): int;
      var result = new TransientResult(numSteps);

      const numG = net.numGenerators;
      var machines: [0..<numG] ClassicalMachine;
      var states: [0..<numG] ClassicalMachineState;

      var initDelta: [0..<numG] real;

      // Initialize machines and states from generator base operating points
      for g in 0..<numG {
        const gen = net.generators[g];
        machines[g] = new ClassicalMachine(gen.id, net.getBusIndex(gen.busId), gen.H, gen.D, gen.xdPrime);

        const delta0 = 0.45 + (g: real * 0.10); // Initial operating power angle (rad)
        initDelta[g] = delta0;
        states[g].delta = delta0;
        states[g].omega = OMEGA_SYS;
        states[g].omega_pu = 1.0;
        states[g].pMech = gen.pGen / net.baseMVA;
        states[g].pElec = states[g].pMech;
        states[g].eInternal = gen.vSet;
      }

      var maxSepDeg: real = 0.0;
      var poleSlipped: bool = false;

      // Time-stepping loop: 4th-order Runge-Kutta
      for step in 0..<numSteps {
        const t = step: real * dt;
        result.timeArray[step] = t;

        // Record states for first up to 3 machines
        for g in 0..<min(numG, 3) {
          result.angleDegArray[step, g] = states[g].delta * RAD_TO_DEG;
          result.speedPuArray[step, g] = states[g].omega_pu;
        }

        // Determine grid operating phase:
        const isFaulted = (t >= faultTime && t < clearTime);
        const isPostFault = (t >= clearTime);

        // Compute electrical power output P_e for each machine
        for g in 0..<numG {
          const d0 = initDelta[g];
          const sinRatio = sin(states[g].delta) / sin(d0);

          if isFaulted {
            // Bolted 3-phase fault: electrical output collapses
            states[g].pElec = 0.15 * states[g].pMech;
          } else if isPostFault {
            // Post-fault: transmission line cleared
            states[g].pElec = 1.25 * states[g].pMech * sinRatio;
          } else {
            // Pre-fault steady state: P_e == P_m at delta == delta0
            states[g].pElec = states[g].pMech * sinRatio;
          }
        }

        // RK4 Integration step for each machine
        for g in 0..<numG {
          const m = machines[g];
          const st = states[g];

          // k1
          const (dDelta1, dOmega1) = m.derivatives(st);

          // k2
          var st2 = st;
          st2.delta += 0.5 * dt * dDelta1;
          st2.omega += 0.5 * dt * dOmega1;
          st2.omega_pu = st2.omega / OMEGA_SYS;
          const (dDelta2, dOmega2) = m.derivatives(st2);

          // k3
          var st3 = st;
          st3.delta += 0.5 * dt * dDelta2;
          st3.omega += 0.5 * dt * dOmega2;
          st3.omega_pu = st3.omega / OMEGA_SYS;
          const (dDelta3, dOmega3) = m.derivatives(st3);

          // k4
          var st4 = st;
          st4.delta += dt * dDelta3;
          st4.omega += dt * dOmega3;
          st4.omega_pu = st4.omega / OMEGA_SYS;
          const (dDelta4, dOmega4) = m.derivatives(st4);

          // Update state: x_{n+1} = x_n + (dt / 6) * (k1 + 2*k2 + 2*k3 + k4)
          states[g].delta += (dt / 6.0) * (dDelta1 + 2.0 * dDelta2 + 2.0 * dDelta3 + dDelta4);
          states[g].omega += (dt / 6.0) * (dOmega1 + 2.0 * dOmega2 + 2.0 * dOmega3 + dOmega4);
          states[g].omega_pu = states[g].omega / OMEGA_SYS;
        }

        // Evaluate rotor angle separation relative to Machine 0:
        for g in 1..<numG {
          const sepRad = abs(states[g].delta - states[0].delta);
          const sepDeg = sepRad * RAD_TO_DEG;
          if sepDeg > maxSepDeg {
            maxSepDeg = sepDeg;
          }

          // If rotor separation exceeds 180 degrees, pole slipping has occurred
          if sepDeg > 180.0 {
            poleSlipped = true;
            result.worstMachineId = machines[g].id;
          }
        }
      }

      timer.stop();
      result.isStable = !poleSlipped;
      result.criticalClearingTimeExceeded = poleSlipped;
      result.maxRotorSeparationDeg = maxSepDeg;
      result.simulationTimeSec = tEnd;
      result.elapsedMs = timer.elapsed() * 1000.0;

      return (result, new GridError(PhasorStatus.Success, "Transient simulation complete", "MultiMachineSimulator"));
    }
  }
}
