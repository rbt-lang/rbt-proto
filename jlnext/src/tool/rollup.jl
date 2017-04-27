#
# The roll-up combinator.
#

immutable RollUpTool <: AbstractTool
    F::Tool
    Ks::Vector{Tool}

    function RollUpTool(F::Tool, Ks::Vector{Tool})
        for K in Ks
            @assert fits(output(F), input(K))
            @assert isplain(output(K))
        end
        return new(F, Ks)
    end
end

RollUpTool(F::AbstractTool, Ks::AbstractTool...) =
    RollUpTool(convert(Tool, F), collect(Tool, Ks))

input(tool::RollUpTool) =
    Input(
        domain(input(tool.F)),
        ibound(mode(input(tool.F)), (mode(input(K)) for K in tool.Ks)...))

output(tool::RollUpTool) = (
    Output(
        Domain((
            output(tool.F) |> setoptional(false),
            (output(K) |> setoptional(true) for K in tool.Ks)...)))
    |> setoptional(isoptional(output(tool.F)))
    |> setplural(isplural(output(tool.F)) && !isempty(tool.Ks)))

run(tool::RollUpTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::RollUpTool) =
    let dom = domain(output(tool.F))
        RecordTool(
            prim(tool.F) >>
            RecordTool(
                HereTool(dom),
                (prim(K) for K in tool.Ks)...)) >>
        RollUpPrimTool(
            output(tool.F),
            Output[output(K) for K in tool.Ks]) >>
        GroupByPrimTool(
            output(tool.F),
            Output[output(K) |> setoptional() for K in tool.Ks])
    end

ThenRollUp(Ks::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                RollUpTool(P, (K(Q) for K in Ks)...)
            end)

# The roll-up primitive.

immutable RollUpPrimTool <: AbstractTool
    sig::Output
    keysigs::Vector{Output}
end

input(tool::RollUpPrimTool) =
    Input(
        Domain((
            Output(
                (domain(tool.sig), tool.keysigs...))
            |> setoptional()
            |> setplural(),)))

output(tool::RollUpPrimTool) =
    Output((
        Output(
            Domain((
                domain(tool.sig),
                (keysig |> setoptional() for keysig in tool.keysigs)...)))
        |> setoptional(isoptional(tool.sig))
        |> setplural(),))

function run_prim(tool::RollUpPrimTool, ds::DataSet)
    ds′ = values(ds, 1)::DataSet
    width = length(flows(ds′))
    offs = offsets(ds, 1)
    groupoffs = run_rollup_offsets(width, offs)
    fs = Vector{OutputFlow}(width)
    fs[1] =
        OutputFlow(
            output(flow(ds′, 1)),
            run_rollup_values(1, width, offs, values(ds′, 1)))
    for k = 2:width
        fs[k] =
            OutputFlow(
                output(flow(ds′, k)) |> setoptional() |> decorate(:nullrev => true),
                run_rollup_values(k, width, offs, values(ds′, k)))
    end
    return Column(
        OneTo(length(ds)+1),
        DataSet(
            length(ds),
            OutputFlow(
                Output(
                    Domain((
                        domain(tool.sig),
                        (keysig |> setoptional() for keysig in tool.keysigs)...)))
                |> setoptional(isoptional(tool.sig))
                |> setplural(),
                Column(groupoffs, DataSet(width*length(ds′), fs)))))
end

function run_rollup_offsets(width::Int, offs::AbstractVector{Int})
    offs′ = Vector{Int}(length(offs))
    for k = 1:endof(offs)
        offs′[k] = width * (offs[k] - 1) + 1
    end
    return offs′
end

function run_rollup_values(k::Int, width::Int, offs::AbstractVector{Int}, vals::AbstractVector)
    len = length(vals)
    offs′ = Vector{Int}(len * width + 1)
    offs′[1] = 1
    n = 1
    m = 1
    idxs = Vector{Int}(len * (width-k+1))
    for i = 1:endof(offs)-1
        l = offs[i]
        r = offs[i+1]
        for p = 1:(width-k+1)
            for j = l:r-1
                idxs[n] = j
                n += 1
                offs′[m+1] = n
                m += 1
            end
        end
        for p = (width-k+2):width
            for j = l:r-1
                offs′[m+1] = n
                m += 1
            end
        end
    end
    return Column(offs′, vals[idxs])
end

