defmodule EnvHelper do
  defmacro env_based(config) do
    quote do
      unquote(Keyword.get(config, Mix.env(), Keyword.get(config, :else)))
    end
  end
end
