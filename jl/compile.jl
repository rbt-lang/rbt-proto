

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

reqtag(fs...) =
    for f in fs
        !isnull(f.tag) || error("expected a tagged expression: $f")
    end


function compile(base::Query, syntax::LiteralSyntax{Void})
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Void, complete=false)
    pipe = NullPipe{I, Void}()
    src = NullableSyntax(syntax)
    return Query(scope, input=input, output=output, pipe=pipe, src=src)
end


function compile{T}(base::Query, syntax::LiteralSyntax{T})
    scope = empty(base)
    I = codomain(base)
    O = T
    input = Input(I)
    output = Output(O)
    pipe = ConstPipe{I, O}(syntax.val)
    src = NullableSyntax(syntax)
    return Query(scope, input=input, output=output, pipe=pipe, src=src)
end


function compile(base::Query, syntax::ApplySyntax)
    src = NullableSyntax(syntax)
    if isempty(syntax.args)
        query = lookup(base, syntax.fn)
        if !isnull(query)
            return Query(get(query), src=src)
        end
    end
    return Query(compile(Fn{syntax.fn}, base, syntax.args...), src=src)
end


function compile(base::Query, syntax::ComposeSyntax)
    f = compile(base, syntax.f)
    g = compile(f, syntax.g)
    src = NullableSyntax(syntax)
    return Query(f >> g, src=src)
end


function >>(f::Query, g::Query)
    reqcomposable(f, g)
    I = domain(f)
    O = codomain(g)
    OM = max(comode(f), comode(g))
    input = Input(I)
    output = Output(O, OM)
    pipe = f.pipe >> g.pipe
    src = g.src
    if !isnull(f.src) && !isnull(g.src)
        src = NullableSyntax(ComposeSyntax(get(f.src), get(g.src)))
    end
    return Query(g, input=input, output=output, pipe=pipe, src=src)
end


compile{name}(fn::Type{Fn{name}}, base::Query, arg1::AbstractSyntax, args::AbstractSyntax...) =
    compile(fn, base, compile(base, arg1), [compile(base, arg) for arg in args]...)


function compile(::Type{Fn{:this}}, base::Query)
    T = codomain(base)
    input = Input(T)
    output = Output(T, exclusive=true, reachable=true)
    pipe = ThisPipe{T}()
    return Query(base, input=input, output=output, pipe=pipe)
end


function compile(::Type{Fn{:unlink}}, base::Query, arg::AbstractSyntax)
    scope = root(base)
    I = codomain(base)
    input = Input(I)
    output = Output(UnitType, reachable=true)
    pipe = ConstPipe{I, UnitType}(())
    root_base = Query(scope, input=input, output=output, pipe=pipe)
    return root_base >> compile(root_base, arg)
end


