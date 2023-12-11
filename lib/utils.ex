defmodule Utils do
  def print(arg), do: IO.write(:stdio, arg)

  # def puts_e(arg), do: IO.write(:stderr, "#{arg}\n")
  # def puts_kv_e(k, v), do: puts_e("#{k} (#{v})")

  def read_stdin_all do
    case IO.read(:stdio, :all) do
      { :error, reason } -> raise "failed to read stdin (#{reason})"
      data -> data
    end
  end

  def str_find_index(str, start, pred) do
    i_last = String.length(str) - 1
    i =
      Enum.find_index(
        start..i_last,
        fn i -> pred.(String.at(str, i)) end
      )
    if i do
      start + i
    else
      nil
    end
  end

  defp str_partition_hd(str, i), do: String.slice(str, 0..(i - 1))
  defp str_partition_tl(str, i), do: String.slice(str, i..-1)

  def str_partition(str, i) do
    {
      str_partition_hd(str, i),
      str_partition_tl(str, i)
    }
  end

  defp int_char?(c), do: Regex.match?(~r/^[-0-9]$/, c)

  def non_int_index(str) do
    str_find_index(str, 0, &(!int_char?(&1)))
  end
end

defmodule Token do
  defstruct kind: nil, val: nil, lineno: nil
end
