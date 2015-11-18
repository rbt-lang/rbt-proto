
# Database schema and backends.
abstract AbstractDatabase

# Returns the root scope.
scope(db::AbstractDatabase) =
    error("scope() is not implemented for $db")

# TODO: interface between database and data sources.
# TODO: introspection interface.
# TODO: `Entity{name}` type.

# Local namespace.
abstract AbstractScope

# Resolves an arrow name into a `Nullable{Query}` object.
lookup(scope::AbstractScope, name::Symbol) =
    error("lookup() is not implemented for scope $scope")

# Returns the root (unit) scope.
root(scope::AbstractScope) =
    error("root() is not implemented for scope $scope")

# Returns an empty (zero) scope.
empty(scope::AbstractScope) =
    error("empty() is not implemented for scope $scope")

# Compatibility with `scope(::AbstractDatabase)` and `scope(::Query)`.
scope(scope::AbstractScope) = scope

# TODO: support for parameterized links.

# Parsed query.
abstract AbstractSyntax

# Parse a query.
syntax(syntax::AbstractSyntax) = syntax

# TODO: interface for a pointer inside a syntax tree (for error reporting).

# The unit type.
typealias Unit Tuple{}

# Structure of input.
immutable InputMode
    # Depends on the past and future input values.
    temporal::Bool
    # Input is parameterized.
    params::Tuple{Vararg{Pair{Symbol,Type}}}
end

# Structure of composition.
max(mode1::InputMode, mode2::InputMode) =
    let temporal = max(mode1.temporal, mode2.temporal),
        params = mode1.params
        if params != mode2.params
            params = ()
            p1 = Dict(mode1.params)
            p2 = Dict(mode2.params)
            names = sort(unique([keys(p1)..., keys(p2)...]))
            for name in names
                if name in keys(p1) && name in keys(p2)
                    @assert p1[name] == p2[name]
                end
                T = name in keys(p1) ? p1[name] : p2[name]
                params = (params..., Pair{Symbol,Type}(name, T))
            end
        end
        InputMode(temporal, params)
    end

# Structure and type of input.
immutable Input
    domain::Type
    mode::InputMode
end

Input(T::Type; temporal=false, params=()) = Input(T, InputMode(temporal, params))

domain(input::Input) = input.domain
mode(input::Input) = input.mode

# Structure of output.
immutable OutputMode
    # At most one output value for each input value.
    singular::Bool
    # At least one output for each input value.
    complete::Bool
    # At most one input for each output value.
    exclusive::Bool
    # At least one input for each output value.
    reachable::Bool
end

# Composition.
max(mode1::OutputMode, mode2::OutputMode) =
    OutputMode(
        min(mode1.singular, mode2.singular),
        min(mode1.complete, mode2.complete),
        min(mode1.exclusive, mode2.exclusive),
        min(mode1.reachable, mode2.reachable))

# Structure and type of output.
immutable Output
    domain::Type
    mode::OutputMode
end

Output(T::Type; singular=true, complete=true, exclusive=false, reachable=false) =
    Output(T, OutputMode(singular, complete, exclusive, reachable))

domain(output::Output) = output.domain
mode(output::Output) = output.mode

# Predicates.
singular(output::Output) = output.mode.singular
complete(output::Output) = output.mode.complete
exclusive(output::Output) = output.mode.exclusive
reachable(output::Output) = output.mode.reachable

# How the value is represented in the pipeline.
functor(input::Input) =
    let T = input.domain
        if !isempty(input.mode.params)
            Ns = tuple([n for (n,T) in input.mode.params]...)
            Ps = Tuple{[T for (n,T) in input.mode.params]...}
            T = input.mode.temporal ? CtxTemp{Ns,Ps,T} : Ctx{Ns,Ps,T}
        elseif input.mode.temporal
            T = Temp{T}
        else
            T = Iso{T}
        end
        T
    end
functor(output::Output) =
    let T = output.domain
        output.mode.singular && output.mode.complete ? Iso{T} :
        output.mode.singular ? Opt{T} : Seq{T}
    end

# Input or output structure.
abstract Functor{T}

show(io::IO, X::Type{Functor}) = print(io, X.name)
eltype{T}(::Type{Functor{T}}) = T

# Structure-free input or output.
immutable Iso{T} <: Functor{T}
    val::T
