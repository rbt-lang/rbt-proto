
# For dispatching on the function name.
immutable Fn{name}
end

fnname(::Type{Fn}) = nothing
fnname{name}(::Type{Fn{name}}) = name

# Type constructor shortcut.
Fn(names...) =
    isempty(names) ? Union{} :
    length(names) == 1 ? Type{Fn{names[1]}} :
    Union{[Type{Fn{name}} for name in names]...}


reqcomposable(base::Scope, gs...) =
    for g in gs
        domain(base) <: idomain(g) || error("expected an expression defined on type $(domain(base)): $g")
    end

reqcomposable(f, gs...) =
    for g in gs
        odomain(f) <: idomain(g) || error("expected composable expressions: $f and $g")
    end

reqsingular(fs...) =
    for f in fs
        issingular(f) || error("expected a singular expression: $f")
    end

reqplural(fs...) =
    for f in fs
        !issingular(f) || error("expected a plural expression: $f")
    end

reqnonempty(fs...) =
    for f in fs
        isnonempty(f) || error("expected a complete expression: $f")
    end

reqpartial(fs...) =
    for f in fs
        !isnonempty(f) || error("expected a partial expression: $f")
    end

reqmonic(fs...) =
    for f in fs
        ismonic(f) || error("expected an exclusive expression: $f")
    end

reqodomain(dom, fs...) =
    for f in fs
        odomain(f) <: dom || error("expected an expression of type $dom: $f")
    end

reqidentity(fs...) =
    for f in fs
        !isnull(lookup(f, :__id)) || error("expected an expression with identity: $f")
    end

reqfields(fs...) =
    for f in fs
        !isnull(f.scope.items) && !isempty(get(f.scope.items)) || error("expected a composite expression: $f")
    end

reqtag(fs...) =
    for f in fs
        !isnull(f.scope.tag) || error("expected a tagged expression: $f")
    end


function >>(f::Query, g::Query)
    reqcomposable(f, g)
    pipe = f.pipe >> g.pipe
    syntax =
        !isnull(f.syntax) && !isnull(g.syntax) ?
            Nullable{AbstractSyntax}(ComposeSyntax(get(f.syntax), get(g.syntax))) :
        !isnull(f.syntax) ? f.syntax :
        !isnull(g.syntax) ? g.syntax :
        Nullable{AbstractSyntax}()
    return Query(g, pipe=pipe, syntax=syntax)
end


select(q::Query) =
    let out = lookup(q, (:__out, 0)),
        tag = q.scope.tag
        q = !isnull(out) ? q >> compile(get(out), q.scope, AbstractSyntax[]) : q
        if !isnull(tag)
            q = Query(q, scope=settag(q.scope, get(tag)))
        end
        q
    end


identify(q::Query) =
    let id = lookup(q, (:__id, 0))
        !isnull(id) ? q >> compile(get(id), q.scope, AbstractSyntax[]) : q
    end


record(base::Query, ops::Query...) =
    record(scope(base), ops...)

function record(base::Scope, ops::Query...)
    reqcomposable(base, ops...)
    pipe = TuplePipe([op.pipe for op in ops])
    scope = nest(base, odomain(pipe))
    fields = Query[]
    items = AbstractBinding[]
    hasid = false
    hasout = false
    for (k, op) in enumerate(ops)
        field = Query(op, pipe=ItemPipe(pipe, k))
        push!(fields, field)
        binding = SimpleBinding(field)
        push!(items, binding)
        if !isnull(field.scope.tag)
            scope = addlocal(scope, (get(field.scope.tag), 0), binding)
        end
        hasid = hasid || !isnull(lookup(op, :__id))
        hasout = hasout || !isnull(lookup(op, :__out))
    end
    scope = setitems(scope, tuple(items...))
    if hasid
        scope = addlocal(scope, (:__id, 0), record(scope, [identify(field) for field in fields]...))
    end
    if hasout
        scope = addlocal(scope, (:__out, 0), record(scope, [select(field) for field in fields]...))
    end
    return Query(scope, pipe)
