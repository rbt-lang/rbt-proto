#
# Query output data.
#

immutable OutputFlow <: AbstractVector{Any}
    oty::Output
    col::Column
end

OutputFlow(oty, offs, vals) = OutputFlow(oty, Column(offs, vals))

# Array interface.

size(flow::OutputFlow) = (flow.col.len,)

length(flow::OutputFlow) = flow.col.len

function getindex(flow::OutputFlow, i)
    data = getdata(Any, flow.col, i)
    if isentity(flow.oty)
        N = classname(domain(flow.oty))
        E = Entity{N}
        data =
            isplural(flow.oty) ?
                EntityVector{N,typeof(data)}(data) :
            isoptional(flow.oty) ?
                !isnull(data) ? Nullable{E}(get(data)) : Nullable{E}() :
                E(data)
    end
    return data
end

getindex(flow::OutputFlow, idxs::AbstractVector{Int}) =
    OutputFlow(flow.oty, flow.col[idxs])

Base.linearindexing(flow::OutputFlow) = Base.LinearFast()

vcat(flow1::OutputFlow, flow2::OutputFlow) =
    OutputFlow(obound(flow1.oty, flow2.oty), vcat(flow1.col, flow2.col))

Base.array_eltype_show_how(::OutputFlow) = (true, "")

summary(flow::OutputFlow) = "OutputFlow[$(length(flow.col)) \ud7 $(flow.oty)]"

# Data components.

convert(::Type{Column}, flow::OutputFlow) =
    flow.col

column(flow::OutputFlow) = flow.col
offsets(flow::OutputFlow) = offsets(flow.col)
values(flow::OutputFlow) = values(flow.col)

# Output signature and its properties.

output(flow::OutputFlow) = flow.oty
domain(flow::OutputFlow) = domain(flow.oty)
mode(flow::OutputFlow) = mode(flow.oty)
decorations(flow::OutputFlow) = decorations(flow.oty)

isplain(flow::OutputFlow) = isregular(flow.oty)
isoptional(flow::OutputFlow) = isoptional(flow.oty)
isplural(flow::OutputFlow) = isplural(flow.oty)