end
Iso{T}(val::T) = Iso{T}(val)

# Partial output.
immutable Opt{T} <: Functor{T}
    val0::Nullable{T}
end
Opt{T}(val::T) = Opt{T}(Nullable{T}(val))
Opt() = Opt{Union{}}(Nullable())
convert{T}(::Type{Opt{T}}) = Opt{T}(Nullable{T}())

isnull(X::Opt) = isnull(X.val0)
get(X::Opt) = get(X.val0)
get(X::Opt, default) = get(X.val0, default)

# Plural output.
immutable Seq{T} <: Functor{T}
    vals::Vector{T}
end
Seq{T}(vals::Vector{T}) = Seq{T}(vals)

length(X::Seq) = length(X.vals)
isempty(X::Seq) = isempty(X.vals)
endof(X::Seq) = endof(X.vals)
getindex(X::Seq, keys...) = getindex(X.vals, keys...)

# Parameterized input (Ns and Ps are names and types of parameters).
immutable Ctx{Ns,Ps,T} <: Functor{T}
    val::T
    ctx::Ps
end
typealias SomeCtx{T,Ns,Ps} Ctx{Ns,Ps,T}

# Input with past and future values.
immutable Temp{T} <: Functor{T}
    vals::Vector{T}
    idx::Int
end

# Input with past, future and parameters.
immutable CtxTemp{Ns,Ps,T} <: Functor{T}
    vals::Vector{T}
    idx::Int
    ctx::Ps
end
typealias SomeCtxTemp{T,Ns,Ps} CtxTemp{Ns,Ps,T}

# Query execution pipeline (query plan).
abstract AbstractPipe{I<:Functor,O<:Functor}

ifunctor{I,O}(::AbstractPipe{I,O}) = I
ofunctor{I,O}(::AbstractPipe{I,O}) = O
itype{I,O}(::AbstractPipe{I,O}) = eltype(I)
otype{I,O}(::AbstractPipe{I,O}) = eltype(O)

# Pipelines classified by the output structure.
typealias IsoPipe{I,T} AbstractPipe{I,Iso{T}}
typealias OptPipe{I,T} AbstractPipe{I,Opt{T}}
typealias SeqPipe{I,T} AbstractPipe{I,Seq{T}}

# Executes the pipeline.
apply{I}(pipe::AbstractPipe{I}, ::I) =
    error("apply() is not implemented for pipeline $pipe and input of type $I")
apply{I}(pipe::AbstractPipe{I}, X) =
    apply(pipe, rewrap(I, X))
# Executes the pipeline by calling it.
call{I,O}(pipe::AbstractPipe{I,O}, x=(); params...) =
    unwrap(apply(pipe, wrap(I, x, Dict{Symbol,Any}(params))))

# Returns an equivalent, but improved pipeline.
optimize(pipe::AbstractPipe) = pipe

# Encapsulates the compiler state and the query combinator.
immutable Query
    # Local namespace.
    scope::AbstractScope
    # The input type of the combinator.
    input::Input
    # The output type of the combinator.
    output::Output
    # Execution pipeline that implements the combinator.
    pipe::AbstractPipe
    # Extractors of individual fields for a record-generating combinator.
    fields::Nullable{Tuple{Vararg{Query}}}
    # Generator of a unique representable value (for opaque output values
    # that cannot be tested for equality).
    identity::Nullable{Query}
    # Output formatter (for opaque output values).
    selector::Nullable{Query}
    # Named attributes that augment the current scope.
    defs::Dict{Symbol,Query}
    # Sorting direction (0 or +1 for ascending, -1 for descending).
    order::Int
    # Identifier that denotes the combinator.
    tag::Nullable{Symbol}
    # The source code for the query.
    syntax::Nullable{AbstractSyntax}
    # The query as it was before formatting and optimizing.  Use it to
    # resume compilation.
    origin::Nullable{Query}
end

# Type aliases.
typealias Queries Tuple{Vararg{Query}}
typealias NullableQuery Nullable{Query}
typealias NullableQueries Nullable{Queries}
typealias NullableSymbol Nullable{Symbol}
typealias NullableSyntax Nullable{AbstractSyntax}

