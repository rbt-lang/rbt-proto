
module Compile

export
    compile

using RBT.Parse
using RBT.Databases
using RBT.Pipes

import RBT.Pipes: domain, codomain


abstract AbstractScope


immutable RootScope <: AbstractScope
    db::Database
end

domain(::RootScope) = Tuple{}


immutable ClassScope <: AbstractScope
    db::Database
    name::Symbol
end

domain(s::ClassScope) = Entity{s.name}


immutable ScalarScope <: AbstractScope
    db::Database
    T::DataType
end

domain(s::ScalarScope) = s.T


immutable Input{comode}
    T::DataType
end


immutable Output{mode}
    T::DataType
end

mode{mode}(::Output{mode}) = mode

maxmode(::Output{:reg}, ::Output{:reg}) = :reg
maxmode(::Output{:reg}, ::Output{:opt}) = :opt
maxmode(::Output{:reg}, ::Output{:seq}) = :seq
maxmode(::Output{:opt}, ::Output{:reg}) = :opt
maxmode(::Output{:opt}, ::Output{:opt}) = :opt
maxmode(::Output{:opt}, ::Output{:seq}) = :seq
maxmode(::Output{:seq}, ::Output{:reg}) = :seq
maxmode(::Output{:seq}, ::Output{:opt}) = :seq
maxmode(::Output{:seq}, ::Output{:seq}) = :seq


immutable Flow
    input::Input
    output::Output
    scope::AbstractScope
    pipe::AbstractPipe
end

mode(f::Flow) = mode(f.output)

maxmode(f::Flow, g::Flow) = maxmode(f.output, g.output)


immutable Fn{name}
end


compile(db::Database, str::AbstractString) = compile(RootScope(db), query(str))
compile(db::Database, syn::AbstractSyntax) = compile(RootScope(db), syn)
compile(s::AbstractScope, str::AbstractString) = compile(s, query(str))


function compile(s::AbstractScope, ::LiteralSyntax{Void})
    input = Input{:reg}(domain(s))
    output = Output{:opt}(Void)
    scope = ScalarScope(s.db, Void)
    pipe = NullPipe{domain(s), Void}()
    return Flow(input, output, scope, pipe)
end


function compile{T}(s::AbstractScope, syn::LiteralSyntax{T})
    input = Input{:reg}(domain(s))
    output = Output{:reg}(T)
    scope = ScalarScope(s.db, T)
    pipe = ConstPipe{domain(s), T}(syn.val)
    return Flow(input, output, scope, pipe)
end


function compile(s::AbstractScope, syn::ApplySyntax)
    if isempty(syn.args)
        maybe_flow = lookup(s, syn.fn)
        try
            return get(maybe_flow)
        catch err
            isa(err, NullException) || rethrow()
        end
    end
    return compile(s, Fn{syn.fn}, syn.args...)
end


function compile(s::AbstractScope, syn::ComposeSyntax)
    f = compile(s, syn.f)
    g = compile(f.scope, syn.g)
    input = f.input
    mode = maxmode(f, g)
    output = Output{mode}(g.output.T)
    scope = g.scope
    pipe = f.pipe >> g.pipe
    return Flow(input, output, scope, pipe)
end


compile{name}(s::AbstractScope, fn::Type{Fn{name}}, syn0::AbstractSyntax, syns::AbstractSyntax...) =
    compile(s, fn, compile(s, syn0), map(syn -> compile(s, syn), syns)...)


function compile(s::AbstractScope, ::Type{Fn{:count}}, op::Flow)
    mode(op) == :seq || error("expected a plural expression: $op")
    input = op.input
    output = Output{:reg}(Int)
    scope = ScalarScope(s.db, Int)
    pipe = CountPipe{domain(op.pipe), eltype(codomain(op.pipe))}(op.pipe)
    return Flow(input, output, scope, pipe)
end

function compile(s::AbstractScope, ::Type{Fn{:max}}, op::Flow)
    mode(op) == :seq || error("expected a plural expression: $op")
    op.output.T == Int || error("expected an integer expression: $op")
    input = op.input
    output = Output{:opt}(Int)
    scope = ScalarScope(s.db, Int)
    pipe = MaxPipe{domain(op.pipe)}(op.pipe)
    return Flow(input, output, scope, pipe)
end

compile(s::AbstractScope, fn::Type{Fn{:select}}, base::AbstractSyntax, ops::AbstractSyntax...) =
    let base_flow = compile(s, base)
        compile(s, fn, base_flow, map(op -> compile(base_flow.scope, op), ops)...)
    end


function compile(s::AbstractScope, ::Type{Fn{:select}}, base::Flow, ops::Flow...)
    T = Tuple{map(op -> codomain(op.pipe), ops)...}
    input = base.input
    output = Output{mode(base)}(T)
    scope = ScalarScope(s.db, T)
    pipe = base.pipe >> TuplePipe{base.output.T,T}([op.pipe for op in ops])
    return Flow(input, output, scope, pipe)
end


function lookup(s::RootScope, n::Symbol)
    if n in keys(s.db.schema.classes)
        input = Input{:reg}(domain(s))
        T = Entity{n}
        output = Output{:seq}(T)
        scope = ClassScope(s.db, n)
        pipe = SetPipe{Tuple{}, T}(n, s.db.instance.sets[n])
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
        T = a.T
        if T <: Entity
            scope = ClassScope(s.db, classname(T))
        else
            scope = ScalarScope(s.db, T)
        end
        if !a.plural && !a.partial
            mode = :reg
            pipe = RegMapPipe{domain(s), T}(n, map)
        elseif !a.plural
            mode = :opt
            pipe = OptMapPipe{domain(s), T}(n, map)
        else
            mode = :seq
            pipe = SeqMapPipe{domain(s), T}(n, map)
        end
        input = Input{:reg}(domain(s))
        output = Output{mode}(T)
        return Nullable{Flow}(Flow(input, output, scope, pipe))
    else
        return Nullable{Flow}()
    end
end

end

