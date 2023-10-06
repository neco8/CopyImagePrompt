type Cmd<T = undefined> = {
  subscribe: (fn: (value: T) => void) => void;
};
type Sub<T = undefined> = {
  send: (value: T) => void;
};
interface Ports {
  copy: Cmd<string>;
  paste: Cmd;
  onPaste: Sub<string>;
  openModal: Cmd<string>;
  closeModal: Cmd<string>;
  receiveModalStatus: Sub<boolean>;
}
type Flags = undefined;

export namespace Elm {
  namespace Main {
    export interface App {
      ports: Ports;
    }
    export function init(param: {
      node: HTMLElement;
      flags: Flags;
    }): Elm.Main.App;
  }
}
