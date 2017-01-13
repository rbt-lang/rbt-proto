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

