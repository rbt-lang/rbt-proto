#
# Sorting.
#

# Combinator for sorting a collection.

SortQuery(q::Query) =
    RecordQuery(q) >>
    Query(
        SortSig(false),
        Input([output(q)]),
        output(q))

SortQuery(qbase::Query, qks::Vector{Query}) =
    let q = RecordQuery(qbase >> RecordQuery(ostub(qbase), qks))
        q >>
        Query(
            SortSig(true),
            Input(domain(output(q))),
            output(qbase))
    end

SortQuery(qbase::Query, qks::Query...) =
    SortQuery(qbase, collect(qks))

# Custom ordering.

immutable SortByOrdering{O<:AbstractVector{Int}, V<:AbstractVector} <: Base.Ordering
    offs::O
    vals::V
    rev::Bool
    nullrev::Bool
end

SortByOrdering(flow::OutputFlow) =
    SortByOrdering(output(flow), column(flow))

function SortByOrdering(oty::Output, col::Column)
    @assert !isplural(oty)
    offs = offsets(col)
    vals = values(col)
    rev = decoration(oty, :rev, Bool, false)
    nullrev = decoration(oty, :nullrev, Bool, false)
    return SortByOrdering(offs, vals, rev, nullrev)
end

function Base.lt{O,V}(o::SortByOrdering{O,V}, a::Int, b::Int)
    la = o.offs[a]
    ra = o.offs[a+1]
    lb = o.offs[b]
    rb = o.offs[b+1]
    if la < ra && lb < rb
        return !o.rev ?
                isless(o.vals[la], o.vals[lb]) :
                isless(o.vals[lb], o.vals[la])
    elseif la < ra
        return o.nullrev
    elseif lb < rb
        return !o.nullrev
    else
        return false
    end
end

Base.lt{V}(o::SortByOrdering{OneTo{Int},V}, a::Int, b::Int) =
    !o.rev ?
        isless(o.vals[a], o.vals[b]) :
        isless(o.vals[b], o.vals[a])

# Sorting primitive.

immutable SortSig <: AbstractPrimitive
    haskey::Bool
end

ev(sig::SortSig, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(oty, ev(sig, values(iflow), fields(domain(iflow))...))

function ev(sig::SortSig, dv::DataVector, oty::Output)
    if !sig.haskey
        rev = decoration(oty, :rev, Bool, false)
        return sort_impl(column(dv, 1), rev)
    else
        return sort_by_impl(column(dv, 1), fields(oty))
    end
end

function sort_impl{OPT,PLU}(col::Column{OPT,PLU}, rev::Bool)
    len = length(col)
    offs = offsets(col)
    vals = copy(values(col))
    col = Column{OPT,PLU}(offs, vals)
    cr = cursor(col)
    while !done(col, cr)
        next!(col, cr)
        sort!(cr, rev=rev)
    end
    return col
end

function sort_by_impl{OPT,PLU}(col::Column{OPT,PLU}, fs::Vector{Output})
    offs = offsets(col)
    dv = values(col)
    vals = values(dv, 1)
    perm = collect(1:length(vals))
    pcol = Column{OPT,PLU}(offs, perm)
    for k = endof(fs):-1:2
        order = SortByOrdering(fs[k], column(dv, k))
        sort_by_impl!(pcol, order)
    end
    return Column{OPT,PLU}(offs, vals[perm])
end

function sort_by_impl!(pcol::Column, order::SortByOrdering)
    cr = cursor(pcol)
    while !done(pcol, cr)
        next!(pcol, cr)
        sort!(cr, alg=MergeSort, order=order)
    end
end

