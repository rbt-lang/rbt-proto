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
            Output(dom)))
end

immutable FilterSig <: AbstractPrimitive
end

ev(sig::FilterSig, ds::DataSet) =
    isplain(output(flow(ds, 2))) ?
        ev_plain_filter(values(ds, 1), values(ds, 2)) :
        ev_filter(values(ds, 1), offsets(ds, 2), values(ds, 2))

function ev_plain_filter(vals::AbstractVector, predvals::AbstractVector{Bool})
    len = length(vals)
    size = 0
    for pred in predvals
        if pred
            size += 1
        end
    end
    if size == len
        return Column(OneTo(len+1), vals)
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
    return Column(offs, vals[idxs])
end

function ev_filter(vals::AbstractVector, predoffs::AbstractVector{Int}, predvals::AbstractVector{Bool})
    len = length(vals)
    size = 0
    for pred in predvals
        if pred
            size += 1
        end
    end
    if size == len
        return Column(OneTo(len+1), vals)
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
    return Column(offs, vals[idxs])
end

