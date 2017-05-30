#
# Query input data.
#

typealias InputContext Dict{Symbol,Any}
typealias InputFrame Nullable{AbstractVector{Int}}
typealias InputSlotFlow Pair{Symbol, OutputFlow}
typealias InputSlotFlows Vector{InputSlotFlow}

immutable InputFlow <: AbstractVector{Any}
    ctx::InputContext
    sig::Input
    len::Int
    vals::AbstractVector
    frameoffs::InputFrame
    slotflows::InputSlotFlows

    function InputFlow(
            ctx,
            dom,
            vals::AbstractVector,
            frameoffs::InputFrame=InputFrame(),
            slotflows::InputSlotFlows=InputSlotFlow[])
        relative = !isnull(frameoffs)
        slots = InputSlot[n => output(pflow) for (n, pflow) in slotflows]
        sig = Input(dom) |> setrelative(relative) |> setslots(slots)
        len = length(vals)
        if !isnull(frameoffs)
            @assert length(get(frameoffs)) >= 1
            @assert get(frameoffs)[1] == 1
            @assert get(frameoffs)[end] == len+1
        end
        for (n, pflow) in slotflows
            @assert length(pflow) == len
        end
        return new(ctx, sig, len, vals, frameoffs, slotflows)
    end
end

InputFlow(ctx, dom, vals::AbstractVector, slotflows::InputSlotFlows) =
    InputFlow(ctx, dom, vals, InputFrame(), slotflows)

# Array interface.

size(flow::InputFlow) = (flow.len,)
length(flow::InputFlow) = flow.len

function getindex(flow::InputFlow, i::Int)
    if isnull(flow.frameoffs) && isempty(flow.slotflows)
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
    if isempty(flow.slotflows)
        return val
    end
    return (val, ((n => pflow[i]) for (n, pflow) in flow.slotflows)...)
end

Base.array_eltype_show_how(::InputFlow) = (true, "")
summary(flow::InputFlow) = "InputFlow[$(flow.len) \ud7 $(flow.sig)]"

# Components and other properties.

context(flow::InputFlow) = flow.ctx

input(flow::InputFlow) = flow.sig
domain(flow::InputFlow) = domain(flow.sig)
isfree(flow::InputFlow) = isfree(flow.sig)
isrelative(flow::InputFlow) = isrelative(flow.sig)
slots(flow::InputFlow) = slots(flow.sig)

values(flow::InputFlow) = flow.vals
frameoffsets(flow::InputFlow) = get(flow.frameoffs)
slotflows(flow::InputFlow) = flow.slotflows

# Converting to a smaller input signature.

function narrow(flow::InputFlow, sig::Input)
    if mode(flow.sig) == mode(sig)
        return flow
    end
    @assert fits(mode(flow.sig), mode(sig))
    frameoffs = !isrelative(sig) ? InputFrame() : flow.frameoffs
    slotflows =
        if length(flow.slotflows) == length(slots(sig))
            flow.slotflows
        elseif length(slots(sig)) == 0
            InputSlotFlow[]
        else
            keep = Set(n for (n, sl) in slots(sig))
            filter(p -> p.first in keep, flow.slotflows)
        end
    return InputFlow(flow.ctx, domain(sig), flow.vals, frameoffs, slotflows)
end

# Converting output flow to a new input flow.

function distribute(iflow::InputFlow, oflow::OutputFlow)
    @assert length(iflow) == length(oflow)
    return InputFlow(
        iflow.ctx,
        domain(oflow),
        values(oflow),
        !isnull(iflow.frameoffs) ?
            InputFrame(dist_frameoffs(get(iflow.frameoffs), offsets(oflow))) :
            iflow.frameoffs,
        !isempty(iflow.slotflows) ?
            dist_slotflows(iflow.slotflows, offsets(oflow)) :
            iflow.slotflows)
end

function dist_frameoffs(frameoffs::AbstractVector{Int}, offs::AbstractVector{Int})
    len = 1
    for i = 2:endof(frameoffs)
        l = offs[frameoffs[i-1]]
        r = offs[frameoffs[i]]
        if l < r
            len += 1
        end
    end
    distoffs = Vector{Int}(len)
    distoffs[1] = 1
    k = 1
    for i = 2:endof(frameoffs)
        l = offs[frameoffs[i-1]]
        r = offs[frameoffs[i]]
        if l < r
            k += 1
            distoffs[k] = r
        end
    end
    return distoffs
end

dist_frameoffs(frameoffs::AbstractVector{Int}, ::OneTo) = frameoffs

function dist_slotflows(slotflows::InputSlotFlows, offs::AbstractVector{Int})
    remap = Vector{Int}(offs[end]-1)
    for i = 1:endof(offs)-1
        l = offs[i]
        r = offs[i+1]
        for k = l:r-1
            remap[k] = i
        end
    end
    return InputSlotFlow[n => pflow[remap] for (n, pflow) in slotflows]
end

dist_slotflows(slotflows::InputSlotFlows, ::OneTo) = slotflows

