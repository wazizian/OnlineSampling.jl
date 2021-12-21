# Propagation of nothing
Cassette.@context NothingCtx

nothing_overdub(f, args...) =
    Cassette.overdub(Cassette.disablehooks(NothingCtx()), f, args...)

function Cassette.overdub(ctx::NothingCtx, f, args...)
    if !applicable(f, args...)
        return nothing
    elseif Cassette.canrecurse(ctx, f, args...)
        return Cassette.recurse(ctx, f, args...)
    else
        return Cassette.fallback(ctx, f, args...)
    end
end

function Cassette.overdub(ctx::NothingCtx, ::typeof(nothing_overdub), args...)
    return Cassette.overdub(ctx, args[1], args[2:end]...)
end

# Manual (and temporary) workaround for 
# https://github.com/JuliaLabs/Cassette.jl/issues/138
function Cassette.overdub(ctx::NothingCtx, ::typeof(println), args...)
    return Cassette.fallback(ctx, println, args...)
end

