#
# Context awareness.
#

AroundQuery(dom::Domain, refl::Bool, before::Bool, after::Bool) =
    Query(
        AroundSig(refl, before, after, false),
        Input(dom) |> setrelative(),
        Output(dom) |> setoptional(!refl) |> setplural(before || after))

AroundQuery(dom, refl::Bool, before::Bool, after::Bool) =
    AroundQuery(convert(Domain, dom), refl, before, after)

function AroundQuery(dom::Domain, refl::Bool, before::Bool, after::Bool, keys::Vector{Query})
    for key in keys
        @assert fits(dom, domain(input(key)))
        @assert isplain(output(key))
    end
    q = RecordQuery(ItQuery(dom), keys)
    q >>
    Query(
        AroundSig(refl, before, after, true),
        Input(domain(output(q))) |> setrelative(),
        Output(dom) |> setoptional(!refl) |> setplural(before || after))
end

AroundQuery(dom, refl::Bool, before::Bool, after::Bool, keys::Query...) =
    AroundQuery(convert(Domain, dom), refl, before, after, collect(Query, keys))

immutable AroundSig <: AbstractPrimitive
    refl::Bool
    before::Bool
    after::Bool
    haskey::Bool
end

ev(sig::AroundSig, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(
        oty,
        if !sig.haskey
            ev_around(sig.refl, sig.before, sig.after, frameoffsets(iflow), values(iflow))
        else
            ev_around_by(sig.refl, sig.before, sig.after, frameoffsets(iflow), values(iflow))
        end)

function ev_around(refl::Bool, before::Bool, after::Bool, foffs::AbstractVector{Int}, vals::AbstractVector{Int})
    size = 0
    for k = 1:endof(foffs)-1
        l = foffs[k]
        r = foffs[k+1]
        w = r - l
        if before
            size += w * (w-1) ÷ 2
        end
        if refl
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
            if refl
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

function ev_around_by(refl::Bool, before::Bool, after::Bool, foffs::AbstractVector{Int}, ds::DataSet)
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
        if refl
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
        if refl
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

