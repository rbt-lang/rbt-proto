
function compile(state::AbstractScope, ::LiteralSyntax{Void})
    I = domain(state)
    input = Iso{I}
    output = Opt{Void}
    scope = scalar(state, Void)
    pipe = NullPipe{I, Void}()
    return Query(input, output, scope, pipe)
end


function compile{T}(state::AbstractScope, syntax::LiteralSyntax{T})
    I = domain(state)
    O = T
    input = Iso{I}
    output = Iso{O}
    scope = scalar(state, O)
    pipe = ConstPipe{I, O}(syntax.val)
    return Query(input, output, scope, pipe)
end


function compile(state::AbstractScope, syntax::ApplySyntax)
    if isempty(syntax.args)
        query = lookup(state, syntax.fn)
        if !isnull(query)
            return get(query)
        end
    end
    return compile(state, Fn{syntax.fn}, syntax.args...)
end


function compile(state::AbstractScope, syntax::ComposeSyntax)
    f = compile(state, syntax.f)
    g = compile(f, syntax.g)
    codomain(f) == domain(g) || error("incompatible operands: $syntax")
    I = domain(f)
    O = codomain(g)
    M = max(comode(f), comode(g))
    input = Iso{I}
    output = M{O}
    scope = g.scope
    pipe = f.pipe >> g.pipe
    return Query(input, output, scope, pipe)
end


compile{name}(state::AbstractScope, fn::Type{Fn{name}}, arg1::AbstractSyntax, args::AbstractSyntax...) =
    compile(state, fn, compile(state, arg1), map(arg -> compile(state, arg), args)...)


function compile(state::AbstractScope, ::Type{Fn{:count}}, op::Query)
    comode(op) == Seq || error("expected a plural expression: $op")
    I = domain(op)
    T = codomain(op)
    input = Iso{I}
    output = Iso{Int}
    scope = scalar(state, Int)
    pipe = CountPipe{I, T}(op.pipe)
    return Query(input, output, scope, pipe)
end

function compile(state::AbstractScope, ::Type{Fn{:max}}, op::Query)
    comode(op) == Seq || error("expected a plural expression: $op")
    codomain(op) == Int || error("expected an integer expression: $op")
    I = domain(op)
    input = Iso{I}
    output = Opt{Int}
    scope = scalar(state, Int)
    pipe = MaxPipe{I}(op.pipe)
    return Query(input, output, scope, pipe)
end

compile(state::AbstractScope, fn::Type{Fn{:select}}, base::AbstractSyntax, ops::AbstractSyntax...) =
    let base = compile(state, base)
        compile(state, fn, base, map(op -> compile(base, op), ops)...)
    end

function compile(state::AbstractScope, ::Type{Fn{:select}}, base::Query, ops::Query...)
    I = domain(base)
    T = codomain(base)
    O = Tuple{map(op -> datatype(op.output), ops)...}
    input = Iso{I}
    output = comode(base){O}
    scope = scalar(state, O)
    pipe = base.pipe >> TuplePipe{T,O}([op.pipe for op in ops])
    return Query(input, output, scope, pipe)
end


compile(state::AbstractScope, fn::Type{Fn{:filter}}, base::AbstractSyntax, op::AbstractSyntax) =
    let base = compile(state, base)
        compile(state, fn, base, compile(base, op))
    end

function compile(state::AbstractScope, ::Type{Fn{:filter}}, base::Query, op::Query)
    comode(base) == Seq || error("expected a plural expression: $base")
    comode(op) == Iso || error("expected a singular expresssion: $op")
    codomain(op) == Bool || error("expected a boolean expression: $op")
    I = domain(base)
    O = codomain(base)
    input = Iso{I}
    output = Seq{O}
    scope = base.scope
    pipe = base.pipe >> SievePipe{O}(op.pipe)
    return Query(input, output, scope, pipe)
end


macro compileunaryop(fn, Pipe, T1, T2)
    return esc(quote
        function compile(state::AbstractScope, ::Type{Fn{$fn}}, op::Query)
            comode(op) == Iso || error("expected a singular expression: $op")
            codomain(op) == $T1 || error("expected an expression of type $($T1): $(codomain(op))")
            I = domain(op)
            input = Iso{I}
            output = Iso{$T2}
            scope = scalar(state, $T2)
            pipe = $Pipe{I}(op.pipe)
            return Query(input, output, scope, pipe)
        end
    end)
end

macro compilebinaryop(fn, Pipe, T1, T2, T3)
    return esc(quote
        function compile(state::AbstractScope, ::Type{Fn{$fn}}, op1::Query, op2::Query)
            comode(op1) == Iso || error("expected a singular expression: $op1")
            codomain(op1) == $T1 || error("expected an expression of type $($T1): $(codomain(op1))")
            comode(op2) == Iso || error("expected a singular expression: $op2")
            codomain(op2) == $T2 || error("expected an expression of type $($T2): $(codomain(op2))")
            domain(op1) == domain(op2) || error("incompatible operands: $op1 and $op2")
            I = domain(state)
            input = Iso{I}
            output = Iso{$T3}
            scope = scalar(state, $T3)
            pipe = $Pipe{I}(op1.pipe, op2.pipe)
            return Query(input, output, scope, pipe)
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

