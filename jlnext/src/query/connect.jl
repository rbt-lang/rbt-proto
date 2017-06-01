#
# Hierarchical closure.
#

function ConnectQuery(refl::Bool, q::Query)
    @assert fits(output(q), input(q))
    @assert isoptional(output(q))
    Query(
        ConnectSig(refl),
        [q],
        input(q),
        output(q) |> setoptional(!refl) |> setplural())
end

immutable ConnectSig <: AbstractSignature
    refl::Bool
end

ev(sig::ConnectSig, args::Vector{Query}, ity::Input, oty::Output, iflow::InputFlow) =
    ev(sig, args..., ity, oty, iflow)

function ev(sig::ConnectSig, arg::Query, ::Input, oty::Output, iflow::InputFlow)
    cols = Column[]
    if sig.refl
        push!(cols, Column(OneTo(length(iflow)+1), values(iflow)))
    end
    oflow = ev(arg, iflow)
    while length(values(oflow)) > 0
        push!(cols, column(oflow))
        iflow = distribute(iflow, oflow)
        oflow = ev(arg, iflow)
    end
    if isempty(cols)
        pile = column(oflow)
    else
        pile = cols[end]
        for k = endof(cols)-1:-1:1
            pile = connect_impl(cols[k], pile)
        end
    end
    return OutputFlow(oty, pile)
end

function connect_impl(col1::Column, col2::Column)
    len1 = length(col1)
    len2 = length(col2)
    offs1 = offsets(col1)
    offs2 = offsets(col2)
    vals1 = values(col1)
    vals2 = values(col2)
    L = length(vals1)
    offs = Vector{Int}(len1+1)
    offs[1] = 1
    vals = vcat(vals1, vals2)
    idxs = Vector{Int}(length(vals))
    n = 1
    for i = 1:len1
        l1 = offs1[i]
        r1 = offs1[i+1]
        for j = l1:r1-1
            idxs[n] = j
            n += 1
            l2 = offs2[j]
            r2 = offs2[j+1]
            for k = l2:r2-1
                idxs[n] = L + k
                n += 1
            end
        end
        offs[i+1] = n
    end
    return Column(offs, vals[idxs])
end

