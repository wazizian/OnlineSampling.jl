macro init(args...)
    error("Ill-formed @init: got @init $(args...)")
end

macro prev(args...)
    error("Ill-formed @prev: got @prev $(args...)")
end

macro node(args...)
    @assert !isempty(args)
    func = args[end]
    splitted = nothing
    try
        splitted = splitdef(func)
    catch AssertionError
        return node_run(args...)
    end
    return node_build(splitted)
end
