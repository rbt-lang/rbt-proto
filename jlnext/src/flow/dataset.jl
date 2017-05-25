#
# A column-oriented representation of an array of records.
#

immutable DataSet <: AbstractVector{Tuple}
    dom::Domain
    len::Int
    flows::Vector{OutputFlow}

    function DataSet(len::Int, flows::Vector{OutputFlow})
        for flow in flows
            @assert length(flow) == len
        end
        return new(Domain(((output(flow) for flow in flows)...)), len, flows)
    end
end

DataSet(len::Int, flows::OutputFlow...) = DataSet(len, collect(flows))
DataSet(flow1::OutputFlow, flows::OutputFlow...) =
    DataSet(length(flow1), flow1, flows...)

# Array interface.

size(ds::DataSet) = (ds.len,)

length(ds::DataSet) = ds.len

getindex(ds::DataSet, i::Int) =
    ((flow[i] for flow in ds.flows)...)

getindex(ds::DataSet, idxs::AbstractVector{Int}) =
    DataSet(length(idxs), OutputFlow[flow[idxs] for flow in ds.flows])

Base.linearindexing(::Type{DataSet}) = Base.LinearFast()

function vcat(ds1::DataSet, ds2::DataSet)
    flows = OutputFlow[]
    w1 = length(ds1.flows)
    w2 = length(ds2.flows)
    for k = 1:min(w1, w2)
        push!(flows, vcat(ds1.flows[k], ds2.flows[k]))
    end
    if w1 < w2
        dummy1 =
            OutputFlow(
                Output(None, optional=true),
                Column(fill(1, ds1.len+1), None[]))
        for k = w1+1:w2
            push!(flows, vcat(dummy1, ds2.flows[k]))
        end
    elseif w1 > w2
        dummy2 =
            OutputFlow(
                Output(None, optional=true),
                Column(fill(1, ds2.len+1), None[]))
        for k = w2+1:w1
            push!(flows, vcat(ds1.flows[k], dummy2))
        end
    end
    return DataSet(ds1.len+ds2.len, flows)
end

Base.array_eltype_show_how(::DataSet) = (true, "")

Base.array_eltype_show_how{T,N,P<:DataSet,I,L}(::SubArray{T,N,P,I,L}) = (true, "")

summary(ds::DataSet) = "DataSet[$(ds.len) \ud7 $(ds.dom)]"

# Properties.

domain(ds::DataSet) = ds.dom
fields(ds::DataSet) = fields(ds.dom)
flows(ds::DataSet) = ds.flows
flow(ds::DataSet, i::Int) = ds.flows[i]
column(ds::DataSet, i::Int) = column(flow(ds, i))
offsets(ds::DataSet, i::Int) = offsets(flow(ds, i))
values(ds::DataSet, i::Int) = values(flow(ds, i))

