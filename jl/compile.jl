
# For dispatching on the function name.
immutable Fn{name}
end

# Type constructor shortcut.
Fn(names...) =
    isempty(names) ? Union{} :
    length(names) == 1 ? Type{Fn{names[1]}} :
    Union{[Type{Fn{name}} for name in names]...}


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
        !isnull(f.identity) || error("expected an expression with identity: $f")
    end

reqfields(fs...) =
    for f in fs
        !isnull(f.fields) && !isempty(get(f.fields)) || error("expected a composite expression: $f")
    end

reqtag(fs...) =
    for f in fs
        !isnull(f.tag) || error("expected a tagged expression: $f")
    end


function >>(f::Query, g::Query)
    reqcomposable(f, g)
    pipe = f.pipe >> g.pipe
    syntax =
        !isnull(f.syntax) && !isnull(g.syntax) ?
            NullableSyntax(ComposeSyntax(get(f.syntax), get(g.syntax))) :
        !isnull(f.syntax) ? f.syntax :
        !isnull(g.syntax) ? g.syntax :
        NullableSyntax()
    return Query(g, pipe=pipe, syntax=syntax)
end


select(q::Query) =
    !isnull(q.selector) ? Query(q >> get(q.selector), order=q.order, tag=q.tag) : q


identify(q::Query) =
    !isnull(q.identity) ? Query(q >> get(q.identity), order=q.order, tag=q.tag) : q


function record(base::Query, ops::Query...)
    reqcomposable(base, ops...)
    scope = empty(base)
    pipe = TuplePipe([op.pipe for op in ops])
    fields = Query[]
    defs = Dict{Symbol,Query}()
    for (k, op) in enumerate(ops)
        field = Query(op, pipe=ItemPipe(pipe, k))
        push!(fields, field)
        if !isnull(field.tag)
            defs[get(field.tag)] = field
        end
    end
    query = Query(scope, pipe=pipe, fields=(fields...), defs=defs)
    if any([!isnull(field.identity) for field in fields])
        identity = record(query, [identify(field) for field in fields]...)
        query = Query(query, identity=identity)
    end
    if any([!isnull(field.selector) for field in fields])
        selector = record(query, [select(field) for field in fields]...)
        query = Query(query, selector=selector)
    end
    return query
end


function compile(base::Query, syntax::LiteralSyntax)
    scope = empty(base)
    T = odomain(base)
    pipe = isa(syntax.val, Void) ? NullPipe(T) : ConstPipe(T, syntax.val)
    return Query(scope, pipe=pipe, syntax=syntax)
end


function compile(base::Query, syntax::ApplySyntax)
    if isempty(syntax.args)
        query = lookup(base, syntax.fn)
        if !isnull(query)
            return Query(get(query), syntax=syntax)
        end
    end
    return Query(compile(Fn{syntax.fn}, base, syntax.args...), syntax=syntax)
end


function compile(base::Query, syntax::ComposeSyntax)
    f = compile(base, syntax.f)
    g = compile(f, syntax.g)
    return Query(f >> g, syntax=syntax)
end


compile{name}(fn::Type{Fn{name}}, base::Query, arg1::AbstractSyntax, args::AbstractSyntax...) =
    compile(fn, base, compile(base, arg1), [compile(base, arg) for arg in args]...)


function compile(::Fn(:here), base::Query)
    T = odomain(base)
    pipe = HerePipe(T)
    return Query(base, pipe=pipe)
end


function compile(::Fn(:unlink), base::Query, arg::AbstractSyntax)
    scope = root(base)
    I = odomain(base)
    pipe = UnitPipe(I)
    root_base = Query(scope, pipe=pipe)
    return root_base >> compile(root_base, arg)
end


compile(::Fn(:link), base::Query, pred::AbstractSyntax, arg::AbstractSyntax) =
    let unlink = compile(Fn{:unlink}, base, arg),
        mix = compile(Fn{:mix}, base, compile(Fn{:here}, base), unlink),
        condition = compile(mix, pred),
        filter = compile(Fn{:filter}, base, mix, condition),
        right = compile(Fn{:right}, mix)
        filter >> right
    end


