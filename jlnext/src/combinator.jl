#
# Combinator API.
#

immutable Combinator
    use::Function
end

Query(C::Combinator) =
    format(C.use(ItQuery(Void) |> setnamespace(DB)))

>>(q::Query, C::Combinator) =
    C.use(q)

(C::Combinator)() = C

convert(::Type{Combinator}, q::Query) =
    Combinator() do q′::Query
        (q′ >> q) |> setnamespace(q′.ns.db)
    end

execute{T}(C::Combinator, val::T=nothing; paramvals...) =
    execute(C.use(ItQuery(T)), val; paramvals...)

# Attribute access.

Field(tag::Symbol) =
    Combinator() do q::Query
        scope = oscope(q)
        maybe_binding = lookup(scope, tag, 0)
        @assert !isnull(maybe_binding) "cannot find attribute $tag in the scope of $(scope.dom)"
        binding = get(maybe_binding)
        (q >> compile(binding, scope, Syntax[])) |> setnamespace(scope.db)
    end

Fields(tag::Symbol, tags′::Symbol...) =
    (Field(tag), (Field(tag′) for tag′ in tags′)...)

convert(::Type{Combinator}, tag::Symbol) =
    Field(tag)

# Composition.

>>(L::Combinator, R::Combinator) =
    Combinator() do q::Query
        (q >> L) >> R
    end

# Identity.

const It =
    Combinator() do q::Query
        q
    end

# Decorations.

Decorate(F::Combinator, decor::Pair{Symbol}) =
    Combinator() do q::Query
        (q >> F) |> decorate(decor)
    end

ThenDecorate(decor::Pair{Symbol}) =
    Combinator() do q::Query
        q |> decorate(decor)
    end

ThenTag(tag::Symbol) =
    ThenDecorate(:tag => tag)

convert{T}(::Type{Combinator}, pair::Pair{Symbol,T}) =
    let (tag, F) = pair
        convert(Combinator, F) >> ThenTag(tag)
    end

# Constants.

Const(val) =
    Combinator() do q::Query
        q >> ConstQuery(val)
    end

convert(::Type{Combinator}, val::Union{Void,Bool,Signed,Unsigned,String}) =
    Const(val)

# Scalar functions.

Lift(fn, argtypes::Tuple{Vararg{Type}}, restype::Type, F::Combinator, Gs...) =
    Combinator() do q::Query
        it = ostub(q)
        q >> LiftQuery(fn, argtypes, restype, it >> F, (it >> convert(Combinator, G) for G in Gs)...)
    end

Lift(fn, argtypes::Tuple{Vararg{Type}}, F::Combinator, Gs...) =
    Combinator() do q::Query
        it = ostub(q)
        q >> LiftQuery(fn, argtypes, it >> F, (it >> convert(Combinator, G) for G in Gs)...)
    end

Lift(fn, F::Combinator, Gs...) =
    Combinator() do q::Query
        it = ostub(q)
        q >> LiftQuery(fn, it >> F, (it >> convert(Combinator, G) for G in Gs)...)
    end

.==(F::Combinator, G) = Lift(==, F, G)
.!=(F::Combinator, G) = Lift(!=, F, G)
.<(F::Combinator, G) = Lift(<, F, G)
.<=(F::Combinator, G) = Lift(<=, F, G)
.>(F::Combinator, G) = Lift(>, F, G)
.>=(F::Combinator, G) = Lift(>=, F, G)

(~)(F::Combinator) = Lift(~, F)
(&)(F::Combinator, Gs::Combinator...) = Lift(&, F, Gs...)
(|)(F::Combinator, Gs::Combinator...) = Lift(|, F, Gs...)

.+(F::Combinator, Gs...) = Lift(+, F, Gs...)
.-(F::Combinator, Gs...) = Lift(-, F, Gs...)
.*(F::Combinator, Gs...) = Lift(*, F, Gs...)
./(F::Combinator, Gs...) = Lift(/, F, Gs...)
.÷(F::Combinator, Gs...) = Lift(÷, F, Gs...)

