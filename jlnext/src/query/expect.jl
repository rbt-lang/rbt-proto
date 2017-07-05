#
#  Cardinality assertions.
#

function ExpectQuery(base::Query, optional::Bool, plural::Bool)
    dom = domain(output(base))
    q = RecordQuery(base)
    return (
        q >>
        Query(
            ExpectSig(optional, plural),
            Input([output(base)]),
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
    col = column(dv, 1)
    if !sig.optional
        expect_not_optional_impl!(col)
    end
    if !sig.plural
        expect_not_plural_impl!(col)
    end
    return Column{sig.optional,sig.plural}(col.offs, col.vals)
end

function expect_not_optional_impl!(col::Column)
    if !isoptional(col)
        return
    end
    cr = cursor(col)
    while !done(col, cr)
        next!(col, cr)
        if length(cr) < 1
            error("expected at least one value: $col")
        end
    end
end

function expect_not_plural_impl!(col::Column)
    if !isplural(col)
        return
    end
    cr = cursor(col)
    while !done(col, cr)
        next!(col, cr)
        if length(cr) > 1
            error("expected at most one value: $col")
        end
    end
end

