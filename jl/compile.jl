
module Compile

export
    compile

using RBT.Parse
using RBT.Databases
using RBT.Pipes

import Base: isless, show
import RBT.Pipes: domain, codomain


abstract Mode{T}
abstract Iso{T} <: Mode{T}
abstract Opt{T} <: Mode{T}
abstract Seq{T} <: Mode{T}

domain{T}(::Type{Iso{T}}) = T
domain{T}(::Type{Opt{T}}) = T
domain{T}(::Type{Seq{T}}) = T

mode{T}(::Type{Iso{T}}) = Iso
mode{T}(::Type{Opt{T}}) = Opt
mode{T}(::Type{Seq{T}}) = Seq

datatype{T}(::Type{Iso{T}}) = T
datatype{T}(::Type{Opt{T}}) = Nullable{T}
datatype{T}(::Type{Seq{T}}) = Vector{T}

isless(::Type{Iso}, ::Type{Iso}) = false
isless(::Type{Iso}, ::Type{Opt}) = true
isless(::Type{Iso}, ::Type{Seq}) = true
isless(::Type{Opt}, ::Type{Iso}) = false
isless(::Type{Opt}, ::Type{Opt}) = false
isless(::Type{Opt}, ::Type{Seq}) = true
isless(::Type{Seq}, ::Type{Iso}) = false
isless(::Type{Seq}, ::Type{Opt}) = false
isless(::Type{Seq}, ::Type{Seq}) = false


abstract AbstractScope


immutable RootScope <: AbstractScope
    db::Database
end

show(io::IO, ::RootScope) = print(io, "ROOT")

domain(::RootScope) = Tuple{}


immutable ClassScope <: AbstractScope
    db::Database
    name::Symbol
end

show(io::IO, s::ClassScope) = print(io, "Class(<", s.name, ">)")

domain(s::ClassScope) = Entity{s.name}


immutable ScalarScope <: AbstractScope
    db::Database
    dom::DataType
end

show(io::IO, s::ScalarScope) = print(io, "Scalar(", s.dom, ")")

domain(s::ScalarScope) = s.dom


immutable Flow
    input::DataType
    output::DataType
    scope::AbstractScope
    pipe::AbstractPipe
end

call(f::Flow, args...) = f.pipe(args...)

show(io::IO, f::Flow) =
    f.input == Iso{Tuple{}} ?
        print(io, f.pipe, " : ", datatype(f.output)) :
        print(io, f.pipe, " : ", datatype(f.input), " -> ", datatype(f.output))

domain(f::Flow) = domain(f.input)
mode(f::Flow) = mode(f.input)
codomain(f::Flow) = domain(f.output)
comode(f::Flow) = mode(f.output)


immutable Fn{name}
end


compile(db::Database, str::AbstractString) = compile(RootScope(db), query(str))
compile(db::Database, syn::AbstractSyntax) = compile(RootScope(db), syn)
compile(s::AbstractScope, str::AbstractString) = compile(s, query(str))
compile(f::Flow, str::AbstractString) = compile(f.scope, query(str))
compile(f::Flow, syn::AbstractSyntax) = compile(f.scope, syn)


function compile(s::AbstractScope, ::LiteralSyntax{Void})
    I = domain(s)
    input = Iso{I}
    output = Opt{Void}
    scope = ScalarScope(s.db, Void)
    pipe = NullPipe{I, Void}()
    return Flow(input, output, scope, pipe)
end


function compile{T}(s::AbstractScope, syn::LiteralSyntax{T})
    I = domain(s)
    O = T
    input = Iso{I}
    output = Iso{O}
    scope = ScalarScope(s.db, O)
    pipe = ConstPipe{domain(s), O}(syn.val)
    return Flow(input, output, scope, pipe)
end


function compile(s::AbstractScope, syn::ApplySyntax)
    if isempty(syn.args)
        maybe_flow = lookup(s, syn.fn)
        if !isnull(maybe_flow)
            return get(maybe_flow)
        end
    end
    return compile(s, Fn{syn.fn}, syn.args...)
end


function compile(s::AbstractScope, syn::ComposeSyntax)
    f = compile(s, syn.f)
    g = compile(f, syn.g)
    codomain(f) == domain(g) || error("incompatible operands: $syn")
    I = domain(f)
    O = codomain(g)
    M = max(comode(f), comode(g))
    input = Iso{I}
    output = M{O}
    scope = g.scope
    pipe = f.pipe >> g.pipe
    return Flow(input, output, scope, pipe)
end


compile{name}(s::AbstractScope, fn::Type{Fn{name}}, syn0::AbstractSyntax, syns::AbstractSyntax...) =
    compile(s, fn, compile(s, syn0), map(syn -> compile(s, syn), syns)...)


function compile(s::AbstractScope, ::Type{Fn{:count}}, op::Flow)
    comode(op) == Seq || error("expected a plural expression: $op")
    I = domain(op)
    T = codomain(op)
    input = Iso{I}
    output = Iso{Int}
    scope = ScalarScope(s.db, Int)
    pipe = CountPipe{I, T}(op.pipe)
    return Flow(input, output, scope, pipe)
end

function compile(s::AbstractScope, ::Type{Fn{:max}}, op::Flow)
    comode(op) == Seq || error("expected a plural expression: $op")
    codomain(op) == Int || error("expected an integer expression: $op")
    I = domain(op)
    input = Iso{I}
    output = Opt{Int}
    scope = ScalarScope(s.db, Int)
    pipe = MaxPipe{I}(op.pipe)
    return Flow(input, output, scope, pipe)
