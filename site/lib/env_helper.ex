defmodule EnvHelper do
  defmacro env_specific(config) do
    quote do
      unquote(Keyword.get_lazy(config, Mix.env(), fn -> Keyword.fetch!(config, :else) end))
    end
  end
end