# Aggregates.

Count(F::Combinator) =
    Combinator() do q::Query
        q >> CountQuery(ostub(q) >> F)
    end

const ThenCount =
    Combinator() do q::Query
        CountQuery(q) |> setnamespace(q.ns.db)
    end

Exists(F::Combinator) =
    Combinator() do q::Query
        q >> ExistsQuery(ostub(q) >> F)
    end

const ThenExists =
    Combinator() do q::Query
        ExistsQuery(q) |> setnamespace(q.ns.db)
    end

Aggregate(fn, argtype::Type, restype::Type, haszero::Bool, F::Combinator) =
    Combinator() do q::Query
        q >> AggregateQuery(fn, argtype, restype, haszero, ostub(q) >> F)
    end

Aggregate(fn, argtype::Type, restype::Type, F::Combinator) =
    Combinator() do q::Query
        q >> AggregateQuery(fn, argtype, restype, ostub(q) >> F)
    end

Aggregate(fn, argtype::Type, haszero::Bool, F::Combinator) =
    Combinator() do q::Query
        q >> AggregateQuery(fn, argtype, haszero, ostub(q) >> F)
    end

Aggregate(fn, argtype::Type, F::Combinator) =
    Combinator() do q::Query
        q >> AggregateQuery(fn, argtype, ostub(q) >> F)
    end

Aggregate(fn, haszero::Bool, F::Combinator) =
    Combinator() do q::Query
        q >> AggregateQuery(fn, haszero, ostub(q) >> F)
    end

Aggregate(fn, F::Combinator) =
    Combinator() do q::Query
        q >> AggregateQuery(fn, ostub(q) >> F)
    end

Aggregate(fn, argtype::Type, restype::Type, haszero::Bool) =
    F -> Aggregate(fn, argtype, restype, haszero, convert(Combinator, F))

Aggregate(fn, argtype::Type, restype::Type) =
    F -> Aggregate(fn, argtype, restype, convert(Combinator, F))

Aggregate(fn, argtype::Type, haszero::Bool) =
    F -> Aggregate(fn, argtype, haszero, convert(Combinator, F))

Aggregate(fn, argtype::Type) =
    F -> Aggregate(fn, argtype, convert(Combinator, F))

Aggregate(fn, haszero::Bool) =
    F -> Aggregate(fn, haszero, convert(Combinator, F))

Aggregate(fn) =
    F -> Aggregate(fn, convert(Combinator, F))

ThenAggregate(fn, argtype::Type, restype::Type, haszero::Bool) =
    Combinator() do q::Query
        AggregateQuery(fn, argtype, restype, haszero, q) |> setnamespace(q.ns.db)
    end

ThenAggregate(fn, argtype::Type, restype::Type) =
    Combinator() do q::Query
        AggregateQuery(fn, argtype, restype, q) |> setnamespace(q.ns.db)
    end

ThenAggregate(fn, argtype::Type, haszero::Bool) =
    Combinator() do q::Query
        AggregateQuery(fn, argtype, haszero, q) |> setnamespace(q.ns.db)
    end

ThenAggregate(fn, argtype::Type) =
    Combinator() do q::Query
        AggregateQuery(fn, argtype, q) |> setnamespace(q.ns.db)
    end

ThenAggregate(fn, haszero::Bool) =
    Combinator() do q::Query
        AggregateQuery(fn, haszero, q) |> setnamespace(q.ns.db)
    end

ThenAggregate(fn) =
    Combinator() do q::Query
        AggregateQuery(fn, q) |> setnamespace(q.ns.db)
    end

const AnyOf = Aggregate(any)
const AllOf = Aggregate(all)
const MaxOf = Aggregate(maximum, false)
const MinOf = Aggregate(minimum, false)
const SumOf = Aggregate(sum)
const MeanOf = Aggregate(mean)

const ThenAny = ThenAggregate(any)
const ThenAll = ThenAggregate(all)
const ThenMax = ThenAggregate(maximum, false)
const ThenMin = ThenAggregate(minimum, false)
const ThenSum = ThenAggregate(sum)
const ThenMean = ThenAggregate(mean)

