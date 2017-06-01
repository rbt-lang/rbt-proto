#
# Record field.
#

FieldQuery(dom::Domain, pos::Int) =
    let fs = fields(dom)
        @assert 1 <= pos <= length(fs)
        Query(
            FieldSig(pos),
            Input(dom),
            fs[pos])
    end

FieldQuery(oty::Output, pos) =
    FieldQuery(domain(oty), pos)

immutable FieldSig <: AbstractPrimitive
    pos::Int
end

ev(sig::FieldSig, dv::DataVector) =
    column(dv, sig.pos)

