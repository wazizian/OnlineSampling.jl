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
    println(postwalk(MacroTools.rmlines ∘ MacroTools.unblock ∘ MacroTools.flatten, body))
end

"""
    Push front for expressions
"""
function push_front(ex, body)
    return quote
        $(ex)
        $(body)
    end
end

"""
    Custom AST walk, which can be stopped
"""
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
