defmodule Stylex.Style do
  @moduledoc """
  Cascading style sheet style node for nested styles.

  ## Example

  The given scss string:
  ```
  \"\"\"
  .page-section {
    padding: 0 16px;
    border: 1px solid blue;

    & + & {
      margin-top: 16px;
    }
  }
  \"\"\"
  ```

  Correspond to the following structure:

  ```
    %Stylex.Style{
      selector: ".page-section",
      body: %{
        "padding" => "0 16px",
        "border" => "1px solid blue"
      },
      children: [%Stylex.Style{
        selector: "& + &",
        body: %{"margin-top" => "16px"},
        children: []
      }],
    }
  ```
  """
  use Stylex.ScssParser, node_resolver: :new
  alias __MODULE__, as: Style

  @type t :: %Style{
          selector: String.t() | nil,
          body: map(),
          children: [t]
        }
  defstruct [:selector, body: %{}, children: []]

  @doc """
  Converts a `t:Stylex.Style.t/0` struct to an scss string
  """
  @spec to_string(t) :: String.t()
  def to_string(%Style{selector: s, body: body, children: children}) do
    str_body = Enum.map_join(body, ":", &Enum.join(&1, ";"))
    "#{s}{#{str_body}#{Enum.map_join(children, "\n", &Style.to_string/1)}}\n"
  end

  @doc """
  Creates and returns a `t:Stylex.Style.t/0` struct or raises on error. See Stylex.Style.new/3 for details
  """
  def new!(selector, body, children) do
    case new(selector, body, children) do
      {:error, error} ->
        raise error

      {:ok, style} ->
        style
    end
  end

  @doc """
  Creates a `t:Stylex.Style.t/0` struct. Body can be a map or a list of key pairs. Children must be a list.
  Returns {:ok, %Style} or {:error, exception}
  """
  @spec new(term(), maybe_improper_list() | map(), list()) ::
          {:ok, t} | {:error, ArgumentError.t()}
  def new(_selector, _body, children) when not is_list(children),
    do:
      {:error,
       ArgumentError.exception(
         "At Stylex.Style.new/3 expected argument children of type list but got: #{
           inspect(children)
         }"
       )}

  def new(selector, [[_, _] | _] = body, children) do
    hash =
      body
      |> Enum.map_join(";", fn [prop, val] -> "#{String.trim(prop)}:#{String.trim(val)}" end)
      |> sha_hash()

    body =
      body
      |> Map.new(fn [prop, val] -> {prop, val} end)
      |> Map.put(:sha, hash)

    {:ok, %Style{selector: selector, children: children, body: body}}
  end

  def new(selector, [{_, _} | _] = body, children) do
    hash =
      body
      |> Enum.map_join(";", fn {prop, val} -> "#{String.trim(prop)}:#{String.trim(val)}" end)
      |> sha_hash()

    body =
      body
      |> Map.new(fn [prop, val] -> {prop, val} end)
      |> Map.put(:sha, hash)

    {:ok, %Style{selector: selector, children: children, body: body}}
  end

  def new(selector, body, children) when is_list(body),
    do: {:ok, %Style{selector: selector, children: children, body: %{sha: sha_hash("")}}}

  def new(selector, body, children) when is_map(body),
    do: {:ok, %Style{selector: selector, children: children, body: body}}


  def hash_tree(selector, body, children) do
    case new(selector, body, children) do
      {:ok, %Style{selector: selector, children: children, body: body}} ->
        {selector, Map.fetch!(body, :sha), children}
      {:error, _} ->
        raise "FUCK"
    end
  end


  defp sha_hash(s), do: :crypto.hash(:sha256, s)
  @doc """
  Converts an scss string to an `t:Stylex.Style.t/0` struct tree
  """
  @spec from_string(String.t(), String.t()) :: t()
  def from_string(selector, raw_styles) when is_binary(selector) and is_binary(raw_styles) do
    case parse_scss(raw_styles) do
      [%Style{selector: s} = style] when is_nil(s) or s == "" ->
        struct!(style, selector: selector)

      styles when is_list(styles) ->
        %Style{selector: selector, children: styles, body: %{}}
    end
  end

  defimpl Phoenix.HTML.Safe, for: Stylex.Style do
    def to_iodata(style) do
      Stylex.Style.to_string(style)
    end
  end
end
