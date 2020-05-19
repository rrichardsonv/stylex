defmodule Stylex.Parser.Utils do
  import NimbleParsec

  # utils
  defcombinatorp(
    :util_whitespace,
    ascii_string([?\s, ?\t, ?\n, ?\r], min: 1) |> ignore() |> label("whitespace")
  )

  def whitespace,
    do:
      ascii_string([?\s, ?\t, ?\n, ?\r], min: 1)
      |> ignore()
      |> label("whitespace")

  defcombinatorp(
    :util_space_chars,
    ascii_string([?\s, ?\t], min: 1) |> ignore() |> label("space_chars")
  )

  def space_chars, do: ascii_string([?\s, ?\t], min: 1) |> ignore() |> label("space_chars")

  defcombinatorp(:util_eol, ascii_char([?\n]) |> ignore() |> label("eol"))

  def eol,
    do: ascii_char([?\n]) |> ignore() |> label("eol")

  defcombinatorp(:util_semi, ascii_char([?;]) |> ignore() |> label("semi"))
  def semi, do: ascii_char([?;]) |> ignore() |> label("semi")

  defcombinatorp(:util_colon, ascii_char([?:]) |> label("colon"))
  def colon, do: ascii_char([?:]) |> label("colon")

  defcombinatorp(:util_comma, ascii_char([?,]) |> label("comma"))
  def comma, do: ascii_char([?,]) |> label("comma")

  defcombinatorp(:util_open_curly, ascii_char([?{]) |> label("open_curly"))
  def open_curly, do: ascii_char([?{]) |> label("open_curly")

  defcombinatorp(:util_close_curly, ascii_char([?}]) |> label("close_curly"))
  def close_curly, do: ascii_char([?}]) |> label("close_curly")


  def non_control_char,
    do:
      ascii_string(
        [
          10..255,
          {:not, ?;},
          {:not, ?}},
          {:not, ?{},
          {:not, ?:},
          {:not, ?\s},
          {:not, ?\t},
          {:not, ?\n},
          {:not, ?\r}
        ],
        min: 1
      )
      |> tag(:non_control_char)

  def noop(_, a, c, _, _), do: {a, c}

  def after_block(r, a, c, l, o) do
    case end_length(r, a, c, l, o) do
      {[{:block, propz} | rest], c} ->
        a =
          Enum.flat_map([{:block, [{:integrity, get_sha(propz)} | propz]} | rest], fn
            {:block, props} ->
              parent_selector = Keyword.get(props, :selector, [])
              {blocks, body} = Keyword.split(props, [:block])
              children =
                Enum.map(blocks, fn {:block, child_props} ->
                  {child_sel, child_props} = Keyword.pop(child_props, :selector, [])
                  {:block, [{:selector, parent_selector ++ child_sel} | child_props]}
                end)

              [{:block, body} | children]
            node ->
              List.wrap(node)
          end)
        {a , c}
      _ ->
        raise "WTF"
    end
  end

  def end_length(_, a, c, l, o) do
    case a do
      [{type, props} | rest] when is_list(props) ->
        new_props = Keyword.put(props, :end_loc, to_loc_props(l, o))
        {[{type, new_props} | rest], c}
      foo ->
        _ = IO.inspect(foo, label: "invariant-----end_length-----")
        {foo, c}
    end
  end

  def start_length(_, a, c, l, o) do
    case a do
      [{type, props} | rest] when is_list(props) ->
        new_props = Keyword.put(props, :start_loc, to_loc_props(l, o))
        {[{type, new_props} | rest], c}
      foo ->
        _ = IO.inspect(foo, label: "invariant-----start_length-----")
        {foo, c}
    end
  end

  defp to_loc_props({line, line_offset}, offset),
    do: [line: line, col: offset - line_offset]

  defp get_sha(a) do
      a
      |> Stream.filter(fn {k, _} -> k == :rule end)
      |> Stream.map(fn {_, rule_props} ->
        prop = Keyword.fetch!(rule_props, :prop)
        value = Keyword.fetch!(rule_props, :value)
        "#{prop}:#{value};"
      end)
      |> Enum.sort()
      |> Enum.join("")
      |> case do
        "" ->
          ""
        s when is_binary(s) ->
          :sha256
          |> :crypto.hash(s)
          |> Base.encode64()
        _ ->
          raise "WTF"
      end
  end
end

