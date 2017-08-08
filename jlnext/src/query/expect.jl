#
#  Cardinality assertions.
#

function ExpectQuery(base::Query, optional::Bool, plural::Bool)
    dom = domain(output(base))
    q = RecordQuery(istub(base), base)
    return (
        q >>
        Query(
            ExpectSig(optional, plural),
            Input(domain(output(q))),
            Output(dom, OutputMode(optional, plural))))
end

ExpectOneQuery(base::Query) = ExpectQuery(base, false, false)

ExpectAtMostOneQuery(base::Query) = ExpectQuery(base, true, false)

ExpectAtLeastOneQuery(base::Query) = ExpectQuery(base, false, true)

immutable ExpectSig <: AbstractPrimitive
    optional::Bool
    plural::Bool
end

function ev(sig::ExpectSig, dv::DataVector)
    icol = column(dv, 1)
    col = column(dv, 2)
    if !sig.optional
        expect_not_optional_impl!(icol, col)
    end
    if !sig.plural
        expect_not_plural_impl!(icol, col)
    end
    return Column{sig.optional,sig.plural}(col.offs, col.vals)
end

function expect_not_optional_impl!(icol::Column, col::Column)
    if !isoptional(col)
        return
    end
    icr = cursor(icol)
    cr = cursor(col)
    while !done(col, cr)
        next!(icol, icr)
        next!(col, cr)
        if length(cr) < 1
            error("expected at least one value: $(icr[1]) -> $cr")
        end
    end
end

function expect_not_plural_impl!(icol::Column, col::Column)
    if !isplural(col)
        return
    end
    icr = cursor(icol)
    cr = cursor(col)
    while !done(col, cr)
        next!(icol, icr)
        next!(col, cr)
        if length(cr) > 1
            error("expected at most one value: $(icr[1]) -> $cr")
        end
    end
end