end

compile(s::AbstractScope, fn::Type{Fn{:select}}, base::AbstractSyntax, ops::AbstractSyntax...) =
    let base = compile(s, base)
        compile(s, fn, base, map(op -> compile(base, op), ops)...)
    end

function compile(s::AbstractScope, ::Type{Fn{:select}}, base::Flow, ops::Flow...)
    I = domain(base)
    T = codomain(base)
    O = Tuple{map(op -> datatype(op.output), ops)...}
    input = Iso{I}
    output = comode(base){O}
    scope = ScalarScope(s.db, O)
    pipe = base.pipe >> TuplePipe{T,O}([op.pipe for op in ops])
    return Flow(input, output, scope, pipe)
end


compile(s::AbstractScope, fn::Type{Fn{:filter}}, base::AbstractSyntax, op::AbstractSyntax) =
    let base = compile(s, base)
        compile(s, fn, base, compile(base, op))
    end

function compile(s::AbstractScope, ::Type{Fn{:filter}}, base::Flow, op::Flow)
    comode(base) == Seq || error("expected a plural expression: $base")
    comode(op) == Iso || error("expected a singular expresssion: $op")
    codomain(op) == Bool || error("expected a boolean expression: $op")
    I = domain(base)
    O = codomain(base)
    input = Iso{I}
    output = Seq{O}
    scope = base.scope
    pipe = base.pipe >> SievePipe{O}(op.pipe)
    return Flow(input, output, scope, pipe)
end


macro defunaryop(name, pipe, T1, T2)
    return esc(quote
        function compile(s::AbstractScope, ::Type{Fn{$name}}, op::Flow)
            comode(op) == Iso || error("expected a singular expression: $op")
            codomain(op) == $T1 || error("expected an expression of type $($T1): $(codomain(op))")
            I = domain(op)
            input = Iso{I}
            output = Iso{$T2}
            scope = ScalarScope(s.db, $T2)
            pipe = $pipe{I}(op.pipe)
            return Flow(input, output, scope, pipe)
        end
    end)
end

macro defbinaryop(name, pipe, T1, T2, T3)
    return esc(quote
        function compile(s::AbstractScope, ::Type{Fn{$name}}, op1::Flow, op2::Flow)
            comode(op1) == Iso || error("expected a singular expression: $op1")
            codomain(op1) == $T1 || error("expected an expression of type $($T1): $(codomain(op1))")
            comode(op2) == Iso || error("expected a singular expression: $op2")
            codomain(op2) == $T2 || error("expected an expression of type $($T2): $(codomain(op2))")
            domain(op1) == domain(op2) || error("incompatible operands: $op1 and $op2")
            I = domain(op1)
            input = Iso{I}
            output = Iso{$T3}
            scope = ScalarScope(s.db, $T3)
            pipe = $pipe{I}(op1.pipe, op2.pipe)
            return Flow(input, output, scope, pipe)
        end
    end)
end

@defunaryop(:(!), NotPipe, Bool, Bool)
@defunaryop(:(+), PosPipe, Int, Int)
@defunaryop(:(-), NegPipe, Int, Int)

@defbinaryop(:(<), LTPipe, Int, Int, Bool)
@defbinaryop(:(<=), LEPipe, Int, Int, Bool)
@defbinaryop(:(==), EQPipe, Int, Int, Bool)
@defbinaryop(:(!=), NEPipe, Int, Int, Bool)
@defbinaryop(:(>=), GEPipe, Int, Int, Bool)
@defbinaryop(:(>), GTPipe, Int, Int, Bool)
@defbinaryop(:(&), AndPipe, Bool, Bool, Bool)
@defbinaryop(:(|), OrPipe, Bool, Bool, Bool)
@defbinaryop(:(+), AddPipe, Int, Int, Int)
@defbinaryop(:(-), SubPipe, Int, Int, Int)
@defbinaryop(:(*), MulPipe, Int, Int, Int)
@defbinaryop(:(/), DivPipe, Int, Int, Int)


function lookup(s::RootScope, n::Symbol)
    if n in keys(s.db.schema.classes)
        I = domain(s)
        O = Entity{n}
        input = Iso{I}
        output = Seq{O}
        scope = ClassScope(s.db, n)
        pipe = SetPipe{I, O}(n, s.db.instance.sets[n])
        return Nullable{Flow}(Flow(input, output, scope, pipe))
    else
        return Nullable{Flow}()
    end
end


function lookup(s::ClassScope, n::Symbol)
    e = s.db.schema.classes[s.name]
    if n in keys(e.arrows)
        a = e.arrows[n]
        map = s.db.instance.maps[(s.name, a.name)]
        I = domain(s)
        O = a.T
        input = Iso{I}
        if O <: Entity
            scope = ClassScope(s.db, classname(O))
        else
            scope = ScalarScope(s.db, O)
        end
        if !a.plural && !a.partial
            output = Iso{O}
            pipe = IsoMapPipe{I, O}(n, map)
        elseif !a.plural
            output = Opt{O}
            pipe = OptMapPipe{I, O}(n, map)
        else
            output = Seq{O}
            pipe = SeqMapPipe{I, O}(n, map)
        end
        return Nullable{Flow}(Flow(input, output, scope, pipe))
    else
        return Nullable{Flow}()
    end
end

end

