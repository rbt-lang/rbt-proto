
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

# Structured output (and input).
abstract Mode{T}
# One value (identity monad).
abstract Iso{T} <: Mode{T}
# One or no value (maybe monad).
abstract Opt{T} <: Mode{T}
# A finite sequence of values (list monad).
abstract Seq{T} <: Mode{T}

# The unit type.
const UnitType = Tuple{}

# TODO: UniqueSeq, NonEmptySeq.

# Extracts the type parameter.
domain{T}(::Type{Iso{T}}) = T
domain{T}(::Type{Opt{T}}) = T
domain{T}(::Type{Seq{T}}) = T

# Extracts the structure.
mode{T}(::Type{Iso{T}}) = Iso
mode{T}(::Type{Opt{T}}) = Opt
mode{T}(::Type{Seq{T}}) = Seq

# How the value is represented in the pipeline
datatype{T}(::Type{Iso{T}}) = datatype(T)
datatype{T}(::Type{Opt{T}}) = Nullable{datatype(T)}
datatype{T}(::Type{Seq{T}}) = Vector{datatype(T)}
datatype(T::DataType) = T

# Partial order between structures: Iso < Opt < Seq.
isless(::Type{Iso}, ::Type{Iso}) = false
isless(::Type{Iso}, ::Type{Opt}) = true
isless(::Type{Iso}, ::Type{Seq}) = true
isless(::Type{Opt}, ::Type{Iso}) = false
isless(::Type{Opt}, ::Type{Opt}) = false
isless(::Type{Opt}, ::Type{Seq}) = true
isless(::Type{Seq}, ::Type{Iso}) = false
isless(::Type{Seq}, ::Type{Opt}) = false
isless(::Type{Seq}, ::Type{Seq}) = false

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
    input::DataType
    # The output type of the combinator.
    output::DataType
    # Execution pipeline that implements the combinator.
    pipe::AbstractPipe
    # Pre-finalized state if we need to resume compilation.
    state::Nullable{Query}
    # Terminates the pipeline.
    cap::Nullable{Query}
    # Indexed fields, if any.
    items::Nullable{Tuple{Vararg{Query}}}
    # Named fields, if any.
    attrs::Dict{Symbol,Query}
    # Sorting direction (0 is default, +1 for ascending, -1 for descending).
    order::Int
    # Identifier that denotes the combinator.
    tag::Nullable{Symbol}
end

# Type aliases.
const Queries = Tuple{Vararg{Query}}
const NullableQuery = Nullable{Query}
const NullableQueries = Nullable{Queries}
const NullableSymbol = Nullable{Symbol}

# Fresh state for the given scope.
Query(
    scope::AbstractScope, domain::DataType=UnitType;
    input=Iso{domain}, output=Iso{domain},
    pipe=ThisPipe{datatype(domain)}(),
    state=NullableQuery(),
    cap=NullableQuery(),
    items=NullableQueries(),
    attrs=Dict{Symbol,Query}(),
    order=0,
    tag=NullableSymbol()) =
    Query(scope, input, output, pipe, state, cap, items, attrs, order, tag)

# Initial compiler state.
Query(db::AbstractDatabase) = Query(scope(db))

# Clone constructor.
Query(
    q::Query;
    scope=nothing, input=nothing, output=nothing,
    pipe=nothing, state=nothing, cap=nothing,
    items=nothing, attrs=nothing,
    order=nothing, tag=nothing) =
    Query(
        scope != nothing ? scope : q.scope,
        input != nothing ? input : q.input,
        output != nothing ? output : q.output,
        pipe != nothing ? pipe : q.pipe,
        state != nothing ? state : q.state,
        cap != nothing ? cap : q.cap,
        items != nothing ? items : q.items,
        attrs != nothing ? attrs : q.attrs,
        order != nothing ? order : q.order,
        tag != nothing ? tag : q.tag)

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

# Displays the query.
show(io::IO, q::Query) =
    q.input == Iso{UnitType} ?
        print(io, q.pipe, " : ", datatype(q.output)) :
        print(io, q.pipe, " : ", datatype(q.input), " -> ", datatype(q.output))

# Compiles the query.
prepare(state, expr) = prepare(Query(state), syntax(expr))
prepare(state::Query, expr::AbstractSyntax) =
    !isnull(state.state) ?
        prepare(get(state.state), expr) :
        optimize(finalize(compile(state, expr)))

# Executes the query.
execute(q::Query, args...) =
    execute(pipe(optimize(finalize(q))), args...)
call(q::Query, args...) = execute(q, args...)

# Builds initial execution pipeline.
compile(state::Query, expr::AbstractSyntax) =
    error("compile() is not implemented for $(typeof(expr))")

# Finalizes the execution pipeline.
finalize(q::Query) = q

# Optimizes the execution pipeline.
optimize(q::Query) = Query(q, pipe=optimize(q.pipe))

# Scope operations passthrough.
lookup(q::Query, name::Symbol) =
    name in keys(q.attrs) ? NullableQuery(q.attrs[name]) : lookup(q.scope, name)
root(q::Query) = root(q.scope)
empty(q::Query) = empty(q.scope)

# For dispatching on the function name.
immutable Fn{name}
end

