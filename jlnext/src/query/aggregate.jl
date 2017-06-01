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

ev(sig::AggregateSig, dv::DataVector) =
    let col = column(dv, 1)
        sig.haszero || !isoptional(col) ?
            plain_aggregate_impl(sig.fn, sig.restype, length(dv), col) :
            aggregate_impl(sig.fn, sig.restype, length(dv), col)
    end

function plain_aggregate_impl{T}(fn::Function, otype::Type{T}, len::Int, arg::Column)
    vals = Vector{T}(len)
    cr = cursor(arg)
    while !done(arg, cr)
        next!(arg, cr)
        vals[cr.pos] = fn(cr)
    end
    return PlainColumn(vals)
end

function aggregate_impl{T}(fn::Function, otype::Type{T}, len::Int, arg::Column)
    argoffs = offsets(arg)
    size = 0
    @inbounds for k = 1:len
        if argoffs[k] < argoffs[k+1]
            size += 1
        end
    end
    if size == len
        col = plain_aggregate_impl(fn, otype, len, arg)
        return OptionalColumn(col.offs, col.vals)
    end
    offs = Vector{Int}(len+1)
    offs[1] = 1
    vals = Vector{T}(size)
    cr = cursor(arg)
    n = 1
    while !done(arg, cr)
        next!(arg, cr)
        if !isempty(cr)
            vals[n] = fn(cr)
            n += 1
        end
        offs[cr.pos+1] = n
    end
    return Column(offs, vals)
end

