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

function ev(::GroupSig, ds::DataSet)
    ds′ = values(ds, 1)::DataSet
    perm, offs = ev_group_by_keys(ev_group_skip(offsets(ds, 1)), ds′)
    groupoffs = ev_group_match(offsets(ds, 1), offs)
    keyperm = perm[view(offs, 1:endof(offs)-1)]
    width = length(flows(ds′)) - 1
    fs = Vector{OutputFlow}(width+1)
    fs[1] =
        OutputFlow(
            Output(domain(output(flow(ds′, 1))), mode(output(flow(ds, 1)))) |> setoptional(false),
            Column(offs, values(ds′, 1)[perm]))
    for k = 1:width
        fs[k+1] =
            OutputFlow(
                output(flow(ds′, k+1)),
                column(ds′, k+1)[keyperm])
    end
    return Column(groupoffs, DataSet(length(offs)-1, fs))
end

function ev_group_skip(offs::AbstractVector{Int})
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

function ev_group_by_keys(offs::AbstractVector{Int}, ds::DataSet)
    len = length(offs) - 1
    width = length(ds.flows) - 1
    vals = values(ds, 1)
    perm = collect(1:length(vals))
    for k = 1:width
        order = SortByOrdering(flow(ds, k+1))
        offs = ev_group_by_key!(offs, perm, order)
    end
    return perm, offs
end

function ev_group_by_key!(
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

function ev_group_match(offs::AbstractVector{Int}, offs′::AbstractVector{Int})
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

