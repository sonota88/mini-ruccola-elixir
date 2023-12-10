defmodule Parser do
  defp to_token(line) do
    [ lineno, kind, val ] = Json.parse(line)
    %Token{ kind: kind, val: val, lineno: lineno }
  end

  defp parse_arg([ t | ts_tl ]) do
    case t.kind do
      "ident" -> (
        { ts_tl, t.val }
      )
      "int" -> (
        { n, _ } = Integer.parse(t.val)
        { ts_tl, n }
      )
      _ -> raise "unsupported"
    end
  end

  defp parse_args(ts) do
    case ts do
      [] -> (
        { ts, [] }
      )
      [ t | ts_tl ] -> (
        case t.val do
          ")" -> (
            { ts, [] }
          )
          "," -> (
            { ts, arg } = parse_arg(ts_tl)
            { ts, arg_rest } = parse_args(ts)
            { ts, [ arg | arg_rest ] }
          )
          _ -> (
            { ts, arg } = parse_arg(ts)
            { ts, arg_rest } = parse_args(ts)
            { ts, [ arg | arg_rest ] }
          )
        end
      )
    end
  end

  defp parse_var(ts) do
    case ts do
      [
        %Token{ val: "var" },
        %Token{ val: name  },
        %Token{ val: ";"   }
        | ts
      ] -> (
        { ts, [ "var", name ] }
      )
      [
        %Token{ val: "var" },
        %Token{ val: name  },
        %Token{ val: "="   }
        | ts
      ] -> (
        { ts, expr } = parse_expr(ts)
        [ %Token{ val: ";" } | ts ] = ts
        { ts, [ "var", name, expr ] }
      )
      _ -> raise "unsupported"
    end
  end

  defp parse_expr_factor(ts) do
    [ t | ts_tl ] = ts

    case t.kind do
      "sym" -> (
        [ %Token{ val: "(" } | ts ] = ts
        { ts, expr } = parse_expr(ts)
        [ %Token{ val: ")" } | ts ] = ts
        { ts, expr }
      )
      "int" -> (
        { n, _ } = Integer.parse(t.val)
        { ts_tl, n }
      )
      "ident" -> (
        { ts_tl, t.val }
      )
      _ -> raise "unsupported"
    end
  end

  defp binop?(t), do: Enum.member?([ "+", "*", "==", "!=" ], t.val)

  defp parse_expr_tail(ts, lhs) do
    [ t | ts ] = ts
    op = t.val
    { ts, rhs } = parse_expr_factor(ts)
    expr = [ op, lhs, rhs ]

    if binop?(hd(ts)) do
      parse_expr_tail(ts, expr)
    else
      { ts, expr }
    end
  end

  defp parse_expr(ts) do
    { ts, expr } = parse_expr_factor(ts)

    if binop?(hd(ts)) do
      parse_expr_tail(ts, expr)
    else
      { ts, expr }
    end
  end

  defp parse_return(ts) do
    [
      %Token{ val: "return" }
      | ts
    ] = ts

    case ts do
      [ %Token{ val: ";" } | ts ] -> (
        { ts, [ "return" ] }
      )
      _ -> (
        { ts, expr } = parse_expr(ts)
        [ %Token{ val: ";" } | ts ] = ts
        { ts, [ "return", expr ] }
      )
    end
  end

  defp parse_set(ts) do
    [
      %Token{ val: "set" },
      %Token{ val: name  },
      %Token{ val: "="   }
      | ts
    ] = ts

    { ts, expr } = parse_expr(ts)

    [
      %Token{ val: ";" }
      | ts
    ] = ts

    stmt = [ "set", name, expr ]

    { ts, stmt }
  end

  defp parse_funcall(ts) do
    [
      %Token{ val: fn_name },
      %Token{ val: "("     }
      | ts
    ] = ts

    { ts, args } = parse_args(ts)

    [
      %Token{ val: ")" }
      | ts
    ] = ts

    { ts, [ fn_name | args ] }
  end

  defp parse_call(ts) do
    [ %Token{ val: "call" } | ts ] = ts

    { ts, funcall } = parse_funcall(ts)

    [ %Token{ val: ";" } | ts ] = ts

    { ts, [ "call", funcall ] }
  end

  defp parse_call_set(ts) do
    case ts do
      [
        %Token{ val: "call_set" },
        %Token{ val: var_name   },
        %Token{ val: "="        }
        | ts
      ] -> (
        { ts, funcall } = parse_funcall(ts)

        [ %Token{ val: ";" } | ts ] = ts

        { ts, [ "call_set", var_name, funcall ] }
      )
      _ -> raise "unsupported"
    end
  end

  defp parse_while(ts) do
    [
      %Token{ val: "while" },
      %Token{ val: "("     }
      | ts
    ] = ts

    { ts, expr } = parse_expr(ts)

    [
      %Token{ val: ")" },
      %Token{ val: "{" }
      | ts
    ] = ts

    { ts, stmts } = parse_stmts(ts)

    [
      %Token{ val: "}" }
      | ts
    ] = ts

    { ts, [ "while", expr, stmts ] }
  end

  defp parse_when_clause(ts) do
    [
      %Token{ val: "when" },
      %Token{ val: "("    }
      | ts
    ] = ts

    { ts, expr } = parse_expr(ts)

    [
      %Token{ val: ")" },
      %Token{ val: "{" }
      | ts
    ] = ts

    { ts, stmts } = parse_stmts(ts)

    [
      %Token{ val: "}" }
      | ts
    ] = ts

    { ts, [ expr | stmts ] }
  end

  defp parse_when_clauses(ts) do
    case hd(ts).val do
      "when" -> (
        { ts, when_clause_hd } = parse_when_clause(ts)
        { ts, when_clause_tl } = parse_when_clauses(ts)
        { ts, [ when_clause_hd | when_clause_tl ] }
      )
      _ -> { ts, [] }
    end
  end

  defp parse_case(ts) do
    [ %Token{ val: "case" } | ts ] = ts
    { ts, when_clauses } = parse_when_clauses(ts)
    { ts, [ "case" | when_clauses ] }
  end

  defp parse_vm_comment(ts) do
    [
      %Token{ val: "_cmt" },
      %Token{ val: "("    },
      %Token{ val: cmt    },
      %Token{ val: ")"    },
      %Token{ val: ";"    }
      | ts
    ] = ts

    { ts, [ "_cmt", cmt ] }
  end

  defp parse_debug(ts) do
    [
      %Token{ val: "_debug" },
      %Token{ val: "("      },
      %Token{ val: ")"      },
      %Token{ val: ";"      }
      | ts
    ] = ts

    { ts, [ "_debug" ] }
  end

  defp parse_stmt(ts) do
    case hd(ts).val do
      "return"   -> parse_return(ts)
      "set"      -> parse_set(ts)
      "call"     -> parse_call(ts)
      "call_set" -> parse_call_set(ts)
      "while"    -> parse_while(ts)
      "case"     -> parse_case(ts)
      "_cmt"     -> parse_vm_comment(ts)
      "_debug"   -> parse_debug(ts)
      _ -> raise "unsupported"
    end
  end

  defp parse_stmts(ts) do
    if hd(ts).val == "}" do
      { ts, [] }
    else
      { ts, stmt } = parse_stmt(ts)
      { ts, stmt_tl } = parse_stmts(ts)
      { ts, [ stmt | stmt_tl ] }
    end
  end

  defp parse_func_body(ts) do
    case hd(ts).val do
      "}" -> (
        { ts, [] }
      )
      "var" -> (
        { ts, stmt } = parse_var(ts)
        { ts, tail_stmts } = parse_func_body(ts)
        { ts, [ stmt | tail_stmts ] }
      )
      _ -> (
        { ts, stmt } = parse_stmt(ts)
        { ts, tail_stmts } = parse_func_body(ts)
        { ts, [ stmt | tail_stmts ] }
      )
    end
  end

  defp parse_func_def(ts) do
    [
      %Token{ val: "func"  },
      %Token{ val: fn_name },
      %Token{ val: "("     }
      | ts
    ] = ts

    { ts, args } = parse_args(ts)

    [
      %Token{ val: ")" },
      %Token{ val: "{" }
      | ts
    ] = ts

    { ts, body } = parse_func_body(ts)

    [ %Token{ val: "}" } | ts ] = ts

    { ts, [ "func", fn_name, args, body ] }
  end

  defp parse_top_stmt(ts) do
    parse_func_def(ts)
  end

  defp parse_top_stmts_iter(ts) do
    case ts do
      [] -> { ts, [] }
      [ t | _ ] -> (
        if t.val == "func" do
          { ts, top_stmt } = parse_top_stmt(ts)
          { ts, tail } = parse_top_stmts_iter(ts)
          top_stmts = [ top_stmt | tail ]
          { ts, top_stmts }
        else
          raise "unsupported"
        end
      )
    end
  end

  defp parse_top_stmts(ts) do
    { _, top_stmts } = parse_top_stmts_iter(ts)

    [ "top_stmts" | top_stmts ]
  end

  def main do
    ts =
      Utils.read_stdin_all()
      |> String.split("\n")
      |> Enum.filter(&(String.starts_with?(&1, "[")))
      |> Enum.map(&(to_token(&1)))

    ast = parse_top_stmts(ts)

    Json.pretty_print(ast)
  end
end
