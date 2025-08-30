defmodule Lexer do
  defp ident_char?(c) do
    Regex.match?(~r/^[a-z0-9_]$/, c)
  end

  defp non_ident_index(str) do
    Utils.str_find_index(str, 0, &(!ident_char?(&1)))
  end

  defp match_int(rest) do
    Utils.non_int_index(rest) || String.length(rest)
  end

  defp match_str(rest) do
    i = Utils.str_find_index(rest, 1, &(&1 == "\""))
    if i do
      i + 1
    else
      raise "unexpected pattern"
    end
  end

  defp match_ident(rest) do
    non_ident_index(rest) || String.length(rest)
  end

  defp match_sym(rest) do
    case String.slice(rest, 0, 2) do
      "==" -> 2
      "!=" -> 2
      _ -> (
        if String.contains?("(){};,+*=", String.at(rest, 0)) do
          1
        else
          0
        end
      )
    end
  end

  defp match_comment(rest) do
    Utils.str_find_index(rest, 0, &(&1 == "\n")) || String.length(rest)
  end

  defp kw?(str) do
    Enum.member?(
      [
        "func", "set", "var", "call_set", "call", "return", "case", "when", "while",
        "_cmt", "_debug"
      ],
      str
    )
  end

  defp print_token(t) do
    Json.print [ t.lineno, t.kind, t.val ]
    Utils.print "\n"
  end

  defp rest_type(rest) do
    if String.length(rest) == 0 do
      :eof
    else
      case String.slice(rest, 0, 2) do
        "//" -> :comment
        _ -> (
          case String.at(rest, 0) do
            " "  -> :skip
            "\n" -> :skip
            "\"" -> :str
            _ -> (
              cond do
                0 < match_int(rest)   -> :int
                0 < match_sym(rest)   -> :sym
                0 < match_ident(rest) -> :ident
                true -> raise "unexpected pattern"
              end
            )
          end
        )
      end
    end
  end

  defp lex(rest, lineno) do
    case rest_type(rest) do
      :skip -> (
        { str, rest } = Utils.str_partition(rest, 1)
        lineno = lineno + (if str == "\n", do: 1, else: 0)
        lex(rest, lineno)
      )
      :sym -> (
        size = match_sym(rest)
        { str, rest } = Utils.str_partition(rest, size)
        print_token(%Token{ kind: "sym", val: str, lineno: lineno })
        lex(rest, lineno)
      )
      :int -> (
        size = match_int(rest)
        { str, rest } = Utils.str_partition(rest, size)
        print_token(%Token{ kind: "int", val: str, lineno: lineno })
        lex(rest, lineno)
      )
      :str -> (
        size = match_str(rest)
        str = String.slice(rest, 1, size - 2)
        { _, rest } = Utils.str_partition(rest, size)
        print_token(%Token{ kind: "str", val: str, lineno: lineno })
        lex(rest, lineno)
      )
      :ident -> (
        size = match_ident(rest)
        { str, rest } = Utils.str_partition(rest, size)
        kind = if kw?(str), do: "kw", else: "ident"
        print_token(%Token{ kind: kind, val: str, lineno: lineno })
        lex(rest, lineno)
      )
      :comment -> (
        size = match_comment(rest)
        { _, rest } = Utils.str_partition(rest, size + 1)
        lex(rest, lineno)
      )
      :eof -> nil
      _ -> raise "unexpected pattern (#{rest})"
    end
  end

  def main do
    src = Utils.read_stdin_all()
    lex(src, 1)
  end
end