function compile(fn::Fn(:before, :and_before, :after, :and_after, :around, :and_around), base::Query, ops::Query...)
    reqcomposable(base, ops...); reqsingular(ops...); reqnonempty(ops...)
    T = odomain(base)
    before = fn in (Fn{:before}, Fn{:and_before}, Fn{:around}, Fn{:and_around})
    self = fn in (Fn{:and_before}, Fn{:and_after}, Fn{:and_around})
    after = fn in (Fn{:after}, Fn{:and_after}, Fn{:around}, Fn{:and_around})
    pipe =
        isempty(ops) ? RelativePipe(T, before, self, after) :
        length(ops) == 1 ? RelativeByPipe(identify(ops[1]).pipe, before, self, after) :
            RelativeByPipe(identify(record(base, ops...)).pipe, before, self, after)
    return Query(base, pipe=pipe)
end


function compile(::Fn(:count), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    scope = empty(base)
    pipe = CountPipe(flow.pipe)
    return Query(scope, pipe=pipe)
end


function compile(fn::Fn(:sum, :max, :min, :sum, :mean), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow); reqodomain(Int, flow)
    scope = empty(base)
    pipe = (
        fn == Fn{:sum} ? IntSumPipe :
        fn == Fn{:max} ? IntMaxPipe :
        fn == Fn{:min} ? IntMinPipe :
        fn == Fn{:sum} ? IntSumPipe :
        IntMeanPipe)(flow.pipe)
    return Query(scope, pipe=pipe)
end


compile(::Fn(:record), base::Query, ops::Query...) = record(base, ops...)


compile(fn::Fn(:select), base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(::Fn(:select), base::Query, flow::Query, ops::Query...)
    reqcomposable(base, flow)
    reqcomposable(flow, ops...)
    left = record(flow, ops...)
    right = Query(flow, pipe=HerePipe(odomain(flow)))
    scope = empty(base)
    pipe = TuplePipe(left.pipe, right.pipe)
    left_field = ItemPipe(pipe, 1)
    right_field = ItemPipe(pipe, 2)
    defs = Dict{Symbol,Query}()
    for (k, op) in enumerate(ops)
        if !isnull(op.tag)
            field = Query(op, pipe=left_field >> ItemPipe(left.pipe, k))
            defs[get(op.tag)] = field
        end
    end
    if !isnull(flow.tag)
        defs[get(flow.tag)] = Query(flow, pipe=right_field)
    end
    if !isnull(flow.identity)
        identity = get(flow.identity)
        identity = Query(identity, pipe=right_field >> identity.pipe)
    else
        identity = Query(flow, pipe=right_field)
    end
    if !isnull(left.selector)
        selector = get(left.selector)
        selector = Query(selector, pipe=left_field >> selector.pipe)
    else
        selector = Query(left, pipe=left_field)
    end
    return flow >> Query(scope, pipe=pipe, defs=defs, identity=identity, selector=selector)
end


compile(fn::Fn(:filter), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Fn(:filter), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqodomain(Bool, op)
    O = odomain(flow)
    pipe = FilterPipe(flow.pipe, op.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:reverse), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    pipe = ReversePipe(flow.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:array), base::Query, op1::Query, ops::Query...)
    reqcomposable(base, op1, ops...); reqsingular(op1, ops...); reqnonempty(op1, ops...)
    reqodomain(odomain(op1), ops...)
    scope = op1.scope
    I = idomain(op1)
    O = odomain(op1)
    pipe = VectorPipe([op.pipe for op in [op1, ops...]]...)
    return Query(scope, pipe=pipe)
end


function compile(::Fn(:range), base::Query, start::Query, step::Query, stop::Query)
    reqcomposable(base, start, step, stop); reqsingular(start, step, stop); reqodomain(Int, start, step, stop)
    scope = empty(base)
    I = odomain(base)
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
    return Query(scope, pipe=pipe)
end


function compile(fn::Fn(:first, :last), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    O = odomain(flow)
    rev = flow.order < 0
    rev = fn == Fn{:first} ? rev : !rev
    pipe = FirstPipe(flow.pipe, rev)
    return Query(flow, pipe=pipe)
end


compile(fn::Fn(:first, :last), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(fn::Fn(:first, :last), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqnonempty(op)
    rev = op.order < 0
    rev = fn == Fn{:first} ? rev : !rev
    op = identify(op)
    pipe = FirstByPipe(flow.pipe, op.pipe, rev)
    return Query(flow, pipe=pipe)
end


function compile(fn::Fn(:take, :skip), base::Query, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqnonempty(size); reqodomain(Int, size)
    pipe = TakePipe(flow.pipe, size.pipe, fn == Fn{:take} ? false : true)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:get), base::Query, flow::Query, idx::Query)
    reqcomposable(base, flow); reqplural(flow); reqmonic(flow); reqidentity(flow)
    reqcomposable(base, idx); reqsingular(idx); reqnonempty(idx)
    reqodomain(odomain(get(flow.identity)), idx)
    O = odomain(flow)
    pipe = GetPipe(flow.pipe, get(flow.identity).pipe, idx.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:asc), base::Query, op::Query)
    return Query(op, order=1)
end


function compile(::Fn(:desc), base::Query, op::Query)
    return Query(op, order=-1)
end


compile(fn::Fn(:sort), base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(fn::Fn(:sort), base::Query, flow::Query, ops::Query...)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, ops...); reqsingular(ops...); reqnonempty(ops...)
    if isempty(ops)
        if !isnull(flow.identity)
            identity = Query(get(flow.identity), order=flow.order)
            return compile(fn, base, flow, identity)
        end
        pipe = SortPipe(flow.pipe, flow.order < 0)
    else
        pipe = SortByPipe(
            flow.pipe,
            [(identify(op).pipe, op.order < 0) for op in ops]...)
    end
    return Query(flow, pipe=pipe)
end


function compile(fn::Fn(:connect, :and_connect), base::Query, op::Query)
    reqcomposable(base, op); reqpartial(op); reqodomain(idomain(op), op)
    pipe = ConnectPipe(op.pipe, fn == Fn{:and_connect})
    return Query(op, pipe=pipe)
end


function compile(::Fn(:depth), base::Query, op::Query)
    reqcomposable(base, op); reqpartial(op); reqodomain(idomain(op), op)
    scope = empty(base)
    pipe = DepthPipe(op.pipe)
    return Query(scope, pipe=pipe)
end


compile(fn::Fn(:sort_connect), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Fn(:sort_connect), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqpartial(op); reqodomain(idomain(op), op)
    if isnull(op.identity)
        pipe = SortConnectPipe(flow.pipe, op.pipe)
    else
        pipe = SortConnectPipe(flow.pipe, get(op.identity).pipe, op.pipe)
    end
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:unique), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    if !isnull(flow.identity)
        identity = get(flow.identity)
        PipeType = ismonic(flow) ? SortByPipe : UniquePipe
        pipe = PipeType(flow.pipe, identity.pipe, flow.order < 0)
    else
        PipeType = ismonic(flow) ? SortPipe : UniquePipe
        pipe = PipeType(flow.pipe, flow.order < 0)
    end
    return Query(flow, pipe=pipe)
end


compile(fn::Fn(:group, :group_cube),
        base::Query, flow::AbstractSyntax, op1::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op1), [compile(flow, op) for op in ops]...)
    end

function compile(
        fn::Fn(:group, :group_cube, :partition, :partition_cube),
        base::Query, flow::Query, ops::Query...)
    iscube = (fn == Fn{:group_cube} || fn == Fn{:partition_cube})
    ispartition = (fn == Fn{:partition} || fn == Fn{:partition_cube})
    reqcomposable(base, flow); reqplural(flow)
    if !ispartition
        reqcomposable(flow, ops...); reqsingular(ops...); reqnonempty(ops...)
    else
        reqcomposable(base, ops...); reqplural(ops...); reqtag(ops...)
    end
    scope = empty(base)
    I = idomain(flow)
    T = odomain(flow)
    if !ispartition
        groups = [
            isnull(op.identity) ? (op.pipe, op.order < 0) : (op.pipe, get(op.identity).pipe, op.order < 0)
            for op in ops]
    else
        groups = []
        for op in ops
            img = lookup(flow, get(op.tag))
            !isnull(img) || error("undefined attribute $(get(op.tag)): $flow")
            img = get(img)
            reqsingular(img); reqnonempty(img); reqodomain(odomain(op), img)
            if isnull(op.identity)
                push!(groups, (op.pipe, img.pipe, op.order < 0))
            else
                push!(groups, (op.pipe, img.pipe, get(op.identity).pipe, op.order < 0))
            end
        end
    end
    pipe = (!ispartition ? GroupPipe : PartitionPipe)(flow.pipe, iscube, groups...)
    query = Query(scope, pipe=pipe)
    items = []
    defs = Dict{Symbol, Query}()
    kernel_pipe = ItemPipe(pipe, 1)
    for (k, op) in enumerate(ops)
        item_pipe = ItemPipe(pipe, 1, k)
        item = Query(op, pipe=item_pipe)
        if !isnull(item.tag)
            defs[get(item.tag)] = item
        end
        push!(items, item)
    end
    kernel_field = record(query, items...)
    flow_field = Query(flow, pipe=ItemPipe(pipe, 2))
    if !isnull(flow_field.tag)
        defs[get(flow_field.tag)] = flow_field
    end
    fields = (kernel_field, flow_field)
    selector = select(record(query, items..., flow_field))
    identity = identify(record(query, items...))
    return Query(query, identity=identity, selector=selector, defs=defs)
end


function compile(::Fn(:mix), base::Query, ops::Query...)
    reqcomposable(base, ops...); reqtag(ops...)
    if isempty(ops)
        scope = empty(base)
        I = odomain(base)
        pipe = ConstPipe(I, ())
        return Query(scope, pipe=pipe)
    elseif length(ops) == 1
        op = ops[1]
        scope = empty(base)
        I = odomain(op)
        pipe = HerePipe(I)
        defs = Dict{Symbol,Query}(
            get(op.tag) => Query(op, pipe=pipe))
        return Query(op, scope=scope, defs=defs)
    else
        scope = empty(base)
        I = odomain(base)
        O = Tuple{odomain(ops[1]), odomain(ops[2])}
        pipe = ops[1].pipe * ops[2].pipe
        field_pipes = Any[ItemPipe(O, 1), ItemPipe(O, 2)]
        mode = max(omode(ops[1]), omode(ops[2]))
        for op in ops[3:end]
            T = O
            O = Tuple{O, odomain(op)}
            pipe = pipe * op.pipe
            for (k, field_pipe) in enumerate(field_pipes)
                field_pipes[k] = ItemPipe(O, 1) >> field_pipe
            end
            push!(field_pipes, ItemPipe(O, 2))
            mode = max(mode, omode(op))
        end
        fields = ()
        defs = Dict{Symbol,Query}()
        for (k, op) in enumerate(ops)
            field = Query(op, pipe=field_pipes[k])
            fields = (fields..., field)
            defs[get(op.tag)] = field
        end
        query = Query(scope, pipe=pipe, fields=fields, defs=defs)
        identity = record(query, [identify(field) for field in fields]...)
        selector = record(query, [select(field) for field in fields]...)
        return Query(query, identity=identity, selector=selector)
    end
end


function compile(fn::Fn(:left, :right), base::Query)
    reqfields(base)
    return get(base.fields)[fn == Fn{:left} ? 1 : end]
end


function compile(::Fn(:pack), base::Query, ops::Query...)
    reqcomposable(base, ops...); reqtag(ops...)
    I = odomain(base)
    Ts = ()
    Ds = ()
    Ss = ()
    Fs = Vector{Pair{Symbol,AbstractPipe}}()
    isisnonempty = false
    identitymap = Dict{Symbol,AbstractPipe}()
    selectormap = Dict{Symbol,AbstractPipe}()
    for op in ops
        T = odomain(op)
        tag = get(op.tag)
        Ts = (Ts..., T)
        push!(Fs, Pair{Symbol,AbstractPipe}(tag, op.pipe))
        if isnonempty(op)
            isisnonempty = true
        end
        identitymap[tag] =
            !isnull(op.identity) ? get(op.identity).pipe : HerePipe(T)
        selectormap[tag] =
            !isnull(op.selector) ? get(op.selector).pipe : HerePipe(T)
        Ds = (Ds..., !isnull(op.identity) ? odomain(get(op.identity)) : T)
        Ss = (Ss..., !isnull(op.selector) ? odomain(get(op.selector)) : T)
    end
    scope = empty(base)
    pipe = PackPipe(Fs...)
    U = odomain(pipe).parameters[2]
    identity = Query(scope, pipe=CasePipe(U, true, identitymap...))
    selector = Query(scope, pipe=CasePipe(U, true, selectormap...))
    defs = Dict{Symbol,Query}()
    for op in ops
        tag = get(op.tag)
        T = odomain(op)
        defs[get(op.tag)] = Query(op, pipe=CasePipe(U, false, tag => HerePipe(T)))
    end
    return Query(scope, pipe=pipe, identity=identity, selector=selector, defs=defs)
end


function compile(::Fn(:as), base::Query, op::AbstractSyntax, ident::AbstractSyntax)
    (isa(ident, ApplySyntax) && isempty(ident.args)) || error("expected an identifier: $ident")
    return Query(compile(base, op), tag=ident.fn)
end


compile(::Fn(:(=>)), base::Query, ident::AbstractSyntax, op::AbstractSyntax) =
    compile(Fn{:as}, base, op, ident)


compile(fn::Fn(:define), base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        for op in ops
            flow = compile(fn, base, flow, compile(flow, op))
        end
        flow
    end


function compile(::Fn(:define), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow)
    reqcomposable(flow, op); reqtag(op)
    defs = merge(flow.defs, Dict(get(op.tag) => op))
    return Query(flow, defs=defs)
end


function compile(::Fn(:!), base::Query, op::Query)
    reqcomposable(base, op); reqsingular(op); reqodomain(Bool, op)
    scope = empty(base)
    pipe = ~op.pipe
    return Query(scope, pipe=pipe)
end


function compile(fn::Fn(:&, :|), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqsingular(op1, op2); reqodomain(Bool, op1, op2)
    scope = empty(base)
    if fn == Fn{:&}
        pipe = op1.pipe & op2.pipe
    else
        pipe = op1.pipe | op2.pipe
    end
    return Query(scope, pipe=pipe)
end


function compile(fn::Fn(:(==), :(!=)), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqodomain(odomain(op1), op2)
    ismonic(op1) || reqsingular(op2)
    T = odomain(op1)
    TT = Tuple{T,T}
    scope = empty(base)
    output = Output(Bool, max(omode(op1), omode(op2)))
    pipe = fn == Fn{:(==)} ? op1.pipe .== op2.pipe : op1.pipe .!= op2.pipe
    return Query(scope, pipe=pipe)
end


function compile(fn::Fn(:in), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqodomain(odomain(op1), op2)
    reqsingular(op1); reqnonempty(op1); reqplural(op2)
    scope = empty(base)
    pipe = InPipe(op1.pipe, op2.pipe)
    return Query(scope, pipe=pipe)
end


macro compileunaryop(fn, operator, T1, T2)
    return esc(quote
        function compile(::Fn($fn), base::Query, op::Query)
            reqcomposable(base, op); reqodomain($T1, op)
            scope = empty(base)
            pipe = OpPipe($operator, Type[$T1], $T2, [op.pipe])
            return Query(scope, pipe=pipe)
        end
    end)
end

macro compilebinaryop(fn, operator, T1, T2, T3)
    return esc(quote
        function compile(::Fn($fn), base::Query, op1::Query, op2::Query)
            reqcomposable(base, op1, op2); reqodomain($T1, op1); reqodomain($T2, op2)
            issingular(op1) || reqsingular(op2)
            scope = empty(base)
            pipe = OpPipe($operator, Type[$T1, $T2], $T3, [op1, op2])
            return Query(scope, pipe=pipe)
        end
    end)
end

@compileunaryop(:(+), (+), Int, Int)
@compileunaryop(:(-), (-), Int, Int)

@compilebinaryop(:(<), (<), Int, Int, Bool)
@compilebinaryop(:(<=), (<=), Int, Int, Bool)
@compilebinaryop(:(>=), (>=), Int, Int, Bool)
@compilebinaryop(:(>), (>), Int, Int, Bool)
@compilebinaryop(:(+), (+), Int, Int, Int)
@compilebinaryop(:(-), (-), Int, Int, Int)
@compilebinaryop(:(*), (*), Int, Int, Int)
@compilebinaryop(:(/), (div), Int, Int, Int)


compile(fn::Fn(:json), base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow),
        ops = [compile(flow, op) for op in ops]
        isempty(ops) ? compile(fn, base, flow) : compile(fn, base, compile(Fn{:select}, base, flow, ops...))
    end


function compile(fn::Fn(:json), base::Query, flow::Query)
    flow = select(flow)
    if !isnull(flow.fields)
        parts = ()
        fields = ()
        for field in get(flow.fields)
            field = compile(fn, flow, field)
            if !isnull(field.tag)
                fields = (fields..., Pair{Symbol,AbstractPipe}(get(field.tag), field.pipe))
            end
        end
        I = idomain(flow)
        O = odomain(flow)
        scope = empty(base)
        pipe = flow.pipe >> DictPipe(fields...)
        if ispartial(flow)
            pipe = NullToVoidPipe(pipe)
        end
        flow = Query(scope, pipe=pipe, tag=flow.tag)
    else
        if ispartial(flow)
            pipe = NullToVoidPipe(flow.pipe)
            flow = Query(flow, pipe=pipe)
        end
    end
    return flow
end


