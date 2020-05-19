defmodule Stylex.Parser do
  import NimbleParsec
  import Stylex.Parser.Common
  import Stylex.Parser.Utils

  defcombinatorp(:block,
    optional(whitespace())
    |> concat(tag(
      repeat(
        lookahead_not(open_curly())
        |> choice([
          ignore(comment()),
          ascii_string([not: ?;, not: ?}, not: ?{, not: ?\n, not: ?\t, not: ?\s], min: 1),
          whitespace()
        ])
      ), :selector))
    |> ignore(open_curly())
    |> repeat(
      lookahead_not(close_curly())
      |> parsec(:root)
    )
    |> optional(whitespace())
    |> ignore(close_curly())
  )

  defcombinatorp(:with_interpolation,
      ascii_string([not: ?;, not: ?:, not: ?}, not: ?{, not: ?\n], min: 1)
      |> concat(string("#\{"))
      |> concat(ascii_string([not: ?;, not: ?:, not: ?}, not: ?{, not: ?\n], min: 1))
      |> concat(close_curly())
      |> concat(ascii_string([not: ?;, not: ?:, not: ?}, not: ?{, not: ?\n], min: 1))
  )

  defcombinatorp(:rule,
    optional(whitespace())
    |> concat(unwrap_and_tag(choice([
      ascii_string([not: ?;, not: ?:, not: ?}, not: ?{, not: ?\n], min: 1),
      parsec(:with_interpolation)
    ]), :prop))
    |> optional(whitespace())
    |> ignore(colon())
    |> optional(whitespace())
    |> concat(ascii_string([not: ?;], min: 1) |> unwrap_and_tag(:value))
    |> optional(whitespace())
    |> ignore(semi())
    |> optional(whitespace())
  )

  defcombinatorp(:at_rule,
    optional(whitespace())
    |> ignore(string("@"))
    |> ascii_string([not: ?;, not: ?}, not: ?{, not: ?\n], min: 1)
    |> optional(whitespace())
    |> ignore(semi())
    |> tag(:at_rule)
  )

  defcombinatorp(:root,
    choice([
      comment(),
      parsec(:at_rule),
      parsec(:block)
      |> tag(:block)
      |> pre_traverse({Stylex.Parser.Utils, :start_length, []})
      |> post_traverse({Stylex.Parser.Utils, :after_block, []}),
      parsec(:rule)
      |> tag(:rule)
      |> pre_traverse({Stylex.Parser.Utils, :start_length, []})
      |> post_traverse({Stylex.Parser.Utils, :end_length, []}),
      whitespace(),
      space_chars(),
      non_control_char(),
      colon() |> tag(:invariant),
      semi() |> tag(:invariant),
      comma() |> tag(:invariant),
      open_curly() |> tag(:invariant),
      close_curly() |> tag(:invariant),
    ])
    |> post_traverse({:foo, []})
  )

  def foo(rest, [{:invariant, _} | _] = a, c, _, _) do
    _ = IO.inspect(String.slice(rest, 0..40), label: "invariant")
    {a, c}
  end

  def foo(_, a, c, _, _), do: {a,c}

  defparsec(
    :parse,
    optional(whitespace())
    |> repeat(
      lookahead_not(eos())
      |> concat(parsec(:root))
    )
    |> optional(whitespace())
    |> eos()
  )
end
