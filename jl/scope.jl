#
# Compiler state.
#


#
# A combinator constructor.
#

abstract AbstractBinding


#
# Collection of bindings and other compiler state.
#

typealias BindingTuple Tuple{Vararg{AbstractBinding}}
typealias NullableBindingTuple Nullable{BindingTuple}
typealias NullableSymbol Nullable{Symbol}
typealias SymbolTable ImmutableDict{Tuple{Symbol,Int}, AbstractBinding}


immutable Scope
    db::AbstractDatabase
    domain::Type
    rev::Bool
    tag::NullableSymbol
    globals::SymbolTable
    locals::SymbolTable
    items::NullableBindingTuple
end

Scope(
    db::AbstractDatabase, domain::Type;
    rev::Bool=false,
    tag::Union{Symbol,NullableSymbol}=NullableSymbol(),
    globals::SymbolTable=SymbolTable(),
    locals::SymbolTable=SymbolTable(),
    items::Union{BindingTuple,NullableBindingTuple}=NullableBindingTuple()) =
    Scope(db, domain, rev, tag, globals, locals, items)

domain(scope::Scope) = scope.domain

addglobal(scope::Scope, key::Tuple{Symbol,Int}, binding::AbstractBinding) =
    Scope(scope.db, scope.domain, scope.rev, scope.tag, assoc(scope.globals, key, binding), scope.locals, scope.items)

addglobal(scope::Scope, key::Symbol, binding::AbstractBinding) =
    addglobal(scope, (key, 0), binding)

addlocal(scope::Scope, key::Tuple{Symbol,Int}, binding::AbstractBinding) =
    Scope(scope.db, scope.domain, scope.rev, scope.tag, scope.globals, assoc(scope.locals, key, binding), scope.items)

addlocal(scope::Scope, key::Symbol, binding::AbstractBinding) =
    addlocal(scope, (key, 0), binding)

settag(scope::Scope, tag::Symbol) =
    Scope(scope.db, scope.domain, scope.rev, tag, scope.globals, scope.locals, scope.items)

setrev(scope::Scope, rev::Bool) =
    Scope(scope.db, scope.domain, rev, scope.tag, scope.globals, scope.locals, scope.items)

setitems(scope::Scope, items::BindingTuple) =
    Scope(scope.db, scope.domain, scope.rev, scope.tag, scope.globals, scope.locals, items)

lookup(scope::Scope, key::Tuple{Symbol,Int}) =
    begin
        name, arity = key
        b = get(scope.locals, (name, arity))
        if !isnull(b)
            return b
        end
        b = get(scope.locals, (name, -1))
        if !isnull(b)
            return b
        end
        b = get(scope.globals, (name, arity))
        if !isnull(b)
            return b
        end
        return get(scope.globals, (name, -1))
    end
lookup(scope::Scope, key::Symbol) = lookup(scope, (key, 0))

nest(scope::Scope, domain::Type) = nest(scope.db, scope, domain)


#
# Encapsulates the compiler state and the combinator.
#

immutable Query
    scope::Scope
    pipe::AbstractPipe
    syntax::Nullable{AbstractSyntax}
    origin::Nullable{Query}
end

Query(
    scope::Scope,
    pipe::AbstractPipe;
    syntax::Union{AbstractSyntax,Nullable{AbstractSyntax}}=Nullable{AbstractSyntax}(),
    origin::Union{Query,Nullable{Query}}=Nullable{Query}()) =
    Query(scope, pipe, syntax, origin)

Query(
    q::Query;
    scope=nothing,
    pipe=nothing,
    syntax=nothing,
    origin=nothing) =
    Query(
        scope == nothing ? q.scope : scope,
        pipe == nothing ? q.pipe : pipe,
        syntax == nothing ? q.syntax : syntax,
        origin == nothing ? q.origin : origin)

# Initial compiler state.
Query(db::AbstractDatabase; params...) =
    let scope = scope(db)
        for (tag, T) in params
            output =
                T <: Vector ? Output(eltype(T), lunique=false, ltotal=false) :
                T <: Nullable ? Output(eltype(T), ltotal=false) : Output(T)
            if output.domain == ASCIIString
                output = Output(UTF8String, output.mode)
            end
            scope = addglobal(scope, tag, ParamBinding(tag, output))
        end
        Query(scope, HerePipe(domain(scope)))
    end

# Extracts the compiler state.
scope(q::Query) = q.scope

lookup(q::Query, key) =
    lookup(scope(q), key)

addlocal(scope::Scope, key, q::Query) =
    addlocal(scope, key, SimpleBinding(q))

addglobal(scope::Scope, key, q::Query) =
    addglobal(scope, key, SimpleBinding(q))

# Extracts the combinator.
pipe(q::Query) = q.pipe
convert(::Type{AbstractPipe}, q::Query) = q.pipe

# The input type and structure.
input(q::Query) = input(q.pipe)
# The output type and structure.
output(q::Query) = output(q.pipe)

# Displays the query.
function show(io::IO, q::Query)
    print(io, isnull(q.syntax) ? "(?)" : get(q.syntax), " :: ", mapping(q))
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
execute(q::Query, args...; params...) =
    pipe(optimize(select(q)))(args...; params...)
call(q::Query, args...; params...) = execute(q, args...; params...)

# Builds initial execution pipeline.
compile(base::Query, expr::AbstractSyntax) =
    error("compile() is not implemented for $(typeof(expr))")

# Optimizes the execution pipeline.
optimize(q::Query) = q
#optimize(q::Query) = Query(q, pipe=optimize(q.pipe))



