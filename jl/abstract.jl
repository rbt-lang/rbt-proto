
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
const UnitType = Tuple{}

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
    domain::DataType
    mode::InputMode
end

Input(T::DataType) = Input(T, InputMode(false, false, ()))

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
    domain::DataType
    mode::OutputMode
end

Output(T::DataType; singular=true, complete=true, exclusive=false, reachable=false) =
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
datatype(T::DataType) = T

# Query execution pipeline (query plan).
abstract AbstractPipe{I,O}

# Pipelines classified by the output structure.
abstract IsoPipe{I,O} <: AbstractPipe{I,O}
abstract OptPipe{I,O} <: AbstractPipe{I,Nullable{O}}
abstract SeqPipe{I,O} <: AbstractPipe{I,Vector{O}}

# Extracts the type of input.
domain{I,O}(::IsoPipe{I,O}) = I
domain{I,O}(::OptPipe{I,O}) = I
domain{I,O}(::SeqPipe{I,O}) = I

# Extracts the type of output.
codomain{I,O}(::IsoPipe{I,O}) = O
codomain{I,O}(::OptPipe{I,O}) = O
codomain{I,O}(::SeqPipe{I,O}) = O

# Executes the pipeline.
execute{I}(pipe::AbstractPipe, x::I) =
    error("execute() is not implemented for pipeline $pipe and input of type $I")
# Executes the pipeline with `()` input.
execute(pipe::AbstractPipe{UnitType}) =
    execute(pipe, ())
# Executes the pipeline by calling it.
call(pipe::AbstractPipe, args...) = execute(pipe, args...)

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
    # For a composite query, the components that form it.
    parts::Nullable{Tuple{Vararg{Query}}}
    # For opaque output, unique representable identifier.
    identity::Nullable{Query}
    # Output formatter.
    selector::Nullable{Query}
    # Named fields, if any.
    defs::Dict{Symbol,Query}
    # Sorting direction (0 is default, +1 for ascending, -1 for descending).
    order::Int
    # Identifier that denotes the combinator.
    tag::Nullable{Symbol}
    # The source code for the query.
    src::Nullable{AbstractSyntax}
    # Pre-finalized state if we need to resume compilation.
    origin::Nullable{Query}
end

# Type aliases.
const Queries = Tuple{Vararg{Query}}
const NullableQuery = Nullable{Query}
const NullableQueries = Nullable{Queries}
const NullableSymbol = Nullable{Symbol}
const NullableSyntax = Nullable{AbstractSyntax}

# Fresh state for the given scope.
Query(
    scope::AbstractScope, domain::DataType=UnitType;
    input=Input(domain), output=Output(domain, exclusive=true, reachable=true),
    pipe=ThisPipe{datatype(domain)}(),
    parts=NullableQueries(),
    identity=NullableQuery(),
    selector=NullableQuery(),
    defs=Dict{Symbol,Query}(),
    order=0,
    tag=NullableSymbol(),
    src=NullableSyntax(),
    origin=NullableQuery()) =
    Query(scope, input, output, pipe, parts, identity, selector, defs, order, tag, src, origin)

# Initial compiler state.
Query(db::AbstractDatabase) = Query(scope(db))

# Clone constructor.
Query(
    q::Query;
    scope=nothing, input=nothing, output=nothing, pipe=nothing,
    parts=nothing, identity=nothing, selector=nothing, defs=nothing,
    order=nothing, tag=nothing,
    src=nothing, origin=nothing) =
    Query(
        scope != nothing ? scope : q.scope,
        input != nothing ? input : q.input,
        output != nothing ? output : q.output,
        pipe != nothing ? pipe : q.pipe,
        parts != nothing ? parts : q.parts,
        identity != nothing ? identity : q.identity,
        selector != nothing ? selector : q.selector,
        defs != nothing ? defs : q.defs,
        order != nothing ? order : q.order,
        tag != nothing ? tag : q.tag,
        src != nothing ? src : q.src,
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
    print(io, isnull(q.src) ? "(?)" : get(q.src), " :: ")
    if domain(q) != UnitType
        print(io, datatype(q.input), " -> ")
    end
    print(io, datatype(q.output))
end

# Compiles the query.
prepare(state, expr) = prepare(Query(state), syntax(expr))
prepare(state::Query, expr::AbstractSyntax) =
    !isnull(state.origin) ?
        prepare(get(state.origin), expr) :
        optimize(select(compile(state, expr)))

# Executes the query.
execute(q::Query, args...) =
    execute(pipe(optimize(select(q))), args...)
call(q::Query, args...) = execute(q, args...)

# Builds initial execution pipeline.
compile(state::Query, expr::AbstractSyntax) =
    error("compile() is not implemented for $(typeof(expr))")

# Finalizes the execution pipeline.
select(q::Query) = q
identify(q::Query) = q

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

