#
# Query composition.
#

function ComposeQuery(qs::Vector{Query})
    if length(qs) >= 2
        lq = qs[1]
        for rq in qs[2:end]
            @assert fits(output(lq), input(rq)) "($lq) >> ($rq)"
            lq = rq
        end
    end
    ity =
        if isempty(qs)
            Input(Any)
        else
            Input(
                domain(input(qs[1])),
                ibound([mode(input(q)) for q in qs]))
        end
    oty =
        if isempty(qs)
            Output(Any)
        else
            Output(
                domain(output(qs[end])),
                obound([mode(output(q)) for q in qs]))
        end
    return Query(ComposeSig(), qs, ity, oty)
end

>>(q1::Query, q2::Query) = ComposeQuery([q1, q2])

immutable ComposeSig <: AbstractSignature
end

function ev(::ComposeSig, args::Vector{Query}, ::Input, oty::Output, iflow::InputFlow)
    oflow = OutputFlow(
            domain(iflow),
            PlainColumn(values(iflow)))
    first = true
    for arg in args
        iflow′ =
            if first
                narrow(iflow, input(arg))
            else
                distribute(narrow(iflow, input(arg)), oflow)
            end
        oflow′ = ev(arg, iflow′)
        oflow =
            if first
                oflow′
            else
                optional = isoptional(oflow) || isoptional(oflow′)
                plural = isplural(oflow) || isplural(oflow′)
                OutputFlow(
                    output(oflow′),
                    Column{optional,plural}(
                        compose_impl(offsets(oflow), offsets(oflow′)),
                        values(oflow′)))
            end
        first = false
    end
    return OutputFlow(oty, column(oflow))
end

compose_impl(offs1::AbstractVector{Int}, offs2::AbstractVector{Int}) =
    Int[offs2[off] for off in offs1]

compose_impl(offs1::OneTo, offs2::OneTo) = offs1

compose_impl(offs1::OneTo, offs2::AbstractVector{Int}) = offs2

compose_impl(offs1::AbstractVector{Int}, offs2::OneTo) = offs1

