import "phoenix_html"
import privacyController from "./privacy_controller"
import css from '../css/app.css';

let articleContentEl = document.querySelector("#article_content");
if (articleContentEl != null) {
  articleContentEl.
    querySelectorAll("a").
    forEach((el) => el.target = "_blank")
}
