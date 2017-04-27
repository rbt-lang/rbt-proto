#
# The grouping combinator.
#

immutable GroupByTool <: AbstractTool
    F::Tool
    Ks::Vector{Tool}

    function GroupByTool(F::Tool, Ks::Vector{Tool})
        for K in Ks
            @assert fits(output(F), input(K))
            @assert !isplural(output(K))
        end
        return new(F, Ks)
    end
end

GroupByTool(F::AbstractTool, Ks::AbstractTool...) =
    GroupByTool(convert(Tool, F), collect(Tool, Ks))

input(tool::GroupByTool) =
    Input(
        domain(input(tool.F)),
        ibound(mode(input(tool.F)), (mode(input(K)) for K in tool.Ks)...))

output(tool::GroupByTool) = (
    Output(
        Domain((
            output(tool.F) |> setoptional(false),
            (output(K) for K in tool.Ks)...)))
    |> setoptional(isoptional(output(tool.F)))
    |> setplural(isplural(output(tool.F)) && !isempty(tool.Ks)))

run(tool::GroupByTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::GroupByTool) =
    let dom = domain(output(tool.F))
        RecordTool(
            prim(tool.F) >>
            RecordTool(
                HereTool(dom),
                (prim(K) for K in tool.Ks)...)) >>
        GroupByPrimTool(
            output(tool.F),
            Output[output(K) for K in tool.Ks])
    end

ThenGroup(Ks::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                GroupByTool(P, (K(Q) for K in Ks)...)
            end)

# The grouping primitive.

immutable GroupByPrimTool <: AbstractTool
    sig::Output
    keysigs::Vector{Output}
end

input(tool::GroupByPrimTool) =
    Input(
        Domain((
            Output(
                (domain(tool.sig), tool.keysigs...))
            |> setoptional()
            |> setplural(),)))

output(tool::GroupByPrimTool) = (
    Output(
        Domain((
            tool.sig |> setoptional(false),
            tool.keysigs...)))
    |> setoptional(isoptional(tool.sig))
    |> setplural(isplural(tool.sig) && !isempty(tool.keysigs)))

function run_prim(tool::GroupByPrimTool, ds::DataSet)
    ds′ = values(ds, 1)::DataSet
    perm, offs = run_group_by_keys(run_group_skip(offsets(ds, 1)), ds′)
    groupoffs = run_group_match(offsets(ds, 1), offs)
    keyperm = perm[view(offs, 1:endof(offs)-1)]
    width = length(flows(ds′)) - 1
    fs = Vector{OutputFlow}(width+1)
    fs[1] =
        OutputFlow(
            tool.sig |> setoptional(false),
            Column(offs, values(ds′, 1)[perm]))
    for k = 1:width
        fs[k+1] =
            OutputFlow(
                tool.keysigs[k],
                column(ds′, k+1)[keyperm])
    end
    return Column(groupoffs, DataSet(length(offs)-1, fs))
end

function run_group_skip(offs::AbstractVector{Int})
    empty = 0
    for k = 1:length(offs)-1
        if offs[k] == offs[k+1]
            empty += 1
        end
    end
    if empty == 0
        return offs
    end
    offs′ = Vector{Int}(length(offs)-empty)
    offs′[1] = 1
    n = 1
    for k = 1:length(offs)-1
        if offs[k] < offs[k+1]
            n += 1
            offs′[n] = offs[k+1]
        end
    end
    return offs′
end

function run_group_by_keys(offs::AbstractVector{Int}, ds::DataSet)
    len = length(offs) - 1
    width = length(ds.flows) - 1
    vals = values(ds, 1)
    perm = collect(1:length(vals))
    for k = 1:width
        order = SortByOrdering(flow(ds, k+1))
        offs = run_group_by_key!(offs, perm, order)
    end
    return perm, offs
end

function run_group_by_key!(
        offs::AbstractVector{Int},
        perm::Vector{Int},
        order::SortByOrdering)
    len = length(offs)-1
    len′ = 0
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(perm, l:r-1), alg=MergeSort, order=order)
        len′ += 1
        for j = l+1:r-1
            if Base.lt(order, perm[j-1], perm[j])
                len′ += 1
            end
        end
    end
    offs′ = Vector{Int}(len′+1)
    offs′[1] = 1
    n = 1
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        for j = l+1:r-1
            if Base.lt(order, perm[j-1], perm[j])
                n += 1
                offs′[n] = j
            end
        end
        n += 1
        offs′[n] = r
    end
    return offs′
end

function run_group_match(offs::AbstractVector{Int}, offs′::AbstractVector{Int})
    groupoffs = Vector{Int}(length(offs))
    n = 1
    for k = 1:length(offs)
        b = offs[k]
        while offs′[n] < b
            n += 1
        end
        groupoffs[k] = n
    end
    return groupoffs
end

