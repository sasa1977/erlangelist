defmodule Erlangelist.Model.PersistentCounter do
  use Ecto.Model
  use Timex.Ecto.Timestamps

  schema "persistent_counters" do
    field :category, :string
    field :name, :string
    field :value, :integer
    field :created_at, Ecto.DateTime
  end

  def new(category, name, value) do
    %__MODULE__{
      category: category, name: name, value: value,
      created_at: Ecto.DateTime.utc
    }
  end
end