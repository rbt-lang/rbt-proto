#
# The input signature.
#

# Parameters with their types.

typealias InputParameter Pair{Symbol, Output}
typealias InputParameters Tuple{Vararg{InputParameter}}

# Input context.

immutable InputMode
    # Depends on the preceeding and subsequent input values.
    relative::Bool
    # List of query parameters.
    params::InputParameters
end

InputMode(;relative::Bool=false, parameters::InputParameters=()) =
    InputMode(relative, parameters)

InputMode(imode::InputMode; relative=nothing, parameters=nothing) =
    InputMode(
        relative !== nothing ? relative::Bool : imode.relative,
        parameters !== nothing ? parameters::InputParameters : imode.params)

# Predicates and properties.

isfree(imode::InputMode) = !imode.relative && isempty(imode.params)
isrelative(imode::InputMode) = imode.relative
parameters(imode::InputMode) = imode.params

# The type and the context of the input.

immutable Input
    dom::Domain
    mode::InputMode
end

Input(dom; relative::Bool=false, parameters::InputParameters=()) =
    Input(convert(Domain, dom), InputMode(relative, parameters))

Input(isig::Input; domain=nothing, relative=nothing, parameters=nothing) =
    Input(
        domain !== nothing ? convert(Domain, domain) : isig.dom,
        InputMode(
            relative !== nothing ? relative::Bool : isig.mode.relative,
            parameters !== nothing ? parameters::InputParameters : isig.mode.params))

convert(::Type{Input}, dom::Union{Type, Symbol, Tuple, Domain}) =
    Input(convert(Domain, dom))

function show(io::IO, isig::Input)
    mode = isig.mode
    if !isempty(mode.params)
        print(io, "{")
    end
    if mode.relative
        print(io, "(")
    end
    print(io, isig.dom)
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

domain(isig::Input) = isig.dom
mode(isig::Input) = isig.mode

isdata(isig::Input) = isdata(isig.dom)
isany(isig::Input) = isany(isig.dom)
isunit(isig::Input) = isunit(isig.dom)
iszero(isig::Input) = iszero(isig.dom)
isentity(isig::Input) = isentity(isig.dom)
isrecord(isig::Input) = isentity(isig.dom)

isfree(isig::Input) = isfree(isig.mode)
isrelative(isig::Input) = isrelative(isig.mode)
parameters(isig::Input) = parameters(isig.mode)

