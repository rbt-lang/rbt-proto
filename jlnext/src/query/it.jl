#
# Identity primitive.
#

ItQuery(dom::Domain) =
    Query(ItSig(), Input(dom), Output(dom))

ItQuery(dom) =
    ItQuery(convert(Domain, dom))

immutable ItSig <: AbstractPrimitive
end

describe(io::IO, ::ItSig) = print(io, "it")

ev(::ItSig, vals::AbstractVector) =
    Column(OneTo(length(vals)+1), vals)

