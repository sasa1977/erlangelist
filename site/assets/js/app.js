import "phoenix_html"

hljs.initHighlightingOnLoad();

document.
  querySelector("#article_content").
  querySelectorAll("a").
  forEach((el) => el.target="_blank")
