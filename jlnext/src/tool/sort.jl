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
                (domain(tool.sig), tool.keysigs...))
            |> setoptional()
            |> setplural(),)))
output(tool::SortByPrimTool) = tool.sig

run_prim(tool::SortPrimTool, ds::DataSet) =
    let rev = decoration(tool.sig, :rev, Bool, false)
        run_sort(column(ds, 1), rev)
    end

function run_prim(tool::SortByPrimTool, ds::DataSet)
    offs = offsets(ds, 1)
    ds′ = values(ds, 1)::DataSet
    vals = values(ds′, 1)
    perm = collect(1:length(vals))
    for k = endof(tool.keysigs):-1:1
        order = SortByOrdering(flow(ds′, k+1))
        run_sort_by!(offs, perm, order)
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

function run_sort_by!(offs::AbstractVector{Int}, perm::Vector{Int}, order::SortByOrdering)
    len = length(offs) - 1
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(perm, l:r-1), alg=MergeSort, order=order)
    end
end

