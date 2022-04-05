macro init(args...)
    error("Ill-formed @init: got @init $(args...)")
end

macro prev(args...)
    error("Ill-formed @prev: got @prev $(args...)")
end

macro observe(args...)
    error("Ill-formed @observe: got @observe $(args...)")
end

macro node(args...)
    @assert !isempty(args)
    func = args[end]
    splitted = nothing
    try
        splitted = splitdef(func)
    catch AssertionError
        error("Improper definition of @node: got @node $(args...)")
    end
    return node_build(splitted)
end

macro nodecall(args...)
    error("Ill-formed @nodecall: got @nodecall $(args...)")
end

macro nodeiter(args...)
    return node_iter(args...)
end

macro noderun(args...)
    return quote
        run($(node_iter(args...)))
    end
end

macro node_ir(args...)
    # For testing purposes
    return node_run_ir(args...)
end
