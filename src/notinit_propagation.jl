using IRTools
using IRTools:
    IR, explicitbranch!, Variable, arguments, block, branches, Branch, blocks, isreturn
using MacroTools: postwalk

"""
    Expr referring to notinit
"""
const notinitGlobalRef = GlobalRef(@__MODULE__, :notinit)

"""
    Determine whether an Expr contains a notinit
"""
isnotinit(notinits::AbstractSet{Variable}, v::Variable) = v in notinits
isnotinit(notinits::AbstractSet{Variable}, ex::Expr) =
    any(arg -> isnotinit(notinits, arg), ex.args)
isnotinit(::AbstractSet{Variable}, g::GlobalRef) = g == notinitGlobalRef
isnotinit(::AbstractSet{Variable}, ::NotInit) = true
isnotinit(::AbstractSet{Variable}, ::Any) = false

"""
    Propagate notinits in a block and follow branches 
"""
function block_propagate_notinits!(
    ir::IR,
    notinit_nbs::Dict{Int,Int},
    notinits::AbstractSet{Variable},
    notinit_args::AbstractVector{Int},
    block_id::Int,
)
    b = block(ir, block_id)
    args = arguments(b)
    union!(notinits, map(i -> args[i], notinit_args))
    if haskey(notinit_nbs, block_id) && (notinit_nbs[block_id] == length(notinits))
        return ir, notinit_nbs, notinits
    end

    for (x, stmt) in b
        if isnotinit(notinits, stmt.expr)
            push!(notinits, x)
            b[x] = Statement(notinitGlobalRef; type = NotInit)
        end
    end

    notinit_nbs[block_id] = length(notinits)
    brs = branches(b)
    next_calls = Any[]
    burn_blocks = false
    for (i, br) in enumerate(brs)
        if !isreturn(br)
            burn_blocks |= isnotinit(notinits, br.condition)
            push!(next_calls, (br.block, arguments(br)))
        end
    end

    if burn_blocks
        for (i, br) in enumerate(brs)
            br =
                brs[i] = Branch(
                    br;
                    condition = nothing,
                    args = fill(notinitGlobalRef, length(arguments(br))),
                )
            ir, notinit_nbs, notinits = burn_block!(ir, notinit_nbs, notinits, br.block)
        end
    else
        for (block_id, args) in next_calls
            ir, notinit_nbs, notinits = block_propagate_notinits!(
                ir,
                notinit_nbs,
                notinits,
                findall(arg -> isnotinit(notinits, arg), args),
                block_id,
            )
        end
    end

    return ir, notinit_nbs, notinits
end

"""
    Burn a block: set all its variables to notinit
    This is required when a block is called with a
    condition which is notinit
"""
function burn_block!(
    ir::IR,
    notinit_nbs::Dict{Int,Int},
    notinits::AbstractSet{Variable},
    block_id,
)
    b = block(ir, block_id)
    args = arguments(b)
    union!(notinits, keys(b))
    return block_propagate_notinits!(
        ir,
        notinit_nbs,
        notinits,
        collect(1:length(args)),
        block_id,
    )
end

"""
    Propagate notinits (over-approximation) in ir by computing a fixed point
"""
function propagate_notinits!(ir::IR)
    explicitbranch!(ir)
    notinit_nbs = Dict{Int,Int}()
    notinits = Set{Variable}()
    old_notinit_nb = -1
    while length(notinits) > old_notinit_nb
        old_notinit_nb = length(notinits)
        b = first(blocks(ir))
        ir, notinit_nbs, notinits =
            block_propagate_notinits!(ir, notinit_nbs, notinits, Vector{Int}(), b.id)
    end
    return ir
end
