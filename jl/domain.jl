#
# Description of the input and the output structures.
#


# Canonical singleton and empty types.
typealias Unit Void
typealias Zero Union{}

# The type has one or no elements.
isunit(T::Type) = T <: Void || T <: Tuple{} || T <: Nullable{Union{}} || T <: Vector{Union{}}
iszero(T::Type) = T <: Union{}


#
# Structure of input.
#

# Maps a tuple of parameter names to a tuple of types.
typealias Params Pair{Tuple{Vararg{Symbol}}, Tuple{Vararg{Type}}}
const NoParams = Params((), ())

immutable InputMode
    # Depends on the preceeding and subsequent input values.
    relative::Bool
    # List of parameters with types.
    params::Params
end

InputMode(;relative::Bool=false, params::Params=NoParams) = InputMode(relative, params)

InputMode(mode::InputMode; relative=nothing, params=nothing) =
    InputMode(
        relative != nothing ? relative : mode.relative,
        params != nothing ? params : mode.params)

# Predicates and properties.
isfree(mode::InputMode) = !mode.relative && isempty(mode.params.first)
isrelative(mode::InputMode) = mode.relative
params(mode::InputMode) = mode.params

# Lattice on input structures.
typemin(::Type{InputMode}) = InputMode(false, NoParams)
max(mode::InputMode) = mode
max(mode1::InputMode, mode2::InputMode) =
    begin
        relative = max(mode1.relative, mode2.relative)
        if mode2.params == NoParams || mode1.params == mode2.params
            params = mode1.params
        elseif mode1.params == NoParams
            params = mode2.params
        else
            # Merging parameters.
            p1 = Dict{Symbol,Type}(zip(mode1.params.first, mode1.params.second))
            p2 = Dict{Symbol,Type}(zip(mode2.params.first, mode2.params.second))
            names = Symbol[]
            types = Type[]
            for name in sort(unique([collect(keys(p1)); collect(keys(p2))]))
                T = !haskey(p1, name) ? p2[name] :
                    !haskey(p2, name) ? p1[name] : typeintersect(p1[name], p2[name])
                push!(names, name)
                push!(types, T)
            end
            params = Params((names...), (types...))
        end
        return InputMode(relative, params)
    end

# Type and structure of input.
immutable Input
    domain::Type
    mode::InputMode
end

Input(domain::Type; relative::Bool=false, params::Params=NoParams) =
    Input(domain, InputMode(relative, params))

Input(input::Input; domain=nothing, relative=nothing, params=nothing) =
    Input(
        domain != nothing ? domain : input.domain,
        InputMode(input.mode; relative=relative, params=params))

show(io::IO, input::Input) =
    begin
        mode = input.mode
        if !isempty(mode.params.first)
            print(io, "{")
        end
        print(io, input.domain)
        if mode.relative
            print(io, "...")
        end
        for (name, T) in zip(mode.params.first, mode.params.second)
            print(io, ", $name => $T")
        end
        if !isempty(mode.params.first)
            print(io, "}")
        end
    end

domain(input::Input) = input.domain
mode(input::Input) = input.mode

typemin(::Type{Input}) = Input(Any, typemin(InputMode))
max(input::Input) = input
max(input1::Input, input2::Input) =
    Input(typeintersect(input1.domain, input2.domain), max(input1.mode, input2.mode))

# Predicates and properties.
isfree(input::Input) = isfree(input.mode)
isrelative(input::Input) = isrelative(input.mode)
params(input::Input) = params(input.mode)

# How the value is represented in the pipeline.
kind(input::Input) =
    let T = input.domain,
        mode = input.mode
        if !isempty(mode.params.first)
            Ns = Val{mode.params.first}
            Vs = Tuple{mode.params.second...}
            input.mode.relative ?
                EnvRel{Ns,Vs,T} : Env{Ns,Vs,T}
        elseif input.mode.relative
            Rel{T}
        else
            Iso{T}
        end
    end

data(input::Input) = data(kind(input))

convert(input::Input, args...; params...) =
    convert(kind(input), args...; params...)


#
# Structure of output.
#

immutable OutputMode
    # At most one output value for each input value.
    lunique::Bool
    # At least one output for each input value.
    ltotal::Bool
    # At most one input for each output value.
    runique::Bool
    # At least one input for each output value.
    rtotal::Bool
end

# Default is a plain function.
OutputMode(; lunique::Bool=true, ltotal::Bool=true, runique::Bool=false, rtotal::Bool=false) =
    OutputMode(lunique, ltotal, runique, rtotal)