# Filtering.

ThenFilter(P::Combinator) =
    Combinator() do q::Query
        FilterQuery(q, ostub(q) >> P) |> setnamespace(q.ns)
    end

# Sorting.

Sort(F::Combinator) =
    Combinator() do q::Query
        (q >> SortQuery(ostub(q) >> F)) |> setnamespace(q.ns)
    end

ThenSort(Fs::Combinator...) =
    Combinator() do q::Query
        it = ostub(q)
        SortQuery(q, (it >> F for F in Fs)...) |> setnamespace(q.ns)
    end

const Asc = ThenDecorate(:rev => false)
const Desc = ThenDecorate(:rev => true)

# Paginating.

ThenTake(N::Combinator) =
    Combinator() do q::Query
        TakeQuery(q, istub(q) >> N) |> setnamespace(q.ns)
    end

ThenSkip(N::Combinator) =
    Combinator() do q::Query
        SkipQuery(q, istub(q) >> N) |> setnamespace(q.ns)
    end

ThenTake(N) = ThenTake(convert(Combinator, N))
ThenSkip(N) = ThenSkip(convert(Combinator, N))

# Output.

ThenSelect(Fs::Combinator...) =
    Combinator() do q::Query
        it = ostub(q)
        compile(StaticBinding{:select}(), oscope(it), q, Query[it >> F for F in Fs])
    end

ThenSelect(Fs...) = ThenSelect((convert(Combinator, F) for F in Fs)...)

ThenSelect(;Fs...) = ThenSelect(Fs...)

# Hierarchical queries.

Connect(F::Combinator) =
    Combinator() do q::Query
        it = ostub(q)
        (q >> ConnectQuery(false, it >> F)) |> setnamespace(q.ns.db)
    end

# Grouping and roll-up.

ThenGroup(Fs::Combinator...) =
    Combinator() do q::Query
        it = ostub(q)
        compile(StaticBinding{:group}(), oscope(it), q, Query[it >> F for F in Fs])
    end

ThenGroup(Fs...) = ThenGroup((convert(Combinator, F) for F in Fs)...)

ThenGroup(;Fs...) = ThenGroup(Fs...)

ThenRollUp(Fs::Combinator...) =
    Combinator() do q::Query
        it = ostub(q)
        compile(StaticBinding{:rollup}(), oscope(it), q, Query[it >> F for F in Fs])
    end

ThenRollUp(Fs...) = ThenRollUp((convert(Combinator, F) for F in Fs)...)

ThenRollUp(;Fs...) = ThenRollUp(Fs...)

Unique(F::Combinator) =
    Combinator() do q::Query
        it = ostub(q)
        (q >> UniqueQuery(it >> F)) |> setnamespace(q.ns.db)
    end

# Parameters.

Parameter(tag::Symbol, oty) =
    Combinator() do q::Query
        (q >> ParameterQuery(tag, oty)) |> setnamespace(q.ns.db)
    end

Given(Fs::Combinator...) =
    Combinator() do q::Query
        it = istub(q)
        GivenQuery(q, (it >> F for F in Fs)...) |> setnamespace(q.ns.db)
    end

Given(Fs...) = Given((convert(Combinator, F) for F in Fs)...)

Given(;Fs...) = Given(Fs...)

# Before and around.

Before(Fs::Combinator...) =
    Combinator() do q::Query
        it = ostub(q)
        (q >> AroundQuery(domain(output(q)), true, true, false, (it >> F for F in Fs)...)) |> setnamespace(q.ns.db)
    end

Around(Fs::Combinator...) =
    Combinator() do q::Query
        it = ostub(q)
        (q >> AroundQuery(domain(output(q)), true, true, true, (it >> F for F in Fs)...)) |> setnamespace(q.ns.db)
    end

const ThenFrame =
    Combinator() do q::Query
        FrameQuery(q) |> setnamespace(q.ns)
    end

