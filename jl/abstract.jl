
# Database schema and backends.
abstract AbstractDatabase

# Returns the root scope.
scope(db::AbstractDatabase) =
    error("scope() is not implemented for $db")

# TODO: interface between database and data sources.
# TODO: introspection interface.
# TODO: `Entity{name}` type.

# Compiler state.
abstract AbstractScope

# Resolves an arrow name into a `Nullable{Query}` object.
lookup(scope::AbstractScope, name::Symbol) =
    error("lookup() is not implemented for scope $scope")

# Generates the terminating pipeline.
getfinish(scope::AbstractScope) =
    Nullable{Query}()

# Replaces the default terminating pipeline.
setfinish(scope::AbstractScope, finish) =
    error("setfinish() is not implemented for scope $scope")

# Get the sort direction (0 is default, +1 for ascending order,
# -1 for descending order).
getorder(scope::AbstractScope) =
    error("getorder() is not implemented for scope $scope")

# Set the sorting direction.
setorder(scope::AbstractScope, order::Int) =
    error("setorder() is not implemented for scope $scope")

# The type of values produced at this scope.
domain(scope::AbstractScope) =
    error("domain() is not implemented for scope $scope")

# Returns the root scope.
root(scope::AbstractScope) =
    error("root() is not implemented for scope $scope")

# Generates a scalar scope of the given type.
scalar(scope::AbstractScope, T::DataType) =
    error("scalar() is not implemented for scope $scope")

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

# TODO: UniqueSeq, NonEmptySeq.

# Extracts the type parameter.
domain{T}(::Type{Iso{T}}) = T
domain{T}(::Type{Opt{T}}) = T
domain{T}(::Type{Seq{T}}) = T

# Extracts the structure.
mode{T}(::Type{Iso{T}}) = Iso
mode{T}(::Type{Opt{T}}) = Opt
mode{T}(::Type{Seq{T}}) = Seq

# How the values are represented.
datatype{T}(::Type{Iso{T}}) = T
datatype{T}(::Type{Opt{T}}) = Nullable{T}
datatype{T}(::Type{Seq{T}}) = Vector{T}

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
execute(pipe::AbstractPipe{Tuple{}}) =
    execute(pipe, ())
# Executes the pipeline by calling it.
call(pipe::AbstractPipe, args...) = execute(pipe, args...)

# Returns an equivalent, but improved pipeline.
optimize(pipe::AbstractPipe) = pipe

# Encapsulates the compiler state and execution pipeline.
immutable Query
    input::DataType
    output::DataType
    scope::AbstractScope
    pipe::AbstractPipe
end

# The input type and structure (e.g. `Iso{Int}`).
input(q::Query) = q.input
# The output type and structure.
output(q::Query) = q.output

# Type and structure of input and output.
domain(q::Query) = domain(q.input)
mode(q::Query) = mode(q.input)
codomain(q::Query) = domain(q.output)
comode(q::Query) = mode(q.output)

# Extracts the compiler state.
scope(q::Query) = q.scope

# Extracts the pipeline.
pipe(q::Query) = q.pipe

# Displays the query.
show(io::IO, q::Query) =
    q.input == Iso{Tuple{}} ?
        print(io, q.pipe, " : ", datatype(q.output)) :
        print(io, q.pipe, " : ", datatype(q.input), " -> ", datatype(q.output))

# Executes the query.
execute(q::Query, args...) =
    execute(pipe(optimize(finalize(q))), args...)
call(q::Query, args...) = execute(q, args...)

# Compiles the query.
prepare(state, expr) =
    optimize(finalize(compile(state, expr)))

# Builds initial execution pipeline.
compile(state, expr) = compile(scope(state), syntax(expr))
compile(state::AbstractScope, expr::AbstractSyntax) =
    error("compile() is not implemented for $(typeof(expr))")

# Finalizes the execution pipeline.
finalize(q::Query) = q

# Optimizes the execution pipeline.
optimize(q::Query) = Query(q.input, q.output, q.scope, optimize(q.pipe))

# Scope operations passthrough.
lookup(q::Query, name::Symbol) = lookup(q.scope, name)
getfinish(q::Query) = getfinish(q.scope)
getorder(q::Query) = getorder(q.scope)

# For dispatching on the function name.
immutable Fn{name}
end

