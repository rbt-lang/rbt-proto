#
# Partial order on domains and signatures.
#

# Is the given type compatible with the expected type?

function fits(act::Domain, exp::Domain)
    if act == exp || iszero(act) || isany(exp)
        return true
    end
    if isdata(exp)
        return isdata(act) && act.desc::Type <: exp.desc::Type
    elseif isentity(exp)
        return isentity(act) && act.desc::Symbol == exp.desc::Symbol
    else
        return (
            isrecord(act) &&
            let actfs = act.desc::Tuple{Vararg{Output}}, expfs = exp.desc::Tuple{Vararg{Output}}
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

ibound(::Type{Domain}) = Domain(Any)

function ibound(dom1::Domain, dom2::Domain)
    if isany(dom1) || iszero(dom2)
        return dom2
    elseif dom1 == dom2 || iszero(dom1) || isany(dom2)
        return dom1
    elseif isdata(dom1) && isdata(dom2)
        return Domain(typeintersect(dom1.desc::Type, dom2.desc::Type))
    elseif isrecord(dom1) && isrecord(dom2)
        osigs1 = dom1.desc::Tuple{Vararg{Output}}
        osigs2 = dom2.desc::Tuple{Vararg{Output}}
        if length(osigs1) == length(osigs2)
            return Domain(((ibound(osig1, osig2) for (osig1, osig2) in zip(osigs1, osigs2))...))
        end
    end
    return Domain(Zero)
end

ibound(::Type{OutputMode}) = OutputMode(true, true)

ibound(omode1::OutputMode, omode2::OutputMode) =
    OutputMode(omode1.optional && omode2.optional, omode1.plural && omode2.plural)

ibound(::Type{Output}) =
    Output(ibound(Domain), ibound(OutputMode), (OutputDecoration(:*, nothing),))

function ibound(osig1::Output, osig2::Output)
    if osig1 == osig2
        return osig1
    end
    dom = ibound(osig1.dom, osig2.dom)
    mode = ibound(osig1.mode, osig2.mode)
    decors =
        if isempty(osig1.decors) || osig1.decors == osig2.decors
            osig1.decors
        elseif isempty(osig2.decors)
            osig2.decors
        else
            dset1 = Set{Symbol}(d.first for d in osig1.decors)
            dset2 = Set{Symbol}(d.first for d in osig2.decors)
            dmap = Dict{Symbol,OutputDecoration}()
            for d in osig1.decors
                if d.first in dset2 || :* in dset2
                    dmap[d.first] = d
                end
            end
            for d in osig2.decors
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
            ((dmap[n] for n in sort(collect(keys(dmap))))...)
        end
    return Output(dom, mode, decors)
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
            pmap1 = Dict{Symbol,InputParameter}()
            for p in imode1.params
                pmap1[p.first] = p
            end
            pmap2 = Dict{Symbol,InputParameter}()
            for p in imode2.params
                pmap2[p.first] = p
            end
            ps = InputParameter[]
            for n in sort(unique([collect(keys(pmap1)); collect(keys(pmap2))]))
                osig =
                    !haskey(pmap1, n) ?
                        pmap2[n].second :
                    !haskey(pmap2, n) ?
                        pmap1[n].second :
                        Output(pmap1[n].second, pmap2[n].second)
                push!(ps, n => osig)
            end
            (ps...)
        end
    return InputMode(relative, params)
end

ibound(::Type{Input}) = Input(ibound(Domain), ibound(InputMode))

ibound(isig1::Input, isig2::Input) =
    isig1 == isig2 ?
        isig1 :
        Input(ibound(isig1.dom, isig2.dom), ibound(isig1.mode, isig2.mode))

# The least upper bound.

obound{T}(t1::T, ts::T...) = obound(T, t1, ts...)
obound{T}(::Type{T}, ts::T...) = foldl(obound, obound(T), ts)

obound(::Type{Domain}) = Domain(Zero)

function obound(dom1::Domain, dom2::Domain)
    if iszero(dom1) || isany(dom2)
        return dom2
    elseif dom1 == dom2 || isany(dom1) || iszero(dom2)
        return dom1
    elseif isdata(dom1) && isdata(dom2)
        return Domain(typejoin(dom1.desc::Type, dom2.desc::Type))
    elseif isrecord(dom1) && isrecord(dom2)
        osigs1 = dom1.desc::Tuple{Vararg{Output}}
        osigs2 = dom2.desc::Tuple{Vararg{Output}}
        if length(osigs1) == length(osigs2)
            return Domain(((obound(osig1, osig2) for (osig1, osig2) in zip(osigs1, osigs2))...))
        end
    end
    return Domain(Any)
end

obound(::Type{OutputMode}) = OutputMode(false, false)

obound(omode1::OutputMode, omode2::OutputMode) =
    OutputMode(omode1.optional || omode2.optional, omode1.plural || omode2.plural)

obound(::Type{Output}) =
    Output(obound(Domain), ibound(OutputMode), ())

function obound(osig1::Output, osig2::Output)
    if osig1 == osig2
        return osig1
    end
    dom = obound(osig1.dom, osig2.dom)
    mode = obound(osig1.mode, osig2.mode)
    decors =
        if isempty(osig2.decors) || osig1.decors == osig2.decors
            osig1.decors
        elseif isempty(osig1.decors)
            osig2.decors
        else
            dset1 = Set{Symbol}(d.first for d in osig1.decors)
            dset2 = Set{Symbol}(d.first for d in osig2.decors)
            dmap = Dict{Symbol,OutputDecoration}()
            for d in osig1.decors
                n = d.first
                if !(n in dset2) && :* in dset2
                    dmap[n] = OutputDecoration(n, nothing)
                else
                    dmap[n] = d
                end
            end
            for d in osig2.decors
                n = d.first
                if n in dset1
                    if !(n in dset1)
                        if :* in dset1
                            dmap[n] = OutputDecoration(n, nothing)
                        else
                            dmap[n] = d
                        end
                    elseif d != dmap[n]
                        dmap[n] = OutputDecoration(n, nothing)
                    end
                end
            end
            ((dmap[n] for n in sort(collect(keys(dmap))))...)
        end
    return Output(dom, mode, decors)
end


