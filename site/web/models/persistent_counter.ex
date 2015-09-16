defmodule Erlangelist.Model.CounterBase do
  defmacro __using__(opts) do
    quote do
      use Ecto.Model
      use Timex.Ecto.Timestamps

      schema unquote(opts[:table_name]) do
        field :key, :string
        field :value, :integer
        field :created_at, Ecto.DateTime
      end

      def new(key, value) do
        %__MODULE__{key: key, value: value, created_at: Ecto.DateTime.utc}
      end
    end
  end
end

for {table_name, module_suffix} <- %{
    "persistent_counters" => PersistentCounter,
    "article_visits" => ArticleVisit,
    "country_visits" => CountryVisit,
    "referer_host_visits" => RefererHostVisit,
    "referer_visits" => RefererVisit
  } do
  defmodule Module.concat(Erlangelist.Model, module_suffix) do
    @table_name table_name
    use Erlangelist.Model.CounterBase, table_name: @table_name
  end
end
