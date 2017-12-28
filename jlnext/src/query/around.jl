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
            around_impl(sig.refl, sig.before, sig.after, frameoffsets(iflow), values(iflow))
        else
            around_by_impl(sig.refl, sig.before, sig.after, frameoffsets(iflow), values(iflow), fields(domain(iflow)))
        end)

function around_impl(refl::Bool, before::Bool, after::Bool, foffs::AbstractVector{Int}, vals::AbstractVector)
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
    return Column{!refl,before||after}(offs, vals[idxs])
end

function around_by_impl(
        refl::Bool, before::Bool, after::Bool, foffs::AbstractVector{Int}, dv::DataVector,
        fs::Vector{Output})
    perm, offs = group_by_keys_impl(foffs, dv, fs)
    rng = Vector{Int}(length(dv))
    pos = Vector{Int}(length(dv))
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
    offs′ = Vector{Int}(length(dv)+1)
    offs′[1] = 1
    n = 1
    for k = 1:length(dv)
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
    return Column{!refl,before||after}(offs′, values(dv, 1)[idxs])
end

