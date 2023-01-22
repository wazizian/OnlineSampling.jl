.PHONY: test
.PHONY: dev_test

NAME=OnlineSampling

JTHREADS=10

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
	julia --project -e "using Revise, OnlineSampling, MacroTools, IRTools" -i -t $(JTHREADS)

demo:
	julia --project -e "using Revise, OnlineSampling, MacroTools, IRTools;include(\"ex.jl\")" -i

collect_mem_analysis:
	julia --track-allocation=user -e "using Pkg, Profile; Pkg.test(\"$(NAME)\"); Profile.clear_malloc_data(); Pkg.test(\"$(NAME)\")" -t $(JTHREADS)

mem_analysis:
	julia -i -e "using Coverage; allocs = analyze_malloc(\"src\")" 

