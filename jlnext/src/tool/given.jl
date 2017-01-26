#
# The given combinator.
#

immutable GivenTool <: AbstractTool
    F::Tool
    Gs::Vector{Tool}
end

GivenTool(F::AbstractTool, Gs::AbstractTool...) =
    GivenTool(convert(Tool, F), collect(Tool, Gs))

function input(tool::GivenTool)
    pset = Set{Symbol}()
    for G in tool.Gs
        tag = decoration(output(G), :tag, Symbol(""))
        if tag != Symbol("")
            push!(pset, tag)
        end
    end
    params = filter(p -> !(p.first in pset), parameters(input(tool.F)))
    imode = InputMode(isrelative(input(tool.F)), (params...))
    return Input(
        domain(input(tool.F)),
        ibound(imode, (mode(input(G)) for G in tool.Gs)...))
end

output(tool::GivenTool) = output(tool.F)

run(tool::GivenTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::GivenTool) =
    RecordTool(
        HereTool(domain(input(tool.F))),
        (prim(G) for G in tool.Gs)...) >>
    GivenPrimTool(prim(tool.F), Output[output(G) for G in tool.Gs])

Given(Gs::Combinator...) =
    Combinator(
        P ->
            let Q = HereTool(domain(input(P)))
                GivenTool(
                    P,
                    (G(Q) for G in Gs)...)
            end)

# The given primitive.

immutable GivenPrimTool <: AbstractTool
    F::Tool
    psigs::Vector{Output}
end

function input(tool::GivenPrimTool)
    pset = Set{Symbol}()
    for psig in tool.psigs
        tag = decoration(psig, :tag, Symbol(""))
        if tag != Symbol("")
            push!(pset, tag)
        end
    end
    params = filter(p -> !(p.first in pset), parameters(input(tool.F)))
    imode = InputMode(isrelative(input(tool.F)), (params...))
    return Input(
        Domain((
            domain(input(tool.F)),
            tool.psigs...)),
        imode)
end

output(tool::GivenPrimTool) = output(tool.F)

run(tool::GivenPrimTool, iflow::InputFlow) =
    run_given(tool, iflow, values(iflow))

function run_given(tool::GivenPrimTool, iflow::InputFlow, ds::DataSet)
    pmap = Dict{Symbol,OutputFlow}(iflow.paramflows)
    for (k, psig) in enumerate(tool.psigs)
        tag = decoration(psig, :tag, Symbol(""))
        if tag != Symbol("")
            pmap[tag] = flow(ds, k+1)
        end
    end
    pkeys = collect(keys(pmap))
    sort!(pkeys)
    pflows = InputParameterFlow[pkey => pmap[pkey] for pkey in pkeys]
    iflow′ = InputFlow(
        iflow.ctx,
        domain(flow(ds, 1)),
        values(ds, 1),
        iflow.frameoffs,
        pflows)
    return run(tool.F, iflow′)
end

