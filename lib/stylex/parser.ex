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

  defcombinatorp(:rule,
    optional(whitespace())
    |> concat(unwrap_and_tag(ascii_string([not: ?;, not: ?:, not: ?}, not: ?{, not: ?\n], min: 1), :prop))
    |> optional(whitespace())
    |> ignore(colon())
    |> optional(whitespace())
    |> concat(ascii_string([not: ?;], min: 1) |> unwrap_and_tag(:value))
    |> ignore(semi())
  )

  defcombinatorp(:root,
    choice([
      comment(),
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
      colon() |> tag(:colon),
      comma() |> tag(:comma),
      open_curly() |> tag(:open_curly),
      close_curly() |> tag(:close_curly),
    ])
  )

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
