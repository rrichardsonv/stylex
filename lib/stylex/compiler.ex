defmodule Stylex.Compiler do
  @moduledoc """
  Style-aware template engine.
  """
  require EEx

  defmacro __before_compile__(_env) do
    style_directory =
      Application.get_env(:stylex, :included_directories, [
        Path.expand("../../assets/css/", __DIR__)
      ])

    global_styles =
      :stylex
      |> Application.get_env(:global_stylesheet)
      |> case do
        nil ->
          EEx.compile_string("")

        path when is_binary(path) ->
          EEx.compile_file(path)
      end

    quote do
      @__style_directory__ unquote(style_directory)
      @__global_styles__ unquote(global_styles)

      def
    end
  end

  # @__style_directory__

  # NOTE: I need to figure out what the order of these calls is

  defmacro to_stylesheet(style) do
    style =
      case is_binary(style) do
        true ->
          quote(do: unquote(style))

        false ->
          style
      end

    quote(
      do:
        Sass.compile(
          unquote(@global_styles) <> "\n/*  Generated styles below  */\n" <> unquote(style),
          %{include_paths: @__style_directory__, output_style: Sass.sass_style_compressed()}
        )
    )
  end
end
