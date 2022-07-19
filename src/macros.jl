"""
    Declare a variable as a memory with a default value.
    Can only be used inside a [`@node`](@ref) declaration.
"""
macro init(args...)
    error("Ill-formed @init: got @init $(args...)")
end

"""
    Access the value of a memory variable at the previous time step.
    Can only be used inside a [`@node`](@ref) declaration.
"""
macro prev(args...)
    error("Ill-formed @prev: got @prev $(args...)")
end

"""
    Condition the model with the assumption that a random variable introduced by [`rand`](@ref) takes a concrete value.

    ```
    x = rand(Normal(0, 1))     # x_t ~ N(0, 1)
    @observe(x, 1.5)           # assume x = 0.5
    ```
"""
macro observe(args...)
    error("Ill-formed @observe: got @observe $(args...)")
end

"""
    Introduced a stream function. 
    E.g.,

    ```
    @node function one()
        return 1
    end
    ```
"""
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

"""
    Function call for stream functions.

    E.g., 
    ```
    @node function one()
        return 1
    end

    @node function two()
        x = @nodecall one()
        return x + 1
    end
    ```
"""
macro nodecall(args...)
    error("Ill-formed @nodecall: got @nodecall $(args...)")
end


"""
    Turn a stream function into a julia iterator.
    Arguments:
    - `T` is the number of iterations (optional, default=`nothing`)
    - `algo` is the probabilistic runtime (optional, see [`Algorithms`](@ref))
    - `particles` is the number of particles for the probabilistic runtime (optional, default=0)
    - `rt` is the resampling threshold (optional, default=0.5)

    E.g., 
    ```
    for x in @nodeiter T = 10 f() # for 10 iterations of f
        println(x)                # print the current value
    end
    ```
"""
macro nodeiter(args...)
    return node_iter(args...)
end


"""
    Unfold an iterator and return its last value
    Arguments:
    - `T` is the number of iterations (optional, default=`nothing`)
    - `algo` is the probabilistic runtime (optional, see [`Algorithms`](@ref))
    - `particles` is the number of particles for the probabilistic runtime (optional, default=0)
    - `rt` is the resampling threshold (optional, default=0.5)

    E.g., 
    ```
    res = @noderun T = 10 f()
    ```
"""
macro noderun(args...)
    return quote
        run($(node_iter(args...)))
    end
end

macro node_ir(args...)
    # For testing purposes
    return node_run_ir(args...)
end
