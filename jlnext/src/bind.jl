#
# Database and bindings.
#

type Database <: AbstractDatabase
    loccache::Dict{Type, BindingTable}
    globcache::BindingTable

    Database() = new(Dict{Type, BindingTable}(), NO_BINDING_TABLE)
end

const DB = Database()

globals(db::Database) = db.globcache
locals(db::Database, dom::Domain) =
    locals(db, dom.desc)

locals(db::Database, desc::Type) =
    get(db.loccache, desc, NO_BINDING_TABLE)

locals(db::Database, desc::Symbol) =
    locals(db, Entity{desc})

function locals(db::Database, desc::Vector{Output})
    tbl = NO_BINDING_TABLE
    for pos in eachindex(desc)
        fld = FieldQuery(Domain(desc), pos)
        tbl = assoc(tbl, (Symbol(pos), 0), QueryBinding(fld))
        tag = decoration(desc[pos], :tag, Symbol, Symbol(""))
        if tag != Symbol("")
            tbl = assoc(tbl, (tag, 0), QueryBinding(fld))
        end
    end
    return tbl
end 

function attach!(db::Database, name::Symbol, prim::AbstractPrimitive)
    T = datatype(domain(input(prim)))
    tbl = get(db.loccache, T, NO_BINDING_TABLE)
    tbl = assoc(tbl, (name, 0), PrimitiveBinding(prim))
    db.loccache[T] = tbl
end

attach!(name::Symbol, prim::AbstractPrimitive) =
    attach!(DB, name, prim)

function attach!(db::Database, name::Symbol, q::Query)
    T = datatype(domain(input(q)))
    tbl = get(db.loccache, T, NO_BINDING_TABLE)
    tbl = assoc(tbl, (name, 0), QueryBinding(q))
    db.loccache[T] = tbl
end

attach!(name::Symbol, q::Query) =
    attach!(DB, name, q)

function attachglobal!(db::Database, name::Symbol, arity::Int, binding::AbstractBinding)
    db.globcache = assoc(db.globcache, (name, arity), binding)
end

attachglobal!(db::Database, name::Symbol, arity::Int=-1) =
    attachglobal!(db, name, arity, StaticBinding{name}())

attachglobal!(name::Symbol, arity::Int=-1) =
    attachglobal!(DB, name, arity)

immutable LiteralBinding <: AbstractBinding
    val
end

immutable StaticBinding{N} <: AbstractBinding
end

compile{N}(binding::StaticBinding{N}, scope::Scope, args::Vector{Syntax}) =
    compile(binding, scope, (compile(scope, arg) for arg in args)...)

immutable PrimitiveBinding <: AbstractBinding
    prim::AbstractPrimitive
end

compile(binding::PrimitiveBinding, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert isempty(args)
        compile(binding, scope)
    end

compile(binding::PrimitiveBinding, scope::Scope) =
    Query(binding.prim) |> setnamespace(scope.db)

immutable QueryBinding <: AbstractBinding
    query::Query
end

compile(binding::QueryBinding, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert isempty(args)
        q = binding.query
        if q.ns === NO_NAMESPACE
            ns = Namespace(scope.db, locals(scope.db, domain(q.ity)), locals(scope.db, domain(q.oty)), scope.globs)
            q = q |> setnamespace(ns)
        end
        q
    end

compile(syntax::Syntax) =
    compile(DB, syntax)

compile(db::AbstractDatabase, syntax::Syntax) =
    compile(Scope(db, Void), syntax)

function compile(scope::Scope, syntax::Syntax)
    binding =
        if !haslabel(syntax)
            QueryBinding(ConstQuery(syntax.val))
        else
            maybe_binding = lookup(scope, syntax.label, length(syntax.args))
            if isnull(maybe_binding)
                error("invalid identifier: $(syntax.label)")
            end
            get(maybe_binding)
        end
    return compile(binding, scope, syntax.args)
end

query(db::AbstractDatabase, syntax::Syntax, paramtypes::Vector{Pair}=Pair[]) =
    let scope = Scope(db, Void)
        globs = scope.globs
        for (tag, oty) in paramtypes
            tag  = Symbol(tag)
            oty = convert(Output, oty)
            globs = assoc(globs, (tag, 0), QueryBinding(ParameterQuery(tag, oty) |> setnamespace(db)))
        end
        scope = Scope(scope.db, scope.dom, globs, scope.locs)
        format(compile(scope, syntax))
    end

query(db::AbstractDatabase, expr, paramtypes=Pair[]) =
    query(db, expr2syntax(expr), paramtypes)

query(syntax, paramtypes=Pair{Symbol}[]) =
    query(DB, syntax, paramtypes)

macro query(args...)
    L = endof(args)
    while L > 0 && isa(args[L], Expr) && args[L].head == :(::)
        L = L-1
    end
    @assert 1 <= L <= 2
    if L == 2
        db, expr = args[1], args[2]
    else
        db, expr = DB, args[1]
    end
    expr = expr2syntax(expr)
    params = [:( $(string(arg.args[1])) => $(arg.args[2]) ) for arg in args[L+1:end]]
    return quote
        query($(esc(db)), $expr, Pair[$(params...)])
    end
end

include("bind/static.jl")

