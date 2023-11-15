import "./styles/index.css";
import { Elm } from "./Main.elm";
import copy from "copy-to-clipboard";

function setNestedObject(
  path: string[],
  value: unknown,
  obj: Record<string, unknown> = {}
): Record<string, unknown> {
  if (path.length === 0) {
    return value as Record<string, unknown>;
  }

  const [head, ...tail] = path;
  return {
    ...obj,
    [head]: setNestedObject(
      tail,
      value,
      (obj[head] as Record<string, unknown>) || {}
    ),
  };
}

function getNestedObject(
  path: string[],
  obj: Record<string, unknown> | undefined
): unknown {
  if (!obj || path.length === 0) return obj;

  return getNestedObject(
    path.slice(1),
    obj[path[0]] as Record<string, unknown>
  );
}

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
    app.ports.receiveModalStatus.send(true);
  });
  app.ports.closeModal.subscribe((id) => {
    const elem = document.getElementById(id);
    if (!(elem instanceof HTMLDialogElement)) return;
    elem.close();
    app.ports.receiveModalStatus.send(false);
  });

  // Elmからの保存要求を受け取る
  app.ports.saveToLocalStoragePort.subscribe(function ({ path, value }) {
    try {
      const data = localStorage.getItem("data");
      const existingData = data ? JSON.parse(data) : {};
      const updatedData = setNestedObject(path, value, existingData);
      localStorage.setItem("data", JSON.stringify(updatedData));
      app.ports.receiveSaveResultPort.send(true);
    } catch (error) {
      console.error("Failed to save to Local Storage:", error);
      app.ports.receiveSaveResultPort.send(false);
    }
  });

  // Elmからの読み取り要求を受け取る
  app.ports.loadFromLocalStoragePort.subscribe(function ({ path, msg }) {
    try {
      const loadedData = localStorage.getItem("data");
      const existingData = loadedData ? JSON.parse(loadedData) : {};
      const result = getNestedObject(path, existingData);
      app.ports.receiveLoadResultPort.send({
        msg,
        value: result,
      });
    } catch (error) {
      console.error("Failed to load from Local Storage:", error);
      app.ports.receiveLoadResultPort.send(null);
    }
  });
}
