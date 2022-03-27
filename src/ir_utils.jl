"""
    Determine if there exists an index `ì` of `a` such that `pred(a[i], a[i+1])` is true.
"""
function anytwo(pred, a)
    return any(tpl -> pred(tpl[1], tpl[2]), zip(a[1:end-1], a[2:end]))
end

"""
    Determines if a function is a node or not,
    by detecting the special node_marker() call
"""
is_node(::Nothing; markers::Any) = false
function is_node(ir::IR; markers = (:node_marker,))
    isempty(ir) && return false
    isn = false
    # TODO (impr): stop the walk when a marker is found (ie adapt stopwalk to ir)
    postwalk(ir) do ex
        if isexpr(ex, :call)
            isn |= anytwo(
                (mod, name) ->
                    (mod == @__MODULE__) && (name isa QuoteNode) && (name.value in markers),
                ex.args,
            )
        elseif isexpr(ex, GlobalRef)
            isn |= (ex.mod == @__MODULE__) && (ex.name in markers)
        end
        return ex
    end
    return isn
end

is_reset_node(ir) = is_node(ir; markers = (:node_reset_marker,))
is_any_node(ir) =
    is_node(ir; markers = (:node_marker, :node_reset_marker, :node_no_reset_marker))

"""
    Determines if the function f whose type is ftype has a method
    for arguments of types argtypes
    Inspired by the code of `IRTools.meta`
"""
function ftypehasmethod(ftype, argtypes...)
    (ftype.name.module === Core.Compiler || ftype <: Core.Builtin) && return true
    methods = Base._methods_by_ftype(Tuple{ftype,argtypes...}, -1, IRTools.Inner.worldcounter())
    isempty(methods) && return false
    _, _, _, fullmatch = last(methods)
    return fullmatch
end

"""
    Apply the function mod.func to the arguments of ir
"""
function inline_map_args!(ir::IR, func::Symbol; mod::Module = @__MODULE__)
    args = arguments(ir)[2:end]
    argmap = Dict{Variable,Variable}()
    for arg in args
        argmap[arg] = pushfirst!(ir, Statement(Expr(:block)))
    end
    ir = varmap(var -> get(argmap, var, var), ir)
    for arg in args
        ir[argmap[arg]] = Statement(xcall(mod, func, arg))
    end
    return ir
end


"""
    Modification of `IRTools.recurse!` to properly handle 
    `Core._apply` and `Core._apply_iterate`
"""
# Related Issues
# https://github.com/FluxML/IRTools.jl/issues/74
# https://github.com/JuliaLabs/Cassette.jl/issues/146
# https://github.com/JuliaLabs/Cassette.jl/issues/162
# The current workaround is inspired by Zygote
# https://github.com/FluxML/Zygote.jl/blob/3a63df8edb3b613107761ff829ca61ed393ce2dd/src/lib/lib.jl#L188
function recurse!(ir, to = self)
    for (x, st) in ir
        isexpr(st.expr, :call) || continue
        if length(st.expr.args) ≥ 2 &&
           st.expr.args[1] == GlobalRef(Core, :_apply_iterate) &&
           st.expr.args[2] == GlobalRef(Base, :iterate)
            funcarg = insert!(ir, x, xcall(:tuple, st.expr.args[3]))
            ir[x] = xcall(Core, :_apply, to, funcarg, st.expr.args[4:end]...)
        elseif st.expr.args[1] == GlobalRef(Core, :_apply)
            funcarg = insert!(ir, x, xcall(:tuple, st.expr.args[2]))
            ir[x] = xcall(Core, :_apply, to, funcarg, st.expr.args[3:end]...)
        else
            ir[x] = Expr(:call, to, st.expr.args...)
        end
    end
    return ir
end
# Equivalent to the following
# irpass(::typeof(Core._apply_iterate), ::typeof(Base.iterate), f, args...) =
#     Core._apply(irpass, (f,), args...)

# irpass(::typeof(Core._apply), f, args...) = Core._apply(irpass, (f,), args...)
