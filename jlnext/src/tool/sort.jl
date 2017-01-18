#
# Sorting.
#

immutable SortTool <: AbstractTool
    F::Tool
end

immutable SortByTool <: AbstractTool
    F::Tool
    Ks::Vector{Tool}

    function SortByTool(F::Tool, Ks::Vector{Tool})
        for K in Ks
            @assert fits(output(F), input(K))
            @assert !isplural(output(K))
        end
        return new(F, Ks)
    end
end

SortByTool(F::AbstractTool, Ks::AbstractTool...) =
    SortByTool(convert(Tool, F), collect(Tool, Ks))

input(tool::SortTool) = input(tool.F)
output(tool::SortTool) = output(tool.F)

input(tool::SortByTool) =
    Input(
        domain(input(tool.F)),
        ibound(mode(input(tool.F)), (mode(input(K)) for K in tool.Ks)...))
output(tool::SortByTool) = output(tool.F)

run(tool::Union{SortTool, SortByTool}, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::SortTool) =
    RecordTool(prim(tool.F)) >> SortPrimTool(output(tool.F))

prim(tool::SortByTool) =
    let dom = domain(output(tool.F))
        RecordTool(
            prim(tool.F) >>
            RecordTool(HereTool(dom), (prim(K) for K in tool.Ks)...)) >>
        SortByPrimTool(output(tool.F), Output[output(K) for K in tool.Ks])
    end

Sort(F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> SortTool(F(Q))
            end)

ThenSort() = Combinator(P -> SortTool(P))

ThenSort(Ks::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                SortByTool(P, (K(Q) for K in Ks)...)
            end)

ThenAsc() = ThenDecorate(rev=false)
ThenDesc() = ThenDecorate(rev=true)
ThenNullFirst() = ThenDecorate(nullrev=false)
ThenNullLast() = ThenDecorate(nullrev=true)

# The sorting primitive.

immutable SortPrimTool <: AbstractTool
    sig::Output
end

immutable SortByPrimTool <: AbstractTool
    sig::Output
    keysigs::Vector{Output}
end

input(tool::SortPrimTool) = Input((tool.sig,))
output(tool::SortPrimTool) = tool.sig

input(tool::SortByPrimTool) =
    Input(
        Domain((
            Output(
                (domain(tool.sig), tool.keysigs...),
                optional=true, plural=true),)))
output(tool::SortByPrimTool) = tool.sig

run_prim(tool::SortPrimTool, ds::DataSet) =
    let rev = decoration(tool.sig, :rev, false)
        run_sort(column(ds, 1), rev)
    end

function run_prim(tool::SortByPrimTool, ds::DataSet)
    offs = offsets(ds, 1)
    ds′ = values(ds, 1)::DataSet
    vals = values(ds′, 1)
    perm = collect(1:length(vals))
    for k = endof(tool.keysigs):-1:1
        keyflow = flow(ds′, k+1)
        rev = decoration(output(keyflow), :rev, false)
        nullrev = decoration(output(keyflow), :nullrev, false)
        run_sort_by!(offs, perm, column(keyflow), rev, nullrev)
    end
    return Column(offs, vals[perm])
end

function run_sort(col::Column, rev::Bool)
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

function run_sort_by!(
        offs::AbstractVector{Int},
        perm::Vector{Int},
        keycol::Column,
        rev::Bool,
        nullrev::Bool)
    len = length(offs) - 1
    order = SortByOrdering(offsets(keycol), values(keycol), rev, nullrev)
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(perm, l:r-1), alg=MergeSort, order=order)
    end
end

# Custom ordering.

immutable SortByOrdering{O<:AbstractVector{Int}, V<:AbstractVector} <: Base.Ordering
    offs::O
    vals::V
    rev::Bool
    nullrev::Bool
end

function Base.lt{O,V}(o::SortByOrdering{O,V}, a::Int, b::Int)
    la = o.offs[a]
    ra = o.offs[a+1]
    lb = o.offs[b]
    rb = o.offs[b+1]
    if la < ra && lb < rb
        return isless(o.vals[la], o.vals[lb]) ? !o.rev : o.rev
    elseif la < ra
        return o.nullrev
    elseif lb < rb
        return !o.nullrev
    else
        return false
    end
end

Base.lt{V}(o::SortByOrdering{OneTo{Int},V}, a::Int, b::Int) =
    isless(o.vals[a], o.vals[b]) ? !o.rev : o.rev

