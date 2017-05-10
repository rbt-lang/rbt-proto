#
# Identity primitive.
#

ItQuery(dom::Domain) =
    Query(ItSig(), Input(dom), Output(dom))

ItQuery(dom) =
    ItQuery(convert(Domain, dom))

immutable ItSig <: AbstractPrimitive
end

ev(::ItSig, vals::AbstractVector) =
    Column(OneTo(length(vals)+1), vals)

