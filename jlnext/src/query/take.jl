#
# Pagination.
#

TakeQuery(qbase::Query, qn::Query, rev::Bool=false) =
    let q = RecordQuery(qbase, qn)
        q >>
        Query(
            TakeSig(rev),
            Input(domain(output(q))),
            output(qbase) |> setoptional(true))
    end

SkipQuery(qbase::Query, qn::Query) =
    TakeQuery(qbase, qn, true)

immutable TakeSig <: AbstractPrimitive
    rev::Bool
end

ev(sig::TakeSig, dv::DataVector) =
    take_impl(sig.rev, column(dv, 1), column(dv, 2))

function take_impl{OPT,PLU}(rev::Bool, icol::Column{OPT,PLU}, ncol::Column)
    len = length(icol)
    ioffs = offsets(icol)
    ivals = values(icol)
    noffs = offsets(ncol)
    nvals = values(ncol)
    size = 0
    for k = 1:len
        W = ioffs[k+1] - ioffs[k]
        if noffs[k+1] == noffs[k]
            size += W
        else
            w = nvals[noffs[k]]
            size +=
                !rev ?
                    (w >= 0 ? min(w, W) : max(0, W + w)) :
                    (w >= 0 ? max(W - w, 0) : min(W, -w))
        end
    end
    if size == length(ivals)
        return icol
    end
    offs = Vector{Int}(len+1)
    idxs = Vector{Int}(size)
    n = 1
    offs[1] = 1
    for k = 1:len
        L = ioffs[k]
        W = ioffs[k+1] - ioffs[k]
        if noffs[k+1] == noffs[k]
            l = 1
            r = W
        else
            w = nvals[noffs[k]]
            if !rev
                l = 1
                r = w >= 0 ? min(w, W) : max(0, W + w)
            else
                l = w >= 0 ? min(w + 1, W + 1) : max(1, W + w + 1)
                r = W
            end
        end
        for i = (L + l - 1):(L + r - 1)
            idxs[n] = i
            n += 1
        end
        offs[k+1] = n
    end
    return Column{true,PLU}(offs, ivals[idxs])
end

