#
# The filter combinator.
#

function FilterQuery(base::Query, pred::Query)
    @assert fits(output(base), input(pred))
    @assert fits(output(pred), Domain(Bool))
    @assert !isplural(output(pred))
    dom = domain(output(base))
    return (
        base >>
        RecordQuery(ItQuery(dom), pred) >>
        Query(
            FilterSig(),
            Input([dom, output(pred)]),
            Output(dom) |> setoptional()))
end

immutable FilterSig <: AbstractPrimitive
end

describe(io::IO, ::FilterSig) = print(io, "filter′")

ev(sig::FilterSig, dv::DataVector) =
    isplain(column(dv, 2)) ?
        plain_filter_impl(values(dv, 1), values(dv, 2)) :
        filter_impl(values(dv, 1), offsets(dv, 2), values(dv, 2))

function plain_filter_impl(vals::AbstractVector, predvals::AbstractVector{Bool})
    len = length(vals)
    size = 0
    for pred in predvals
        if pred
            size += 1
        end
    end
    if size == len
        return OptionalColumn(OneTo(len+1), vals)
    end
    offs = Vector{Int}(len+1)
    offs[1] = 1
    idxs = Vector{Int}(size)
    n = 1
    for k in eachindex(predvals)
        if predvals[k]
            idxs[n] = k
            n += 1
        end
        offs[k+1] = n
    end
    return OptionalColumn(offs, vals[idxs])
end

function filter_impl(vals::AbstractVector, predoffs::AbstractVector{Int}, predvals::AbstractVector{Bool})
    len = length(vals)
    size = 0
    for pred in predvals
        if pred
            size += 1
        end
    end
    if size == len
        return OptionalColumn(OneTo(len+1), vals)
    end
    offs = Vector{Int}(len+1)
    offs[1] = 1
    idxs = Vector{Int}(size)
    n = 1
    for k in 1:len
        l = predoffs[k]
        r = predoffs[k+1]
        if l < r && predvals[l]
            idxs[n] = k
            n += 1
        end
        offs[k+1] = n
    end
    return OptionalColumn(offs, vals[idxs])
end