# Fresh state for the given scope.
Query(
    scope::AbstractScope, domain::Type=Unit;
    input=Input(domain), output=Output(domain, exclusive=true, reachable=true),
    pipe=HerePipe{domain}(),
    fields=NullableQueries(),
    identity=NullableQuery(),
    selector=NullableQuery(),
    defs=Dict{Symbol,Query}(),
    order=0,
    tag=NullableSymbol(),
    syntax=NullableSyntax(),
    origin=NullableQuery()) =
    Query(scope, input, output, pipe, fields, identity, selector, defs, order, tag, syntax, origin)

# Initial compiler state.
Query(db::AbstractDatabase; params...) = Query(scope(db, Dict{Symbol,Any}(params)))

# Clone constructor.
Query(
    q::Query;
    scope=nothing, input=nothing, output=nothing, pipe=nothing,
    fields=nothing, identity=nothing, selector=nothing, defs=nothing,
    order=nothing, tag=nothing,
    syntax=nothing, origin=nothing) =
    Query(
        scope != nothing ? scope : q.scope,
        input != nothing ? input : q.input,
        output != nothing ? output : q.output,
        pipe != nothing ? pipe : q.pipe,
        fields != nothing ? fields : q.fields,
        identity != nothing ? identity : q.identity,
        selector != nothing ? selector : q.selector,
        defs != nothing ? defs : q.defs,
        order != nothing ? order : q.order,
        tag != nothing ? tag : q.tag,
        syntax != nothing ? syntax : q.syntax,
        origin != nothing ? origin : q.origin)

# Extracts local namespace.
scope(q::Query) = q.scope

# Extracts the pipeline.
pipe(q::Query) = q.pipe

# The input type and structure (e.g. `Iso{Int}`).
input(q::Query) = q.input
# The output type and structure.
output(q::Query) = q.output

# Type and structure of input and output.
idomain(q::Query) = domain(q.input)
imode(q::Query) = mode(q.input)
ifunctor(q::Query) = functor(q.input)
odomain(q::Query) = domain(q.output)
omode(q::Query) = mode(q.output)
ofunctor(q::Query) = functor(q.output)

# Output predicates.
singular(q::Query) = singular(q.output)
complete(q::Query) = complete(q.output)
exclusive(q::Query) = exclusive(q.output)
reachable(q::Query) = reachable(q.output)

# Displays the query.
function show(io::IO, q::Query)
    print(io, isnull(q.syntax) ? "(?)" : get(q.syntax), " :: ")
    if q.input.domain != Unit || q.input.mode.temporal || !isempty(q.input.mode.params)
        print(io, q.input.domain == Unit ? "1" : q.input.domain)
        if q.input.mode.temporal
            print(io, "...")
        end
        for (n, T) in q.input.mode.params
            print(io, " * (", n, " => ", T, ")")
        end
        print(io, " -> ")
    end
    T = q.output.domain
    T = q.output.mode.singular && q.output.mode.complete ? T :
        q.output.mode.singular ? Nullable{T} : Vector{T}
    print(io, T)
end

# Compiles the query.
prepare(base, expr; params...) = prepare(Query(base; params...), syntax(expr))
prepare(base::Query, expr::AbstractSyntax) =
    if !isnull(base.origin)
        return prepare(get(base.origin), expr)
    else
        origin = compile(base, expr)
        return Query(optimize(select(origin)), origin=origin)
    end

# Executes the query.
execute(q::Query, args...) =
    pipe(optimize(select(q)))(args...)
call(q::Query, args...) = execute(q, args...)

# Builds initial execution pipeline.
compile(base::Query, expr::AbstractSyntax) =
    error("compile() is not implemented for $(typeof(expr))")

# Optimizes the execution pipeline.
optimize(q::Query) = Query(q, pipe=optimize(q.pipe))

# Scope operations passthrough.
lookup(q::Query, name::Symbol) =
    name in keys(q.defs) ? NullableQuery(q.defs[name]) : lookup(q.scope, name)
root(q::Query) = root(q.scope)
empty(q::Query) = empty(q.scope)

# For dispatching on the function name.
immutable Fn{name}
end

# Type constructor shortcut.
Fn(names...) =
    isempty(names) ? Union{} :
    length(names) == 1 ? Type{Fn{names[1]}} :
    Union{[Type{Fn{name}} for name in names]...}

