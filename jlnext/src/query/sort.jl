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

function SortByOrdering(flow::OutputFlow)
    @assert !isplural(output(flow))
    offs = offsets(flow)
    vals = values(flow)
    rev = decoration(output(flow), :rev, Bool, false)
    nullrev = decoration(output(flow), :nullrev, Bool, false)
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

function ev(sig::SortSig, ds::DataSet)
    if !sig.haskey
        f = flow(ds, 1)
        rev = decoration(output(f), :rev, Bool, false)
        return ev_sort(column(f), rev)
    else
        offs = offsets(ds, 1)
        ds′ = values(ds, 1)::DataSet
        vals = values(ds′, 1)
        perm = collect(1:length(vals))
        fs = flows(ds′)
        for k = endof(fs):-1:2
            order = SortByOrdering(fs[k])
            ev_sort_by!(offs, perm, order)
        end
        return Column(offs, vals[perm])
    end
end

function ev_sort(col::Column, rev::Bool)
    len = length(col)
    offs = offsets(col)
    vals = copy(values(col))
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(vals, l:r-1), rev=rev)
    end
    return Column(offs, vals)
end

function ev_sort_by!(offs::AbstractVector{Int}, perm::Vector{Int}, order::SortByOrdering)
    len = length(offs) - 1
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(perm, l:r-1), alg=MergeSort, order=order)
    end
end

