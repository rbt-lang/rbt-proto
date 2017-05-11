#
# Partial order on domains and input/output types.
#

# Is the given type compatible with the expected type?

function fits(act::Domain, exp::Domain)
    if act == exp || isnone(act) || isany(exp)
        return true
    end
    if isdata(exp)
        return isdata(act) && datatype(act) <: datatype(exp)
    elseif isentity(exp)
        return isentity(act) && classname(act) == classname(exp)
    else
        return (
            isrecord(act) &&
            let actfs = fields(act), expfs = fields(exp)
                length(actfs) == length(expfs) &&
                all(fits(actf, expf) for (actf, expf) in zip(actfs, expfs))
            end)
    end
end

fits(act::Output, exp::Output) =
    fits(act.dom, exp.dom) && fits(act.mode, exp.mode)

fits(act::OutputMode, exp::OutputMode) =
    act.optional <= exp.optional && act.plural <= exp.plural

fits(act::Input, exp::Input) =
    fits(act.dom, exp.dom) && fits(act.mode, exp.mode)

function fits(act::InputMode, exp::InputMode)
    if act.relative < exp.relative
        return false
    end
    if isempty(exp.params) || exp.params == act.params
        return true
    end
    pmap = Dict{Symbol,InputParameter}()
    for actp in act.params
        pmap[actp.first] = actp
    end
    for (n, p) in exp.params
        if !(n in keys(pmap)) || !fits(pmap[n].second, p)
            return false
        end
    end
    return true
end

fits(act::Domain, exp::Type) = fits(act, convert(Domain, exp))
fits(act::Output, exp::Input) = fits(act.dom, exp.dom)
fits(act::Output, exp::Domain) = fits(act.dom, exp)
fits(act::Output, exp::Type) = fits(act.dom, convert(Domain, exp))

# The greatest lower bound.

ibound{T}(t1::T, ts::T...) = ibound(T, t1, ts...)
ibound{T}(::Type{T}, ts::T...) = foldl(ibound, ibound(T), ts)
ibound{T}(ts::Vector{T}) = foldl(ibound, ibound(T), ts)

ibound(::Type{Domain}) = Domain(Any)

function ibound(dom1::Domain, dom2::Domain)
    if dom1 == dom2
        return dom1
    end
    decors =
        if isempty(dom1.decors) || dom1.decors == dom2.decors
            dom1.decors
        elseif isempty(dom2.decors)
            dom2.decors
        else
            dset1 = Set{Symbol}(d.first for d in dom1.decors)
            dset2 = Set{Symbol}(d.first for d in dom2.decors)
            dmap = Dict{Symbol,Decoration}()
            for d in dom1.decors
                if d.first in dset2 || :* in dset2
                    dmap[d.first] = d
                end
            end
            for d in dom2.decors
                (n, v) = d
                if n in dset1
                    if dmap[n].second === nothing
                        dmap[n] = d
                    elseif v !== nothing && d !== dmap[n]
                        delete!(dmap, n)
                    end
                elseif :* in dset1
                    dmap[n] = d
                end
            end
            Decoration[dmap[n] for n in sort(collect(keys(dmap)))]
        end
    if isany(dom1) || isnone(dom2)
        return Domain(dom2.desc, decors)
    elseif isnone(dom1) || isany(dom2)
        return Domain(dom1.desc, decors)
    elseif isdata(dom1) && isdata(dom2)
        return Domain(typeintersect(dom1.desc::Type, dom2.desc::Type), decors)
    elseif isentity(dom1) && isentity(dom2) && dom1.desc::Symbol == dom2.desc::Symbol
        return Domain(dom1.desc, decors)
    elseif isrecord(dom1) && isrecord(dom2)
        otypes1 = dom1.desc::Vector{Output}
        otypes2 = dom2.desc::Vector{Output}
        if length(otypes1) == length(otypes2)
            return Domain(
                    Output[ibound(otype1, otype2) for (otype1, otype2) in zip(otypes1, otypes2)],
                    decors)
        end
    end
    return Domain(None, decors)
end

ibound(::Type{OutputMode}) = OutputMode(true, true)

ibound(omode1::OutputMode, omode2::OutputMode) =
    OutputMode(omode1.optional && omode2.optional, omode1.plural && omode2.plural)

ibound(::Type{Output}) =
    Output(ibound(Domain), ibound(OutputMode), Decoration[Decoration(:*, nothing)])

