

reqcomposable(f, gs...) =
    for g in gs
        odomain(f) == idomain(g) || error("expected composable expressions: $f and $g")
    end

reqsingular(fs...) =
    for f in fs
        singular(f) || error("expected a singular expression: $f")
    end

reqplural(fs...) =
    for f in fs
        !singular(f) || error("expected a plural expression: $f")
    end

reqcomplete(fs...) =
    for f in fs
        complete(f) || error("expected a complete expression: $f")
    end

reqpartial(fs...) =
    for f in fs
        !complete(f) || error("expected a partial expression: $f")
    end

reqexclusive(fs...) =
    for f in fs
        exclusive(f) || error("expected an exclusive expression: $f")
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


function lift(q::Query, imode::InputMode, omode::OutputMode)
    if q.input.mode == imode && q.output.mode == omode
        return q
    end
    input = Input(q.input.domain, imode)
    output = Output(q.output.domain, omode)
    I0, I = functor(q.input), functor(input)
    O0, O = functor(q.output), functor(output)
    pipe = (I ^ (pipe ^ O))
    return Query(q, input=input, output=output, pipe=pipe)
end

lift(q::Query, imode::InputMode) =
    lift(q, imode, q.output.mode)

lift(q::Query, omode::OutputMode) =
    lift(q, q.input.mode, omode)

lift(imode::InputMode, omode::OutputMode, qs::Query...) =
    ([lift(q, imode, omode) for q in qs]...)

lift(imode::InputMode, qs::Query...) =
    ([lift(q, imode, q.output.mode) for q in qs]...)

lift(omode::OutputMode, qs::Query...) =
    ([lift(q, q.input.mode, omode) for q in qs]...)


function >>(f::Query, g::Query)
    reqcomposable(f, g)
    input = Input(idomain(f), max(imode(f), imode(g)))
    output = Output(odomain(g), max(omode(f), omode(g)))
    pipe = f.pipe >> g.pipe
    syntax =
        !isnull(f.syntax) && !isnull(g.syntax) ?
            NullableSyntax(ComposeSyntax(get(f.syntax), get(g.syntax))) :
        !isnull(f.syntax) ? f.syntax :
        !isnull(g.syntax) ? g.syntax :
        NullableSyntax()
    return Query(g, input=input, output=output, pipe=pipe, syntax=syntax)
end


select(q::Query) =
    !isnull(q.selector) ? Query(q >> get(q.selector), order=q.order, tag=q.tag) : q


identify(q::Query) =
    !isnull(q.identity) ? Query(q >> get(q.identity), order=q.order, tag=q.tag) : q


function record(base::Query, ops::Query...)
    reqcomposable(base, ops...)
    scope = empty(base)
    IT = odomain(base)
    OT = Tuple{[unwrap(ofunctor(op)) for op in ops]...}
    input = Input(IT)
    output = Output(OT)
    pipe = TuplePipe([op.pipe for op in ops]...)
    fields = Query[]
    defs = Dict{Symbol,Query}()
    for (k, op) in enumerate(ops)
        field = Query(op, input=Input(OT), pipe=ItemPipe(OT, k, ofunctor(op)))
        push!(fields, field)
        if !isnull(field.tag)
            defs[get(field.tag)] = field
        end
    end
    query = Query(scope, input=input, output=output, pipe=pipe, fields=(fields...), defs=defs)
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


function compile(base::Query, syntax::LiteralSyntax{Void})
    scope = empty(base)
    IT = odomain(base)
    input = Input(IT)
    output = Output(Any, complete=false)
    pipe = NullPipe(IT)
    return Query(scope, input=input, output=output, pipe=pipe, syntax=syntax)
end


function compile{T}(base::Query, syntax::LiteralSyntax{T})
    scope = empty(base)
    IT = odomain(base)
    input = Input(IT)
    output = Output(T)
    pipe = ConstPipe(IT, syntax.val)
    return Query(scope, input=input, output=output, pipe=pipe, syntax=syntax)
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
    input = Input(T)
    output = Output(T, exclusive=true, reachable=true)
    pipe = HerePipe(T)
    return Query(base, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:unlink), base::Query, arg::AbstractSyntax)
    scope = root(base)
    I = odomain(base)
    input = Input(I)
    output = Output(Unit, reachable=true)
    pipe = ConstPipe{I, Unit}(())
    root_base = Query(scope, input=input, output=output, pipe=pipe)
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


