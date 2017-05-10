#
# Framing the input context.
#

FrameQuery(q::Query) =
    Query(
        FrameSig(),
        [q],
        input(q) |> setrelative(false),
        output(q))

immutable FrameSig <: AbstractSignature
end

ev(sig::FrameSig, args::Vector{Query}, ity::Input, oty::Output, iflow::InputFlow) =
    ev(sig, args..., ity, oty, iflow)

ev(::FrameSig, arg::Query, ::Input, oty::Output, iflow::InputFlow) =
    let iflow =
        InputFlow(
            iflow.ctx,
            domain(iflow),
            iflow.vals,
            InputFrame(OneTo(iflow.len+1)),
            iflow.paramflows)
        OutputFlow(
            oty,
            column(ev(arg, iflow)))
    end

