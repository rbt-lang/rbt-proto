#
# The grouping combinator.
#

function GroupQuery(qbase::Query, qks::Vector{Query})
    for qk in qks
        @assert fits(output(qbase), input(qk))
        @assert !isplural(qk)
    end
    q = RecordQuery(
            qbase >>
            RecordQuery(ostub(qbase), qks))
    q >>
    Query(
        GroupSig(),
        Input(domain(output(q))),
        Output([output(qbase) |> setoptional(false), (output(qk) for qk in qks)...])
            |> setoptional(isoptional(output(qbase)))
            |> setplural(isplural(output(qbase)) && !isempty(qks)))
end

GroupQuery(qbase::Query, qks::Query...) =
    GroupQuery(qbase, collect(Query, qks))

immutable GroupSig <: AbstractPrimitive
end

describe(io::IO, ::GroupSig) = print(io, "group′")

ev(sig::GroupSig, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(oty, ev(sig, values(iflow), fields(domain(iflow))...))

ev(sig::GroupSig, dv::DataVector, oty::Output) =
    group_impl(column(dv, 1), fields(oty))

function group_impl{OPT,PLU}(dvcol::Column{OPT,PLU}, fs::Vector{Output})
    dvoffs = offsets(dvcol)
    dv = values(dvcol)
    perm, offs = group_by_keys_impl(group_skip_impl(dvoffs), dv, fs)
    groupoffs = group_match_impl(dvoffs, offs)
    keyperm = perm[view(offs, 1:endof(offs)-1)]
    width = length(columns(dv)) - 1
    cols = Vector{Column}(width+1)
    cols[1] = Column{false,PLU}(offs, values(dv, 1)[perm])
    for k = 1:width
        cols[k+1] = column(dv, k+1)[keyperm]
    end
    return Column{OPT,PLU}(groupoffs, DataVector(length(offs)-1, cols))
end

function group_skip_impl(offs::AbstractVector{Int})
    empty = 0
    for k = 1:length(offs)-1
        if offs[k] == offs[k+1]
            empty += 1
        end
    end
    if empty == 0
        return offs
    end
    offs′ = Vector{Int}(length(offs)-empty)
    offs′[1] = 1
    n = 1
    for k = 1:length(offs)-1
        if offs[k] < offs[k+1]
            n += 1
            offs′[n] = offs[k+1]
        end
    end
    return offs′
end

function group_by_keys_impl(offs::AbstractVector{Int}, dv::DataVector, fs::Vector{Output})
    len = length(offs) - 1
    width = length(dv.cols) - 1
    vals = values(dv, 1)
    perm = collect(1:length(vals))
    for k = 1:width
        order = SortByOrdering(fs[k+1], column(dv, k+1))
        offs = group_by_key_impl!(offs, perm, order)
    end
    return perm, offs
end

function group_by_key_impl!(
        offs::AbstractVector{Int},
        perm::Vector{Int},
        order::SortByOrdering)
    len = length(offs)-1
    len′ = 0
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(perm, l:r-1), alg=MergeSort, order=order)
        len′ += 1
        for j = l+1:r-1
            if Base.lt(order, perm[j-1], perm[j])
                len′ += 1
            end
        end
    end
    offs′ = Vector{Int}(len′+1)
    offs′[1] = 1
    n = 1
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        for j = l+1:r-1
            if Base.lt(order, perm[j-1], perm[j])
                n += 1
                offs′[n] = j
            end
        end
        n += 1
        offs′[n] = r
    end
    return offs′
end

function group_match_impl(offs::AbstractVector{Int}, offs′::AbstractVector{Int})
    groupoffs = Vector{Int}(length(offs))
    n = 1
    for k = 1:length(offs)
        b = offs[k]
        while offs′[n] < b
            n += 1
        end
        groupoffs[k] = n
    end
    return groupoffs
end

