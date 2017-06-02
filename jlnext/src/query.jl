#
# Database queries.
#

# Binding table associates identifiers with query constructors.

abstract AbstractBinding

typealias MaybeBinding Nullable{AbstractBinding}
typealias BindingTable ImmutableDict{Tuple{Symbol, Int}, AbstractBinding}

const NO_BINDING_TABLE = BindingTable()

lookup(tbl::BindingTable, ident::Symbol, arity::Int) =
    let mb = get(tbl, (ident, arity))
        isnull(mb) ? get(tbl, (ident, -1)) : mb
    end

# Database can produce global and local binding tables.

abstract AbstractDatabase

globals(db::AbstractDatabase) =
    error("not implemented")
locals(db::AbstractDatabase, dom::Domain) =
    error("not implemented")

immutable EmptyDatabase <: AbstractDatabase
end

const NO_DB = EmptyDatabase()

globals(db::EmptyDatabase) = NO_BINDING_TABLE
locals(db::EmptyDatabase, dom::Domain) = NO_BINDING_TABLE

# Scope is a pair of global and local binding tables.

immutable Scope
    db::AbstractDatabase
    dom::Domain
    globs::BindingTable
    locs::BindingTable
end

Scope(db::AbstractDatabase, dom::Domain) =
    Scope(db, dom, globals(db), locals(db, dom))

Scope(db::AbstractDatabase, desc::Union{Symbol, Type}) =
    Scope(db, Domain(desc))

database(scope::Scope) = scope.db
domain(scope::Scope) = scope.dom
globals(scope::Scope) = scope.globs
locals(scope::Scope) = scope.locs

lookup(scope::Scope, ident::Symbol, arity::Int) =
    let mb = lookup(scope.locs, ident, arity)
        isnull(mb) ? lookup(scope.globs, ident, arity) : mb
    end

# Signature of the query expression.

abstract AbstractSignature
abstract AbstractPrimitive <: AbstractSignature

# Binding tables for the input and the output scopes.

immutable Namespace
    db::AbstractDatabase
    ilocs::BindingTable
    olocs::BindingTable
    globs::BindingTable
end

const NO_NAMESPACE =
    Namespace(NO_DB, NO_BINDING_TABLE, NO_BINDING_TABLE, NO_BINDING_TABLE)

# Query interface.

immutable Query
    sig::AbstractSignature
    args::Vector{Query}
    ity::Input
    oty::Output
    ns::Namespace
    src::Any
end

const NO_ARGUMENTS = Query[]

Query(sig::AbstractPrimitive) =
    Query(sig, NO_ARGUMENTS, input(sig), output(sig), NO_NAMESPACE, nothing)
Query(sig::AbstractSignature, args::Vector{Query}) =
    Query(sig, args, input(sig, args), output(sig, args), NO_NAMESPACE, nothing)
Query(sig::AbstractSignature, args::Vector{Query}, ity::Union{Domain,Input}, oty::Union{Domain,Output}) =
    Query(sig, args, convert(Input, ity), convert(Output, oty), NO_NAMESPACE, nothing)
Query(sig::AbstractPrimitive, ity::Union{Domain,Input}, oty::Union{Domain,Output}) =
    Query(sig, NO_ARGUMENTS, convert(Input, ity), convert(Output, oty))

show(io::IO, q::Query) =
    print(io, "$(q.ity) -> $(q.oty)")

setsignature(q::Query, sig::AbstractSignature) =
    Query(sig, q.args, q.ity, q.oty, q.ns, q.src)
setarguments(q::Query, args::Vector{Query}) =
    Query(q.sig, args, q.ity, q.oty, q.ns, q.src)
setinput(q::Query, ity::Input) =
    Query(q.sig, q.args, ity, q.oty, q.ns, q.src)
setoutput(q::Query, oty::Output) =
    Query(q.sig, q.args, q.ity, oty, q.ns, q.src)
setnamespace(q::Query, ns::Namespace) =
    Query(q.sig, q.args, q.ity, q.oty, ns, q.src)
setnamespace(q::Query, db::AbstractDatabase) =
    let globs = globals(db),
        ilocs = locals(db, domain(q.ity)),
        olocs = locals(db, domain(q.oty)),
        ns = Namespace(db, ilocs, olocs, globs)
        setnamespace(q, ns)
    end
setsource(q::Query, src::Any) =
    Query(q.sig, q.args, q.ity, q.oty, q.ns, src)

setsignature(sig::AbstractSignature) =
    q -> setsignature(q, sig)
setarguments(args::Vector{Query}) =
    q -> setarguments(q, args)
setinput(itype::Input) =
    q -> setinput(q, itype)
setoutput(oty::Output) =
    q -> setoutput(q, oty)
setnamespace(ns::Union{Namespace, AbstractDatabase}) =
    q -> setnamespace(q, ns)
setsource(src::Any) =
    q -> setsource(q, src)

signature(q::Query) = q.sig

input(q::Query) = q.ity
output(q::Query) = q.oty

