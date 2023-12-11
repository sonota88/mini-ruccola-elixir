require "rake/clean"

C_RESET = "\e[m"
C_ERR  = "\e[0;31m" # red
C_WARN = "\e[0;33m" # yellow

DEPS = {
  "build/Elixir.Utils.beam" => [
    "lib/utils.ex",
    []
  ],
  "build/Elixir.Json.beam" => [
    "lib/json.ex",
    ["lib/utils.ex"],
  ],
  "build/Elixir.Lexer.beam" => [
    "mrcl_lexer.ex",
    ["lib/utils.ex", "lib/json.ex"]
  ],
  "build/Elixir.Parser.beam" => [
    "mrcl_parser.ex",
    ["lib/utils.ex", "lib/json.ex"]
  ],
  "build/Elixir.Codegen.beam" => [
    "mrcl_codegen.ex",
    ["lib/utils.ex", "lib/json.ex"]
  ],
  "build/Elixir.Compiler.beam" => [
    "mrcl_compiler.ex",
    [
      "lib/utils.ex",
      "lib/json.ex",
      "mrcl_lexer.ex",
      "mrcl_parser.ex",
      "mrcl_codegen.ex",
    ]
  ]
}

# { "lib/utils.ex" => "build/Elixir.Utils.beam", ... }
MAP_LIB_BEAM = {}
DEPS.each { |dest, src|
  src2, _ = src
  MAP_LIB_BEAM[src2] = dest
}

task :default => :build

CLEAN.include "build/Elixir.*.beam"

task :build => [
       "build/Elixir.Compiler.beam"
     ]

DEPS.each do |dest, srcs|
  src, libs = srcs
  prerequisites = [src] + libs.map { |lib| MAP_LIB_BEAM[lib] }

  file dest => prerequisites do |t|
    f_out = File.join(__dir__, "z_compile_out.txt")

    cmd = %(elixirc -o build/)
    libs.each { |lib|
      cmd << %( -r #{lib})
    }
    cmd << %( #{src} > #{f_out} 2>&1)

    sh cmd do |ok, status|
      out = File.read(f_out)

      out.each_line do |line|
        if %r{^error: } =~ line
          print [C_ERR, line.chomp, C_RESET, "\n"].join
        elsif %r{^warning: } =~ line
          print [C_WARN, line.chomp, C_RESET, "\n"].join
        else
          puts line
        end
      end

      unless ok
        exit status.exitstatus
      end
    end
  end
end
