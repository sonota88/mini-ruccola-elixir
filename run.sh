#!/usr/bin/bash

elixir -pz build/ -e Compiler.main "$@"