function compile(::Type{Fn{:count}}, base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    scope = empty(base)
    I = domain(flow)
    T = codomain(flow)
    input = Input(I)
    output = Output(Int)
    pipe = CountPipe{I, T}(flow.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Type{Fn{:max}}, base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow); reqcodomain(Int, flow)
    scope = empty(base)
    I = domain(flow)
    input = Input(I)
    output = Output(Int, complete=complete(flow))
    pipe = complete(flow) ? MaxPipe{I}(flow.pipe) : OptMaxPipe{I}(flow.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end

compile(fn::Type{Fn{:max}}, base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Type{Fn{:max}}, base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqcomplete(op); reqcodomain(Int, op)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=true, complete=complete(flow), exclusive=exclusive(flow))
    pipe = complete(flow) ?
        MaxByPipe{I,O}(flow.pipe, op.pipe) : OptMaxByPipe{I,O}(flow.pipe, op.pipe)
    return Query(flow, output=output, pipe=pipe)
end


function mkproduct(base::Query, fields::Query...)
    for field in fields
        @assert codomain(base) == domain(field) "$(codomain(base)) != $(domain(field))"
    end
    scope = empty(base)
    I = codomain(base)
    O = Tuple{[datatype(field.output) for field in fields]...}
    input = Input(I)
    output = Output(O)
    pipe = TuplePipe{I,O}([field.pipe for field in fields])
    parts = NullableQueries(fields)
    query = Query(scope, input=input, output=output, pipe=pipe, parts=parts)
    projections = [mkprojection(base, query, i) for (i, field) in enumerate(fields)]
    if any([!isnull(field.identity) for field in fields])
        identity = mkproduct(query, [identify(projection) for projection in projections]...)
        query = Query(query, identity=identity)
    end
    if any([!isnull(field.selector) for field in fields])
        selector = mkproduct(query, [select(projection) for projection in projections]...)
        query = Query(query, selector=selector)
    end
    return query
end


function mkprojection(base::Query, product::Query, index::Int)
    @assert codomain(base) == domain(product)
    @assert !isnull(product.parts) && 1 <= index <= length(get(product.parts))
    part = get(product.parts)[index]
    I = codomain(product)
    O = codomain(part)
    input = Input(I)
    pipe =
        singular(part) && complete(part) ? IsoItemPipe{I,O}(index) :
        singular(part) ? OptItemPipe{I,O}(index) : SeqItemPipe{I,O}(index)
    return Query(part, input=input, pipe=pipe)
end


function compile(::Type{Fn{:record}}, base::Query, ops::Query...)
    reqcomposable(base, ops...)
    return mkproduct(base, ops...)
end


compile(fn::Type{Fn{:select}}, base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(::Type{Fn{:select}}, base::Query, flow::Query, ops::Query...)
    reqcomposable(base, flow)
    reqcomposable(flow, ops...)
    parts = ops
    ops = tuple([select(op) for op in ops]...)
    scope = empty(flow)
    I = codomain(flow)
    O = Tuple{[datatype(op.output) for op in ops]...}
    input = Input(I)
    output = Output(O)
    pipe = TuplePipe{I,O}([op.pipe for op in ops])
    selector = Query(scope, input=input, output=output, pipe=pipe, parts=parts)
    return Query(flow, selector=selector, parts=parts)
end


compile(fn::Type{Fn{:filter}}, base::Query, flow::AbstractSyntax, op::AbstractSyntax) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op))
    end

function compile(::Type{Fn{:filter}}, base::Query, flow::Query, op::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, op); reqsingular(op); reqcomplete(op); reqcodomain(Bool, op)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(op))
    pipe = flow.pipe >> SievePipe{O}(op.pipe)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Type{Fn{:reverse}}, base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    pipe = ReversePipe{I,O}(flow.pipe)
    return Query(flow, pipe=pipe)
end


function compile(::Type{Fn{:first}}, base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, complete=complete(flow), exclusive=exclusive(flow))
    pipe = complete(flow) ? IsoFirstPipe{I,O}(flow.pipe) : OptFirstPipe{I,O}(flow.pipe)
    return Query(flow, output=output, pipe=pipe)
end

function compile(::Type{Fn{:first}}, base::Query, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqcomplete(size); reqcodomain(Int, size)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(flow))
    pipe = SeqFirstPipe{I,O}(flow.pipe, size.pipe)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Type{Fn{:last}}, base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, complete=complete(flow), exclusive=exclusive(flow))
    pipe = complete(flow) ? IsoLastPipe{I,O}(flow.pipe) : OptLastPipe{I,O}(flow.pipe)
    return Query(flow, output=output, pipe=pipe)
end

function compile(::Type{Fn{:last}}, base::Query, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqcomplete(size); reqcodomain(Int, size)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(flow))
    pipe = SeqLastPipe{I,O}(flow.pipe, size.pipe)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Type{Fn{:take}}, base::Query, flow::Query, size::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size); reqsingular(size); reqcomplete(size); reqcodomain(Int, size)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(flow))
    pipe = TakePipe{I,O}(flow.pipe, size.pipe, ConstPipe{I,Int}(0))
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Type{Fn{:take}}, base::Query, flow::Query, size::Query, skip::Query)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(base, size, skip); reqsingular(size, skip)
    reqcomplete(size, skip); reqcodomain(Int, size, skip)
    I = domain(flow)
    O = codomain(flow)
    output = Output(O, singular=false, complete=false, exclusive=exclusive(flow))
    pipe = TakePipe{I,O}(flow.pipe, size.pipe, skip.pipe)
    return Query(flow, output=output, pipe=pipe)
end


