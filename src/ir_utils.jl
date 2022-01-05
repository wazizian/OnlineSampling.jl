"""
    Determines if a function is a node or not,
    by detecting the special node_marker() call
"""
is_node(::Nothing; markers::Any) = false
function is_node(
    ir::IR;
    markers = (:node_marker, :node_reset_marker, :node_no_reset_marker),
)
    isempty(ir) && return false
    isn = false
    # TODO (impr): stop the walk when a marker is found (ie adapt stopwalk to ir)
    postwalk(ir) do ex
        if isexpr(ex, :call)
            index = findfirst(arg -> (arg isa QuoteNode) && (arg.value in markers), ex.args)
            ((index == nothing) || (index == 1)) && return ex
            isn |= ex.args[index-1] == @__MODULE__
        elseif isexpr(ex, GlobalRef)
            isn |= (ex.mod == @__MODULE__) && (ex.name in markers)
        end
        return ex
    end
    return isn
end

is_reset_node(ir) = is_node(ir; markers = (:node_reset_marker,))

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
function inline_map_args!(ir::IR, func::Symbol; mod::Module = @__MODULE__)
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
