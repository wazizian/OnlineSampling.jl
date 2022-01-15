"""
    Debug pretty-printer (using MacroTools)
"""
function sh(body)
    println(prettify(body))
end

"""
    Debug pretty-printer (using MacroTools)
"""
function shh(body)
    println(postwalk(rmlines, body))
end

function push_front(ex, body)
    return quote
        $(ex)
        $(body)
    end
end

function stopwalk(f, x::Expr)
    # Walk the AST of x
    # If f(x) = nothing, continue recursively on x's children
    # Otherwise, the walk stops
    # Note that f is given the ability to call the walk itself
    # (Inspired by the walk function from MacroTools)
    self = x -> stopwalk(f, x)
    y = f(self, x)
    return isnothing(y) ? Expr(x.head, map(x -> stopwalk(f, x), x.args)...) : y
end
# Ignore x if not an expr
stopwalk(f, x) = x

const unesc = Symbol("hygienic-scope")

function unescape(transf, expr_args...)
    # unescape the code transformation transf
    return @chain expr_args begin
        map(esc, _)
        transf(_...)
        Expr(unesc, _, @__MODULE__)
    end
end

# TODO (impr): mark as const (except during testing)
@gensym node_mem_struct

"""
    Generate deterministic struct types
"""
function get_node_mem_struct_type(node_name::Symbol)
    global node_mem_struct
    return Symbol(node_mem_struct, node_name)
end

function get_node_mem_struct_type(ex::Expr)
    # handle the case Module.f
    if ex.head == :.
        @assert length(ex.args) >= 2
        return Expr(:., ex.args[1], get_node_mem_struct_type(ex.args[2]))
    else
        error("Invalid call: got $(ex)")
    end
end
get_node_mem_struct_type(qn::QuoteNode) = QuoteNode(get_node_mem_struct_type(qn.value))

# For testing purposes
function _reset_node_mem_struct_types()
    global node_mem_struct
    node_mem_struct = gensym()
    # redefine special nodes with new names
    srcdir = dirname(@__FILE__)
    include(joinpath(srcdir, "special_nodes.jl"))
end

"""
    Given a mutable struct, perform a deep-copy of all its fields
"""
@generated function deeptransfer!(target::S, origin::S) where {S}
    ex = Expr(:block)
    # compile-time loop, no run-time introspection
    ex.args = [
        :($(target).$(field) = deepcopy($(origin).$(field))) for field in fieldnames(target)
    ]
    return ex
end