function ibound(otype1::Output, otype2::Output)
    if otype1 == otype2
        return otype1
    end
    dom = ibound(otype1.dom, otype2.dom)
    mode = ibound(otype1.mode, otype2.mode)
    return Output(dom, mode)
end

ibound(::Type{InputMode}) = InputMode()

function ibound(imode1::InputMode, imode2::InputMode)
    if imode1 == imode2
        return imode1
    end
    relative = imode1.relative || imode2.relative
    params =
        if isempty(imode1.params) || imode1.params == imode2.params
            imode2.params
        elseif isempty(imode2.params)
            imode1.params
        else
            pmap1 = Dict{Symbol,Output}()
            for p in imode1.params
                pmap1[p.first] = p.second
            end
            pmap2 = Dict{Symbol,Output}()
            for p in imode2.params
                pmap2[p.first] = p.second
            end
            ps = InputParameter[]
            for n in sort(unique([collect(keys(pmap1)); collect(keys(pmap2))]))
                otype =
                    !haskey(pmap1, n) ?
                        pmap2[n] :
                    !haskey(pmap2, n) ?
                        pmap1[n] :
                        ibound(pmap1[n], pmap2[n])
                push!(ps, n => otype)
            end
            ps
        end
    return InputMode(relative, params)
end

ibound(::Type{Input}) = Input(ibound(Domain), ibound(InputMode))

ibound(itype1::Input, itype2::Input) =
    itype1 == itype2 ?
        itype1 :
        Input(ibound(itype1.dom, itype2.dom), ibound(itype1.mode, itype2.mode))

# The least upper bound.

obound{T}(t1::T, ts::T...) = obound(T, t1, ts...)
obound{T}(::Type{T}, ts::T...) = foldl(obound, obound(T), ts)
obound{T}(ts::Vector{T}) = foldl(obound, obound(T), ts)

obound(::Type{Domain}) = Domain(None)

function obound(dom1::Domain, dom2::Domain)
    if dom1 == dom2
        return dom1
    end
    decors =
        if isempty(dom2.decors) || dom1.decors == dom2.decors
            dom1.decors
        elseif isempty(dom1.decors)
            dom2.decors
        else
            dset1 = Set{Symbol}(d.first for d in dom1.decors)
            dset2 = Set{Symbol}(d.first for d in dom2.decors)
            dmap = Dict{Symbol,Decoration}()
            for d in dom1.decors
                n = d.first
                if !(n in dset2) && :* in dset2
                    dmap[n] = Decoration(n, nothing)
                else
                    dmap[n] = d
                end
            end
            for d in dom2.decors
                n = d.first
                if n in dset1
                    if !(n in dset1)
                        if :* in dset1
                            dmap[n] = Decoration(n, nothing)
                        else
                            dmap[n] = d
                        end
                    elseif d != dmap[n]
                        dmap[n] = Decoration(n, nothing)
                    end
                end
            end
            Decoration[dmap[n] for n in sort(collect(keys(dmap)))]
        end
    if isnone(dom1) || isany(dom2)
        return Domain(dom2.desc, decors)
    elseif isany(dom1) || isnone(dom2)
        return Domain(dom1.desc, decors)
    elseif isdata(dom1) && isdata(dom2)
        return Domain(typejoin(dom1.desc::Type, dom2.desc::Type), decors)
    elseif isrecord(dom1) && isrecord(dom2)
        otypes1 = dom1.desc::Vector{Output}
        otypes2 = dom2.desc::Vector{Output}
        if length(otypes1) == length(otypes2)
            return Domain(
                    Output[obound(otype1, otype2) for (otype1, otype2) in zip(otypes1, otypes2)],
                    decors)
        end
    end
    return Domain(Any, decors)
end

obound(::Type{OutputMode}) = OutputMode(false, false)

obound(omode1::OutputMode, omode2::OutputMode) =
    OutputMode(omode1.optional || omode2.optional, omode1.plural || omode2.plural)

obound(::Type{Output}) =
    Output(obound(Domain), ibound(OutputMode), ())

function obound(otype1::Output, otype2::Output)
    if otype1 == otype2
        return otype1
    end
    dom = obound(otype1.dom, otype2.dom)
    mode = obound(otype1.mode, otype2.mode)
    return Output(dom, mode)
end


