#
# The roll-up combinator.
#

function RollUpQuery(qbase::Query, qks::Vector{Query})
    for qk in qks
        @assert fits(output(qbase), input(qk))
        @assert isplain(qk)
    end
    q = RecordQuery(
            qbase >>
            RecordQuery(ostub(qbase), qks))
    q = q >>
        Query(
            RollUpSig(),
            Input(domain(output(q))),
            Output([
                Output([
                    domain(output(qbase)),
                    (output(qk) |> setoptional() for qk in qks)...]) |> setoptional(isoptional(qbase)) |> setplural()]))
    q >>
    Query(
        GroupSig(),
        Input(domain(output(q))),
        Output([output(qbase) |> setoptional(false), (output(qk) |> setoptional(true) for qk in qks)...])
            |> setoptional(isoptional(qbase))
            |> setplural(isplural(qbase) && !isempty(qks)))

end

RollUpQuery(qbase::Query, qks::Query...) =
    RollUpQuery(qbase, collect(Query, qks))

immutable RollUpSig <: AbstractPrimitive
end

function ev(::RollUpSig, ds::DataSet)
    ds′ = values(ds, 1)::DataSet
    width = length(flows(ds′))
    offs = offsets(ds, 1)
    groupoffs = ev_rollup_offsets(width, offs)
    fs = Vector{OutputFlow}(width)
    fs[1] =
        OutputFlow(
            output(flow(ds′, 1)),
            ev_rollup_values(1, width, offs, values(ds′, 1)))
    for k = 2:width
        fs[k] =
            OutputFlow(
                output(flow(ds′, k)) |> setoptional() |> decorate(:nullrev => true),
                ev_rollup_values(k, width, offs, values(ds′, k)))
    end
    return Column(
        OneTo(length(ds)+1),
        DataSet(
            length(ds),
            OutputFlow(
                Output([output(f) for f in fs])
                    |> setoptional(isoptional(output(flow(ds, 1))))
                    |> setplural(),
                Column(groupoffs, DataSet(width*length(ds′), fs)))))
end

function ev_rollup_offsets(width::Int, offs::AbstractVector{Int})
    offs′ = Vector{Int}(length(offs))
    for k = 1:endof(offs)
        offs′[k] = width * (offs[k] - 1) + 1
    end
    return offs′
end

function ev_rollup_values(k::Int, width::Int, offs::AbstractVector{Int}, vals::AbstractVector)
    len = length(vals)
    offs′ = Vector{Int}(len * width + 1)
    offs′[1] = 1
    n = 1
    m = 1
    idxs = Vector{Int}(len * (width-k+1))
    for i = 1:endof(offs)-1
        l = offs[i]
        r = offs[i+1]
        for p = 1:(width-k+1)
            for j = l:r-1
                idxs[n] = j
                n += 1
                offs′[m+1] = n
                m += 1
            end
        end
        for p = (width-k+2):width
            for j = l:r-1
                offs′[m+1] = n
                m += 1
            end
        end
    end
    return Column(offs′, vals[idxs])
end

