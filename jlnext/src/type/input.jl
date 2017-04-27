#
# The type of the query input.
#

# InputParameters with their types.

typealias InputParameter Pair{Symbol, Output}
typealias InputParameters Vector{InputParameter}

const NO_PARAMETERS = InputParameter[]

# Input context.

immutable InputMode
    # Depends on the preceeding and subsequent input values.
    relative::Bool
    # List of query parameters.
    params::Vector{InputParameter}
end

InputMode() = InputMode(false, NO_PARAMETERS)

setrelative(imode::InputMode, relative::Bool=true) =
    InputMode(relative, imode.params)

setparameters(imode::InputMode, params::InputParameters=NO_PARAMETERS) =
    InputMode(imode.relative, params)

setrelative(relative::Bool=true) =
    imode -> setrelative(imode, relative)

setparameters(params::InputParameters=NO_PARAMETERS) =
    imode -> setparameters(imode, params)

# Predicates and properties.

isfree(imode::InputMode) = !imode.relative && isempty(imode.params)
isrelative(imode::InputMode) = imode.relative
parameters(imode::InputMode) = imode.params

# The type and the context of the input.

immutable Input
    dom::Domain
    mode::InputMode
end

Input(dom) = Input(convert(Domain, dom), InputMode())

decorate(itype::Input, d::Decoration) =
    Input(decorate(itype.dom, d), itype.mode)

setrelative(itype::Input, relative::Bool=true) =
    Input(itype.dom, setrelative(itype.mode, relative))

setparameters(itype::Input, params::InputParameters=NO_PARAMETERS) =
    Input(itype.dom, setparameters(itype.mode, params))

convert(::Type{Input}, dom::Union{Type, Symbol, Tuple, Vector, Domain}) =
    Input(convert(Domain, dom))

function show(io::IO, itype::Input)
    mode = itype.mode
    if !isempty(mode.params)
        print(io, "{")
    end
    if mode.relative
        print(io, "(")
    end
    print(io, itype.dom)
    if mode.relative
        print(io, "...)")
    end
    for (n, o) in mode.params
        print(io, ", $n => $o")
    end
    if !isempty(mode.params)
        print(io, "}")
    end
end

# Predicates and properties.

domain(itype::Input) = itype.dom
mode(itype::Input) = itype.mode

isdata(itype::Input) = isdata(itype.dom)
isany(itype::Input) = isany(itype.dom)
isunit(itype::Input) = isunit(itype.dom)
iszero(itype::Input) = iszero(itype.dom)
isentity(itype::Input) = isentity(itype.dom)
isrecord(itype::Input) = isentity(itype.dom)

isfree(itype::Input) = isfree(itype.mode)
isrelative(itype::Input) = isrelative(itype.mode)
parameters(itype::Input) = parameters(itype.mode)

