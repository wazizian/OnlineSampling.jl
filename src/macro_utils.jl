function sh(body)
    return println(prettify(body))
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

# Generate deterministic struct types
# TODO (impr): mark as const (except during testing)
global node_mem_struct = gensym()
function get_node_mem_struct_type(node_name::Symbol)
    global node_mem_struct
    return Symbol(node_mem_struct, node_name)
end

# For testing purposes
function _reset_node_mem_struct_types()
    global node_mem_struct
    node_mem_struct = gensym()
end
