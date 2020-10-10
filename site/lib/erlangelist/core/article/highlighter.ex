defmodule Erlangelist.Core.Article.Highlighter do
  defp pick_language_and_lexer(""), do: {"elixir", Makeup.Lexers.ElixirLexer, []}

  defp pick_language_and_lexer(lang) do
    case Makeup.Registry.fetch_lexer_by_name(lang) do
      {:ok, {lexer, opts}} ->
        {lang, lexer, opts}

      :error ->
        {lang, nil, []}
    end
  end

  def highlight_code_blocks(html, opts \\ []) do
    Application.ensure_all_started(:earmark)
    Application.ensure_all_started(:makeup_elixir)

    Regex.replace(
      ~r/<pre><code(?:\s+class="(\w*)")?>([^<]*)<\/code><\/pre>/,
      html,
      &highlight_code_block(&1, &2, &3, opts)
    )
  end

  defp highlight_code_block(full_block, lang, code, outer_opts) do
    case pick_language_and_lexer(lang) do
      {_language, nil, _opts} -> full_block
      {language, lexer, opts} -> render_code(language, lexer, opts, code, outer_opts)
    end
  end

  defp render_code(lang, lexer, lexer_opts, code, opts) do
    highlight_tag = Keyword.get(opts, :highlight_tag, "span")

    highlighted =
      code
      |> unescape_html()
      |> IO.iodata_to_binary()
      |> Makeup.highlight_inner_html(
        lexer: lexer,
        lexer_options: lexer_opts,
        formatter_options: [highlight_tag: highlight_tag]
      )

    ~s(<pre><code class="highlight makeup #{lang}">#{highlighted}</code></pre>)
  end

  entities = [{"&amp;", ?&}, {"&lt;", ?<}, {"&gt;", ?>}, {"&quot;", ?"}, {"&#39;", ?'}]

  for {encoded, decoded} <- entities do
    defp unescape_html(unquote(encoded) <> rest) do
      [unquote(decoded) | unescape_html(rest)]
    end
  end

  defp unescape_html(<<c, rest::binary>>) do
    [c | unescape_html(rest)]
  end

  defp unescape_html(<<>>) do
    []
  end
end
