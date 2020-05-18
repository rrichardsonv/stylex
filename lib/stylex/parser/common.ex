defmodule Stylex.Parser.Common do
  import NimbleParsec
  import Stylex.Parser.Utils

  def curly_group(children, traverse_mapper \\ {Stylex.Parser.Utils, :noop, []})
      when is_list(children) do
    ignore(open_curly())
    |> repeat(
      lookahead_not(close_curly())
      |> optional(whitespace())
      |> choice(children ++ [non_control_char(), ascii_char(not: ?}) |> tag(:unknown)])
    )
    |> post_traverse(traverse_mapper)
    |> wrap()
    |> optional(whitespace())
    |> ignore(close_curly())
  end

  def comment do
    choice([
      ignore(string("//"))
      |> optional(space_chars())
      |> concat(ascii_string([0..255, {:not, ?\n}], min: 1))
      |> concat(eol()),
      ignore(string("/*"))
      |> optional(eol())
      |> repeat(
        lookahead_not(string("*/"))
        |> choice([
          ascii_string([0..255, {:not, ?*}], min: 1),
          ascii_char([?*]) |> lookahead_not(ascii_char([?/]))
        ])
      )
      |> ignore(string("*/"))
    ])
    |> tag(:comment)
  end
end