end


compile(base::Query, syntax::AbstractSyntax) =
    compile(scope(base), syntax)


function compile(base::Scope, syntax::LiteralSyntax)
    T = domain(base)
    pipe = isa(syntax.val, Void) ? NullPipe(T) : ConstPipe(T, syntax.val)
    scope = nest(base, odomain(pipe))
    return Query(scope, pipe, syntax=syntax)
end


function compile(base::Scope, syntax::ApplySyntax)
    binding = lookup(base, (syntax.fn, length(syntax.args)))
    !isnull(binding) ?
        Query(compile(get(binding), base, syntax.args), syntax=syntax) :
        error("undefined combinator $(syntax.fn)")
end


function compile(base::Scope, syntax::ComposeSyntax)
    f = compile(base, syntax.f)
    g = compile(f, syntax.g)
    return Query(f >> g, syntax=syntax)
end


compile{name}(fn::Type{Fn{name}}, base::Scope, arg1::AbstractSyntax, args::AbstractSyntax...) =
    compile(fn, base, compile(base, arg1), [compile(base, arg) for arg in args]...)


function compile(::Fn(:here), base::Scope)
    T = domain(base)
    pipe = HerePipe(T)
    return Query(base, pipe)
end


function compile(::Fn(:unlink), base::Scope, arg::AbstractSyntax)
    scope = nest(base, Unit)
    I = domain(base)
    pipe = UnitPipe(I)
    root_base = Query(scope, pipe)
    return root_base >> compile(root_base, arg)
end


compile(::Fn(:link), base::Scope, pred::AbstractSyntax, arg::AbstractSyntax) =
    let unlink = compile(Fn{:unlink}, base, arg),
        mix = compile(Fn{:mix}, base, compile(Fn{:here}, base), unlink),
        condition = compile(mix, pred),
        filter = compile(Fn{:filter}, base, mix, condition),
        right = compile(Fn{:right}, mix.scope)
        filter >> right
    end


function compile(fn::Fn(:before, :and_before, :after, :and_after, :around, :and_around), base::Scope, ops::Query...)
    reqcomposable(base, ops...); reqsingular(ops...); reqnonempty(ops...)
    T = domain(base)
    before = fn in (Fn{:before}, Fn{:and_before}, Fn{:around}, Fn{:and_around})
    self = fn in (Fn{:and_before}, Fn{:and_after}, Fn{:and_around})
    after = fn in (Fn{:after}, Fn{:and_after}, Fn{:around}, Fn{:and_around})
    pipe =
        isempty(ops) ? RelativePipe(T, before, self, after) :
        length(ops) == 1 ? RelativeByPipe(identify(ops[1]).pipe, before, self, after) :
            RelativeByPipe(identify(record(base, ops...)).pipe, before, self, after)
    return Query(base, pipe)
end


compile(::Fn(:record), base::Scope, ops::Query...) = record(base, ops...)