OutputMode(mode::OutputMode; lunique=nothing, ltotal=nothing, runique=nothing, rtotal=nothing) =
    OutputMode(
        lunique != nothing ? lunique : mode.lunique,
        ltotal != nothing ? ltotal : mode.ltotal,
        runique != nothing ? runique : mode.runique,
        rtotal != nothing ? rtotal : mode.rtotal)

# Predicates.
isplain(mode::OutputMode) = mode.lunique && mode.ltotal
ispartial(mode::OutputMode) = mode.lunique && !mode.ltotal
isplural(mode::OutputMode) = !mode.lunique
issingular(mode::OutputMode) = mode.lunique
isnonempty(mode::OutputMode) = mode.ltotal
ismonic(mode::OutputMode) = mode.runique
iscovering(mode::OutputMode) = mode.rtotal

# Lattice.
typemin(::Type{OutputMode}) = OutputMode(true, true, true, true)
max(mode::OutputMode) = mode
max(mode1::OutputMode, mode2::OutputMode) =
    OutputMode(
        min(mode1.lunique, mode2.lunique),
        min(mode1.ltotal, mode2.ltotal),
        min(mode1.runique, mode2.runique),
        min(mode1.rtotal, mode2.rtotal))

# Type and structure of output.
immutable Output
    domain::Type
    mode::OutputMode
end

Output(domain::Type; lunique::Bool=true, ltotal::Bool=true, runique::Bool=false, rtotal::Bool=false) =
    Output(domain, OutputMode(lunique, ltotal, runique, rtotal))

Output(output::Output; domain=nothing, lunique=nothing, ltotal=nothing, runique=nothing, rtotal=nothing) =
    Output(
        domain != nothing ? domain : output.domain,
        OutputMode(output.mode, lunique=lunique, ltotal=ltotal, runique=runique, rtotal=rtotal))

show(io::IO, output::Output) =
    begin
        T = output.domain
        props = []
        if isplural(output)
            T = Vector{T}
            if output.mode.ltotal
                push!(props, :nonempty)
            end
        elseif ispartial(output)
            T = Nullable{T}
        end
        if output.mode.runique
            push!(props, :unique)
        end
        if output.mode.rtotal
            push!(props, :covering)
        end
        print(io, T)
        if !isempty(props)
            print(io, " # $(join(props, ", "))")
        end
    end

domain(output::Output) = output.domain
mode(output::Output) = output.mode

typemin(::Type{Output}) = Output(Null, typemin(OutputMode))
max(output::Output) = output
max(output1::Output, output2::Output) =
    Output(typejoin(output1.domain, output2.domain), max(output1.mode, output2.mode))

# Predicates.
isplain(output::Output) = isplain(output.mode)
ispartial(output::Output) = ispartial(output.mode)
isplural(output::Output) = isplural(output.mode)
issingular(output::Output) = issingular(output.mode)
isnonempty(output::Output) = isnonempty(output.mode)
ismonic(output::Output) = ismonic(output.mode)
iscovering(output::Output) = iscovering(output.mode)

# How the value is represented in the pipeline.
kind(output::Output) =
    let T = output.domain,
        mode = output.mode
        mode.lunique && mode.ltotal ? Iso{T} : mode.lunique ? Opt{T} : Seq{T}
    end

data(output::Output) = data(kind(output))

convert(output::Output, args...) =
    convert(kind(output), args...)


#
# Properties of any mapping that defines `input` and `output` methods.
#

input(input::Input) = input
output(output::Output) = output
input(mapping::Pair{Input,Output}) = mapping.first
output(mapping::Pair{Input,Output}) = mapping.second
mapping(input::Input, output::Output) = input => output
mapping(mapping) = input(mapping) => output(mapping)
idomain(mapping) = domain(input(mapping))
odomain(mapping) = domain(output(mapping))
imode(mapping) = mode(input(mapping))
omode(mapping) = mode(output(mapping))
ikind(mapping) = kind(input(mapping))
okind(mapping) = kind(output(mapping))
idata(mapping) = data(input(mapping))
odata(mapping) = data(output(mapping))
isfree(mapping) = isfree(input(mapping))
isrelative(mapping) = isrelative(input(mapping))
params(mapping) = params(input(mapping))
isplain(mapping) = isplain(output(mapping))
ispartial(mapping) = ispartial(output(mapping))
isplural(mapping) = isplural(output(mapping))
issingular(mapping) = issingular(output(mapping))
isnonempty(mapping) = isnonempty(output(mapping))
ismonic(mapping) = ismonic(output(mapping))
iscovering(mapping) = iscovering(output(mapping))

show(io::IO, mapping::Pair{Input,Output}) =
    begin
        if mapping.first != Input(Unit)
            print(io, mapping.first, " -> ")
        end
        print(io, mapping.second)
    end

