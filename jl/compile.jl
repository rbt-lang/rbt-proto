

reqcomposable(f, gs...) =
    for g in gs
        codomain(f) == domain(g) || error("expected composable expressions: $f and $g")
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

reqcodomain(dom, fs...) =
    for f in fs
        codomain(f) <: dom || error("expected an expression of type $dom: $f")
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
    I = domain(f)
    O = codomain(g)
    OM = max(comode(f), comode(g))
    input = Input(I)
    output = Output(O, OM)
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
    I = codomain(base)
    O = Tuple{[datatype(op.output) for op in ops]...}
    input = Input(I)
    output = Output(O)
    pipe = TuplePipe{I,O}([op.pipe for op in ops])
    fields = Query[]
    defs = Dict{Symbol,Query}()
    for (k, op) in enumerate(ops)
        T = codomain(op)
        field = Query(
            op, input=Input(O),
            pipe=
                singular(op) && complete(op) ? IsoItemPipe{O,T}(k) :
                singular(op) ? OptItemPipe{O,T}(k) : SeqItemPipe{O,T}(k))
        push!(fields, field)
        if !isnull(field.tag)
            defs[get(field.tag)] = field
        end
    end
    query = Query(scope, input=input, output=output, pipe=pipe, fields=tuple(fields...), defs=defs)
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
    I = codomain(base)
    input = Input(I)
    output = Output(Void, complete=false)
    pipe = NullPipe{I, Void}()
    return Query(scope, input=input, output=output, pipe=pipe, syntax=syntax)
end


function compile{T}(base::Query, syntax::LiteralSyntax{T})
    scope = empty(base)
    I = codomain(base)
    O = T
    input = Input(I)
    output = Output(O)
    pipe = ConstPipe{I, O}(syntax.val)
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


function compile(::Fn(:this), base::Query)
    T = codomain(base)
    input = Input(T)
    output = Output(T, exclusive=true, reachable=true)
    pipe = ThisPipe{T}()
    return Query(base, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:unlink), base::Query, arg::AbstractSyntax)
    scope = root(base)
    I = codomain(base)
    input = Input(I)
    output = Output(UnitType, reachable=true)
    pipe = ConstPipe{I, UnitType}(())
    root_base = Query(scope, input=input, output=output, pipe=pipe)
    return root_base >> compile(root_base, arg)
end


compile(::Fn(:link), base::Query, pred::AbstractSyntax, arg::AbstractSyntax) =
    let unlink = compile(Fn{:unlink}, base, arg),
        mix = compile(Fn{:mix}, base, compile(Fn{:this}, base), unlink),
        condition = compile(mix, pred),
        filter = compile(Fn{:filter}, base, mix, condition),
        right = compile(Fn{:right}, mix)
        filter >> right
    end


function compile(::Fn(:count), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    scope = empty(base)
    I = domain(flow)
    T = codomain(flow)
    input = Input(I)
    output = Output(Int)
    pipe = CountPipe{I, T}(flow.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:max), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow); reqcodomain(Int, flow)
    scope = empty(base)
    I = domain(flow)
    input = Input(I)
    output = Output(Int, complete=complete(flow))
    pipe = complete(flow) ? MaxPipe{I}(flow.pipe) : OptMaxPipe{I}(flow.pipe)
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
    reqcomposable(flow, op); reqsingular(op); reqcodomain(Bool, op)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(op))
    predicate = op.pipe
    if !complete(op)
        predicate = IsoIfNullPipe{O,Bool}(predicate, ConstPipe{O,Bool}(false))
    end
    pipe = flow.pipe >> SievePipe{O}(predicate)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Fn(:reverse), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    pipe = ReversePipe{I,O}(flow.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:array), base::Query, op1::Query, ops::Query...)
    reqcomposable(base, op1, ops...); reqsingular(op1, ops...); reqcomplete(op1, ops...)
    reqcodomain(codomain(op1), ops...)
    scope = op1.scope
    I = domain(op1)
    O = codomain(op1)
    input = Input(I)
    output = Output(O, singular=false)
    pipe = ArrayPipe{I,O}([op.pipe for op in [op1, ops...]])
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:range), base::Query, start::Query, step::Query, stop::Query)
    reqcomposable(base, start, step, stop); reqsingular(start, step, stop); reqcodomain(Int, start, step, stop)
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Int, singular=false, complete=false)
    if complete(start) && complete(step) && complete(stop)
        pipe = RangePipe{I}(start.pipe, step.pipe, stop.pipe)
    else
        pipe =
            (start.pipe * (step.pipe * stop.pipe)) >>
            RangePipe{Tuple{Int,Tuple{Int,Int}}}(
                IsoItemPipe{Tuple{Int,Tuple{Int,Int}},Int}(1),
                IsoItemPipe{Tuple{Int,Tuple{Int,Int}},Tuple{Int,Int}}(2) >> IsoItemPipe{Tuple{Int,Int}}{Int}(1),
                IsoItemPipe{Tuple{Int,Tuple{Int,Int}},Tuple{Int,Int}}(2) >> IsoItemPipe{Tuple{Int,Int}}{Int}(2))
    end
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:first, :last), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, complete=complete(flow), exclusive=exclusive(flow))
    dir = flow.order >= 0 ? 1 : -1
    dir = fn == Fn{:first} ? dir : -dir
    pipe = complete(flow) ? IsoFirstPipe{I,O}(flow.pipe, dir) : OptFirstPipe{I,O}(flow.pipe, dir)
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
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=true, complete=complete(flow), exclusive=exclusive(flow))
    pipe = complete(flow) ?
        IsoFirstByPipe{I,O}(flow.pipe, op.pipe, dir) : OptFirstByPipe{I,O}(flow.pipe, op.pipe, dir)
    return Query(flow, output=output, pipe=pipe)