compile(fn::Fn(:select), base::Scope, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(::Fn(:select), base::Scope, flow::Query, ops::Query...)
    reqcomposable(base, flow)
    reqcomposable(flow, ops...)
    left = record(flow, ops...)
    right = Query(flow, pipe=HerePipe(odomain(flow)))
    pipe = TuplePipe(left.pipe, right.pipe)
    scope = nest(base, odomain(pipe))
    left_field = ItemPipe(pipe, 1)
    right_field = ItemPipe(pipe, 2)
    items = AbstractBinding[]
    defs = Dict{Symbol,Query}()
    for (k, op) in enumerate(ops)
        field = Query(op, pipe=left_field >> ItemPipe(left.pipe, k))
        push!(items, SimpleBinding(field))
        if !isnull(op.scope.tag)
            scope = addlocal(scope, get(op.scope.tag), field)
        end
    end
    if !isnull(flow.scope.tag)
        scope = addlocal(scope, get(flow.scope.tag), Query(flow, pipe=right_field))
    end
    maybe_id = lookup(flow, :__id)
    if !isnull(maybe_id)
        identity = compile(get(maybe_id), flow.scope)
        identity = Query(identity, pipe=right_field >> identity.pipe)
    else
        identity = Query(flow, pipe=right_field)
    end
    scope = addlocal(scope, :__id, identity)
    maybe_out = lookup(left, :__out)
    if !isnull(maybe_out)
        selector = compile(get(maybe_out), left.scope)
        selector = Query(selector, pipe=left_field >> selector.pipe)
    else
        selector = Query(left, pipe=left_field)
    end
    scope = addlocal(scope, :__out, selector)
    return flow >> Query(scope, pipe)
end


compile(fn::Fn(:filter), base::Scope, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Fn(:filter), base::Scope, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqodomain(Bool, op)
    O = odomain(flow)
    pipe = FilterPipe(flow.pipe, op.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:reverse), base::Scope, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    pipe = ReversePipe(flow.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:array), base::Scope, op1::Query, ops::Query...)
    reqcomposable(base, op1, ops...); reqsingular(op1, ops...); reqnonempty(op1, ops...)
    reqodomain(odomain(op1), ops...)
    scope = op1.scope
    pipe = VectorPipe([op.pipe for op in [op1, ops...]]...)
    return Query(scope, pipe)
end


function compile(::Fn(:range), base::Scope, start::Query, step::Query, stop::Query)
    reqcomposable(base, start, step, stop); reqsingular(start, step, stop); reqodomain(Int, start, step, stop)
    scope = nest(base, Int)
    if isnonempty(start) && isnonempty(step) && isnonempty(stop)
        pipe = RangePipe(start.pipe, step.pipe, stop.pipe)
    else
        pipe =
            (start.pipe * (step.pipe * stop.pipe)) >>
            RangePipe(
                ItemPipe(Tuple{Int,Tuple{Int,Int}}, 1),
                ItemPipe(Tuple{Int,Tuple{Int,Int}}, 2) >> ItemPipe(Tuple{Int,Int}, 1),
                ItemPipe(Tuple{Int,Tuple{Int,Int}}, 2) >> ItemPipe(Tuple{Int,Int}, 2))
    end
    return Query(scope, pipe)
end


function compile(fn::Fn(:first, :last), base::Scope, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    rev = flow.scope.rev
    rev = fn == Fn{:first} ? rev : !rev
    pipe = FirstPipe(flow.pipe, rev)
    return Query(flow, pipe=pipe)
end


compile(fn::Fn(:first, :last), base::Scope, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(fn::Fn(:first, :last), base::Scope, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqnonempty(op)
    rev = op.scope.rev
    rev = fn == Fn{:first} ? rev : !rev
    op = identify(op)
    pipe = FirstByPipe(flow.pipe, op.pipe, rev)
    return Query(flow, pipe=pipe)
end


function compile(fn::Fn(:take, :skip), base::Scope, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqnonempty(size); reqodomain(Int, size)
    pipe = TakePipe(flow.pipe, size.pipe, fn == Fn{:take} ? false : true)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:get), base::Scope, flow::Query, idx::Query)
    reqcomposable(base, flow); reqplural(flow); reqmonic(flow); reqidentity(flow)
    reqcomposable(base, idx); reqsingular(idx); reqnonempty(idx)
    maybe_id = lookup(flow, :__id)
    identity = compile(get(maybe_id), flow.scope)
    reqodomain(odomain(identity), idx)
    pipe = GetPipe(flow.pipe, identity.pipe, idx.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:asc), base::Scope, op::Query)
    return Query(op, scope=setrev(op.scope, false))
end


function compile(::Fn(:desc), base::Scope, op::Query)
    return Query(op, scope=setrev(op.scope, true))
end


compile(fn::Fn(:sort), base::Scope, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(fn::Fn(:sort), base::Scope, flow::Query, ops::Query...)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, ops...); reqsingular(ops...); reqnonempty(ops...)
    if isempty(ops)
        maybe_id = lookup(flow, :__id)
        if !isnull(maybe_id)
            identity = Query(compile(get(maybe_id), flow.scope))
            identity = Query(identity, scope=setrev(identity.scope, flow.scope.rev))
            return compile(fn, base, flow, identity)
        end
        pipe = SortPipe(flow.pipe, flow.scope.rev)
    else
        pipe = SortByPipe(
            flow.pipe,
            [(identify(op).pipe, op.scope.rev) for op in ops]...)
    end
    return Query(flow, pipe=pipe)
end


function compile(fn::Fn(:connect, :and_connect), base::Scope, op::Query)
    reqcomposable(base, op); reqpartial(op); reqodomain(idomain(op), op)
    pipe = ConnectPipe(op.pipe, fn == Fn{:and_connect})
    return Query(op, pipe=pipe)
end


function compile(::Fn(:depth), base::Scope, op::Query)
    reqcomposable(base, op); reqpartial(op); reqodomain(idomain(op), op)
    scope = nest(base, Int)
    pipe = DepthPipe(op.pipe)
    return Query(scope, pipe)
end


compile(fn::Fn(:sort_connect), base::Scope, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Fn(:sort_connect), base::Scope, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqpartial(op); reqodomain(idomain(op), op)
    maybe_id = lookup(op, :__id)
    if isnull(maybe_id)
        pipe = SortConnectPipe(flow.pipe, op.pipe)
    else
        identity = compile(get(maybe_id), op.scope)
        pipe = SortConnectPipe(flow.pipe, identity.pipe, op.pipe)
    end
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:unique), base::Scope, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    maybe_id = lookup(flow, :__id)
    if !isnull(maybe_id)
        identity = compile(get(maybe_id), flow.scope)
        PipeType = ismonic(flow) ? SortByPipe : UniquePipe
        pipe = PipeType(flow.pipe, identity.pipe, flow.scope.rev)
    else
        PipeType = ismonic(flow) ? SortPipe : UniquePipe
        pipe = PipeType(flow.pipe, flow.scope.rev)
    end
    return Query(flow, pipe=pipe)
end


compile(fn::Fn(:group, :group_cube),
        base::Scope, flow::AbstractSyntax, op1::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op1), [compile(flow, op) for op in ops]...)
    end

function compile(
        fn::Fn(:group, :group_cube, :partition, :partition_cube),
        base::Scope, flow::Query, ops::Query...)
    iscube = (fn == Fn{:group_cube} || fn == Fn{:partition_cube})
    ispartition = (fn == Fn{:partition} || fn == Fn{:partition_cube})
    reqcomposable(base, flow); reqplural(flow)
    if !ispartition
        reqcomposable(flow, ops...); reqsingular(ops...); reqnonempty(ops...)
    else
        reqcomposable(base, ops...); reqplural(ops...); reqtag(ops...)
    end
    if !ispartition
        groups = []
        for op in ops
            maybe_id = lookup(op, :__id)
            if isnull(maybe_id)
                push!(groups, (op.pipe, op.scope.rev))
            else
                identity = compile(get(maybe_id), op.scope)
                push!(groups, (op.pipe, identity.pipe, op.scope.rev))
            end
        end
    else
        groups = []
        for op in ops
            img = lookup(flow, get(op.scope.tag))
            !isnull(img) || error("undefined attribute $(get(op.tag)): $flow")
            img = compile(get(img), base)
            reqsingular(img); reqnonempty(img); reqodomain(odomain(op), img)
            maybe_id = lookup(op, :__id)
            if isnull(maybe_id)
                push!(groups, (op.pipe, img.pipe, op.scope.rev))
            else
                identity = compile(get(maybe_id), op.scope)
                push!(groups, (op.pipe, img.pipe, identity.pipe, op.scope.rev))
            end
        end
    end
    pipe = (!ispartition ? GroupPipe : PartitionPipe)(flow.pipe, iscube, groups...)
    scope = nest(base, odomain(pipe))
    fields = Query[]
    items = AbstractBinding[]
    kernel_pipe = ItemPipe(pipe, 1)
    for (k, op) in enumerate(ops)
        item_pipe = ItemPipe(pipe, 1, k)
        field = Query(op, pipe=item_pipe)
        push!(fields, field)
        item = SimpleBinding(field)
        push!(items, item)
        if !isnull(field.scope.tag)
            scope = addlocal(scope, get(field.scope.tag), item)
        end
    end
    kernel_field = record(scope, fields...)
    scope = addlocal(scope, :__id, identify(kernel_field))
    flow_field = Query(flow, pipe=ItemPipe(pipe, 2))
    push!(fields, flow_field)
    flow_item = SimpleBinding(flow_field)
    push!(items, flow_item)
    if !isnull(flow_field.scope.tag)
        scope = addlocal(scope, get(flow_field.scope.tag), flow_item)
    end
    scope = setitems(scope, tuple(items...))
    scope = addlocal(scope, :__out, select(record(scope, fields...)))
    return Query(scope, pipe)
end


function compile(::Fn(:mix), base::Scope, ops::Query...)
    reqcomposable(base, ops...); reqtag(ops...)
    if isempty(ops)
        scope = next(base, Tuple{})
        I = odomain(base)
        pipe = ConstPipe(I, ())
        return Query(scope, pipe)
    else
        pipe = MixPipe([op.pipe for op in ops])
        T = odomain(pipe)
        scope = nest(base, T)
        fields = Query[]
        items = AbstractBinding[]
        for (k, op) in enumerate(ops)
            field = Query(op, pipe=ItemPipe(T, k))
            push!(fields, field)
            item = SimpleBinding(field)
            push!(items, item)
            scope = addlocal(scope, get(op.scope.tag), item)
        end
        scope = setitems(scope, tuple(items...))
        identity = record(scope, [identify(field) for field in fields]...)
        selector = record(scope, [select(field) for field in fields]...)
        scope = addlocal(scope, :__id, identity)
        scope = addlocal(scope, :__out, selector)
        return Query(scope, pipe)
    end
end


function compile(fn::Fn(:left, :right), base::Scope)
    reqfields(Query(base, HerePipe(base.domain)))
    return (get(base.items)[fn == Fn{:left} ? 1 : end])(base)
end


function compile(::Fn(:pack), base::Scope, ops::Query...)
    reqcomposable(base, ops...); reqtag(ops...)
    I = domain(base)
    Fs = Vector{Pair{Symbol,AbstractPipe}}()
    isisnonempty = false
    identitymap = Dict{Symbol,AbstractPipe}()
    selectormap = Dict{Symbol,AbstractPipe}()
    for op in ops
        T = odomain(op)
        tag = get(op.scope.tag)
        push!(Fs, Pair{Symbol,AbstractPipe}(tag, op.pipe))
        if isnonempty(op)
            isisnonempty = true
        end
        maybe_id = lookup(op, :__id)
        identitymap[tag] =
            !isnull(maybe_id) ? compile(get(maybe_id), op.scope).pipe : HerePipe(T)
        maybe_out = lookup(op, :__out)
        selectormap[tag] =
            !isnull(maybe_out) ? compile(get(maybe_out), op.scope).pipe : HerePipe(T)
    end
    pipe = PackPipe(Fs...)
    scope = nest(base, odomain(pipe))
    U = odomain(pipe).parameters[2]
    identity = Query(scope, CasePipe(U, true, identitymap...))
    selector = Query(scope, CasePipe(U, true, selectormap...))
    scope = addlocal(scope, :__id, identity)
    scope = addlocal(scope, :__out, selector)
    for op in ops
        tag = get(op.scope.tag)
        T = odomain(op)
        scope = addlocal(scope, tag, Query(op, pipe=CasePipe(U, false, tag => HerePipe(T))))
    end
    return Query(scope, pipe)
end


function compile(::Fn(:as), base::Scope, op::AbstractSyntax, ident::AbstractSyntax)
    (isa(ident, ApplySyntax) && isempty(ident.args)) || error("expected an identifier: $ident")
    q = compile(base, op)
    scope = settag(q.scope, ident.fn)
    return Query(q, scope=scope)
end


compile(::Fn(:(=>)), base::Scope, ident::AbstractSyntax, op::AbstractSyntax) =
    compile(Fn{:as}, base, op, ident)


compile(fn::Fn(:define), base::Scope, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        for op in ops
            flow = compile(fn, base, flow, compile(flow, op))
        end
        flow
    end


function compile(::Fn(:define), base::Scope, flow::Query, op::Query)
    reqcomposable(base, flow)
    reqcomposable(flow, op); reqtag(op)
    return Query(flow, scope=addlocal(flow.scope, get(op.scope.tag), op))
end


function compile(::Fn(:!), base::Scope, op::Query)
    reqcomposable(base, op); reqsingular(op); reqodomain(Bool, op)
    scope = nest(base, Bool)
    pipe = ~op.pipe
    return Query(scope, pipe)
end


function compile(fn::Fn(:&, :|), base::Scope, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqsingular(op1, op2); reqodomain(Bool, op1, op2)
    scope = nest(base, Bool)
    if fn == Fn{:&}
        pipe = op1.pipe & op2.pipe
    else
        pipe = op1.pipe | op2.pipe
    end
    return Query(scope, pipe)
end


function compile(fn::Fn(:(==), :(!=)), base::Scope, op1::Query, op2::Query)
    reqcomposable(base, op1, op2);
    typejoin(odomain(op1), odomain(op2)) != Any || reqodomain(odomain(op1), op2)
    ismonic(op1) || reqsingular(op2)
    T = odomain(op1)
    TT = Tuple{T,T}
    scope = nest(base, Bool)
    output = Output(Bool, max(omode(op1), omode(op2)))
    pipe = fn == Fn{:(==)} ? op1.pipe .== op2.pipe : op1.pipe .!= op2.pipe
    return Query(scope, pipe)
end


function compile(fn::Fn(:in), base::Scope, op1::Query, op2::Query)
    reqcomposable(base, op1, op2);
    typejoin(odomain(op1), odomain(op2)) != Any || reqodomain(odomain(op1), op2)
    reqsingular(op1); reqnonempty(op1); reqplural(op2)
    scope = nest(base, Bool)
    pipe = InPipe(op1.pipe, op2.pipe)
    return Query(scope, pipe)
end


const SCALAR_OPS = (
    :(+), :(-), :(*), :(/),
    :(<), :(<=), :(>), :(>=),
    :startswith, :endswith, :contains, :substr,
    :date,
    :day, :_day, :days, :_days,
    :month, :_month, :months, :_months,
    :year, :_year, :years, :_years,
    :_usd)

const AGGREGATE_OPS = (
    :sum, :max, :min, :mean,
    :count, :exists,
    :all, :any)


function compile(fn::Fn(SCALAR_OPS...), base::Scope, ops::Query...)
    reqcomposable(base, ops...)
    for j = eachindex(ops)
        issingular(ops[j]) || reqsingular(ops[1:j-1]...)
    end
    Ts = Type[odomain(op) for op in ops]
    method_exists(polydomain, Tuple{Type{fn}, [Type{T} for T in Ts]...}) ||
        error("expected compatible operands for operator $(fnname(fn)): $(join(ops, ", "))")
    method = polymethod(fn, Ts...)
    domain = polydomain(fn, Ts...)
    scope = nest(base, domain)
    pipe = OpPipe(method, Ts, domain, [op.pipe for op in ops])
    return Query(scope, pipe)
end


function compile(fn::Fn(AGGREGATE_OPS...), base::Scope, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    T = odomain(flow)
    method = polymethod(fn, T)
    domain = polydomain(fn, T)
    haszero = polyhaszero(fn, T)
    scope = nest(base, domain)
    pipe = AggregateOpPipe(method, T, domain, haszero, flow.pipe)
    scope = nest(base, odomain(pipe))
    return Query(scope, pipe)
end

polymethod{name}(::Type{Fn{name}}, ::Type...) = eval(name)
polyhaszero{name}(::Type{Fn{name}}, ::Type) = true

polydomain(::Fn(:(+), :(-)), ::Type{Int}) = Int
polydomain(::Fn(:(+), :(-)), ::Type{Int}, ::Type{Int}) = Int
polydomain(::Fn(:(+), :(-)), ::Type{Int}, ::Type{Float64}) = Float64
polydomain(::Fn(:(+), :(-)), ::Type{Float64}, ::Type{Int}) = Float64
polydomain(::Fn(:(+), :(-)), ::Type{Float64}, ::Type{Float64}) = Float64
polydomain{M<:Monetary}(::Fn(:(+), :(-)), ::Type{M}, ::Type{M}) = M
polydomain(::Fn(:(*)), ::Type{Int}, ::Type{Int}) = Int
polymethod(::Fn(:(/)), ::Type{Int}, ::Type{Int}) = div
polydomain(::Fn(:(/)), ::Type{Int}, ::Type{Int}) = Int
polydomain(::Fn(:(*), :(/)), ::Type{Int}, ::Type{Float64}) = Float64
polydomain(::Fn(:(*), :(/)), ::Type{Float64}, ::Type{Int}) = Float64
polydomain(::Fn(:(*), :(/)), ::Type{Float64}, ::Type{Float64}) = Float64
polydomain{T<:Number,M<:Monetary}(::Fn(:(*)), ::Type{T}, ::Type{M}) = M
polydomain{T<:Number,M<:Monetary}(::Fn(:(*)), ::Type{M}, ::Type{T}) = M
polydomain{T<:Number,M<:Monetary}(::Fn(:(*)), ::Type{M}, ::Type{T}, ::Type{T}) = M
polydomain{M<:Monetary}(::Fn(:(/)), ::Type{M}, ::Type{M}) = Float64
polydomain{T<:Number,M<:Monetary}(::Fn(:(/)), ::Type{M}, ::Type{T}) = M
polydomain{T1<:Number,T2<:Number}(::Fn(:(<), :(<=), :(>), :(>=)), ::Type{T1}, ::Type{T2}) = Bool
polydomain{M<:Monetary}(::Fn(:(<), :(<=), :(>), :(>=)), ::Type{M}, ::Type{M}) = Bool

_regex_contains(s, r) = ismatch(r, s)
_substr(s, i, j) = s[i:j]
polydomain{S1<:AbstractString,S2<:AbstractString}(
    ::Fn(:startswith, :endswith, :contains), ::Type{S1}, ::Type{S2}) = Bool
polymethod{S<:AbstractString}(::Fn(:contains), ::Type{S}, ::Type{Regex}) = _regex_contains
polydomain{S<:AbstractString}(::Fn(:contains), ::Type{S}, ::Type{Regex}) = Bool
polymethod{S<:AbstractString}(::Fn(:substr), ::Type{S}, ::Type{Int}, ::Type{Int}) = _substr
polydomain{S<:AbstractString}(::Fn(:substr), ::Type{S}, ::Type{Int}, ::Type{Int}) = S

_dates_date(s) = Date(s)
_dates_day() = Dates.Day(1)
_dates_month() = Dates.Month(1)
_dates_year() = Dates.Year(1)
polymethod(::Fn(:year), ::Type{Date}) = Dates.year
polymethod(::Fn(:month), ::Type{Date}) = Dates.month
polymethod(::Fn(:day), ::Type{Date}) = Dates.day
polydomain(::Fn(:year, :month, :day), ::Type{Date}) = Int
polymethod{S<:AbstractString}(::Fn(:date), ::Type{S}) = _dates_date
polydomain{S<:AbstractString}(::Fn(:date), ::Type{S}) = Date
polymethod(::Fn(:day, :_day, :days, :_days)) = _dates_day
polymethod(::Fn(:month, :_month, :months, :_months)) = _dates_month
polymethod(::Fn(:year, :_year, :years, :_years)) = _dates_year
polydomain(::Fn(:day, :_day, :days, :_days)) = Dates.Day
polydomain(::Fn(:month, :_month, :months, :_months)) = Dates.Month
polydomain(::Fn(:year, :_year, :years, :_years)) = Dates.Year
polydomain{P<:Dates.Period}(::Fn(:(+), :(-)), ::Type{P}) = Dates.Period
polydomain{P1<:Dates.Period,P2<:Dates.Period}(::Fn(:(+), :(-)), ::Type{P1}, ::Type{P2}) = Dates.Period
polydomain{P<:Dates.Period}(::Fn(:(+), :(-)), ::Type{Date}, ::Type{P}) = Date
polydomain{P<:Dates.Period}(::Fn(:(*)), ::Type{Int}, ::Type{P}) = Dates.Period
polydomain(::Fn(:(<), :(<=), :(>), :(>=)), ::Type{Date}, ::Type{Date}) = Bool

_usd() = Monetary{:USD}(1, 0)
polymethod(::Fn(:_usd)) = _usd
polydomain(::Fn(:_usd)) = Monetary{:USD}
polydomain{T<:Number}(::Fn(:sum), ::Type{T}) = T
polydomain{M<:Monetary}(::Fn(:sum), ::Type{M}) = M
polymethod(::Fn(:max), ::Type) = maximum
polymethod(::Fn(:min), ::Type) = minimum
polydomain{T}(::Fn(:max, :min), ::Type{T}) = T
polyhaszero(::Fn(:max, :min, :mean), ::Type) = false
polydomain(::Fn(:mean), ::Type{Int}) = Float64
polydomain(::Fn(:mean), ::Type{Float64}) = Float64
polydomain{M<:Monetary}(::Fn(:mean), ::Type{M}) = M

_exists(a) = !isempty(a)
polydomain(::Fn(:all, :any), ::Type{Bool}) = Bool
polymethod(::Fn(:exists), ::Type) = _exists
polydomain(::Fn(:exists), ::Type) = Bool
polymethod(::Fn(:count), ::Type) = length
polydomain(::Fn(:count), ::Type) = Int


compile(fn::Fn(:json), base::Scope, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow),
        ops = [compile(flow, op) for op in ops]
        isempty(ops) ? compile(fn, base, flow) : compile(fn, base, compile(Fn{:select}, base, flow, ops...))
    end


function compile(fn::Fn(:json), base::Scope, flow::Query)
    flow = select(flow)
    if !isnull(flow.scope.items)
        parts = ()
        fields = ()
        for item in get(flow.scope.items)
            field = compile(fn, flow.scope, item(flow.scope))
            if !isnull(field.scope.tag)
                fields = (fields..., Pair{Symbol,AbstractPipe}(get(field.scope.tag), field.pipe))
            end
        end
        scope = nest(base, Dict{Any,Any})
        if !isnull(flow.scope.tag)
            scope = settag(scope, get(flow.scope.tag))
        end
        pipe = flow.pipe >> DictPipe(fields...)
        if ispartial(flow)
            pipe = NullToVoidPipe(pipe)
        end
        flow = Query(scope, pipe)
    else
        if ispartial(flow)
            pipe = NullToVoidPipe(flow.pipe)
            flow = Query(flow, pipe=pipe)
        end
    end
    return flow
end


function compile(::Fn(:frame), base::Scope, flow::Query)
    return Query(flow, pipe=BindRelPipe(flow.pipe))
end


function compile(::Fn(:given), base::Scope, flow::AbstractSyntax, ops::AbstractSyntax...)
    scope = base
    qs = Query[]
    tags = Symbol[]
    for op in ops
        q = compile(scope, op)
        reqtag(q)
        push!(qs, q)
        tag = gensym(get(q.scope.tag))
        push!(tags, tag)
        binding = ParamBinding(tag, output(q))
        scope = addglobal(scope, get(q.scope.tag), binding)
    end
    query = compile(scope, flow)
    pipe = query.pipe
    reverse!(qs)
    reverse!(tags)
    for (q, tag) in zip(qs, tags)
        pipe = BindEnvPipe(pipe, tag, q.pipe)
    end
    # FIXME: remove parameters from the query scope.
    return Query(query, pipe=pipe)
end

