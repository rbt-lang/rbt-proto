#
# The output signature.
#

# Output cardinality.

immutable OutputMode
    optional::Bool
    plural::Bool
end

OutputMode(; optional::Bool=false, plural::Bool=false) =
    OutputMode(optional, plural)

OutputMode(omode::OutputMode; optional=nothing, plural=nothing) =
    OutputMode(
        optional !== nothing ? optional::Bool : omode.optional,
        plural !== nothing ? plural::Bool : omode.plural)

isplain(omode::OutputMode) = !omode.optional && !omode.plural
isoptional(omode::OutputMode) = omode.optional
isplural(omode::OutputMode) = omode.plural

# The domain, cardinality and decorations of the output.

typealias OutputDecoration Pair{Symbol,Any}
typealias OutputDecorations Tuple{Vararg{OutputDecoration}}

immutable Output
    dom::Domain
    mode::OutputMode
    decors::OutputDecorations
end

Output(dom, mode) = Output(dom, mode, ())

Output(dom; optional::Bool=false, plural::Bool=false, decorations...) =
    Output(
        convert(Domain, dom),
        OutputMode(optional, plural),
        ((OutputDecoration(n, v) for (n, v) in sort(decorations))...))

function Output(osig::Output; domain=nothing, optional=nothing, plural=nothing, decorations...)
    dom = domain !== nothing ? convert(Domain, domain) : osig.dom
    mode = OutputMode(
        optional !== nothing ? optional::Bool : osig.mode.optional,
        plural !== nothing ? plural::Bool : osig.mode.plural)
    decors =
        if isempty(decorations)
            osig.decors
        elseif isempty(osig.decors)
            ((OutputDecoration(n, v) for (n, v) in sort(decorations))...)
        else
            dmap = Dict{Symbol,OutputDecoration}()
            for d in osig.decors
                dmap[d.first] = d
            end
            for (n, v) in decorations
                dmap[n] = OutputDecoration(n, v)
            end
            ((dmap[n] for n in sort(collect(keys(dmap))))...)
        end
    return Output(dom, mode, decors)
end

convert(::Type{Output}, dom::Union{Type, Symbol, Tuple, Domain}) =
    Output(convert(Domain, dom))

function show(io::IO, osig::Output)
    print(io, osig.dom)
    if isplural(osig) && isoptional(osig)
        print(io, "*")
    elseif isplural(osig)
        print(io, "+")
    elseif isoptional(osig)
        print(io, "?")
    end
    if !isempty(osig.decors)
        print(io, " [")
        comma = false
        for (n, v) in osig.decors
            if comma
                print(io, ", ")
            end
            comma = true
            print(io, n)
            print(io, "=")
            if v !== nothing
                show(io, v)
            else
                print(io, "?")
            end
        end
        print(io, "]")
    end
end

# Predicates and properties.

domain(osig::Output) = osig.dom
mode(osig::Output) = osig.mode
decorations(osig::Output) = osig.decors

isdata(osig::Output) = isdata(osig.dom)
isany(osig::Output) = isany(osig.dom)
isunit(osig::Output) = isunit(osig.dom)
iszero(osig::Output) = iszero(osig.dom)
isentity(osig::Output) = isentity(osig.dom)
isrecord(osig::Output) = isrecord(osig.dom)

isplain(osig::Output) = isplain(osig.mode)
isoptional(osig::Output) = isoptional(osig.mode)
isplural(osig::Output) = isplural(osig.mode)

function decoration{T}(osig::Output, name::Symbol, default::T)
    for (n, v) in osig.decors
        if n == name && isa(v, T)
            return v::T
        end
    end
    return default
end

# The native Julia type that can represent the output.

datatype(osig::Output) =
    let T = datatype(osig.dom)
        isplural(osig) ?
            Vector{T} :
        isoptional(osig) ?
            Nullable{T} :
            T
    end

# Domain definitions that depend on Output.

convert(::Type{Domain}, desc::Type) = Domain(desc)
convert(::Type{Domain}, desc::Symbol) = Domain(desc)
convert(::Type{Domain}, desc::Tuple{Vararg{Union{Type, Symbol, Domain, Output}}}) =
    Domain(((convert(Output, osig) for osig in desc)...))

