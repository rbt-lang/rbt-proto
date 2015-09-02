
module BQL

import Base: show, showerror, >>, !, +, -, <, <=, >, >=, ==, !=, &, |, *, /

export
    Combinator,
    IllegalInputError,
    IllegalOperandsError,
    IllegalContextError,
    Const,
    This,
    Field,
    Fields,
    Var,
    Vars,
    Select,
    Given,
    UnaryOp,
    BinaryOp,
    Sieve,
    Count,
    Min,
    Max,
    First,
    vars


abstract Combinator

call(C::Combinator, x) = call(C, x, Dict())

call(C::Combinator, x, ctx) = error("$C: not implemented")

vars(C::Combinator) = Set()


immutable IllegalInputError <: Exception
    C::Combinator
    x
end

function showerror(io::IO, err::IllegalInputError)
    print(io, "IllegalInputError: cannot apply ", err.C, " to ")
    dump(io, err.x, 2)
end


immutable IllegalOperandsError <: Exception
    C::Combinator
    y
end

function showerror(io::IO, err::IllegalOperandsError)
    print(io, "IllegalOperandsError: cannot evaluate ", err.C, " on ")
    dump(io, err.y, 2)
end


immutable IllegalContextError <: Exception
    C::Combinator
end

function showerror(io::IO, err::IllegalContextError)
    print(io, "IllegalContextError: cannot evaluate ", err.C, " in the given context")
end


immutable Const <: Combinator
    val
end

call(C::Const, x, ctx) = x == nothing ? nothing : C.val


immutable This <: Combinator
end

call(C::This, x, ctx) = x


immutable Field <: Combinator
    name::AbstractString
end

Field(name::Symbol) = Field(string(name))

call(C::Field, x, ctx) =
    isa(x, Dict) && haskey(x, C.name) ? x[C.name] :
    x == nothing ? nothing :
    throw(IllegalInputError(C, x))

Fields(names...) = map(Field, names)


immutable Var <: Combinator
    name::AbstractString
end

Var(name::Symbol) = Var(string(name))

call(C::Var, x, ctx) =
    haskey(ctx, C.name) ? ctx[C.name] :
    throw(IllegalContextError(C))

vars(C::Var) = Set([C.name])

Vars(names...) = map(Var, names)


immutable Compose <: Combinator
    F::Combinator
    G::Combinator
end

>>(F::Combinator, G::Combinator) = Compose(F, G)

show(io::IO, C::Compose) = print(io, C.F, " >> ", C.G)

function call(C::Compose, x, ctx)
    y = C.F(x, ctx)
    if isa(y, Array)
        z = []
        for yi in y
            zi = C.G(yi, ctx)
            if isa(zi, Array)
                append!(z, zi)
            elseif zi != nothing
                push!(z, zi)
            end
        end
    else
        z = C.G(y)
    end
    z
end

vars(C::Compose) = union(vars(C.F), vars(C.G))


immutable Select <: Combinator
    name_to_F::Dict{AbstractString, Combinator}
end

show(io::IO, C::Select) = print(io, "Select(", join([string(name=>F) for (name, F) in C.name_to_F], ","), ")")

Select(ps::Pair...) = Select(Dict{AbstractString, Combinator}(map(p -> string(p.first) => p.second, ps)))

call(C::Select, x, ctx) = Dict([name => F(x, ctx) for (name, F) in C.name_to_F])

vars(C::Select) = union(map(vars, values(C.name_to_F))...)


immutable Given <: Combinator
    F::Combinator
    name_to_F::Dict{AbstractString, Combinator}
end

show(io::IO, C::Given) =
    print(io, "Given(", C.F, ",", join([string(name=>F) for (name, F) in C.name_to_F], ","), ")")

Given(C::Combinator, ps::Pair...) =
    Given(C, Dict{AbstractString, Combinator}(map(p -> string(p.first) => p.second, ps)))