function compile(::Type{Fn{:get}}, base::Query, flow::Query, key::Query)
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


function compile(::Type{Fn{:asc}}, base::Query, op::Query)
    return Query(op, order=1)
end


function compile(::Type{Fn{:desc}}, base::Query, op::Query)
    return Query(op, order=-1)
end


compile(fn::Type{Fn{:sort}}, base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, [compile(flow, op) for op in ops]...)
    end

function compile(::Type{Fn{:sort}}, base::Query, flow::Query, ops::Query...)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, ops...); reqsingular(ops...); reqcomplete(ops...)
    I = domain(flow)
    O = codomain(flow)
    if isempty(ops)
        if isnull(flow.identity)
            pipe = SortPipe{I,O}(flow.pipe, flow.order)
        else
            cap = get(flow.identity)
            @assert singular(cap) && complete(cap) && exclusive(cap)
            K = codomain(cap)
            pipe = SortByPipe{I,O,K}(flow.pipe, cap.pipe, flow.order)
        end
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


function compile(::Type{Fn{:unique}}, base::Query, flow::Query)
    reqcomposable(base, flow); reqplural(flow)
    I = domain(flow)
    O = codomain(flow)
    output = Output(
        O, singular=false, complete=complete(flow),
        exclusive=true, reachable=reachable(flow))
    if isnull(flow.identity)
        PipeType = exclusive(flow) ? SortPipe : UniquePipe
        pipe = PipeType{I,O}(flow.pipe, flow.order)
    else
        cap = get(flow.identity)
        @assert singular(cap) && complete(cap) && exclusive(cap)
        K = codomain(cap)
        PipeType = exclusive(flow) ? SortByPipe : UniqueByPipe
        pipe = UniqueByPipe{I,O,K}(flow.pipe, cap.pipe, flow.order)
    end
    return Query(flow, output=output, pipe=pipe)
end


