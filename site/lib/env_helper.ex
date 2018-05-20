defmodule EnvHelper do
  defmacro env_specific(config) do
    quote do
      unquote(Keyword.get(config, Mix.env(), Keyword.get(config, :else)))
    end
  end
end
