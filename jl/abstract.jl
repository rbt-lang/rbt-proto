
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
typealias UnitType Tuple{}

# Structure of input.
immutable InputMode
    # Depends on the past input values.
    sees_past::Bool
    # Depends on the future input values.
    sees_future::Bool
    # For parameterized queries.
    params::Tuple
end

# Structure of composition (TODO).
max(mode1::InputMode, mode2::InputMode) =
    InputMode(false, false, ())

# Structure and type of input.
immutable Input
    domain::Type
    mode::InputMode
end

Input(T::Type) = Input(T, InputMode(false, false, ()))

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
datatype(input::Input) = datatype(input.domain)
datatype(output::Output) =
    let T = datatype(output.domain)
        output.mode.singular && output.mode.complete ? T :
        output.mode.singular ? Nullable{T} : Vector{T}
    end
datatype(T::Type) = T

# Query execution pipeline (query plan).
abstract AbstractPipe{I,O}

# Parameterized input (N and V are names and types of parameters).
immutable Ctx{I,N,V}
    val::I
    ctx::V
end

convert{I,N,V}(::Type{Ctx{I,N,V}}, val::I, params::Tuple{Symbol,Any}...) =
    let d = Dict(params),
        ctx = ([d[n] for n in N]...)::V
        Ctx{I,N,V}(val, ctx)
    end

# Time-aware input.
immutable Temp{I}
    vals::Vector{I}
    idx::Int
end

convert{I}(::Type{Temp{I}}, val::I) =
    Temp{I}(I[val], 1)

# Partial output.
typealias Opt{O} Nullable{O}

# Plural output.
typealias Seq{O} Vector{O}

# Pipelines classified by the input structure.
typealias CtxPipe{I,N,V,O} AbstractPipe{Ctx{I,N,V},O}
typealias TempPipe{I,O} AbstractPipe{Temp{I},O}
typealias CtxTempPipe{I,N,V,O} AbstractPipe{Ctx{Temp{I},N,V},O}

# Pipelines classified by the output structure.
typealias IsoPipe{I,O} AbstractPipe{I,O}
typealias OptPipe{I,O} AbstractPipe{I,Opt{O}}
typealias SeqPipe{I,O} AbstractPipe{I,Seq{O}}

# Combinations.
typealias CtxOptPipe{I,N,V,O} AbstractPipe{Ctx{I,N,V},Opt{O}}
typealias CtxSeqPipe{I,N,V,O} AbstractPipe{Ctx{I,N,V},Seq{O}}
typealias TempOptPipe{I,O} AbstractPipe{Temp{I},Opt{O}}
typealias TempSeqPipe{I,O} AbstractPipe{Temp{I},Seq{O}}
typealias CtxTempOptPipe{I,N,V,O} AbstractPipe{Ctx{Temp{I},N,V},Opt{O}}
typealias CtxTempSeqPipe{I,N,V,O} AbstractPipe{Ctx{Temp{I},N,V},Seq{O}}

# Extracts the type of input and output.
idomain{I,O}(::AbstractPipe{I,O}) = I
odomain{I,O}(::AbstractPipe{I,O}) = O

# Executes the pipeline.
execute{I}(pipe::AbstractPipe, x::I) =
    error("execute() is not implemented for pipeline $pipe and input of type $I")
# Executes the pipeline by calling it.
call(pipe::AbstractPipe, args...; kwds...) = execute(pipe, args...; kwds...)
# Executes the pipeline with unit input.
execute(pipe::AbstractPipe{UnitType}) = execute(pipe, ())
# Executes a context-aware or time-aware pipeline.
execute{I,N,V}(pipe::AbstractPipe{Ctx{Temp{I},N,V}}, x::I; params...) =
    execute(pipe, Ctx{Temp{I},N,V}(Temp{I}(x), params...))
execute{I,N,V}(pipe::AbstractPipe{Ctx{I,N,V}}, x::I; params...) =
    execute(pipe, Ctx{I,N,V}(x, params...))
execute{I}(pipe::AbstractPipe{Temp{I}}, x::I) =
    execute(pipe, Temp{I}(x))
execute{N,V}(pipe::AbstractPipe{Ctx{Temp{UnitType},N,V}}; params...) =
    execute(pipe, Ctx{Temp{UnitType},N,V}(Temp{UnitType}(()), params...))
execute{N,V}(pipe::AbstractPipe{Ctx{UnitType,N,V}}; params...) =
    execute(pipe, Ctx{UnitType,N,V}((), params...))
execute(pipe::AbstractPipe{Temp{UnitType}}) =
    execute(pipe, Temp{UnitType}(()))

# Returns an equivalent, but improved pipeline.
optimize{I,O}(pipe::AbstractPipe{I,O}) = pipe::AbstractPipe{I,O}

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
    scope::AbstractScope, domain::Type=UnitType;
    input=Input(domain), output=Output(domain, exclusive=true, reachable=true),
    pipe=HerePipe{datatype(domain)}(),
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
domain(q::Query) = domain(q.input)
mode(q::Query) = mode(q.input)
codomain(q::Query) = domain(q.output)
comode(q::Query) = mode(q.output)

# Output predicates.
singular(q::Query) = singular(q.output)
complete(q::Query) = complete(q.output)
exclusive(q::Query) = exclusive(q.output)
reachable(q::Query) = reachable(q.output)

# Displays the query.
function show(io::IO, q::Query)
    print(io, isnull(q.syntax) ? "(?)" : get(q.syntax), " :: ")
    if domain(q) != UnitType
        print(io, datatype(q.input), " -> ")
    end
    print(io, datatype(q.output))
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
    execute(pipe(optimize(select(q))), args...)
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

