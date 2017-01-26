#
# Context awareness.
#

immutable AroundTool <: AbstractTool
    dom::Domain
    here::Bool
    before::Bool
    after::Bool
end

immutable AroundByTool <: AbstractTool
    dom::Domain
    here::Bool
    before::Bool
    after::Bool
    Ks::Vector{Tool}

    function AroundByTool(dom::Domain, here, before, after, Ks::Vector{Tool})
        for K in Ks
            @assert fits(dom, domain(input(K)))
            @assert isplain(output(K))
        end
        return new(dom, here, before, after, Ks)
    end
end

AroundByTool(dom, here, before, after, Ks::AbstractTool...) =
    AroundByTool(convert(Domain, dom), here, before, after, collect(Tool, Ks))

input(tool::AroundTool) = Input(tool.dom, relative=true)
output(tool::AroundTool) =
    Output(tool.dom, optional=!tool.here, plural=(tool.before || tool.after))

input(tool::AroundByTool) =
    Input(
        Input(
            tool.dom,
            ibound(InputMode, (mode(input(K)) for K in tool.Ks)...)),
        relative=true)
output(tool::AroundByTool) =
    Output(tool.dom, optional=!tool.here, plural=(tool.before || tool.after))

run(tool::AroundTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        run_around(tool.here, tool.before, tool.after, frameoffsets(iflow), values(iflow)))

function run_around(here::Bool, before::Bool, after::Bool, foffs::AbstractVector{Int}, vals::AbstractVector{Int})
    size = 0
    for k = 1:endof(foffs)-1
        l = foffs[k]
        r = foffs[k+1]
        w = r - l
        if before
            size += w * (w-1) ÷ 2
        end
        if here
            size += w
        end
        if after
            size += w * (w-1) ÷ 2
        end
    end
    offs = Vector{Int}(length(vals)+1)
    offs[1] = 1
    idxs = Vector{Int}(size)
    n = 1
    for k = 1:endof(foffs)-1
        l = foffs[k]
        r = foffs[k+1]
        for i = l:r-1
            if before
                for j = l:i-1
                    idxs[n] = j
                    n += 1
                end
            end
            if here
                idxs[n] = i
                n += 1
            end
            if after
                for j = i+1:r-1
                    idxs[n] = j
                    n += 1
                end
            end
            offs[i+1] = n
        end
    end
    return Column(offs, vals[idxs])
end

run(tool::AroundByTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::AroundByTool) =
    RecordTool(
        HereTool(tool.dom),
        tool.Ks...) >>
    AroundByPrimTool(tool.dom, tool.here, tool.before, tool.after, Domain[domain(output(K)) for K in tool.Ks])

HereAndAround() =
    Combinator(
        P -> P >> AroundTool(domain(output(P)), true, true, true))

HereAndAround(Fs::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> AroundByTool(domain(output(P)), true, true, true, (F(Q) for F in Fs)...)
            end)

HereAndBefore() =
    Combinator(
        P -> P >> AroundTool(domain(output(P)), true, true, false))

HereAndBefore(Fs::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> AroundByTool(domain(output(P)), true, true, false, (F(Q) for F in Fs)...)
            end)

# The around primitive.

immutable AroundByPrimTool <: AbstractTool
    dom::Domain
    here::Bool
    before::Bool
    after::Bool
    keydoms::Vector{Domain}
end

input(tool::AroundByPrimTool) =
    Input(
        Domain((
            tool.dom,
            tool.keydoms...)),
        relative=true)

output(tool::AroundByPrimTool) =
    Output(tool.dom, optional=!tool.here, plural=(tool.before || tool.after))

run(tool::AroundByPrimTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        run_around_by(tool.here, tool.before, tool.after, frameoffsets(iflow), values(iflow)))

function run_around_by(here::Bool, before::Bool, after::Bool, foffs::AbstractVector{Int}, ds::DataSet)
    perm, offs = run_group_by_keys(foffs, ds)
    rng = Vector{Int}(length(ds))
    pos = Vector{Int}(length(ds))
    size = 0
    for k = 1:endof(offs)-1
        l = offs[k]
        r = offs[k+1]
        for i = l:r-1
            n = perm[i]
            rng[n] = k
            pos[n] = i
        end
        w = r - l
        if before
            size += w * (w-1) ÷ 2
        end
        if here
            size += w
        end
        if after
            size += w * (w-1) ÷ 2
        end
    end
    idxs = Vector{Int}(size)
    offs′ = Vector{Int}(length(ds)+1)
    offs′[1] = 1
    n = 1
    for k = 1:length(ds)
        r = rng[k]
        p = pos[k]
        l = offs[r]
        r = offs[r+1]
        if before
            for j = l:p-1
                idxs[n] = perm[j]
                n += 1
            end
        end
        if here
            idxs[n] = perm[p]
            n += 1
        end
        if after
            for j = p+1:r-1
                idxs[n] = perm[j]
                n += 1
            end
        end
        offs′[k+1] = n
    end
    return Column(offs′, values(ds, 1)[idxs])
end