compile(fn::Type{Fn{:by}}, base::Query, flow::AbstractSyntax, op1::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        compile(fn, base, flow, compile(flow, op1), [compile(flow, op) for op in ops]...)
    end

function compile(::Type{Fn{:by}}, base::Query, flow::Query, ops::Query...)
    reqcomposable(base, flow); reqplural(flow)
    reqcomposable(flow, ops...); reqsingular(ops...); reqcomplete(ops...)
    kernel = mkproduct(flow, ops...)
    key = !isnull(kernel.identity) ? get(kernel.identity) : compile(Fn{:this}, kernel)
    I = codomain(base)
    K = codomain(kernel)
    U = codomain(key)
    V = codomain(flow)
    O = Tuple{K,Vector{V}}
    scope = empty(base)
    input = Input(I)
    output = Output(O, singular=false, complete=true)
    pipe = GroupByPipe{I,K,U,V}(flow.pipe, kernel.pipe, key.pipe, 0)
    parts = (
        Query(kernel, input=Input(O), pipe=IsoItemPipe{O,K}(1)),
        Query(
            flow,
            input=Input(O),
            output=Output(
                V, singular=false, complete=true,
                exclusive=exclusive(flow), reachable=reachable(flow)),
            pipe=SeqItemPipe{O,V}(2)))
    query = Query(scope, input=input, output=output, pipe=pipe, parts=parts)
    kerproj = mkprojection(base, query, 1)
    valproj = mkprojection(base, query, 2)
    identity = identify(kerproj)
    items = []
    defs = Dict{Symbol, Query}()
    for (i, op) in enumerate(ops)
        itemproj = kerproj >> mkprojection(query, kerproj, i)
        if !isnull(itemproj.tag)
            defs[get(itemproj.tag)] = itemproj
        end
        push!(items, itemproj)
    end
    if !isnull(valproj.tag)
        defs[get(valproj.tag)] = valproj
    end
    push!(items, valproj)
    selector = select(mkproduct(query, items...))
    return Query(query, identity=identity, selector=selector, defs=defs)
end


function compile(::Type{Fn{:as}}, base::Query, op::AbstractSyntax, ident::AbstractSyntax)
    (isa(ident, ApplySyntax) && isempty(ident.args)) || error("expected an identifier: $ident")
    return Query(compile(base, op), tag=NullableSymbol(ident.fn))
end


compile(::Type{Fn{:(=>)}}, base::Query, ident::AbstractSyntax, op::AbstractSyntax) =
    compile(Fn{:as}, base, op, ident)


compile(fn::Type{Fn{:define}}, base::Query, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow)
        for op in ops
            flow = compile(fn, base, flow, compile(flow, op))
        end
        flow
    end


function compile(::Type{Fn{:define}}, base::Query, flow::Query, op::Query)
    reqcomposable(base, flow)
    reqcomposable(flow, op); reqtag(op)
    defs = merge(flow.defs, Dict(get(op.tag) => op))
    return Query(flow, defs=defs)
end


function compile(::Type{Fn{:!}}, base::Query, op::Query)
    reqcomposable(base, op); reqsingular(op); reqcodomain(Bool, op)
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Bool, complete=complete(op))
    pipe = complete(op) ? IsoNotPipe{I}(op.pipe) : OptNotPipe{I}(op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Type{Fn{:&}}, base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqsingular(op1, op2); reqcodomain(Bool, op1, op2)
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Bool, complete=complete(op1) && complete(op2))
    pipe = complete(output) ?
        IsoAndPipe{I}(op1.pipe, op2.pipe) : OptAndPipe{I}(op1.pipe, op2.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(::Type{Fn{:|}}, base::Query, op1::Query, op2::Query)
    reqcomposable(base, op1, op2); reqsingular(op1, op2); reqcodomain(Bool, op1, op2)
    scope = empty(base)
    I = codomain(base)
    input = Input(I)
    output = Output(Bool)
    output = Output(Bool, complete=complete(op1) && complete(op2))
    pipe = complete(output) ?
        IsoOrPipe{I}(op1.pipe, op2.pipe) : OptOrPipe{I}(op1.pipe, op2.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


macro compileunaryop(fn, Pipe, T1, T2)
    return esc(quote
        function compile(::Type{Fn{$fn}}, base::Query, op::Query)
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
        function compile(::Type{Fn{$fn}}, base::Query, op1::Query, op2::Query)
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
@compilebinaryop(:(==), EQPipe, Int, Int, Bool)
@compilebinaryop(:(!=), NEPipe, Int, Int, Bool)
@compilebinaryop(:(>=), GEPipe, Int, Int, Bool)
@compilebinaryop(:(>), GTPipe, Int, Int, Bool)
@compilebinaryop(:(+), AddPipe, Int, Int, Int)
@compilebinaryop(:(-), SubPipe, Int, Int, Int)
@compilebinaryop(:(*), MulPipe, Int, Int, Int)
@compilebinaryop(:(/), DivPipe, Int, Int, Int)


function compile(fn::Type{Fn{:json}}, base::Query, flow::Query)
    if !isnull(flow.selector) && !isnull(get(flow.selector).parts)
        parts = ()
        fields = ()
        for part in get(get(flow.selector).parts)
            part = compile(fn, flow, part)
            if !isnull(part.tag)
                field = isnull(part.selector) ? part.pipe : part.pipe >> get(part.selector).pipe
                if singular(part) && !complete(part)
                    field = OptToVoidPipe(field)
                end
                fields = (fields..., (get(part.tag) => field))
            end
        end
        I = codomain(flow)
        pipe = DictPipe{I}(fields)
        output = Output(Dict)
        selector = Query(get(flow.selector), output=output, pipe=pipe)
        flow = Query(flow, selector=selector)
    else
        flow = select(flow)
        if singular(flow) && !complete(flow)
            I = domain(flow)
            O = codomain(flow)
            # FIXME:
            #output = Output(Union{O,Void}, exclusive=exclusive(flow), reachable=reachable(flow))
            output = Output(O, exclusive=exclusive(flow), reachable=reachable(flow))
            pipe = OptToVoidPipe{I,O}(flow.pipe)
            flow = Query(flow, output=output, pipe=pipe)
        end
    end
    return flow
end


function select(q::Query)
    return Query(isnull(q.selector) ? q : q >> get(q.selector), src=q.src, origin=q)
end

function identify(q::Query)
    return Query(isnull(q.identity) ? q : q >> get(q.identity), src=q.src, origin=q)
end