iscope(q::Query) = Scope(q.ns.db, domain(q.ity), q.ns.globs, q.ns.ilocs)
oscope(q::Query) = Scope(q.ns.db, domain(q.oty), q.ns.globs, q.ns.olocs)

isplain(q::Query) = isplain(output(q))
isoptional(q::Query) = isoptional(output(q))
isplural(q::Query) = isplural(output(q))

input(sig::AbstractSignature, args::Vector{Query}) =
    input(sig, args...)
output(sig::AbstractSignature, args::Vector{Query}) =
    output(sig, args...)

istub(q::Query) =
    let dom = domain(q.ity),
        ns = Namespace(q.ns.db, q.ns.ilocs, q.ns.ilocs, q.ns.globs)
        Query(ItSig(), NO_ARGUMENTS, Input(dom), Output(dom), ns, nothing)
    end

ostub(q::Query) =
    let dom = domain(q.oty),
        ns = Namespace(q.ns.db, q.ns.olocs, q.ns.olocs, q.ns.globs)
        Query(ItSig(), NO_ARGUMENTS, Input(dom), Output(dom), ns, nothing)
    end

decorate(q::Query, decor::Decoration) =
    let dom = domain(q.oty),
        ns = Namespace(q.ns.db, q.ns.olocs, q.ns.olocs, q.ns.globs)
        q >> Query(ItSig(), NO_ARGUMENTS, Input(dom), Output(decorate(dom, decor)), ns, nothing)
    end

# Executing queries.

ev(q::Query, ctx::InputContext=InputContext(), dom=Domain(Void), vals::AbstractVector=[nothing]) =
    ev(q, InputFlow(ctx, dom, vals))

ev(q::Query, dom, vals::AbstractVector) =
    ev(q, InputFlow(InputContext(), dom, vals))

ev{T}(q::Query, vals::AbstractVector{T}) =
    ev(q, InputFlow(InputContext(), T, vals))

ev(q::Query, iflow::InputFlow) =
    ev(q.sig, q.args, q.ity, q.oty, iflow)

ev(sig::AbstractPrimitive, ::Vector{Query}, ity::Input, oty::Output, iflow::InputFlow) =
    ev(sig, ity, oty, iflow)

ev(sig::AbstractPrimitive, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(oty, ev(sig, values(iflow)))

const OPTIMIZE_CACHE = Dict{Query, Query}()

function optimize(q::Query)
    if q in keys(OPTIMIZE_CACHE)
        return OPTIMIZE_CACHE[q]
    end
    oq = q
    OPTIMIZE_CACHE[q] = oq
    return oq
end

format(q::Query) =
    format(q, decoration(domain(output(q)), :fmt, Union{Void, Symbol, Vector{Symbol}}, nothing))

format(q::Query, ::Void) = q

format(q::Query, name::Symbol) =
    let scope = oscope(q),
        binding = get(lookup(scope, name, 0)),
        tag = decoration(output(q), :tag, Symbol, Symbol(""))
        q = q >> format(compile(binding, scope, Syntax[]))
        if tag != Symbol("")
            q = q |> decorate(:tag => tag)
        end
        q
    end

format(q::Query, names::Vector{Symbol}) =
    let scope = oscope(q),
        bindings = [get(lookup(scope, name, 0)) for name in names],
        tag = decoration(output(q), :tag, Symbol, Symbol(""))
        q = q >> RecordQuery(
                    [format(compile(binding, scope, Syntax[])) for binding in bindings])
        if tag != Symbol("")
            q = q |> decorate(:tag => tag)
        end
        q
    end

function execute{T}(q::Query, val::T=nothing; paramvals...)
    q = optimize(q)
    itype = input(q)
    otype = output(q)
    if isrelative(itype)
        frameoffs = InputFrame(OneTo(2))
    else
        frameoffs = InputFrame()
    end
    pflows = InputSlotFlow[]
    parammap = Dict{Symbol,Any}(paramvals)
    for (pname, ptype) in slots(itype)
        paramval = get(parammap, pname, nothing)
        paramcol = Column(OneTo(2), [paramval])
        paramflow = InputSlotFlow(pname, OutputFlow(ptype, paramcol))
        push!(pflows, paramflow)
    end
    iflow = InputFlow(InputContext(), T, T[val], frameoffs, pflows)
    oflow = ev(q, iflow)
    return oflow[nothing]
end

include("query/const.jl")
include("query/it.jl")
include("query/collection.jl")
include("query/mapping.jl")
include("query/compose.jl")
include("query/record.jl")
include("query/field.jl")
include("query/lift.jl")
include("query/count.jl")
include("query/exists.jl")
include("query/aggregate.jl")
include("query/filter.jl")
include("query/sort.jl")
include("query/take.jl")
include("query/connect.jl")
include("query/group.jl")
include("query/rollup.jl")
include("query/unique.jl")
include("query/given.jl")
include("query/parameter.jl")
include("query/around.jl")
include("query/frame.jl")
include("query/sql.jl")

