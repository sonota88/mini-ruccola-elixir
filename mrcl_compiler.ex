defmodule Compiler do
  def main do
    case System.argv() do
      [ "lex"       ] -> Lexer.main()
      [ "parse"     ] -> Parser.main()
      [ "codegen"   ] -> Codegen.main()
      [ "test_json" ] -> test_json()
      _ -> raise "invalid arguments"
    end
  end

  defp test_json do
    json = Utils.read_stdin_all()
    xs = Json.parse(json)
    Json.pretty_print(xs)
  end
end
