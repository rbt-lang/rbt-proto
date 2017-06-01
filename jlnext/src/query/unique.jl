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

ev(::UniqueSig, dv::DataVector) =
    unique_impl(length(dv), column(dv, 1))

function unique_impl{OPT,PLU,O,V}(len::Int, col::Column{OPT,PLU,O,V})
    offs = offsets(col)
    vals = values(col)
    dict = Dict{eltype(V),Int}()
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
    return Column{OPT,PLU}(offs′, vals[idxs])
end

