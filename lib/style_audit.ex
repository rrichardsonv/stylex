defmodule Stylex.StyleAudit do
  alias Stylex.Style, as: Sty
  alias Stylex.ScssParser, as: P

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
          _ ->
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

  def log_results(results) do
      {:ok, file} = File.open("data.log", [:append])
      save_results(file, List.wrap(results))
      File.close(file)
  end

  def save_results(file, []), do: :ok
  def save_results(file, [data|rest]) do
      IO.write(file, data)
      save_results(file, rest)
  end
end
