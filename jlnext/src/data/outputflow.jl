#
# Query output data.
#

immutable OutputFlow <: AbstractVector{Any}
    sig::Output
    col::Column
end

OutputFlow(sig, offs, vals) = OutputFlow(sig, Column(offs, vals))

# Array interface.

size(flow::OutputFlow) = (flow.col.len,)

length(flow::OutputFlow) = flow.col.len

function getindex(flow::OutputFlow, i::Int)
    offs = offsets(flow)
    vals = values(flow)
    l = offs[i]
    r = offs[i+1]
    T = eltype(vals)
    if isentity(flow.sig)
        E = Entity{classname(domain(flow.sig))}
        item =
            isplural(flow.sig) ?
                E[E(i) for i in view(vals, l:r-1)] :
            isoptional(flow.sig) ?
                (l < r ? Nullable{E}(E(vals[l])) : Nullable{E}()) :
                E(vals[l])
    else
        item =
            isplural(flow.sig) && length(flow) == 1 ?
                vals :
            isplural(flow.sig) ?
                view(vals, l:r-1) :
            isoptional(flow.sig) ?
                (l < r ? Nullable{T}(vals[l]) : Nullable{T}()) :
                vals[l]
    end
    return item
end

getindex(flow::OutputFlow, idxs::AbstractVector{Int}) =
    OutputFlow(flow.sig, flow.col[idxs])

Base.linearindexing(flow::OutputFlow) = Base.LinearFast()

vcat(flow1::OutputFlow, flow2::OutputFlow) =
    OutputFlow(obound(flow1.sig, flow2.sig), vcat(flow1.col, flow2.col))

Base.array_eltype_show_how(::OutputFlow) = (true, "")

summary(flow::OutputFlow) = "OutputFlow[$(length(flow.col)) \ud7 $(flow.sig)]"

# Data components.

column(flow::OutputFlow) = flow.col
offsets(flow::OutputFlow) = offsets(flow.col)
values(flow::OutputFlow) = values(flow.col)

# Output signature and its properties.

output(flow::OutputFlow) = flow.sig
domain(flow::OutputFlow) = domain(flow.sig)
mode(flow::OutputFlow) = mode(flow.sig)
decorations(flow::OutputFlow) = decorations(flow.sig)

