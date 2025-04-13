Elixir port of [Mini Ruccola (vm2gol-v2)](https://github.com/sonota88/vm2gol-v2) compiler

[Elixirで簡単な自作言語のコンパイラを書いた](https://qiita.com/sonota88/items/fefef95264320a903300)

---

```
  $ asdf list erlang
 *27.3.2

  $ asdf list elixir
 *1.18.3-otp-27
```

```sh
git clone --recursive https://github.com/sonota88/mini-ruccola-elixir.git
cd mini-ruccola-elixir

./docker.sh build
./test.sh all
```

```
  $ LANG=C wc -l mrcl_{lexer,parser,codegen}.ex
  132 mrcl_lexer.ex
  392 mrcl_parser.ex
  445 mrcl_codegen.ex
  969 total
```
