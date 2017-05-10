#
# The unique combinator.
#

UniqueQuery(q) =
    RecordQuery(q) >>
    Query(
        UniqueSig(),
        Input([output(q)]),
        output(q))

immutable UniqueSig <: AbstractPrimitive
end

ev(::UniqueSig, ds::DataSet) =
    ev_unique(length(ds), offsets(ds, 1), values(ds, 1))

function ev_unique{T}(len::Int, offs::AbstractVector{Int}, vals::AbstractVector{T})
    dict = Dict{T,Int}()
    offs′ = Vector{Int}(len+1)
    offs′[1] = 1
    idxs = Vector{Int}(length(vals))
    seen = fill(0, length(vals))
    n = 1
    for k in 1:len
        l = offs[k]
        r = offs[k+1]
        for i = l:r-1
            idx = get!(dict, vals[i], i)
            last = seen[idx]
            if last < l
                seen[idx] = i
                idxs[n] = idx
                n += 1
            end
        end
        offs′[k+1] = n
    end
    resize!(idxs, n-1)
    return Column(offs′, vals[idxs])
end

