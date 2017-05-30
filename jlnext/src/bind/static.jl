#
# Global static bindings.
#

# Composition.

attachglobal!(:(.))

function compile(::StaticBinding{:(.)}, scope::Scope, args::Vector{Syntax})
    qs = Query[]
    scope′ = scope
    for arg in args
        q = compile(scope′, arg) |> setnamespace(scope′.db)
        push!(qs, q)
        scope′ = oscope(q)
    end
    return ComposeQuery(qs) |> setnamespace(scope.db)
end

# Count and exists aggregates.

attachglobal!(:count, 1)

compile(::StaticBinding{:count}, scope::Scope, arg::Query) =
    CountQuery(arg) |> setnamespace(scope.db)

attachglobal!(:exists, 1)

compile(::StaticBinding{:exists}, scope::Scope, arg::Query) =
    ExistsQuery(arg) |> setnamespace(scope.db)

# Other aggregates.

attachglobal!(:any, 1)

compile(::StaticBinding{:any}, scope::Scope, arg::Query) =
    AggregateQuery(any, Bool, Bool, true, arg) |> setnamespace(scope.db)

attachglobal!(:all, 1)

compile(::StaticBinding{:all}, scope::Scope, arg::Query) =
    AggregateQuery(all, Bool, Bool, true, arg) |> setnamespace(scope.db)

attachglobal!(:max, 1)

compile(::StaticBinding{:max}, scope::Scope, arg::Query) =
    let T = datatype(domain(output(arg)))
        AggregateQuery(maximum, T, T, false, arg)
    end

attachglobal!(:min, 1)

compile(::StaticBinding{:min}, scope::Scope, arg::Query) =
    let T = datatype(domain(output(arg)))
        AggregateQuery(minimum, T, T, false, arg)
    end

attachglobal!(:sum, 1)

compile(::StaticBinding{:sum}, scope::Scope, arg::Query) =
    let T = datatype(domain(output(arg)))
        AggregateQuery(sum, T, T, true, arg)
    end

attachglobal!(:mean, 1)

compile(::StaticBinding{:mean}, scope::Scope, arg::Query) =
    AggregateQuery(mean, true, arg)

macro lift!(N, fn)
    return esc(quote
        attachglobal!(Symbol($N))
        function compile(binding::StaticBinding{Symbol($N)}, scope::Scope, args::Vector{Syntax})
            return compile(binding, scope, Query[compile(scope, arg) for arg in args])
        end
        function compile(::StaticBinding{Symbol($N)}, scope::Scope, args::Vector{Query})
            fn = $fn
            return LiftQuery(fn, args) |> setnamespace(scope.db)
        end
    end)
end

macro lift!(N)
    return quote
        @lift!($N, $N)
    end
end

@lift!(==)
@lift!(!=)
@lift!(>)
@lift!(>=)
@lift!(<)
@lift!(<=)
@lift!(+)
@lift!(-)
@lift!(*)
@lift!(/)
@lift!(÷)
@lift!(&)
@lift!(|)
@lift!(!)

attachglobal!(DB, :÷, -1, StaticBinding{:div}())

# Filtering.

attachglobal!(:filter, 2)

compile(sig::StaticBinding{:filter}, scope::Scope, args::Vector{Syntax}) =
    compile(sig, scope, args...)

compile(sig::StaticBinding{:filter}, scope::Scope, base::Syntax, pred::Syntax) =
    let base′ = compile(scope, base),
        pred′ = compile(oscope(base′), pred)
        compile(sig, scope, base′, pred′)
    end

compile(::StaticBinding{:filter}, scope::Scope, base::Query, pred::Query) =
    FilterQuery(base, pred) |> setnamespace(base.ns)

# Sorting.

attachglobal!(:sort)

