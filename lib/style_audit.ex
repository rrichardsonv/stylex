defmodule Stylex.StyleAudit do
  alias Stylex.Style, as: Sty
  alias Stylex.ScssParser, as: P
  alias Stylex.Parser, as: Parse

  @output_dir "audit_log"

  def audit(dir) do
    _ = File.mkdir_p!(@output_dir)
    do_audit([dir], dir)
  end

  defp do_audit([], _base), do: :ok
  defp do_audit([maybe_dir | rest], base) do
    if File.dir?(maybe_dir) do
      maybe_dir
      |> File.ls!()
      |> Enum.map(fn s -> Path.join(maybe_dir, s) end)
      |> Enum.concat(rest)
      |> do_audit(base)
    else
      if Path.extname(maybe_dir) == ".scss" do
          _ =
            maybe_dir
            |> IO.inspect(label: "wut: #{File.exists?(maybe_dir)}")
            |> File.read!()
            |> Parse.parse()
            |> get_dups()
            |> log_results(String.replace_prefix(maybe_dir, base, ""))

        do_audit(rest, base)
      else
        do_audit(rest, base)
      end
    end
  end

  def get_dups({:ok, acc, _, _, _, _}) do
    Enum.reduce(acc, %{}, fn
      {:block, props}, acc ->
        int = Keyword.fetch!(props, :integrity)
        if int == "" do
          acc
        else
          Map.update(acc, int, [{:block, props}], fn v -> [{:block, props} | v] end)
        end
      inv, acc ->
        _ = IO.inspect(inv, label: "parse_invarient")
        acc
    end)
    |> Stream.reject(fn
      {_k, [_]} -> true
      _ -> false
    end)
    |> Enum.flat_map(fn {hash, v} ->
      dups =
        v
        |> Enum.map(fn {_, p} -> p end)
        |> Enum.reject(fn
          [] -> true
          _ -> false
        end)
        |> Enum.map(fn props ->
          rules_content =
            props
            |> fmt(:rule, fn
              rule_props when is_list(rule_props) ->
                Enum.join([
                  Keyword.fetch!(rule_props, :prop),
                  Keyword.fetch!(rule_props, :value)
                ], ":")
              foo ->
                IO.inspect(foo, label: "invariant")
            end)
            |> case do
              res when is_list(res) ->
                Enum.join(res, "\n")
              foo ->
                foo
            end
          {
            """
            -----
            #{fmt(props, :start_loc, &inspect(&1)) |> String.slice(1..-2)}
            #{fmt(props, :selector, &Enum.join(&1, "\n"))}
            -----
            """,
            rules_content
          }
        end)
      [{hash, dups}]
    end)
  end

  def get_dups({:error, _, _, _, _, _} = e) do
    IO.inspect(e, label: "error")
  end
  def fmt(v, k, mapper \\ fn x -> x end)
  def fmt([], _, _), do: ""
  def fmt(kw, k, mapper) do
    case Keyword.take(kw, [k]) do
      [_ | [_ | _]] = v ->
        v
        |> Keyword.values()
        |> Enum.map(fn
          {_, v} -> mapper.(v)
          v -> mapper.(v)
        end)
      [{_, v}] ->
        mapper.(v)
      [] ->
        ""
    end
  end


  ## OLD SHIT
  def run(dir) do
    do_run([dir])
  end

  defp do_run([], _), do: :ok
  defp do_run([maybe_dir | rest]) do
    if File.dir?(maybe_dir) do
      maybe_dir
      |> File.ls!()
      |> Enum.map(fn s -> Path.join(maybe_dir, s) end)
      |> Enum.concat(rest)
      |> do_run()
    else
      if Path.extname(maybe_dir) == ".scss" do
        try do
          _ =
            maybe_dir
            |> File.read!()
            |> P.parse({Sty, :hash_tree})
            |> flat_tree()
            |> Enum.join("\n")
            |> log_results()
        rescue
          foo ->
            IO.inspect(foo, label: "error")
            IO.puts("Error in #{maybe_dir}")
        end

        do_run(rest)
      else
        do_run(rest)
      end
    end
  end

  def flat_tree(shiit, selecter \\ [])
  def flat_tree([{s, sha, chil} | rest], selecter) do
    do_flatten(s, sha, chil, selecter) ++ flat_tree(rest, selecter)
  end

  def flat_tree([{s, sha, chil}], selecter) do
    do_flatten(s, sha, chil, selecter)
  end

  def flat_tree([], _), do: []

  def do_flatten(s, sha, [], p_sel) do
    sel = Enum.reverse([s | p_sel]) |> Enum.join(" ")
    ["#{Base.encode64(sha)}|#{sel}"]
  end

  def do_flatten(s, sha, chil, p_sel) do
    sel = Enum.reverse([s | p_sel]) |> Enum.join(" ")
    ["#{Base.encode64(sha)}|#{sel}" | flat_tree(chil, [s | p_sel])]
  end

  def log_results(results), do: log_results(results, "unknown")
  def log_results(results, base_file) do
      Enum.each(results, fn {file_name, data} ->
        p = Path.join(@output_dir, Regex.replace(~r/\.[^.]+$/, file_name, ""))

        data =
        case File.touch(p, System.os_time(:second)) do
          :ok ->
            rule_def =
              data
              |> hd()
              |> elem(1)

            "------\n#{rule_def}\n------\n\n" <> Enum.map_join(data, "\n", fn {a, _} -> a end)
          _ ->
            Enum.map_join(data, "\n", fn {a, _} -> a end)
        end
        p
        |> IO.inspect(label: "path")
        |> File.open([:append], fn file ->
          save_results(file, ["-------------\n## #{base_file}\n\n" | List.wrap(data)])
        end)
      end)
  end

  def save_results(_file, []), do: :ok
  def save_results(file, [data|rest]) do
      IO.write(file, data)
      save_results(file, rest)
  end
end
