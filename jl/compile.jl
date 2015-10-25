
function compile(state::Query, syntax::LiteralSyntax{Void})
    scope = empty(state)
    I = codomain(state)
    input = Input(I)
    output = Output(Void, total=false)
    pipe = NullPipe{I, Void}()
    src = NullableSyntax(syntax)
    return Query(scope, input=input, output=output, pipe=pipe, src=src)
end


function compile{T}(state::Query, syntax::LiteralSyntax{T})
    scope = empty(state)
    I = codomain(state)
    O = T
    input = Input(I)
    output = Output(O)
    pipe = ConstPipe{I, O}(syntax.val)
    src = NullableSyntax(syntax)
    return Query(scope, input=input, output=output, pipe=pipe, src=src)
end


function compile(state::Query, syntax::ApplySyntax)
    src = NullableSyntax(syntax)
    if isempty(syntax.args)
        query = lookup(state, syntax.fn)
        if !isnull(query)
            return Query(get(query), src=src)
        end
    end
    return Query(compile(state, Fn{syntax.fn}, syntax.args...), src=src)
end


function compile(state::Query, syntax::ComposeSyntax)
    f = compile(state, syntax.f)
    g = compile(f, syntax.g)
    src = NullableSyntax(syntax)
    return Query(f >> g, src=src)
end


function >>(f::Query, g::Query)
    codomain(f) == domain(g) || error("incompatible operands: $f and $g")
    I = domain(f)
    O = codomain(g)
    M = max(comode(f), comode(g))
    input = Input(I)
    output = Output(O, M)
    pipe = f.pipe >> g.pipe
    src = g.src
    if !isnull(f.src) && !isnull(g.src)
        src = NullableSyntax(ComposeSyntax(get(f.src), get(g.src)))
    end
    return Query(g, input=input, output=output, pipe=pipe, src=src)
end


compile{name}(state::Query, fn::Type{Fn{name}}, arg1::AbstractSyntax, args::AbstractSyntax...) =
    compile(state, fn, compile(state, arg1), map(arg -> compile(state, arg), args)...)


function compile(state::Query, ::Type{Fn{:this}})
    T = codomain(state)
    input = Input(T)
    output = Output(T, unique=true, reachable=true)
    pipe = ThisPipe{T}()
    return Query(state, input=input, output=output, pipe=pipe)
end


