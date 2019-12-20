defmodule Stylex.ScssParser do
  @moduledoc """
  Parses a string of nested scss into a tree structure.
  Accepts optional resolver function with arity 3 to handle
  transformation into the completed nodes
  """

  defmacro __using__(opts) do
    maybe_resolver =
      opts
      |> Keyword.get(:node_resolver, false)
      |> Macro.escape()

    resolver =
      case is_atom(maybe_resolver) do
        true ->
          {__CALLER__.module, maybe_resolver}

        false ->
          {__MODULE__, :default_resolver}
      end

    quote do
      def parse_scss(str) do
        Stylex.ScssParser.parse(str, unquote(resolver))
      end
    end
  end

  def default_resolver(s, b, c), do: %{s: s, b: b, c: c}

  def parse(str, node_resolver) do
    str_chars = to_charlist(str)
    transformer = fn c, acc -> to_node_tree(c, acc, node_resolver) end

    [3]
    |> :lists.append(str_chars)
    |> :lists.reverse()
    |> Stream.reject(&is_non_space_whitespace/1)
    |> Stream.transform([], transformer)
    |> Stream.reject(&Kernel.==(&1, 32))
    |> Stream.map(&format_node/1)
    |> Enum.into([])
  end

  defp to_node_tree(3, acc, node_resolver) do
    result =
      acc
      |> Enum.map(&open_selector/1)
      |> Enum.map(&close_node(&1, node_resolver))

    {result, []}
  end

  defp to_node_tree(char, acc, node_resolver), do: {[], add_node(char, acc, node_resolver)}

  defp is_open_node?({type, _, _, _}) when type in [:body, :children], do: true
  defp is_open_node?(_), do: false

  defp add_node(?}, acc, node_resolver),
    do: prepend(acc, new(), node_resolver)

  defp add_node(?{, [{type, _, _, _} = curr | acc], _) when type in [:body, :children] do
    [open_selector(curr) | acc]
  end

  defp add_node(?{, [{:selector, _, _, _} | _] = acc, node_resolver) do
    next_acc = rollup(acc, node_resolver)
    add_node(?{, next_acc, node_resolver)
  end

  defp add_node(?;, [{type, _, _, _} = curr | acc], _)
       when type in [:body, :children] do
    node =
      curr
      |> open_body()
      |> put(?;)

    [node | acc]
  end

  defp add_node(?;, [{:selector, _, _, _} | _] = acc, node_resolver) do
    next_acc = rollup(acc, node_resolver)
    add_node(?;, next_acc, node_resolver)
  end

  defp add_node(?;, [], _), do: new() |> open_body() |> put(?;) |> List.wrap()

  defp add_node(c, [curr | acc], _) do
    [put(curr, c) | acc]
  end

  defp find_first(tree, checker_fn) when is_list(tree) do
    do_check({[], nil, tree}, checker_fn)
  end

  defp do_check({[], nil, [_ | _]} = zipper, checker_fn) do
    zipper |> next() |> do_check(checker_fn)
  end

  defp do_check({before, curr, []}, checker_fn) do
    case checker_fn.(curr) do
      true -> {:lists.reverse(before), curr, []}
      false -> {:lists.reverse([curr | before]), nil, []}
    end
  end

  defp do_check({before, curr, aft} = zipper, checker_fn) do
    case checker_fn.(curr) do
      true ->
        {:lists.reverse(before), curr, aft}

      false ->
        zipper |> next() |> do_check(checker_fn)
    end
  end

  defp next({[], nil, [next | aft]}), do: {[], next, aft}

  defp next({before, curr, [next | aft]}) do
    {[curr | before], next, aft}
  end

  defp next({_, _, []}), do: raise("Went to far!")

  defp open_body({:body, s, b, c}), do: {:body, s, b, c}
  defp open_body({:children, s, b, c}), do: {:body, s, b, c}
  defp open_body(unknown), do: raise(inspect(unknown))

  defp open_children({:body, s, b, c}) do
    case Enum.split_while(b, &is_integer/1) do
      {[], []} ->
        {:children, s, b, c}

      {[], groups} ->
        {:children, s, groups, c}

      {[_ | _] = b, groups} ->
        {:children, s, [b | groups], c}
    end
  end

  defp open_children({:children, _, _, _} = node),
    do: node

  defp open_children(unknown), do: raise(inspect(unknown))

  defp open_selector({:body, _, _, _} = node) do
    node
    |> open_children()
    |> open_selector()
  end

  defp open_selector({:children, s, b, c}) do
    {:selector, s, b, c}
  end

  defp open_selector({:selector, _, _, _} = node), do: node

  defp open_selector(unknown), do: raise(inspect(unknown))

  defp close_node({:selector, s, b, c}, node_resolver) do
    selector = s |> Kernel.to_string() |> String.trim()

    body =
      case b do
        [h | _] = body when is_list(h) ->
          body
          |> Stream.reject(&Kernel.==(&1, 32))
          |> Stream.map(&to_string/1)
          |> Stream.map(&String.replace_trailing(&1, ";", ""))
          |> Stream.flat_map(&String.split(&1, ";"))
          |> Stream.map(&String.trim/1)
          |> Stream.map(&String.split(&1, ":"))
          |> Enum.into([])

        body ->
          body
          |> Kernel.to_string()
          |> String.replace_trailing(";", "")
          |> String.split(";")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.split(&1, ":"))
      end

    children = Enum.reject(c, &Kernel.==(&1, 32))

    {module, function} = node_resolver
    Kernel.apply(module, function, [selector, body, children])
  end

  defp close_node(node, _), do: node

  defp put({:selector, s, b, c}, item), do: {:selector, [item | s], b, c}
  defp put({:body, s, b, c}, item), do: {:body, s, [item | b], c}
  defp put({:children, s, b, c}, items) when is_list(items), do: {:children, s, b, items ++ c}
  defp put({:children, s, b, c}, item), do: {:children, s, b, [item | c]}
  defp put(unknown, _), do: raise(inspect(unknown))

  defp prepend([{:selector, _, _, _} = node | tree], new_node, node_resolver),
    do: [new_node | [close_node(node, node_resolver) | tree]]

  defp prepend([{:body, _, _, _} = node | tree], new_node, _),
    do: [new_node | [open_children(node) | tree]]

  defp prepend(tree, new_node, _), do: [new_node | tree]

  defp new(children \\ []) do
    {:children, [], [], children}
  end

  defp rollup(acc, node_resolver) do
    case find_first(acc, &is_open_node?/1) do
      {tree, nil, _} ->
        tree
        |> Enum.map(&close_node(&1, node_resolver))
        |> new()
        |> List.wrap()

      {siblings, {_, _, _, _} = parent, tree} ->
        children = Enum.map(siblings, &close_node(&1, node_resolver))

        new_head =
          parent
          |> open_children()
          |> put(children)

        [new_head | tree]
    end
  end

  defp is_non_space_whitespace(char) when char in [9, 10, 12, 13], do: true
  defp is_non_space_whitespace(_), do: false

  defp format_node([h | _] = rules) when is_integer(h) do
    rules
    |> Kernel.to_string()
    |> String.split(";")
    |> Enum.map(&String.trim/1)
  end

  defp format_node(node), do: node
end
