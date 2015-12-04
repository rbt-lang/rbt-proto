
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

# Encapsulates the compiler state and the query combinator.
immutable Query
    # Local namespace.
    scope::AbstractScope
    # The input type of the combinator.
    #input::Input
    # The output type of the combinator.
    #output::Output
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
    pipe=HerePipe(domain),
    fields=NullableQueries(),
    identity=NullableQuery(),
    selector=NullableQuery(),
    defs=Dict{Symbol,Query}(),
    order=0,
    tag=NullableSymbol(),
    syntax=NullableSyntax(),
    origin=NullableQuery()) =
    Query(scope, pipe, fields, identity, selector, defs, order, tag, syntax, origin)

# Initial compiler state.
Query(db::AbstractDatabase; params...) = Query(scope(db, Dict{Symbol,Type}(params)))

# Clone constructor.
Query(
    q::Query;
    scope=nothing, pipe=nothing,
    fields=nothing, identity=nothing, selector=nothing, defs=nothing,
    order=nothing, tag=nothing,
    syntax=nothing, origin=nothing) =
    Query(
        scope != nothing ? scope : q.scope,
        #input != nothing ? input : q.input,
        #output != nothing ? output : q.output,
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

# Scope operations passthrough.
lookup(q::Query, name::Symbol) =
    name in keys(q.defs) ? NullableQuery(q.defs[name]) : lookup(q.scope, name)
root(q::Query) = root(q.scope)
empty(q::Query) = empty(q.scope)


immutable RootScope <: AbstractScope
    db::Database
    params::Dict{Symbol,Type}
end

show(io::IO, ::RootScope) = print(io, "ROOT")

root(self::RootScope) = self

empty(self::RootScope) = EmptyScope(self.db, self.params)

function lookup(self::RootScope, name::Symbol)
    if name in keys(self.params)
        return NullableQuery(param2q(self, name, self.params[name]))
    end
    if name in keys(self.db.schema.name2class)
        class = self.db.schema.name2class[name]
        scope = ClassScope(self.db, name, self.params)
        T = Entity{name}
        pipe = SetPipe(name, self.db.instance.sets[name], ismonic=true, iscovering=true)
        tag = NullableSymbol(name)
        syntax = NullableSyntax(ApplySyntax(name, []))
        query = Query(scope, pipe=pipe, tag=tag, syntax=syntax)
        selector = mkselector(
            query,
            class.select != nothing ? class.select : tuple(keys(class.arrows)...))
        identity = mkidentity(query, :id)
        query = Query(query, selector=selector, identity=identity)
        return NullableQuery(query)
    else
        return NullableQuery()
    end
end


immutable ClassScope <: AbstractScope
    db::Database
    name::Symbol
    params::Dict{Symbol,Type}
end

show(io::IO, self::ClassScope) = print(io, "Class(<", self.name, ">)")

root(self::ClassScope) = RootScope(self.db, self.params)

empty(self::ClassScope) = EmptyScope(self.db, self.params)

function lookup(self::ClassScope, name::Symbol)
    if name in keys(self.params)
        return NullableQuery(param2q(self, name, self.params[name]))
    end
    class = self.db.schema.name2class[self.name]
    if name == :id
        scope = EmptyScope(self.db, self.params)
        IT = Entity{self.name}
        pipe = ItemPipe(IT, 1, typemin(OutputMode))
        tag = NullableSymbol(name)
        syntax = NullableSyntax(ApplySyntax(name, []))
        return NullableQuery(Query(scope, pipe=pipe, tag=tag, syntax=syntax))
    elseif name in keys(class.name2arrow)
        tag = NullableSymbol(name)
        arrow = class.name2arrow[name]
        map = self.db.instance.maps[(self.name, arrow.name)]
        IT = Entity{self.name}
        OT = domain(arrow.output)
        pipe_name = symbol(self.name, "/", name)
        if isplain(arrow)
            pipe = IsoMapPipe(pipe_name, map, ismonic(arrow), iscovering(arrow))
        elseif ispartial(arrow)
            pipe = OptMapPipe(pipe_name, map, ismonic(arrow), iscovering(arrow))
        else
            pipe = SeqMapPipe(pipe_name, map, isnonempty(arrow), ismonic(arrow), iscovering(arrow))
        end
        syntax = NullableSyntax(ApplySyntax(name, []))
        if OT <: Entity
            targetname = classname(OT)
            targetclass = self.db.schema.name2class[targetname]
            scope = ClassScope(self.db, targetname, self.params)
            query = Query(scope, pipe=pipe, tag=tag, syntax=syntax)
            selector = mkselector(
                query,
                arrow.select != nothing ? arrow.select :
                targetclass.select != nothing ? targetclass.select :
                    tuple(keys(targetclass.arrows)...))
            identity = mkidentity(query, :id)
            query = Query(query, selector=selector, identity=identity)
        else
            scope = EmptyScope(self.db, self.params)
            query = Query(scope, pipe=pipe, tag=tag, syntax=syntax)
        end
        return NullableQuery(query)
    else
        return NullableQuery()
    end
end


immutable EmptyScope <: AbstractScope
    db::Database
    params::Dict{Symbol,Type}
end

show(io::IO, ::EmptyScope) = print(io, "EMPTY")

root(self::EmptyScope) = RootScope(self.db, self.params)

empty(self::EmptyScope) = self

lookup(self::EmptyScope, name::Symbol) =
    name in keys(self.params) ?
        NullableQuery(param2q(self, name, self.params[name])) :
        NullableQuery()


mkselector(base::Query, spec) = mkcomposite(base, spec, :selector)

mkidentity(base::Query, spec) = mkcomposite(base, spec, :identity)

function mkcomposite(base::Query, query::Query, field)
    cap = getfield(query, field)
    if !isnull(cap)
        query = Query(query >> get(cap), tag=query.tag)
    end
    return query
end

function mkcomposite(base::Query, name::Symbol, field)
    op = lookup(base, name)
    @assert !isnull(op)
    return mkcomposite(base, get(op), field)
end

function mkcomposite(base::Query, parts::Tuple, field)
    ops = [mkcomposite(base, part, field) for part in parts]
    return record(base, ops...)
end

function param2q(base::AbstractScope, name::Symbol, T::Type)
    if T <: AbstractString
        T = UTF8String
    elseif T <: Nullable{ASCIIString}
        T = Nullable{UTF8String}
    elseif T <: Vector{ASCIIString}
        T = Vector{UTF8String}
    end
    if T == Void
        T = Nullable{Union{}}
    end
    scope = empty(base)
    IT = isa(base, ClassScope) ? Entity{base.name} : Unit
    output =
        T <: Vector ? Output(eltype(T), lunique=false, ltotal=false) :
        T <: Nullable ? Output(eltype(T), ltotal=false) : Output(T)
    pipe = ParamPipe(IT, name, output)
    return Query(scope, pipe=pipe)
end

scope(db::Database) = RootScope(db, Dict{Symbol,Type}())

scope(db::Database, params::Dict{Symbol,Type}) = RootScope(db, params)

