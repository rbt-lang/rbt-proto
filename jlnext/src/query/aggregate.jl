#
# Aggregate combinators lifted from Julia functions.
#

function AggregateQuery(fn, argtype::Type, restype::Type, haszero::Bool, q::Query)
    @assert method_exists(fn, (argtype,))
    @assert fits(domain(output(q)), Domain(argtype))
    argq = RecordQuery(q)
    sig = AggregateSig(fn, argtype, restype, haszero)
    ity = Input(domain(output(argq)))
    oty = Output(restype) |> setoptional(!haszero && isoptional(output(q)))
    return argq >> Query(sig, ity, oty)
end

AggregateQuery(fn, argtype::Type, restype::Type, q::Query) =
    AggregateQuery(fn, argtype, restype, true, q)

AggregateQuery(fn, argtype::Type, haszero::Bool, q::Query) =
    let restype = Union{Base.return_types(fn, (Vector{argtype},))...}
        AggregateQuery(fn, argtype, restype, haszero, q)
    end

AggregateQuery(fn, argtype::Type, q::Query) =
    AggregateQuery(fn, argtype, true, q)

AggregateQuery(fn, haszero::Bool, q::Query) =
    let argtype = datatype(domain(output(q)))
        AggregateQuery(fn, argtype, haszero, q)
    end

AggregateQuery(fn, q::Query) =
    AggregateQuery(fn, true, q)

immutable AggregateSig <: AbstractPrimitive
    fn::Function
    argtype::Type
    restype::Type
    haszero::Bool
end

ev(sig::AggregateSig, ds::DataSet) =
    sig.haszero || !isoptional(output(flow(ds, 1))) ?
        ev_plain_aggregate(sig.fn, sig.restype, length(ds), column(ds, 1)) :
        ev_aggregate(sig.fn, sig.restype, length(ds), column(ds, 1))

function ev_plain_aggregate{T}(fn::Function, otype::Type{T}, len::Int, arg::Column)
    argoffs = offsets(arg)
    argvals = values(arg)
    offs = OneTo(len+1)
    vals = Vector{T}(len)
    for k = 1:len
        l = argoffs[k]
        r = argoffs[k+1]
        vals[k] = fn(view(argvals, l:r-1))
    end
    return Column(offs, vals)
end

function ev_aggregate{T}(fn::Function, otype::Type{T}, len::Int, arg::Column)
    argoffs = offsets(arg)
    size = 0
    for k = 1:len
        if argoffs[k] < argoffs[k+1]
            size += 1
        end
    end
    if size == len
        return ev_plain_aggregate(fn, otype, len, arg)
    end
    argvals = values(arg)
    offs = Vector{Int}(len+1)
    offs[1] = 1
    vals = Vector{T}(size)
    n = 1
    for k = 1:len
        l = argoffs[k]
        r = argoffs[k+1]
        if l < r
            vals[n] = fn(view(argvals, l:r-1))
            n += 1
        end
        offs[k+1] = n
    end
    return Column(offs, vals)
end

