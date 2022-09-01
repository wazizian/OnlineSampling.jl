.PHONY: test
.PHONY: dev_test

NAME=OnlineSampling

JTHREADS=8

install:
	# fetches the lastest code from the github repo if possible, or install a copy of the
	# current folder globally, changes in this folder are not reflected globally
	julia -e "using Pkg; Pkg.add(path=\".\")"

develop: 
	# install the current folder are reflected globally, changes to this folder are
	# reflected globally
	julia -e "using Pkg; Pkg.develop(path=\".\")"
	# to undo, run
	# julia -e "using Pkg; Pkg.free(\"$(NAME)\")"

test:
	# Full package test
	julia -e "using Pkg; Pkg.test(\"$(NAME)\")" -t $(JTHREADS)

dev_test:
	# Development tests
	julia --project test/conttesting.jl -t $(JTHREADS)

uninstall:
	# Uninstall package
	julia -e "using Pkg; Pkg.rm(\"$(NAME)\")"

format:
	# Format code
	julia --project -e "using JuliaFormatter; format(\".\"; verbose=true)"

interactive:
	julia --project -e "using Revise, OnlineSampling, MacroTools, IRTools" -i

demo:
	julia --project -e "using Revise, OnlineSampling, MacroTools, IRTools;include(\"ex.jl\")" -i