function call(C::Given, x, ctx)
    ctx = copy(ctx)
    for (name, F) in C.name_to_F
        ctx[name] = F(x, ctx)
    end
    C.F(x, ctx)
end

vars(C::Given) = setdiff(vars(C.F), keys(C.name_to_F))


immutable UnaryOp <: Combinator
    op
    F::Combinator
end

show(io::IO, C::UnaryOp) = print(io, C.op, C.F)

function call(C::UnaryOp, x, ctx)
    y = C.F(x, ctx)
    return (
        isa(y, Array) ? map(C.op, y) :
        y != nothing ? C.op(y) :
        nothing)
end

vars(C::UnaryOp) = vars(C.F)

for op in [:(!), :(+), :(-)]
    @eval $op(F::Combinator) = UnaryOp($op, F)
end


immutable BinaryOp <: Combinator
    op
    F::Combinator
    G::Combinator
end

show(io::IO, C::BinaryOp) = print(io, C.F, C.op, C.G)

function call(C::BinaryOp, x, ctx)
    y1 = C.F(x, ctx)
    y2 = C.G(x, ctx)
    return _binop(C.op, y1, y2)
end

_binop(op, y1, y2) =
    y1 == nothing || y2 == nothing ? nothing :
    isa(y1, Array) && !isa(y2, Array) ? map(y1i -> _binop(op, y1i, y2), y1) :
    !isa(y1, Array) && isa(y2, Array) ? map(y2i -> _binop(op, y1, y2i), y2) :
    op == (+) && isa(y1, Dict) && isa(y2, Dict) ? merge(y1, y2) :
    op(y1, y2)

vars(C::BinaryOp) = union(vars(C.F), vars(C.G))

const Scalar = Union(Void, Bool, Number, AbstractString)
for op in [:(<), :(<=), :(>), :(>=), :(==), :(!=), :(&), :(|), :(+), :(-), :(*), :(/)]
    @eval begin
        $op(F::Combinator, G::Combinator) = BinaryOp($op, F, G)
        $op(F::Combinator, g::Scalar) = BinaryOp($op, F, Const(g))
        $op(f::Scalar, G::Combinator) = BinaryOp($op, Const(f), G)
    end
end


immutable Sieve <: Combinator
    P::Combinator
end

function call(C::Sieve, x, ctx)
    p = C.P(x, ctx)
    return (
        p == true ? x :
        p == nothing || p == false ? nothing :
        throw(IllegalOperandsError(C, p)))
end

vars(C::Sieve) = vars(C.P)


immutable Count <: Combinator
    F::Combinator
end

function call(C::Count, x, ctx)
    y = C.F(x)
    return isa(y, Array) ? length(y) : throw(IllegalOperandsError(C, y))
end

vars(C::Count) = vars(C.F)


immutable Min <: Combinator
    F::Combinator
end

function call(C::Min, x, ctx)
    y = C.F(x)
    return (
        isa(y, Array) && length(y) > 0 ? minimum(y) :
        isa(y, Array) ? nothing :
        throw(IllegalOperandsError(C, y)))
end

vars(C::Min) = vars(C.F)


immutable Max <: Combinator
    F::Combinator
end

function call(C::Max, x, ctx)
    y = C.F(x)
    return (
        isa(y, Array) && length(y) > 0 ? maximum(y) :
        isa(y, Array) ? nothing :
        throw(IllegalOperandsError(C, y)))
end

vars(C::Max) = vars(C.F)


immutable First <: Combinator
    F::Combinator
    N
end

First(F) = First(F, nothing)

function call(C::First, x, ctx)
    y = C.F(x)
    if C.N == nothing
        return (
            isa(y, Array) && length(y) > 0 ? y[1] :
            isa(y, Array) ? nothing :
            throw(IllegalOperandsError(C, y)))
    else
        N = isa(C.N, Combinator) ? C.N(x, ctx) : C.N
        return isa(y, Array) ? y[1:N] : throw(IllegalOperandsError(C, y))
    end
end

vars(C::First) = vars(C.F)


end

