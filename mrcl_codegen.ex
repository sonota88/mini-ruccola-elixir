defmodule Env do
  defstruct fn_args: [], lvars: [], label_id: 0

  def bump_label_id(env) do
    update_in(env.label_id, &(&1 + 1))
  end

  def add_lvar(env, lvar) do
    update_in(env.lvars, &([ lvar | &1 ]))
  end

  def fn_arg?(env, name) do
    env.fn_args |> Enum.any?(&(&1 == name))
  end

  def lvar?(env, name) do
    env.lvars |> Enum.any?(&(&1 == name))
  end

  def fn_arg_disp(env, name) do
    i = Enum.find_index(env.fn_args, &(&1 == name))
    i + 2
  end

  def lvar_disp(env, name) do
    i_rev = Enum.find_index(env.lvars, &(&1 == name))
    i = length(env.lvars) - i_rev - 1
    -(i + 1)
  end
end

defmodule Codegen do
  defp puts(arg) do
    IO.puts arg
  end

  defp asm_prologue do
    puts "  push bp"
    puts "  mov bp sp"
  end

  defp asm_epilogue do
    puts "  mov sp bp"
    puts "  pop bp"
  end

  defp gen_expr_add(env) do
    puts "  pop reg_b"
    puts "  pop reg_a"
    puts "  add reg_a reg_b"

    env
  end

  defp gen_expr_mul(env) do
    puts "  pop reg_b"
    puts "  pop reg_a"
    puts "  mul reg_b"

    env
  end

  defp gen_expr_eq_neq(env, type) do
    label_id = env.label_id
    env = Env.bump_label_id(env)

    label_end = "end_#{type}_#{label_id}"
    label_then = "then_#{label_id}"

    puts "  pop reg_b"
    puts "  pop reg_a"

    puts "  compare"
    puts "  jump_eq #{label_then}"

    val_else =
      case type do
        :eq  -> 0
        :neq -> 1
        _ -> raise "invalid type"
      end
    puts "  mov reg_a #{val_else}"
    puts "  jump #{label_end}"

    puts "label #{label_then}"
    val_then =
      case type do
        :eq  -> 1
        :neq -> 0
        _ -> raise "invalid type"
      end
    puts "  mov reg_a #{val_then}"

    puts "label #{label_end}"

    env
  end

  defp gen_expr_eq(env) do
    gen_expr_eq_neq(env, :eq)
  end

  defp gen_expr_neq(env) do
    gen_expr_eq_neq(env, :neq)
  end

  defp gen_expr_binary(env, expr) do
    [ op, lhs, rhs ] = expr

    gen_expr(env, lhs)
    puts "  push reg_a"

    gen_expr(env, rhs)
    puts "  push reg_a"

    case op do
      "+"  -> gen_expr_add(env)
      "*"  -> gen_expr_mul(env)
      "==" -> gen_expr_eq(env)
      "!=" -> gen_expr_neq(env)
      _ -> raise "unsupported"
    end
  end

  defp gen_expr(env, expr) do
    cond do
      is_integer(expr) -> (
        puts "  mov reg_a #{expr}"
        env
      )
      is_binary(expr) -> (
        cond do
          Env.lvar?(env, expr) -> (
            disp = Env.lvar_disp(env, expr)
            puts "  mov reg_a [bp:#{disp}]"
            env
          )
          Env.fn_arg?(env, expr) -> (
            disp = Env.fn_arg_disp(env, expr)
            puts "  mov reg_a [bp:#{disp}]"
            env
          )
          true -> raise "unsupported"
        end
      )
      is_list(expr) -> (
        gen_expr_binary(env, expr)
      )
      true -> raise "unsupported"
    end
  end

  defp push_args(env, args) do
    case args do
      [] -> env
      [ arg | args_tl ] -> (
        push_args(env, args_tl)
        env = gen_expr(env, arg)
        puts "  push reg_a"
        env
      )
    end
  end

  defp gen_funcall(env, funcall) do
    [ fn_name | args ] = funcall

    env = push_args(env, args)

    gen_vm_comment_common("call  #{fn_name}")
    puts "  call #{fn_name}"

    puts "  add sp #{length(args)}"

    env
  end

  defp gen_call(env, stmt) do
    [ "call", funcall ] = stmt

    gen_funcall(env, funcall)
  end

  defp gen_set_common(env, var_name) do
    if Env.lvar?(env, var_name) do
      disp = Env.lvar_disp(env, var_name)
      puts "  mov [bp:#{disp}] reg_a"
    else
      raise "unsupported"
    end

    env
  end

  defp gen_call_set(env, stmt) do
    [ "call_set", var_name, funcall ] = stmt

    env = gen_funcall(env, funcall)
    gen_set_common(env, var_name)
  end

  defp gen_set(env, stmt) do
    [ "set", var_name, expr ] = stmt

    env = gen_expr(env, expr)
    gen_set_common(env, var_name)
  end

  defp gen_return(env, stmt) do
    case stmt do
      [ "return", expr ] -> (
        env = gen_expr(env, expr)
        asm_epilogue()
        puts "  ret"
        env
      )
      [ "return" ] -> (
        asm_epilogue()
        puts "  ret"
        env
      )
      _ -> raise "unsupported"
    end
  end

  defp gen_while(env, stmt) do
    [ "while", expr, stmts ] = stmt

    label_id = env.label_id
    env = Env.bump_label_id(env)

    puts "label while_#{label_id}"

    env = gen_expr(env, expr)

    puts "  mov reg_b 0"
    puts "  compare"

    puts "  jump_eq end_while_#{label_id}"

    env = gen_stmts(env, stmts)

    puts "  jump while_#{label_id}"

    puts "label end_while_#{label_id}"

    env
  end

  defp gen_when_clause(env, when_clause, case_label_id, when_id) do
    [ expr | stmts ] = when_clause

    label_end_when = "end_when_#{case_label_id}_#{when_id}"

    env = gen_expr(env, expr)

    puts "  mov reg_b 0"
    puts "  compare"
    puts "  jump_eq #{label_end_when}"

    env = gen_stmts(env, stmts)

    puts "  jump end_case_#{case_label_id}"

    puts "label #{label_end_when}"

    env
  end

  defp gen_when_clauses(env, when_clauses, case_label_id, when_id \\ 0) do
    case when_clauses do
      [] -> env
      [ hd | tl ] -> (
        env = gen_when_clause(env, hd, case_label_id, when_id)
        gen_when_clauses(env, tl, case_label_id, when_id + 1)
      )
    end
  end

  defp gen_case(env, stmt) do
    [ "case" | when_clauses ] = stmt

    label_id = env.label_id
    env = Env.bump_label_id(env)

    env = gen_when_clauses(env, when_clauses, label_id)

    puts "label end_case_#{label_id}"
    
    env
  end

  defp gen_vm_comment_common(comment) do
    replaced = String.replace(comment, " ", "~")
    puts "  _cmt #{replaced}"
  end

  defp gen_vm_comment(env, stmt) do
    [ "_cmt", comment_raw ] = stmt

    gen_vm_comment_common(comment_raw)
    env
  end

  defp gen_debug(env, _stmt) do
    puts "  _debug"
    env
  end

  defp gen_stmt(env, stmt) do
    case hd(stmt) do
      "return"   -> gen_return(env, stmt)
      "set"      -> gen_set(env, stmt)
      "call"     -> gen_call(env, stmt)
      "call_set" -> gen_call_set(env, stmt)
      "while"    -> gen_while(env, stmt)
      "case"     -> gen_case(env, stmt)
      "_cmt"     -> gen_vm_comment(env, stmt)
      "_debug"   -> gen_debug(env, stmt)
      _ -> raise "unsupported"
    end
  end

  defp gen_stmts(env, stmts) do
    case stmts do
      [] -> env
      [ stmt | stmts_tl ] -> (
        env = gen_stmt(env, stmt)
        env = gen_stmts(env, stmts_tl)
        env
      )
    end
  end

  defp gen_var(env, stmt) do
    case stmt do
      [ "var", name, expr ] -> (
        puts "  add sp -1"
        env = Env.add_lvar(env, name)
        env = gen_expr(env, expr)

        disp = Env.lvar_disp(env, name)
        puts "  mov [bp:#{disp}] reg_a" # TODO set common

        env
      )
      [ "var", name ] -> (
        puts "  add sp -1"
        Env.add_lvar(env, name)
      )
      _ -> raise "unsupported"
    end
  end

  defp gen_func_body(env, stmts) do
    case stmts do
      [] -> env
      [ stmt | tail ] -> (
        case stmt do
          [ "var" | _ ] -> (
            env = gen_var(env, stmt)
            gen_func_body(env, tail)
          )
          _ -> (
            env = gen_stmt(env, stmt)
            gen_func_body(env, tail)
          )
        end
      )
    end
  end

  defp gen_func_def(func_def, label_id) do
    [ "func", fn_name, fn_args, stmts ] = func_def

    puts "label #{fn_name}"
    asm_prologue()

    env = %Env{ fn_args: fn_args, lvars: [], label_id: label_id }

    env = gen_func_body(env, stmts)

    asm_epilogue()
    puts "  ret"

    env.label_id
  end

  defp gen_top_stmt(top_stmt, label_id) do
    [ head | _ ] = top_stmt

    case head do
      "func" -> (
        gen_func_def(top_stmt, label_id)
      )
      _ -> raise "unsupported"
    end
  end

  defp gen_top_stmts(top_stmts, label_id) do
    case top_stmts do
      [] -> nil
      [ hd | tl ] -> (
        label_id = gen_top_stmt(hd, label_id)
        gen_top_stmts(tl, label_id)
      )
    end
  end

  defp gen_builtin_set_vram do
    puts ""
    puts "label set_vram"
    asm_prologue()
    puts "  set_vram [bp:2] [bp:3]" # vram_addr value
    asm_epilogue()
    puts "  ret"
  end

  defp gen_builtin_get_vram do
    puts ""
    puts "label get_vram"
    asm_prologue()
    puts "  get_vram [bp:2] reg_a" # vram_addr dest
    asm_epilogue()
    puts "  ret"
  end

  def main do
    src = Utils.read_stdin_all()
    ast = Json.parse(src)
    # Utils.puts_kv_e "ast", inspect(ast)

    puts "  call main"
    puts "  exit"

    [ "top_stmts" | top_stmts ] = ast
    gen_top_stmts(top_stmts, 1)

    puts ""
    puts "#>builtins"
    gen_builtin_set_vram()
    gen_builtin_get_vram()
    puts "#<builtins"
  end
end