function compile(state::Query, ::Type{Fn{:count}}, op::Query)
    codomain(state) == domain(op) || error("incompatible operand: $op")
    !singular(op) || error("expected a plural expression: $op")
    scope = empty(state)
    I = domain(op)
    T = codomain(op)
    input = Input(I)
    output = Output(Int)
    pipe = CountPipe{I, T}(op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(state::Query, ::Type{Fn{:max}}, op::Query)
    codomain(state) == domain(op) || error("incompatible operand: $op")
    !singular(op) || error("expected a plural expression: $op")
    codomain(op) == Int || error("expected an integer expression: $op")
    scope = empty(state)
    I = domain(op)
    input = Input(I)
    output = Output(Int, total=total(op))
    if total(op)
        pipe = MaxPipe{I}(op.pipe)
    else
        pipe = OptMaxPipe{I}(op.pipe)
    end
    return Query(scope, input=input, output=output, pipe=pipe)
end


compile(state::Query, fn::Type{Fn{:select}}, base::AbstractSyntax, ops::AbstractSyntax...) =
    let base = compile(state, base)
        compile(state, fn, base, map(op -> compile(base, op), ops)...)
    end

function compile(state::Query, ::Type{Fn{:select}}, base::Query, ops::Query...)
    codomain(state) == domain(base) || error("incompatible operand: $base")
    for op in ops
        codomain(base) == domain(op) || error("incompatible operands: $base and $op")
    end
    items = ops
    ops = tuple(map(op -> fasten(op), ops)...)
    scope = empty(base)
    I = codomain(base)
    O = Tuple{map(op -> datatype(op.output), ops)...}
    input = Input(I)
    output = Output(O)
    pipe = TuplePipe{I,O}([op.pipe for op in ops])
    cap = Query(scope, input=input, output=output, pipe=pipe)
    return Query(base, cap=cap, items=ops)
end


compile(state::Query, fn::Type{Fn{:filter}}, base::AbstractSyntax, op::AbstractSyntax) =
    let base = compile(state, base)
        compile(state, fn, base, compile(base, op))
    end

function compile(state::Query, ::Type{Fn{:filter}}, base::Query, op::Query)
    codomain(state) == domain(base) || error("incompatible operand: $base")
    codomain(base) == domain(op) || error("incompatible operands: $base and $op")
    !singular(base) || error("expected a plural expression: $base")
    singular(op) || error("expected a singular expresssion: $op")
    total(op) || error("expected a total expresssion: $op")
    codomain(op) == Bool || error("expected a boolean expression: $op")
    O = codomain(base)
    output = Output(O, singular=false, total=false, unique=unique(op))
    pipe = base.pipe >> SievePipe{O}(op.pipe)
    return Query(base, output=output, pipe=pipe)
end


function compile(state::Query, ::Type{Fn{:asc}}, op::Query)
    return Query(op, order=1)
end


function compile(state::Query, ::Type{Fn{:desc}}, op::Query)
    return Query(op, order=-1)
end


compile(state::Query, fn::Type{Fn{:sort}}, base::AbstractSyntax, ops::AbstractSyntax...) =
    let base = compile(state, base)
        compile(state, fn, base, map(op -> compile(base, op), ops)...)
    end

function compile(state::Query, ::Type{Fn{:sort}}, base::Query, ops::Query...)
    codomain(state) == domain(base) || error("incompatible operand: $base")
    for op in ops
        codomain(base) == domain(op) || error("incompatible operands: $base and $op")
    end
    !singular(base) || error("expected a plural expression: $base")
    I = domain(base)
    O = codomain(base)
    if isempty(ops)
        if isnull(base.cap)
            pipe = SortPipe{I,O}(base.pipe, base.order)
        else
            cap = get(base.cap)
            singular(cap) || error("expected a singular expression: $cap")
            total(cap) || error("expected a total expression: $cap")
            K = codomain(cap)
            pipe = SortByPipe{I,O,K}(base.pipe, cap.pipe, base.order)
        end
    else
        pipe = base.pipe
        for op in reverse(ops)
            order = op.order
            op = fasten(op)
            singular(op) || error("expected a singular expression: $op")
            total(op) || error("expected a total expression: $op")
            K = codomain(op)
            pipe = SortByPipe{I,O,K}(pipe, op.pipe, order)
        end
    end
    return Query(base, pipe=pipe)
end


function compile(state::Query, ::Type{Fn{:as}}, base::AbstractSyntax, ident::AbstractSyntax)
    (isa(ident, ApplySyntax) && isempty(ident.args)) || error("expected an identifier: $ident")
    return Query(compile(state, base), tag=NullableSymbol(ident.fn))
end


compile(state::Query, ::Type{Fn{:(=>)}}, ident::AbstractSyntax, base::AbstractSyntax) =
    compile(state, Fn{:as}, base, ident)


compile(state::Query, fn::Type{Fn{:define}}, base::AbstractSyntax, ops::AbstractSyntax...) =
    let base = compile(state, base)
        compile(state, fn, base, map(op -> compile(base, op), ops)...)
    end


function compile(state::Query, ::Type{Fn{:define}}, base::Query, ops::Query...)
    codomain(state) == domain(base) || error("incompatible operand: $base")
    for op in ops
        codomain(base) == domain(op) || error("incompatible operands: $base and $op")
    end
    attrs = base.attrs
    for op in ops
        !isnull(op.tag) || error("expected a named expression: $op")
        attrs = merge(attrs, Dict(get(op.tag) => op))
    end
    return Query(base, attrs=attrs)
end


macro compileunaryop(fn, Pipe, T1, T2)
    return esc(quote
        function compile(state::Query, ::Type{Fn{$fn}}, op::Query)
            codomain(state) == domain(op) || error("incompatible operand: $op")
            singular(op) || error("expected a singular expression: $op")
            total(op) || error("expected a total expression: $op")
            codomain(op) == $T1 || error("expected an expression of type $($T1): $(codomain(op))")
            scope = empty(state)
            I = codomain(state)
            input = Input(I)
            output = Output($T2)
            pipe = $Pipe{I}(op.pipe)
            return Query(scope, input=input, output=output, pipe=pipe)
        end
    end)
end

macro compilebinaryop(fn, Pipe, T1, T2, T3)
    return esc(quote
        function compile(state::Query, ::Type{Fn{$fn}}, op1::Query, op2::Query)
            codomain(state) == domain(op1) || error("incompatible operand: $op1")
            singular(op1) || error("expected a singular expression: $op1")
            total(op1) || error("expected a total expression: $op1")
            codomain(op1) == $T1 || error("expected an expression of type $($T1): $(codomain(op1))")
            codomain(state) == domain(op2) || error("incompatible operand: $op2")
            singular(op2) || error("expected a singular expression: $op2")
            total(op2) || error("expected a total expression: $op2")
            codomain(op2) == $T2 || error("expected an expression of type $($T2): $(codomain(op2))")
            scope = empty(state)
            I = codomain(state)
            input = Input(I)
            output = Output($T3)
            pipe = $Pipe{I}(op1.pipe, op2.pipe)
            return Query(scope, input=input, output=output, pipe=pipe)
        end
    end)
end

@compileunaryop(:(!), NotPipe, Bool, Bool)
@compileunaryop(:(+), PosPipe, Int, Int)
@compileunaryop(:(-), NegPipe, Int, Int)

@compilebinaryop(:(<), LTPipe, Int, Int, Bool)
@compilebinaryop(:(<=), LEPipe, Int, Int, Bool)
@compilebinaryop(:(==), EQPipe, Int, Int, Bool)
@compilebinaryop(:(!=), NEPipe, Int, Int, Bool)
@compilebinaryop(:(>=), GEPipe, Int, Int, Bool)
@compilebinaryop(:(>), GTPipe, Int, Int, Bool)
@compilebinaryop(:(&), AndPipe, Bool, Bool, Bool)
@compilebinaryop(:(|), OrPipe, Bool, Bool, Bool)
@compilebinaryop(:(+), AddPipe, Int, Int, Int)
@compilebinaryop(:(-), SubPipe, Int, Int, Int)
@compilebinaryop(:(*), MulPipe, Int, Int, Int)
@compilebinaryop(:(/), DivPipe, Int, Int, Int)


function fasten(q::Query)
    return Query(isnull(q.cap) ? q : q >> get(q.cap), origin=q, src=q.src)
end

