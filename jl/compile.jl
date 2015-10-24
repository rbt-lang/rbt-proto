
function compile(state::Query, ::LiteralSyntax{Void})
    scope = empty(state)
    I = codomain(state)
    input = Iso{I}
    output = Opt{Void}
    pipe = NullPipe{I, Void}()
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile{T}(state::Query, syntax::LiteralSyntax{T})
    scope = empty(state)
    I = codomain(state)
    O = T
    input = Iso{I}
    output = Iso{O}
    pipe = ConstPipe{I, O}(syntax.val)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(state::Query, syntax::ApplySyntax)
    if isempty(syntax.args)
        query = lookup(state, syntax.fn)
        if !isnull(query)
            return get(query)
        end
    end
    return compile(state, Fn{syntax.fn}, syntax.args...)
end


function compile(state::Query, syntax::ComposeSyntax)
    f = compile(state, syntax.f)
    g = compile(f, syntax.g)
    return f >> g
end


function >>(f::Query, g::Query)
    codomain(f) == domain(g) || error("incompatible operands: $f and $g")
    I = domain(f)
    O = codomain(g)
    M = max(comode(f), comode(g))
    input = Iso{I}
    output = M{O}
    pipe = f.pipe >> g.pipe
    return Query(g, input=input, output=output, pipe=pipe)
end


compile{name}(state::Query, fn::Type{Fn{name}}, arg1::AbstractSyntax, args::AbstractSyntax...) =
    compile(state, fn, compile(state, arg1), map(arg -> compile(state, arg), args)...)


function compile(state::Query, ::Type{Fn{:this}})
    T = codomain(state)
    input = Iso{T}
    output = Iso{T}
    pipe = ThisPipe{T}()
    return Query(state, input=input, output=output, pipe=pipe)
end


function compile(state::Query, ::Type{Fn{:count}}, op::Query)
    codomain(state) == domain(op) || error("incompatible operand: $op")
    comode(op) == Seq || error("expected a plural expression: $op")
    scope = empty(state)
    I = domain(op)
    T = codomain(op)
    input = Iso{I}
    output = Iso{Int}
    pipe = CountPipe{I, T}(op.pipe)
    return Query(scope, input=input, output=output, pipe=pipe)
end


function compile(state::Query, ::Type{Fn{:max}}, op::Query)
    codomain(state) == domain(op) || error("incompatible operand: $op")
    comode(op) == Seq || error("expected a plural expression: $op")
    codomain(op) == Int || error("expected an integer expression: $op")
    scope = empty(state)
    I = domain(op)
    input = Iso{I}
    output = Opt{Int}
    pipe = MaxPipe{I}(op.pipe)
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
    ops = tuple(map(op -> finalize(op), ops)...)
    scope = empty(base)
    I = codomain(base)
    O = Tuple{map(op -> datatype(op.output), ops)...}
    input = Iso{I}
    output = Iso{O}
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
    comode(base) == Seq || error("expected a plural expression: $base")
    comode(op) == Iso || error("expected a singular expresssion: $op")
    codomain(op) == Bool || error("expected a boolean expression: $op")
    O = codomain(base)
    pipe = base.pipe >> SievePipe{O}(op.pipe)
    return Query(base, pipe=pipe)
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
    comode(base) == Seq || error("expected a plural expression: $base")
    I = domain(base)
    O = codomain(base)
    if isempty(ops)
        if isnull(base.cap)
            pipe = SortPipe{I,O}(base.pipe, base.order)
        else
            cap = get(base.cap)
            comode(cap) == Iso || error("expected a singular expression: $cap")
            K = codomain(cap)
            pipe = SortByPipe{I,O,K}(base.pipe, cap.pipe, base.order)
        end
    else
        pipe = base.pipe
        for op in reverse(ops)
            order = op.order
            op = finalize(op)
            comode(op) == Iso || error("expected a singular expression: $op")
            K = codomain(op)
            pipe = SortByPipe{I,O,K}(pipe, op.pipe, order)
        end
    end
    return Query(base, pipe=pipe)
end


macro compileunaryop(fn, Pipe, T1, T2)
    return esc(quote
        function compile(state::Query, ::Type{Fn{$fn}}, op::Query)
            codomain(state) == domain(op) || error("incompatible operand: $op")
            comode(op) == Iso || error("expected a singular expression: $op")
            codomain(op) == $T1 || error("expected an expression of type $($T1): $(codomain(op))")
            scope = empty(state)
            I = codomain(state)
            input = Iso{I}
            output = Iso{$T2}
            pipe = $Pipe{I}(op.pipe)
            return Query(scope, input=input, output=output, pipe=pipe)
        end
    end)
end

macro compilebinaryop(fn, Pipe, T1, T2, T3)
    return esc(quote
        function compile(state::Query, ::Type{Fn{$fn}}, op1::Query, op2::Query)
            codomain(state) == domain(op1) || error("incompatible operand: $op1")
            comode(op1) == Iso || error("expected a singular expression: $op1")
            codomain(op1) == $T1 || error("expected an expression of type $($T1): $(codomain(op1))")
            codomain(state) == domain(op2) || error("incompatible operand: $op2")
            comode(op2) == Iso || error("expected a singular expression: $op2")
            codomain(op2) == $T2 || error("expected an expression of type $($T2): $(codomain(op2))")
            scope = empty(state)
            I = codomain(state)
            input = Iso{I}
            output = Iso{$T3}
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


function finalize(q::Query)
    return Query(isnull(q.cap) ? q : q >> get(q.cap), state=q)
end

