defmodule Json do
  defp print_node(x, lv, pretty) do
    if pretty, do: print_indent(lv)

    cond do
      is_integer(x) -> Utils.print(x)
      is_binary(x)  -> Utils.print("\"#{x}\"")
      is_list(x)    -> print_list(x, lv, pretty)
      true -> raise "unsupported"
    end
  end

  defp print_list_elements(xs, lv, pretty) do
    case xs do
      [] -> nil
      [ x ] -> (
        print_node(x, lv, pretty)
        if pretty, do: Utils.print("\n")
      )
      [ x | xs_tl ] -> (
        print_node(x, lv, pretty)
        Utils.print(if pretty, do: ",\n", else: ", ")
        print_list_elements(xs_tl, lv, pretty)
      )
    end
  end

  defp print_indent(lv) do
    if lv == 0 do
      nil
    else
      1..lv |> Enum.each(fn _ -> Utils.print("  ") end)
    end
  end

  defp print_list(xs, lv, pretty) do
    Utils.print "["
    if pretty, do: Utils.print("\n")

    print_list_elements(xs, lv + 1, pretty)

    if pretty, do: print_indent(lv)
    Utils.print "]"
  end

  def print(xs) do
    print_list(xs, 0, false)
  end

  def pretty_print(xs) do
    print_list(xs, 0, true)
  end

  defp match_int(rest) do
    Utils.non_int_index(rest) || 0
  end

  defp match_str(rest) do
    i = Utils.str_find_index(rest, 1, &(&1 == "\""))
    if i do
      i + 1
    else
      raise "unexpected pattern"
    end
  end

  defp rest_type(rest) do
    case String.at(rest, 0) do
      " "  -> :skip 
      "\n" -> :skip
      ","  -> :skip
      "["  -> :list_begin
      "]"  -> :list_end
      "\"" -> :str
      nil  -> :eof
      _ -> (
        cond do
          0 < match_int(rest) -> :int
          true -> raise "unexpected pattern"
        end
      )
    end
  end

  defp parse_list_elements(rest) do
    case rest_type(rest) do
      :skip -> (
        { _, rest } = Utils.str_partition(rest, 1)
        parse_list_elements(rest)
      )
      :list_begin -> (
        { x, rest } = parse_list(rest)
        { xs, rest } = parse_list_elements(rest)
        { [ x ] ++ xs, rest }
      )
      :list_end -> (
        { _, rest } = Utils.str_partition(rest, 1)
        { [], rest }
      )
      :int -> (
        size = match_int(rest)
        { str, rest } = Utils.str_partition(rest, size)
        { n, _ } = Integer.parse(str)
        { xs, rest } = parse_list_elements(rest)
        { [ n ] ++ xs, rest }
      )
      :str -> (
        size = match_str(rest)
        str = String.slice(rest, 1, size - 2)
        { _, rest } = Utils.str_partition(rest, size)
        { xs, rest } = parse_list_elements(rest)
        { [ str ] ++ xs, rest }
      )
      _ -> raise "unexpected pattern"
    end
  end

  defp parse_list(rest) do
    if String.at(rest, 0) == "[" do
      { _, rest } = Utils.str_partition(rest, 1)
      parse_list_elements(rest)
    else
      raise "unexpected pattern"
    end
  end

  def parse(json) do
    { xs, _ } = parse_list(json)
    xs
  end
end