end


function compile(fn::Fn(:take, :skip), base::Query, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqcomplete(size); reqcodomain(Int, size)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(flow))
    pipe = TakePipe{I,O}(flow.pipe, size.pipe, fn == Fn{:take} ? 1 : -1)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Fn(:get), base::Query, flow::Query, key::Query)
    reqcomposable(base, flow); reqplural(flow); reqexclusive(flow); reqidentity(flow)
    reqcomposable(base, key); reqsingular(key); reqcomplete(key)
    reqcodomain(codomain(get(flow.identity)), key)
    I = domain(flow)
    O = codomain(flow)
    K = codomain(key)
    output = Output(O, complete=false, exclusive=exclusive(flow))
    pipe = GetPipe{I,O,K}(flow.pipe, get(flow.identity).pipe, key.pipe)
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
    I = domain(flow)
    O = codomain(flow)
    if isempty(ops)
        if !isnull(flow.identity)
            identity = Query(get(flow.identity), order=flow.order)
            return compile(fn, base, flow, identity)
        end
        pipe = SortPipe{I,O}(flow.pipe, flow.order)
    else
        pipe = flow.pipe
        for op in reverse(ops)
            order = op.order
            op = identify(op)
            K = codomain(op)
            pipe = SortByPipe{I,O,K}(pipe, op.pipe, order)
        end
    end
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:connect), base::Query, op::Query)
    reqcomposable(base, op); reqpartial(op); reqcodomain(domain(op), op)
    I = domain(op)
    input = Input(I)
    output = Output(I, singular=false, complete=false)
    pipe = ConnectPipe{I}(singular(op) ? OptToSeqPipe(op.pipe) : op.pipe, false)
    return Query(op, input=input, output=output, pipe=pipe)
end


