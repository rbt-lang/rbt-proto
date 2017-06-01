#
# Record combinator.
#

RecordQuery(qs::Vector{Query}) =
    Query(
        RecordSig(),
        qs,
        ibound([input(q) for q in qs]),
        Output([output(q) for q in qs]))

RecordQuery(q1::Query, qrest...) =
    RecordQuery([q1], qrest...)

RecordQuery(qs1::Vector{Query}, q2::Query, qrest...) =
    RecordQuery([qs1..., q2], qrest...)

RecordQuery(qs1::Vector{Query}, qs2::Vector{Query}, qrest...) =
    RecordQuery([qs1..., qs2...], qrest...)

immutable RecordSig <: AbstractSignature
end

ev(::RecordSig, args::Vector{Query}, ::Input, oty::Output, iflow::InputFlow) =
    let len = length(iflow),
        cols = Column[ev(arg, narrow(iflow, input(arg))) for arg in args]
        OutputFlow(oty, PlainColumn(DataVector(len, cols)))
    end

