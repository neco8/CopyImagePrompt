import "./styles/index.css";
import { Elm } from "./Main.elm";
import copy from "copy-to-clipboard";


const elem = document.getElementById("main");
if (elem) {
  const app = Elm.Main.init({ node: elem, flags: undefined });

  app.ports.copy.subscribe((v) => {
    copy(v);
  });
  app.ports.paste.subscribe((_) => {
    navigator.clipboard
      .readText()
      .then((clipText) => app.ports.onPaste.send(clipText));
  });

  app.ports.openModal.subscribe((id) => {
    const elem = document.getElementById(id);
    if (!(elem instanceof HTMLDialogElement)) return;
    elem.showModal();
    app.ports.receiveModalStatus.send(true)
  });
  app.ports.closeModal.subscribe((id) => {
    const elem = document.getElementById(id);
    if (!(elem instanceof HTMLDialogElement)) return;
    elem.close();
    app.ports.receiveModalStatus.send(false)
  });
}
