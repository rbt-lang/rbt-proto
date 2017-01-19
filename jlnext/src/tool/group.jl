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

output(tool::GroupByTool) =
    Output(
        Domain((
            Output(output(tool.F), optional=false),
            (output(K) for K in tool.Ks)...)),
        optional=isoptional(output(tool.F)),
        plural=(isplural(output(tool.F)) && !isempty(tool.Ks)))

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
                (domain(tool.sig), tool.keysigs...),
                optional=true, plural=true),)))

output(tool::GroupByPrimTool) =
    Output(
        Domain((
            Output(tool.sig, optional=false),
            tool.keysigs...)),
        optional=isoptional(tool.sig),
        plural=(isplural(tool.sig) && !isempty(tool.keysigs)))

function run_prim(tool::GroupByPrimTool, ds::DataSet)
    width = length(tool.keysigs)
    len = length(ds)
    offs = offsets(ds, 1)
    ds′ = values(ds, 1)::DataSet
    vals = values(ds′, 1)
    perm = collect(1:length(vals))
    for k = 1:width
        order = SortByOrdering(flow(ds′, k+1))
        offs = run_group_by!(offs, perm, order)
    end
    groupoffs = run_group_offs(offsets(ds, 1), offs)
    flows = Vector{OutputFlow}(width+1)
    flows[1] =
        OutputFlow(
            Output(tool.sig, optional=false),
            Column(offs, vals[perm]))
    keyslice = perm[view(offs, 1:endof(offs)-1)]
    for k = 1:width
        keycol = column(ds′, k+1)
        flows[k+1] =
            OutputFlow(
                tool.keysigs[k],
                keycol[keyslice])
    end
    return Column(groupoffs, DataSet(length(offs)-1, flows))
end

function run_group_by!(offs::AbstractVector{Int}, perm::Vector{Int}, order::SortByOrdering)
    len = length(offs)-1
    len′ = 0
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(perm, l:r-1), alg=MergeSort, order=order)
        len′ += r - l
        for j = l+1:r-1
            if !Base.lt(order, perm[j-1], perm[j])
                len′ -= 1
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

function run_group_offs(offs::AbstractVector{Int}, offs′::AbstractVector{Int})
    groupoffs = Vector{Int}(length(offs))
    n = 1
    b = offs[1]
    for k = 1:endof(offs′)-1
        if offs′[k] == b
            groupoffs[n] = k
            n += 1
            b = offs[n]
        end
    end
    groupoffs[n] = length(offs′)
    return groupoffs
end