function compile(::Fn(:fork), base::Query, ops::Query...)
    reqcomposable(base, ops...); reqsingular(ops...); reqcomplete(ops...)
    T = odomain(base)
    input = Input(T, temporal=true)
    output = Output(T, singular=false, complete=true)
    pipe =
        isempty(ops) ? ForkPipe(T) :
        length(ops) == 1 ? ForkByPipe(identify(ops[1]).pipe) :
            ForkByPipe(identify(record(base, ops...)).pipe)
    return Query(base, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:future, :past), base::Query)
    T = odomain(base)
    input = Input(T, temporal=true)
    output = Output(T, singular=false, complete=false)
    pipe = FuturePipe(T, fn == Fn{:future} ? 1 : -1)
    return Query(base, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:next, :prev), base::Query)
    T = odomain(base)
    input = Input(T, temporal=true)
    output = Output(T, singular=true, complete=false)
    pipe = NextPipe(T, fn == Fn{:next} ? 1 : -1)
    return Query(base, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:count), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    scope = empty(base)
    I = ifunctor(flow)
    T = odomain(flow)
    input = flow.input
    output = Output(Int)
    pipe = CountPipe{I, T}(flow.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:sum), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow); reqodomain(Int, flow)
    scope = empty(base)
    input = flow.input
    output = Output(Int)
    pipe = SumPipe(flow.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:max), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow); reqodomain(Int, flow)
    scope = empty(base)
    I = ifunctor(flow)
    input = flow.input
    output = Output(Int, complete=complete(flow))
    pipe = complete(flow) ? MaxPipe(flow.pipe) : OptMaxPipe(flow.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


compile(::Fn(:record), base::Query, ops::Query...) = record(base, ops...)


compile(fn::Fn(:select), base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(::Fn(:select), base::Query, flow::Query, ops::Query...)
    reqcomposable(base, flow)
    reqcomposable(flow, ops...)
    selector = record(flow, [select(op) for op in ops]...)
    return Query(flow, selector=selector)
end


compile(fn::Fn(:filter), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Fn(:filter), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqodomain(Bool, op)
    input = Input(idomain(flow), max(imode(flow), imode(op)))
    O = odomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(op))
    pipe = flow.pipe >> SievePipe(op.pipe)
    return Query(flow, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:reverse), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    pipe = ReversePipe(flow.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:array), base::Query, op1::Query, ops::Query...)
    reqcomposable(base, op1, ops...); reqsingular(op1, ops...); reqcomplete(op1, ops...)
    reqodomain(odomain(op1), ops...)
    scope = op1.scope
    I = idomain(op1)
    O = odomain(op1)
    input = Input(I)
    output = Output(O, singular=false)
    pipe = ArrayPipe([op.pipe for op in [op1, ops...]]...)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:range), base::Query, start::Query, step::Query, stop::Query)
    reqcomposable(base, start, step, stop); reqsingular(start, step, stop); reqodomain(Int, start, step, stop)
    scope = empty(base)
    I = odomain(base)
    input = Input(I)
    output = Output(Int, singular=false, complete=false)
    if complete(start) && complete(step) && complete(stop)
        pipe = RangePipe(start.pipe, step.pipe, stop.pipe)
    else
        pipe =
            (start.pipe * (step.pipe * stop.pipe)) >>
            RangePipe(
                ItemPipe(Tuple{Int,Tuple{Int,Int}}, 1),
                ItemPipe(Tuple{Int,Tuple{Int,Int}}, 2) >> ItemPipe(Tuple{Int,Int}, 1),
                ItemPipe(Tuple{Int,Tuple{Int,Int}}, 2) >> ItemPipe(Tuple{Int,Int}, 2))
    end
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:first, :last), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    O = odomain(flow)
    output = Output(O, complete=complete(flow), exclusive=exclusive(flow))
    dir = flow.order >= 0 ? 1 : -1
    dir = fn == Fn{:first} ? dir : -dir
    pipe = complete(flow) ? IsoFirstPipe(flow.pipe, dir) : OptFirstPipe(flow.pipe, dir)
    return Query(flow, output=output, pipe=pipe)
end


