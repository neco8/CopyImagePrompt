import "./styles/index.css";
import { Elm } from "./Main.elm";
import copy from "copy-to-clipboard";

const API_ENDPOINT = "https://api.openai.com/v1/chat/completions";
const API_KEY = "YOUR_OPENAI_API_KEY";

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
}
