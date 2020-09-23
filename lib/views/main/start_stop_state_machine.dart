class StartStopStateMachine {
  Transition run = Transition("run");
  Transition stop = Transition("stop");
  Transition pause = Transition("pause");

  State stopped;
  State running;
  State paused;
  State currentState;

  StartStopStateMachine() {
    stopped = State("stopped", Set<Transition>.from({run}));
    running = State("running", Set<Transition>.from({stop, pause}));
    paused = State("paused", Set<Transition>.from({run, stop}));

    currentState = stopped;
  }

  State nextState(Transition transition) {
    switch (transition.name) {
      case "run":
        switch (currentState.name) {
          case "paused":
          case "stopped":
            currentState = running;
            break;
          case "running":
            break;
        }
        break;
      case "stop":
        switch (currentState.name) {
          case "paused":
          case "running":
            currentState = stopped;
            break;
          case "stopped":
            break;
        }
        break;
      case "pause":
        switch (currentState.name) {
          case "running":
            currentState = paused;
            break;
          case "stopped":
          case "paused":
            break;
        }
        break;
    }

    return currentState;
  }
}

class Transition {
  String name;
  Transition(this.name);
}

class State {
  String name;
  Set<Transition> transitions;

  State(this.name, this.transitions);
}
