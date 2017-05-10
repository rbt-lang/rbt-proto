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

function parameter(imode::InputMode, tag::Symbol)
    for param in imode.params
        if param.first == tag
            return param.second
        end
    end
    return Output(None)
end

# The type and the context of the input.

immutable Input
    dom::Domain
    mode::InputMode
end

Input(dom) = Input(convert(Domain, dom), InputMode())

decorate(ity::Input, d::Decoration) =
    Input(decorate(ity.dom, d), ity.mode)

setrelative(ity::Input, relative::Bool=true) =
    Input(ity.dom, setrelative(ity.mode, relative))

setparameters(ity::Input, params::InputParameters=NO_PARAMETERS) =
    Input(ity.dom, setparameters(ity.mode, params))

convert(::Type{Input}, dom::Union{Type, Symbol, Tuple, Vector, Domain}) =
    Input(convert(Domain, dom))

function show(io::IO, ity::Input)
    mode = ity.mode
    if !isempty(mode.params)
        print(io, "{")
    end
    if mode.relative
        print(io, "(")
    end
    print(io, ity.dom)
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

domain(ity::Input) = ity.dom
mode(ity::Input) = ity.mode

isdata(ity::Input) = isdata(ity.dom)
isany(ity::Input) = isany(ity.dom)
isvoid(ity::Input) = isvoid(ity.dom)
isnone(ity::Input) = isnone(ity.dom)
isentity(ity::Input) = isentity(ity.dom)
isrecord(ity::Input) = isentity(ity.dom)

isfree(ity::Input) = isfree(ity.mode)
isrelative(ity::Input) = isrelative(ity.mode)
parameters(ity::Input) = parameters(ity.mode)
parameter(ity::Input, tag::Symbol) = parameter(ity, tag)

