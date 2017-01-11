#
# Query input data.
#

typealias InputContext Dict{Symbol,Any}
typealias InputFrame Nullable{AbstractVector{Int}}
typealias InputParameterFlow Pair{Symbol, OutputFlow}
typealias InputParameterFlows Vector{InputParameterFlow}

immutable InputFlow <: AbstractVector{Any}
    ctx::InputContext
    sig::Input
    len::Int
    vals::AbstractVector
    frameoffs::InputFrame
    paramflows::InputParameterFlows

    function InputFlow(
            ctx,
            dom,
            vals::AbstractVector,
            frameoffs::InputFrame=InputFrame(),
            paramflows::InputParameterFlows=InputParameterFlow[])
        relative = !isnull(frameoffs)
        parameters = ((n => output(pflow) for (n, pflow) in paramflows)...)
        sig = Input(dom, relative=relative, parameters=parameters)
        len = length(vals)
        if !isnull(frameoffs)
            @assert length(get(frameoffs)) >= 1
            @assert get(frameoffs)[1] == 1
            @assert get(frameoffs)[end] == len+1
        end
        for (n, pflow) in paramflows
            @assert length(pflow) == len
        end
        return new(ctx, sig, len, vals, frameoffs, paramflows)
    end
end

InputFlow(ctx, dom, vals::AbstractVector, paramflows::InputParameterFlows) =
    InputFlow(ctx, dom, vals, InputFrame(), paramflows)

# Array interface.

size(flow::InputFlow) = (flow.len,)
length(flow::InputFlow) = flow.len

function getindex(flow::InputFlow, i::Int)
    if isnull(flow.frameoffs) && isempty(flow.paramflows)
        return flow.vals[i]
    end
    val =
        if isnull(flow.frameoffs)
            flow.vals[i]
        else
            frameoffs = get(flow.frameoffs)
            frame = 0
            while frameoffs[frame+1] <= i
                frame += 1
            end
            l = frameoffs[frame]
            r = frameoffs[frame+1]
            (i - l + 1, view(flow.vals, l:r-1))
        end
    if isempty(flow.paramflows)
        return val
    end
    return (val, ((n => pflow[i]) for (n, pflow) in flow.paramflows)...)
end

Base.array_eltype_show_how(::InputFlow) = (true, "")
summary(flow::InputFlow) = "InputFlow[$(flow.len) \ud7 $(flow.sig)]"

# Components and other properties.

context(flow::InputFlow) = flow.ctx

input(flow::InputFlow) = flow.sig
domain(flow::InputFlow) = domain(flow.sig)
isfree(flow::InputFlow) = isfree(flow.sig)
isrelative(flow::InputFlow) = isrelative(flow.sig)
parameters(flow::InputFlow) = parameters(flow.sig)

values(flow::InputFlow) = flow.vals
frameoffsets(flow::InputFlow) = get(flow.frameoffs)
parameterflows(flow::InputFlow) = flow.paramflows

