"""
    Determines if a function is a node or not,
    by detecting the special node_marker() call
    Warning: is_node is broken after ir_pass due to this transform
    https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/src/reflection/utils.jl#L80
"""
is_node(::Nothing) = false
function is_node(ir::IR)
    isempty(ir) && return false
    _, st = first(ir)
    isn = false
    postwalk(st.expr) do ex
        isexpr(ex, :call) || return ex
        index =
            findfirst(arg -> (arg isa QuoteNode) && (arg.value == :node_marker), ex.args)
        ((index == nothing) || (index == 1)) && return ex
        isn |= ex.args[index-1] == @__MODULE__
        return ex
    end
    return isn
end

"""
    Determines if the function f whose type is ftype has a method
    for arguments of types argtypes
    Inspired by the code of IRTools.meta
"""
ftypehasmethod(ftype, argtypes...) =
    ftype.name.module === Core.Compiler ||
    ftype <: Core.Builtin ||
    Base._methods_by_ftype(Tuple{ftype,argtypes...}, -1, IRTools.Inner.worldcounter()) |>
    isempty |> (!)

"""
    Apply the function mod.func to the arguments of ir
"""
function inline_map_args(ir::IR, func::Symbol; mod::Module = @__MODULE__)
    args = arguments(ir)
    argtypes = IRTools.argtypes(ir)
    # following IRTools.varargs!
    argtypes = Core.Compiler.widenconst.(argtypes)
    argmap = Dict{Variable,Variable}()
    for (t, arg) in zip(argtypes, args)
        argmap[arg] = pushfirst!(ir, Statement(Expr(:block); type = t))
    end
    ir = varmap(var -> get(argmap, var, var), ir)
    for arg in args
        ir[argmap[arg]] = Statement(xcall(mod, func, arg))
    end
    return ir
end
