#
# The type of the query output.
#

# Output cardinality.

immutable OutputMode
    optional::Bool
    plural::Bool
end

OutputMode() = OutputMode(false, false)

setoptional(omode::OutputMode, optional::Bool=true) =
    OutputMode(optional, omode.plural)
setplural(omode::OutputMode, plural::Bool=true) =
    OutputMode(omode.optional, plural)

setoptional(optional::Bool=true) =
    omode -> setoptional(omode, optional)

setplural(plural::Bool=true) =
    omode -> setplural(omode, plural)

isplain(omode::OutputMode) = !omode.optional && !omode.plural
isoptional(omode::OutputMode) = omode.optional
isplural(omode::OutputMode) = omode.plural

# The output type.

immutable Output
    dom::Domain
    mode::OutputMode
end

Output(dom) = Output(convert(Domain, dom), OutputMode())

decorate(otype::Output, d::Decoration) =
    Output(decorate(otype.dom, d), otype.mode)

setoptional(otype::Output, optional::Bool=true) =
    Output(otype.dom, setoptional(otype.mode, optional))

setplural(otype::Output, plural::Bool=true) =
    Output(otype.dom, setplural(otype.mode, plural))

convert(::Type{Output}, dom::Union{Type, Symbol, Tuple, Vector, Domain}) =
    Output(convert(Domain, dom))

function show(io::IO, otype::Output)
    print(io, otype.dom)
    if isplural(otype) && isoptional(otype)
        print(io, "*")
    elseif isplural(otype)
        print(io, "+")
    elseif isoptional(otype)
        print(io, "?")
    end
end

# Predicates and properties.

domain(otype::Output) = otype.dom
mode(otype::Output) = otype.mode

isdata(otype::Output) = isdata(otype.dom)
isany(otype::Output) = isany(otype.dom)
isunit(otype::Output) = isunit(otype.dom)
iszero(otype::Output) = iszero(otype.dom)
isentity(otype::Output) = isentity(otype.dom)
isrecord(otype::Output) = isrecord(otype.dom)

isplain(otype::Output) = isplain(otype.mode)
isoptional(otype::Output) = isoptional(otype.mode)
isplural(otype::Output) = isplural(otype.mode)

decorations(otype::Output) = decorations(otype.dom)
decoration(otype::Output, name, T, default) =
    decoration(otype.dom, name, T, default)

classname(otype::Output) = classname(otype.dom)
fields(otype::Output) = fields(otype.dom)

# The native Julia type that can represent the output.

datatype(otype::Output) =
    let T = datatype(otype.dom)
        isplural(otype) ?
            Vector{T} :
        isoptional(otype) ?
            Nullable{T} :
            T
    end

# Domain definitions that depend on Output.

convert(::Type{Domain}, desc::Union{Tuple, Vector}) =
    Domain(Output[convert(Output, otype) for otype in desc])

isdata(::Vector{Output}) = false
isany(::Vector{Output}) = false
isunit(::Vector{Output}) = false
iszero(::Vector{Output}) = false
isentity(::Vector{Output}) = false
isrecord(::Vector{Output}) = true

datatype(desc::Vector{Output}) =
    Tuple{(datatype(otype) for otype in desc)...}

classname(::Vector{Output}) = NO_CLASSNAME

const NO_FIELDS = Output[]

fields(desc::Type) = NO_FIELDS
fields(desc::Symbol) = NO_FIELDS
fields(desc::Vector{Output}) = desc

