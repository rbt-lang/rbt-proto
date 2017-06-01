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
                    (output(qk) |> setoptional() |> decorate(:nullrev => true) for qk in qks)...]) |> setoptional(isoptional(qbase)) |> setplural()]))
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

ev(sig::RollUpSig, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(oty, ev(sig, values(iflow), fields(domain(iflow))...))

ev(::RollUpSig, dv::DataVector, oty::Output) =
    rollup_impl(column(dv, 1), fields(oty))

function rollup_impl{OPT,PLU}(dvcol::Column{OPT,PLU}, fs::Vector{Output})
    offs = offsets(dvcol)
    dv = values(dvcol)
    width = length(dv.cols)
    groupoffs = rollup_offsets_impl(width, offs)
    fs = Vector{Column}(width)
    fs[1] = rollup_values_impl(1, width, offs, values(dv, 1))
    for k = 2:width
        fs[k] = rollup_values_impl(k, width, offs, values(dv, k))
    end
    return PlainColumn(
                DataVector(
                    length(dvcol),
                    Column{OPT,true}(
                        groupoffs,
                        DataVector(width*length(dv), fs))))
end

function rollup_offsets_impl(width::Int, offs::AbstractVector{Int})
    offs′ = Vector{Int}(length(offs))
    for k = 1:endof(offs)
        offs′[k] = width * (offs[k] - 1) + 1
    end
    return offs′
end

function rollup_values_impl(k::Int, width::Int, offs::AbstractVector{Int}, vals::AbstractVector)
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
    return Column{k!=1,false}(offs′, vals[idxs])
end