compile(fn::Fn(:first, :last), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(fn::Fn(:first, :last), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqcomplete(op)
    dir = op.order >= 0 ? 1 : -1
    dir = fn == Fn{:first} ? dir : -dir
    op = identify(op)
    I = idomain(flow)
    O = odomain(flow)
    output = Output(O, singular=true, complete=complete(flow), exclusive=exclusive(flow))
    pipe = complete(flow) ?
        IsoFirstByPipe(flow.pipe, op.pipe, dir) : OptFirstByPipe(flow.pipe, op.pipe, dir)
    return Query(flow, output=output, pipe=pipe)
end


function compile(fn::Fn(:take, :skip), base::Query, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqcomplete(size); reqodomain(Int, size)
    O = odomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(flow))
    pipe = TakePipe(flow.pipe, size.pipe, fn == Fn{:take} ? 1 : -1)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Fn(:get), base::Query, flow::Query, idx::Query)
    reqcomposable(base, flow); reqplural(flow); reqexclusive(flow); reqidentity(flow)
    reqcomposable(base, idx); reqsingular(idx); reqcomplete(idx)
    reqodomain(odomain(get(flow.identity)), idx)
    O = odomain(flow)
    output = Output(O, complete=false, exclusive=exclusive(flow))
    pipe = GetPipe(flow.pipe, get(flow.identity).pipe, idx.pipe)
    return Query(flow, output=output, pipe=pipe)
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
    reqcomposable(flow, ops...); reqsingular(ops...); reqcomplete(ops...)
    if isempty(ops)
        if !isnull(flow.identity)
            identity = Query(get(flow.identity), order=flow.order)
            return compile(fn, base, flow, identity)
        end
        pipe = SortPipe(flow.pipe, flow.order)
    else
        pipe = SortByPipe(
            flow.pipe,
            [(identify(op).pipe, op.order) for op in ops]...)
    end
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:connect), base::Query, op::Query)
    reqcomposable(base, op); reqpartial(op); reqodomain(idomain(op), op)
    I = idomain(op)
    input = Input(I)
    output = Output(I, singular=false, complete=false)
    pipe = ConnectPipe(op.pipe, false)
    return Query(op, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:depth), base::Query, op::Query)
    reqcomposable(base, op); reqpartial(op); reqodomain(idomain(op), op)
    scope = empty(base)
    I = idomain(op)
    input = Input(I)
    output = Output(Int)
    pipe = DepthPipe(op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


compile(fn::Fn(:sort_connect), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Fn(:sort_connect), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqpartial(op); reqodomain(idomain(op), op)
    I = idomain(flow)
    O = odomain(flow)
    J = !isnull(op.identity) ? odomain(get(op.identity)) : O
    if isnull(op.identity)
        pipe = SortConnectPipe(flow.pipe, op.pipe)
    else
        pipe = SortConnectPipe(flow.pipe, op.pipe, get(op.identity).pipe)
    end
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:unique), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = idomain(flow)
    O = odomain(flow)
    output = Output(
        O, singular=false, complete=complete(flow),
        exclusive=true, reachable=reachable(flow))
    if !isnull(flow.identity)
        identity = get(flow.identity)
        K = odomain(identity)
        PipeType = exclusive(flow) ? SortByPipe : UniqueByPipe
        pipe = PipeType(flow.pipe, identity.pipe, flow.order)
    else
        PipeType = exclusive(flow) ? SortPipe : UniquePipe
        pipe = PipeType(flow.pipe, flow.order)
    end
    return Query(flow, output=output, pipe=pipe)
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
        reqcomposable(flow, ops...); reqsingular(ops...); reqcomplete(ops...)
    else
        reqcomposable(base, ops...); reqplural(ops...); reqtag(ops...)
    end
    GroupPipe =
        !iscube && !ispartition ? GroupByPipe :
        !ispartition ? CubeGroupByPipe :
        !iscube ? PartitionByPipe : CubePartitionByPipe
    scope = empty(base)
    I = idomain(flow)
    T = odomain(flow)
    if !ispartition
        groups = [
            isnull(op.identity) ? (op.pipe, op.order) : (op.pipe, get(op.identity).pipe, op.order)
            for op in ops]
    else
        groups = []
        for op in ops
            img = lookup(flow, get(op.tag))
            !isnull(img) || error("undefined attribute $(get(op.tag)): $flow")
            img = get(img)
            reqsingular(img); reqcomplete(img); reqodomain(odomain(op), img)
            if isnull(op.identity)
                push!(groups, (op.pipe, img.pipe, op.order))
            else
                push!(groups, (op.pipe, img.pipe, get(op.identity).pipe, op.order))
            end
        end
    end
    if !iscube
        Q = Tuple{[odomain(op) for op in ops]...}
    else
        Q = Tuple{[Nullable{odomain(op)} for op in ops]...}
    end
    O = Tuple{Q, Vector{T}}
    pipe = GroupPipe(flow.pipe, groups...)
    input = Input(I)
    output = Output(O, singular=isempty(ops), complete=(complete(flow) || isempty(ops) || iscube))
    query = Query(scope, input=input, output=output, pipe=pipe)
    items = []
    defs = Dict{Symbol, Query}()
    kernel_pipe = ItemPipe(O, 1)
    for (k, op) in enumerate(ops)
        R = odomain(op)
        item_pipe = kernel_pipe >> ItemPipe(Q, k, iscube ? Opt{R} : Iso{R})
        item = Query(
            op,
            input=Input(O),
            output=Output(R, complete=!iscube, exclusive=(length(ops)==1), reachable=reachable(op)),
            pipe=item_pipe)
        if !isnull(item.tag)
            defs[get(item.tag)] = item
        end
        push!(items, item)
    end
    kernel_field = record(query, items...)
    flow_field = Query(
        flow,
        input=Input(O),
        output=Output(
            T, singular=false, complete=!iscube && !ispartition,
            exclusive=(exclusive(flow) && !iscube), reachable=reachable(flow)),
        pipe=ItemPipe(O, 2, Seq{T}))
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
        input = Input(I)
        output = Output(Unit)
        pipe = ConstPipe(I, ())
        return Query(scope, input=input, output=output, pipe=pipe)
    elseif length(ops) == 1
        op = ops[1]
        scope = empty(base)
        I = odomain(op)
        input = Input(I)
        output = Output(I, exclusive=true, reachable=true)
        pipe = HerePipe(I)
        defs = Dict{Symbol,Query}(
            get(op.tag) => Query(op, input=input, output=output, pipe=pipe))
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
        input = Input(I)
        output = Output(O, mode)
        fields = ()
        defs = Dict{Symbol,Query}()
        for (k, op) in enumerate(ops)
            field = Query(op, input=Input(O), output=Output(odomain(op)), pipe=field_pipes[k])
            fields = (fields..., field)
            defs[get(op.tag)] = field
        end
        query = Query(scope, input=input, output=output, pipe=pipe, fields=fields, defs=defs)
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
    iscomplete = false
    identitymap = Dict{Symbol,AbstractPipe}()
    selectormap = Dict{Symbol,AbstractPipe}()
    for op in ops
        T = odomain(op)
        tag = get(op.tag)
        Ts = (Ts..., T)
        push!(Fs, Pair{Symbol,AbstractPipe}(tag, op.pipe))
        if complete(op)
            iscomplete = true
        end
        identitymap[tag] =
            !isnull(op.identity) ? get(op.identity).pipe : HerePipe{T}()
        selectormap[tag] =
            !isnull(op.selector) ? get(op.selector).pipe : HerePipe{T}()
        Ds = (Ds..., !isnull(op.identity) ? odomain(get(op.identity)) : T)
        Ss = (Ss..., !isnull(op.selector) ? odomain(get(op.selector)) : T)
    end
    scope = empty(base)
    input = Input(I)
    U = Union{Ts...}
    O = Pair{Symbol, U}
    output = Output(O, singular=false, complete=iscomplete)
    pipe = CoproductPipe(Fs...)
    identity = Query(
        scope,
        input=Input(O),
        output=Output(Pair{Symbol,Union{Ds...}}),
        pipe=CoproductMapPipe(identitymap...))
    selector = Query(
        scope,
        input=Input(O),
        output=Output(Pair{Symbol,Union{Ss...}}),
        pipe=CoproductMapPipe(selectormap...))
    defs = Dict{Symbol,Query}()
    for op in ops
        tag = get(op.tag)
        T = odomain(op)
        defs[get(op.tag)] =
            Query(
                op,
                input=Input(O),
                output=Output(T, complete=false),
                pipe=SwitchPipe(U, T, tag))
    end
    return Query(scope, input=input, output=output, pipe=pipe, identity=identity, selector=selector, defs=defs)
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
    input = op.input
    output = Output(Bool, complete=complete(op))
    pipe = complete(op) ? IsoNotPipe(op.pipe) : OptNotPipe(op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:&, :|), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqsingular(op1, op2); reqodomain(Bool, op1, op2)
    scope = empty(base)
    input = Input(odomain(base), max(imode(op1), imode(op2)))
    output = Output(Bool, complete=complete(op1) && complete(op2))
    if fn == Fn{:&}
        pipe = AndPipe(op1.pipe, op2.pipe)
    else
        pipe = OrPipe(op1.pipe, op2.pipe)
    end
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:(==), :(!=)), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqodomain(odomain(op1), op2)
    singular(op1) || reqsingular(op2)
    T = odomain(op1)
    TT = Tuple{T,T}
    scope = empty(base)
    input = Input(odomain(base), max(imode(op1), imode(op2)))
    output = Output(Bool, max(omode(op1), omode(op2)))
    PipeType = (fn == Fn{:(==)}) ? EQPipe : NEPipe
    pipe = singular(output) && complete(output) ?
        PipeType(op1.pipe, op2.pipe) :
        (op1.pipe * op2.pipe) >> PipeType(ItemPipe(TT, 1), ItemPipe(TT, 2))
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:in), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqodomain(odomain(op1), op2)
    reqsingular(op1); reqcomplete(op1); reqplural(op2)
    scope = empty(base)
    input = Input(odomain(base), max(imode(op1), imode(op2)))
    output = Output(Bool)
    pipe = InPipe(op1.pipe, op2.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


macro compileunaryop(fn, Pipe, T1, T2)
    return esc(quote
        function compile(::Fn($fn), base::Query, op::Query)
            reqcomposable(base, op); reqodomain($T1, op)
            scope = empty(base)
            input = op.input
            output = Output($T2, omode(op))
            pipe = singular(output) && complete(output) ?
                $Pipe(op.pipe) :
                op.pipe >> $Pipe(HerePipe($T1))
            return Query(scope, input=input, output=output, pipe=pipe)
        end
    end)
end

macro compilebinaryop(fn, Pipe, T1, T2, T3)
    return esc(quote
        function compile(::Fn($fn), base::Query, op1::Query, op2::Query)
            reqcomposable(base, op1, op2); reqodomain($T1, op1); reqodomain($T2, op2)
            singular(op1) || reqsingular(op2)
            TT = Tuple{$T1,$T2}
            scope = empty(base)
            input = Input(odomain(base), max(imode(op1), imode(op2)))
            output = Output($T3, max(omode(op1), omode(op2)))
            pipe = singular(output) && complete(output) ?
                $Pipe(op1.pipe, op2.pipe) :
                (op1.pipe * op2.pipe) >> $Pipe(ItemPipe(TT, 1), ItemPipe(TT, 2))
            return Query(scope, input=input, output=output, pipe=pipe)
        end
    end)
end

@compileunaryop(:(+), PosPipe, Int, Int)
@compileunaryop(:(-), NegPipe, Int, Int)

@compilebinaryop(:(<), LTPipe, Int, Int, Bool)
@compilebinaryop(:(<=), LEPipe, Int, Int, Bool)
@compilebinaryop(:(>=), GEPipe, Int, Int, Bool)
@compilebinaryop(:(>), GTPipe, Int, Int, Bool)
@compilebinaryop(:(+), AddPipe, Int, Int, Int)
@compilebinaryop(:(-), SubPipe, Int, Int, Int)
@compilebinaryop(:(*), MulPipe, Int, Int, Int)
@compilebinaryop(:(/), DivPipe, Int, Int, Int)


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
        input = flow.input
        output = Output(Dict{Any,Any})
        pipe = flow.pipe >> DictPipe(fields...)
        if singular(flow) && !complete(flow)
            output = Output(Union{Dict{Any,Any},Void})
            pipe = OptToVoidPipe(pipe)
        end
        flow = Query(scope, input=input, output=output, pipe=pipe, tag=flow.tag)
    else
        if singular(flow) && !complete(flow)
            I = idomain(flow)
            O = odomain(flow)
            output = Output(Union{Dict{Any,Any},Void}, exclusive=exclusive(flow), reachable=reachable(flow))
            pipe = OptToVoidPipe(flow.pipe)
            flow = Query(flow, output=output, pipe=pipe)
        end
    end
    return flow
end