compile(sig::StaticBinding{:sort}, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert length(args) >= 1
        compile(sig, scope, args[1], args[2:end])
    end

compile(sig::StaticBinding{:sort}, scope::Scope, base::Syntax, keys::Vector{Syntax}) =
    let base′ = compile(scope, base),
        basescope = oscope(base′),
        keys′ = Query[compile(basescope, key) for key in keys]
        compile(sig, scope, base′, keys′)
    end

compile(sig::StaticBinding{:sort}, scope::Scope, base::Query, keys::Vector{Query}) =
    if isempty(keys)
        SortQuery(base)
    else
        SortQuery(base, keys)
    end |> setnamespace(base.ns)

attachglobal!(:asc, 1)

compile(sig::StaticBinding{:asc}, scope::Scope, arg::Query) =
    (arg |> decorate(:rev => false)) |> setnamespace(arg.ns)

attachglobal!(:desc, 1)

compile(sig::StaticBinding{:desc}, scope::Scope, arg::Query) =
    (arg |> decorate(:rev => true)) |> setnamespace(arg.ns)

attachglobal!(:nullfirst, 1)

compile(sig::StaticBinding{:nullfirst}, scope::Scope, arg::Query) =
    (arg |> decorate(:nullrev => false)) |> setnamespace(arg.ns)

attachglobal!(:nulllast, 1)

compile(sig::StaticBinding{:nulllast}, scope::Scope, arg::Query) =
    (arg |> decorate(:nullrev => true)) |> setnamespace(arg.ns)

# Paginating.

attachglobal!(:take, 2)

compile(::StaticBinding{:take}, scope::Scope, base::Query, N::Query) =
    TakeQuery(base, N) |> setnamespace(base.ns)

attachglobal!(:skip, 2)

compile(::StaticBinding{:skip}, scope::Scope, base::Query, N::Query) =
    SkipQuery(base, N) |> setnamespace(base.ns)

# Select.

attachglobal!(:(=>), 2)

compile(sig::StaticBinding{:(=>)}, scope::Scope, args::Vector{Syntax}) =
    compile(sig, scope, args...)

function compile(sig::StaticBinding{:(=>)}, scope::Scope, key::Syntax, base::Syntax)
    @assert haslabel(key) && !hasargs(key)
    tag = label(key)
    q = compile(scope, base)
    q = q |> decorate(:tag => tag)
    return q
end

attachglobal!(:select)

compile(sig::StaticBinding{:select}, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert length(args) >= 1
        compile(sig, scope, args[1], args[2:end])
    end

compile(sig::StaticBinding{:select}, scope::Scope, base::Syntax, fields::Vector{Syntax}) =
    let base′ = compile(scope, base),
        basescope = oscope(base′),
        fields′ = Query[compile(basescope, field) for field in fields]
        compile(sig, scope, base′, fields′)
    end

function compile(sig::StaticBinding{:select}, scope::Scope, base::Query, fields::Vector{Query})
    tag = decoration(domain(output(base)), :tag, Symbol, Symbol(""))
    q = base >> RecordQuery(ostub(base), fields)
    q = q |> decorate(:fmt => Symbol[Symbol(pos+1) for pos in eachindex(fields)])
    if tag != Symbol("")
        q = q |> decorate(:tag => tag)
    end
    q = q |> setnamespace(scope.db)
    return q
end

# Query aliases.

attachglobal!(:define)

compile(sig::StaticBinding{:define}, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert length(args) >= 1
        compile(sig, scope, args[1], args[2:end])
    end

function compile(sig::StaticBinding{:define}, scope::Scope, base::Syntax, aliases::Vector{Syntax})
    base′ = compile(scope, base)
    scope′ = oscope(base′)
    for alias in aliases
        q = compile(scope′, alias)
        tag = decoration(domain(output(q)), :tag, Symbol, Symbol(""))
        ns = base′.ns
        olocs = ns.olocs
        olocs = assoc(olocs, (tag, 0), QueryBinding(q))
        ns = Namespace(ns.db, ns.ilocs, olocs, ns.globs)
        base′ = base′ |> setnamespace(ns)
        scope′ = oscope(base′)
    end
    return base′
end

# Hierarchical closure.

attachglobal!(:connect, 1)

compile(sig::StaticBinding{:connect}, scope::Scope, arg::Query) =
    ConnectQuery(false, arg) |> setnamespace(arg.ns)

# Unique combinator.

attachglobal!(:unique, 1)

compile(sig::StaticBinding{:unique}, scope::Scope, arg::Query) =
    UniqueQuery(arg) |> setnamespace(arg.ns)

# Grouping.

attachglobal!(:group)

compile(sig::StaticBinding{:group}, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert length(args) >= 1
        compile(sig, scope, args[1], args[2:end])
    end

compile(sig::StaticBinding{:group}, scope::Scope, base::Syntax, keys::Vector{Syntax}) =
    let base′ = compile(scope, base),
        basescope = oscope(base′),
        keys′ = Query[compile(basescope, key) for key in keys]
        compile(sig, scope, base′, keys′)
    end

function compile(sig::StaticBinding{:group}, scope::Scope, base::Query, keys::Vector{Query})
    q = GroupQuery(base, keys) |> setnamespace(scope.db)
    locs = q.ns.olocs
    tag = decoration(domain(output(base)), :tag, Symbol, Symbol(""))
    if tag != Symbol("")
        field = FieldQuery(domain(output(q)), 1) |> setnamespace(base.ns)
        locs = assoc(locs, (tag, 0), QueryBinding(field))
    end
    for k in eachindex(keys)
        key = keys[k]
        tag = decoration(domain(output(key)), :tag, Symbol, Symbol(""))
        if tag != Symbol("")
            field = FieldQuery(domain(output(q)), k+1) |> setnamespace(key.ns)
            locs = assoc(locs, (tag, 0), QueryBinding(field))
        end
    end
    ns = Namespace(q.ns.db, q.ns.ilocs, locs, q.ns.globs)
    q = q |> decorate(:fmt => Symbol[Symbol(pos+1) for pos in eachindex(keys)])
    q = q |> setnamespace(ns)
    return q
end

# Roll-up.

attachglobal!(:rollup)

compile(sig::StaticBinding{:rollup}, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert length(args) >= 1
        compile(sig, scope, args[1], args[2:end])
    end

compile(sig::StaticBinding{:rollup}, scope::Scope, base::Syntax, keys::Vector{Syntax}) =
    let base′ = compile(scope, base),
        basescope = oscope(base′),
        keys′ = Query[compile(basescope, key) for key in keys]
        compile(sig, scope, base′, keys′)
    end

function compile(sig::StaticBinding{:rollup}, scope::Scope, base::Query, keys::Vector{Query})
    q = RollUpQuery(base, keys) |> setnamespace(scope.db)
    locs = q.ns.olocs
    tag = decoration(domain(output(base)), :tag, Symbol, Symbol(""))
    if tag != Symbol("")
        field = FieldQuery(domain(output(q)), 1) |> setnamespace(base.ns)
        locs = assoc(locs, (tag, 0), QueryBinding(field))
    end
    for k in eachindex(keys)
        key = keys[k]
        tag = decoration(domain(output(key)), :tag, Symbol, Symbol(""))
        if tag != Symbol("")
            field = FieldQuery(domain(output(q)), k+1) |> setnamespace(key.ns)
            locs = assoc(locs, (tag, 0), QueryBinding(field))
        end
    end
    ns = Namespace(q.ns.db, q.ns.ilocs, locs, q.ns.globs)
    q = q |> decorate(:fmt => Symbol[Symbol(pos+1) for pos in eachindex(keys)])
    q = q |> setnamespace(ns)
    return q
end

# Given combinator.

attachglobal!(:given)

compile(sig::StaticBinding{:given}, scope::Scope, args::Vector{Syntax}) =
    begin
        @assert length(args) >= 1
        base = args[1]
        keys = args[2:end]
        reverse!(keys)
        compile(sig, scope, base, keys)
    end

function compile(sig::StaticBinding{:given}, scope::Scope, base::Syntax, keys::Vector{Syntax})
    globs = scope.globs
    kqs = Query[]
    for key in keys
        kq = compile(scope, key)
        push!(kqs, kq)
        tag = decoration(domain(output(kq)), :tag, Symbol, Symbol(""))
        binding = QueryBinding(SlotQuery(tag, output(kq)) |> setnamespace(kq.ns))
        globs = assoc(globs, (tag, 0), binding)
        scope = Scope(scope.db, scope.dom, globs, scope.locs)
    end
    reverse!(kqs)
    baseq = compile(scope, base)
    return GivenQuery(baseq, kqs) |> setnamespace(baseq.ns)
end

# Context combinators.

attachglobal!(:around)
attachglobal!(:before)

compile(sig::Union{StaticBinding{:around}, StaticBinding{:before}}, scope::Scope, args::Vector{Syntax}) =
    begin
        compile(sig, scope, Query[compile(scope, arg) for arg in args])
    end

compile(sig::StaticBinding{:around}, scope::Scope, keys::Vector{Query}) =
    isempty(keys) ?
        AroundQuery(scope.dom, true, true, true) :
        AroundQuery(scope.dom, true, true, true, keys)

compile(sig::StaticBinding{:before}, scope::Scope, keys::Vector{Query}) =
    isempty(keys) ?
        AroundQuery(scope.dom, true, true, false) :
        AroundQuery(scope.dom, true, true, false, keys)

attachglobal!(:frame, 1)

compile(sig::StaticBinding{:frame}, scope::Scope, q::Query) =
    FrameQuery(q) |> setnamespace(q.ns)

