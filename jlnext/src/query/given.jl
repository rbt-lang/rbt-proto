#
# The given combinator.
#

function GivenQuery(base::Query, param::Query)
    tag = decoration(output(param), :tag, Symbol, Symbol(""))
    @assert tag != Symbol("")
    remparams = filter(p -> p.first != tag, slots(input(base)))
    q = RecordQuery(istub(base), param)
    q >>
    Query(
        GivenSig(),
        [FieldQuery(output(q), 1) >> base],
        Input(domain(output(q)), mode(input(base)) |> setslots(remparams)),
        output(base))
end

function GivenQuery(base::Query)
    oty = fields(domain(input(base)))[2]
    tag = decoration(oty, :tag, Symbol, Symbol(""))
    @assert tag != Symbol("")
    remparams = filter(p -> p.first != tag, slots(input(base)))
    Query(
        GivenSig(),
        [base],
        Input(domain(input(base)), mode(input(base)) |> setslots(remparams)),
        output(base))
end

GivenQuery(base::Query, param::Pair{Symbol, Query}) =
    GivenQuery(base, param.second |> decorate(:tag => param.first))

GivenQuery(base::Query, params::Vector{Query}) =
    isempty(params) ? base : GivenQuery(GivenQuery(base, params[1:end-1]), params[end])

GivenQuery(base::Query, param, params...) =
    GivenQuery(GivenQuery(base, params...), param)

immutable GivenSig <: AbstractSignature
end

ev(::GivenSig, args::Vector{Query}, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(
        oty,
        given_impl(args..., iflow.ctx, iflow.frameoffs, iflow.slotflows, values(iflow), domain(iflow)))

function given_impl(
        arg::Query, ctx::InputContext, frameoffs::InputFrame, slotflows::InputSlotFlows, dv::DataVector,
        dom::Domain)
    fs = fields(dom)
    tag = decoration(fs[2], :tag, Symbol, Symbol(""))
    pmap = Dict{Symbol,OutputFlow}(slotflows)
    pmap[tag] = OutputFlow(fs[2], column(dv, 2))
    pkeys = collect(keys(pmap))
    sort!(pkeys)
    pflows = InputSlotFlow[pkey => pmap[pkey] for pkey in pkeys]
    iflow′ = InputFlow(
        ctx,
        dom,
        dv,
        frameoffs,
        pflows)
    return column(ev(arg, iflow′))
end