function compile(::Fn(:depth), base::Query, op::Query)
    reqcomposable(base, op); reqpartial(op); reqcodomain(domain(op), op)
    scope = empty(base)
    I = domain(op)
    input = Input(I)
    output = Output(Int)
    pipe = DepthPipe{I}(singular(op) ? OptToSeqPipe(op.pipe) : op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


compile(fn::Fn(:toposort), base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(fn::Fn(:toposort), base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqpartial(op); reqcodomain(domain(op), op)
    I = domain(flow)
    O = codomain(flow)
    J = !isnull(op.identity) ? codomain(get(op.identity)) : O
    pipe = TopoSortPipe{I,O,J}(
        flow.pipe,
        singular(op) ? OptToSeqPipe(op.pipe) : op.pipe,
        !isnull(op.identity) ? get(op.identity).pipe : ThisPipe{O}())
    return Query(flow, pipe=pipe)
end


function compile(::Fn(:unique), base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    output = Output(
        O, singular=false, complete=complete(flow),
        exclusive=true, reachable=reachable(flow))
    if !isnull(flow.identity)
        identity = get(flow.identity)
        K = codomain(identity)
        PipeType = exclusive(flow) ? SortByPipe : UniqueByPipe
        pipe = PipeType{I,O,K}(flow.pipe, identity.pipe, flow.order)
    else
        PipeType = exclusive(flow) ? SortPipe : UniquePipe
        pipe = PipeType{I,O}(flow.pipe, flow.order)
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
    I = domain(flow)
    V = codomain(flow)
    Ps = ()
    Q = UnitType
    O = Tuple{Q, Vector{V}}
    pipe = TuplePipe{I, O}([ConstPipe{I,UnitType}(()), flow.pipe])
    if ispartition
        pipe = TuplePipe{I, Tuple{I,O}}([ThisPipe{I}(), pipe])
    end
    for op in ops
        opid = !isnull(op.identity) ? get(op.identity) : compile(Fn{:this}, op)
        P = Tuple{Ps...}
        K = codomain(op)
        J = codomain(opid)
        Ps = (Ps..., (iscube ? Nullable{K} : K))
        Q = Tuple{Ps...}
        if !ispartition
            pipe = pipe >> GroupPipe{P,Q,V,K,J}(op.pipe, opid.pipe, op.order)
        else
            ker = lookup(flow, get(op.tag))
            !isnull(ker) || error("undefined attribute $(get(op.tag)): $flow")
            ker = get(ker)
            reqsingular(ker); reqcomplete(ker); reqcodomain(K, ker)
            pipe = pipe >> GroupPipe{I,P,Q,V,K,J}(op.pipe, ker.pipe, opid.pipe, op.order)
        end
    end
    O = Tuple{Q, Vector{V}}
    if ispartition
        pipe = pipe >> IsoItemPipe{Tuple{I, O}, O}(2)
    end
    input = Input(I)
    output = Output(O, singular=isempty(ops), complete=(complete(flow) || isempty(ops) || iscube))
    query = Query(scope, input=input, output=output, pipe=pipe)
    items = []
    defs = Dict{Symbol, Query}()
    kernel_pipe = IsoItemPipe{O, Q}(1)
    for (k, op) in enumerate(ops)
        T = codomain(op)
        item_pipe = kernel_pipe >> (iscube ? OptItemPipe : IsoItemPipe){Q, T}(k)
        item = Query(
            op,
            input=Input(O),
            output=Output(T, complete=!iscube, exclusive=(length(ops)==1), reachable=reachable(op)),
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
            V, singular=false, complete=!iscube && !ispartition,
            exclusive=(exclusive(flow) && !iscube), reachable=reachable(flow)),
        pipe=SeqItemPipe{O,V}(2))
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
        I = codomain(base)
        input = Input(I)
        output = Output(UnitType)
        pipe = ConstPipe{I,UnitType}(())
        return Query(scope, input=input, output=output, pipe=pipe)
    elseif length(ops) == 1
        op = ops[1]
        scope = empty(base)
        I = codomain(op)
        input = Input(I)
        output = Output(I, exclusive=true, reachable=true)
        pipe = ThisPipe{I}()
        defs = Dict{Symbol,Query}(
            get(op.tag) => Query(op, input=input, output=output, pipe=pipe))
        return Query(op, scope=scope, defs=defs)
    else
        scope = empty(base)
        I = codomain(base)
        O = Tuple{codomain(ops[1]), codomain(ops[2])}
        pipe = ops[1].pipe * ops[2].pipe
        field_pipes = Any[
            IsoItemPipe{O,codomain(ops[1])}(1),
            IsoItemPipe{O,codomain(ops[2])}(2)]
        mode = max(comode(ops[1]), comode(ops[2]))
        for op in ops[3:end]
            T = O
            O = Tuple{O, codomain(op)}
            pipe = pipe * op.pipe
            for (k, field_pipe) in enumerate(field_pipes)
                field_pipes[k] = IsoItemPipe{O,T}(1) >> field_pipe
            end
            push!(field_pipes, IsoItemPipe{O,codomain(op)}(2))
            mode = max(mode, comode(op))
        end
        input = Input(I)
        output = Output(O, mode)
        fields = ()
        defs = Dict{Symbol,Query}()
        for (k, op) in enumerate(ops)
            field = Query(op, input=Input(O), output=Output(codomain(op)), pipe=field_pipes[k])
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
    I = codomain(base)
    Ts = ()
    Ds = ()
    Ss = ()
    Fs = Vector{Pair{Symbol,SeqPipe}}()
    iscomplete = false
    identitymap = Dict{Symbol,IsoPipe}()
    selectormap = Dict{Symbol,IsoPipe}()
    for op in ops
        T = codomain(op)
        tag = get(op.tag)
        Ts = (Ts..., T)
        field_pipe =
            singular(op) && complete(op) ? IsoToSeqPipe{I,T}(op.pipe) :
            singular(op) ? OptToSeqPipe{I,T}(op.pipe) : op.pipe
        push!(Fs, Pair{Symbol,SeqPipe}(tag, field_pipe))
        if complete(op)
            iscomplete = true
        end
        identitymap[tag] =
            !isnull(op.identity) ? get(op.identity).pipe : ThisPipe{T}()
        selectormap[tag] =
            !isnull(op.selector) ? get(op.selector).pipe : ThisPipe{T}()
        Ds = (Ds..., !isnull(op.identity) ? codomain(get(op.identity)) : T)
        Ss = (Ss..., !isnull(op.selector) ? codomain(get(op.selector)) : T)
    end
    scope = empty(base)
    input = Input(I)
    U = Union{Ts...}
    O = Pair{Symbol, U}
    output = Output(O, singular=false, complete=iscomplete)
    pipe = CoproductPipe{I,U}(Fs)
    identity = Query(
        scope,
        input=Input(O),
        output=Output(Pair{Symbol,Union{Ds...}}),
        pipe=IsoLiftPipe{U, Union{Ds...}}(identitymap))
    selector = Query(
        scope,
        input=Input(O),
        output=Output(Pair{Symbol,Union{Ss...}}),
        pipe=IsoLiftPipe{U, Union{Ss...}}(selectormap))
    defs = Dict{Symbol,Query}()
    for op in ops
        tag = get(op.tag)
        T = codomain(op)
        defs[get(op.tag)] =
            Query(
                op,
                input=Input(O),
                output=Output(T, complete=false),
                pipe=SwitchPipe{U,T}(tag))
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
    reqcomposable(base, op); reqsingular(op); reqcodomain(Bool, op)
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Bool, complete=complete(op))
    pipe = complete(op) ? IsoNotPipe{I}(op.pipe) : OptNotPipe{I}(op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:&, :|), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqsingular(op1, op2); reqcodomain(Bool, op1, op2)
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Bool, complete=complete(op1) && complete(op2))
    if fn == Fn{:&}
        pipe = complete(output) ?
            IsoAndPipe{I}(op1.pipe, op2.pipe) : OptAndPipe{I}(op1.pipe, op2.pipe)
    else
        pipe = complete(output) ?
            IsoOrPipe{I}(op1.pipe, op2.pipe) : OptOrPipe{I}(op1.pipe, op2.pipe)
    end
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(fn::Fn(:(==), :(!=)), base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqcodomain(codomain(op1), op2)
    singular(op1) || reqsingular(op2)
    T = codomain(op1)
    TT = Tuple{T,T}
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Bool, max(comode(op1), comode(op2)))
    PipeType = (fn == Fn{:(==)}) ? EQPipe : NEPipe
    pipe = singular(output) && complete(output) ?
        PipeType{I,T}(op1.pipe, op2.pipe) :
        (op1.pipe * op2.pipe) >> PipeType{TT,T}(IsoItemPipe{TT,T}(1), IsoItemPipe{TT,T}(2))
    return Query(scope, input=input, output=output, pipe=pipe)
end


macro compileunaryop(fn, Pipe, T1, T2)
    return esc(quote
        function compile(::Fn($fn), base::Query, op::Query)
            reqcomposable(base, op); reqcodomain($T1, op)
            scope = empty(base)
            I = codomain(base)
            input = Input(I)
            output = Output($T2, comode(op))
            pipe = singular(output) && complete(output) ?
                $Pipe{I}(op.pipe) :
                op.pipe >> $Pipe{$T1}(ThisPipe{$T1})
            return Query(scope, input=input, output=output, pipe=pipe)
        end
    end)
end

macro compilebinaryop(fn, Pipe, T1, T2, T3)
    return esc(quote
        function compile(::Fn($fn), base::Query, op1::Query, op2::Query)
            reqcomposable(base, op1, op2); reqcodomain($T1, op1); reqcodomain($T2, op2)
            singular(op1) || reqsingular(op2)
            T = Tuple{$T1,$T2}
            scope = empty(base)
            I = codomain(base)
            input = Input(I)
            output = Output($T3, max(comode(op1), comode(op2)))
            pipe = singular(output) && complete(output) ?
                $Pipe{I}(op1.pipe, op2.pipe) :
                (op1.pipe * op2.pipe) >> $Pipe{Tuple{$T1,$T2}}(IsoItemPipe{T,$T1}(1), IsoItemPipe{T,$T2}(2))
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


function compile(fn::Fn(:json), base::Query, flow::Query)
    flow = select(flow)
    if !isnull(flow.fields)
        parts = ()
        fields = ()
        for field in get(flow.fields)
            field = compile(fn, flow, field)
            if !isnull(field.tag)
                fields = (fields..., (get(field.tag) => field))
            end
        end
        I = domain(flow)
        O = codomain(flow)
        scope = empty(base)
        input = flow.input
        output = Output(Dict)   # FIXME: Union{Dict,Void}
        pipe = flow.pipe >> DictPipe{O}(fields)
        if singular(flow) && !complete(flow)
            pipe = OptToVoidPipe{I,Dict}(pipe)
        end
        flow = Query(scope, input=input, output=output, pipe=pipe, tag=flow.tag)
    else
        if singular(flow) && !complete(flow)
            I = domain(flow)
            O = codomain(flow)
            # FIXME: Union{O,Void}
            output = Output(O, exclusive=exclusive(flow), reachable=reachable(flow))
            pipe = OptToVoidPipe{I,O}(flow.pipe)
            flow = Query(flow, output=output, pipe=pipe)
        end
    end
    return flow
end


