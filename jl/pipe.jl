#
# A library of combinators.
#


#
# Combinator interface.
#

abstract AbstractPipe

showall(io::IO, pipe::AbstractPipe) =
    print(io, "$pipe :: $(mapping(pipe))")

# Input and output.
input(pipe::AbstractPipe) = pipe.input
output(pipe::AbstractPipe) = pipe.output

# Examines structure.
arms(::AbstractPipe) = AbstractPipe[]
getindex(pipe::AbstractPipe, idx) = arms(pipe)[idx]
length(pipe::AbstractPipe) = length(arms(pipe))

foreach(f, pipe::AbstractPipe) =
    begin
        f(pipe)
        for arm in arms(pipe)
            foreach(f, arm)
        end
        nothing
    end

# Executes the combinator.
execute(pipe::AbstractPipe, args...; params...) =
    let plan = plan(pipe),
        X = convert(ikind(pipe), args...; params...),
        Y = plan(X)
        data(Y)
    end

# Generates execution context.

ctxgen(pipe::AbstractPipe) = Pair{Symbol,Any}[]

# Generates a Julia function that runs the combinator.

codegen(pipe::AbstractPipe) = codegen(pipe, gensym(:X), ikind(pipe))

codegen{I<:Kind}(pipe::AbstractPipe, X, ::Type{I}) =
    let I0 = ikind(pipe)
        if I <: I0
            codegen(pipe, X)
        else
            codegen(pipe, :( lift($I0, $X) ))
        end
    end

codegen_compose{I<:Kind,I2<:Kind,O2<:Kind}(G, ::Type{I2}, ::Type{O2}, F::AbstractPipe, X, ::Type{I}) =
    codegen_compose(G, I2, O2, F, ikind(F), okind(F), X, I)

codegen_compose{I<:Kind}(G::AbstractPipe, F::AbstractPipe, X, ::Type{I}) =
    codegen_compose(G, ikind(G), okind(G), F, ikind(F), okind(F), X, I)

codegen_map{KK<:Kind}(F::AbstractPipe, XX, ::Type{KK}) =
    codegen_map(F, ikind(F), okind(F), XX, KK)


abstract AbstractPlan

const CACHED_PLANS = ObjectIdDict()

plan(pipe::AbstractPipe) =
    begin
        if pipe in keys(CACHED_PLANS)
            return CACHED_PLANS[pipe]
        end
        ctx = Dict{Symbol,Any}()
        foreach(pipe) do pipe
            for (attr, val) in ctxgen(pipe)
                ctx[attr] = val
            end
        end
        X = gensym(:X)
        code = codegen(pipe, X, ikind(pipe))
        name = gensym(:Plan)
        sig = Any[]
        args = ()
        for attr in sort(collect(keys(ctx)))
            val = ctx[attr]
            push!(sig, :( $(attr)::$(typeof(val)) ))
            args = (args..., val)
        end
        typedef = Expr(:type, false, Expr(:(<:), name, AbstractPlan), Expr(:block, sig...))
        I = ikind(pipe)
        showdef = Expr(:quote, :( (_::$name, $X::$I) -> $code ))
        def = quote
            $typedef
            show(io::IO, _::$name) = show(io, $showdef)
            (_::$name)($X::$I) = $code
            $name
        end
        Plan = eval(def)
        plan = Plan(args...)
        CACHED_PLANS[pipe] = plan
        return plan
    end


#
# Identity combinator maps any input to itself.
#
#   Here :: T -> T
#   Here = x -> x
#

immutable HerePipe <: AbstractPipe
    domain::Type
end

show(io::IO, ::HerePipe) = print(io, "Here")

input(pipe::HerePipe) = Input(pipe.domain)
output(pipe::HerePipe) = Output(pipe.domain, typemin(OutputMode))

codegen(pipe::HerePipe, X) = X


#
# Universal combinator Unit maps any input to the canonical singleton object.
#
#   Unit :: I -> Unit
#   Unit = x -> unit
#
# We use Unit = Void, unit = nothing.
#

immutable UnitPipe <: AbstractPipe
    domain::Type
end


show(io::IO, ::UnitPipe) = print(io, "Unit")

input(pipe::UnitPipe) = Input(pipe.domain)
output(pipe::UnitPipe) =
    Output(
        Unit,
        runique=(iszero(pipe.domain) || isunit(pipe.domain)),
        rtotal=!iszero(pipe.domain))

codegen(::UnitPipe, X) =
    quote
        Iso{Unit}(Unit())
    end


#
# Universal combinator Zero maps the empty set to the output.
#
#   Zero :: Zero -> O
#

immutable ZeroPipe <: AbstractPipe
    domain::Type
end

show(io::IO, ::ZeroPipe) = print(io, "Zero")

input(::ZeroPipe) = Input(Zero)
output(pipe::ZeroPipe) =
    Output(
        pipe.domain,
        runique=true,
        rtotal=iszero(pipe.domain))


#
# Constant combinator maps the singleton to a constant value.
#
#   Const(val) :: Unit -> O
#   Const(val) = x -> val
#

immutable ConstPipe <: AbstractPipe
    val
end

ConstPipe(T, val) =
    T <: Unit ? ConstPipe(val) : UnitPipe(T) >> ConstPipe(val)

show(io::IO, pipe::ConstPipe) = print(io, "Const($(pipe.val))")

input(::ConstPipe) = Input(Unit)
output(pipe::ConstPipe) =
    Output(
        typeof(pipe.val),
        runique=true,
        rtotal=isunit(typeof(pipe.val)))

codegen(pipe::ConstPipe, X) =
    let C = pipe.val,
        T = typeof(C)
        quote
            Iso{$T}($C)
        end
    end


#
# Null combinator maps the singleton to a NULL value (that is, Nullable{Union{}}()).
#
#   Null :: Unit -> Zero?
#   Null = unit -> null
#

immutable NullPipe <: AbstractPipe
end

NullPipe(T) =
    T <: Unit ? NullPipe() : UnitPipe(T) >> NullPipe()

show(io::IO, ::NullPipe) = print(io, "Null")

input(::NullPipe) = Input(Unit)
output(pipe::NullPipe) =
    Output(
        Zero,
        lunique=true,
        ltotal=false,
        runique=true,
        rtotal=true)

codegen(::NullPipe, X) =
    quote
        Opt{$Zero}()
    end


#
# Empty combinator maps the singleton to an empty sequence of values.
#
#   Empty :: Unit -> Zero*
#   Empty = unit -> []
#

immutable EmptyPipe <: AbstractPipe
end

EmptyPipe(T) =
    T <: Unit ? EmptyPipe() : UnitPipe(T) >> EmptyPipe()

show(io::IO, ::EmptyPipe) = print(io, "Empty")

input(::EmptyPipe) = Input(Unit)
output(pipe::EmptyPipe) =
    Output(
        Zero,
        lunique=false,
        ltotal=false,
        runique=true,
        rtotal=true)

codegen(::EmptyPipe, X) =
    quote
        Seq{$Zero}($Zero[])
    end


#
# Set combinator maps the singleton to a constant sequence.
#
#   Set(set) :: Unit -> O*
#   Set(set) = unit -> [set...]
#

immutable SetPipe <: AbstractPipe
    tag::Symbol
    set::Vector
    isnonempty::Bool
    ismonic::Bool
    iscovering::Bool
end

SetPipe(tag::Symbol, set::Vector; isnonempty::Bool=false, ismonic::Bool=false, iscovering::Bool=false) =
    SetPipe(tag, set, isnonempty, ismonic, iscovering)

show(io::IO, pipe::SetPipe) = print(io, "Set(<$(pipe.tag)>)")

input(::SetPipe) = Input(Unit)
output(pipe::SetPipe) =
    Output(
        eltype(pipe.set),
        lunique=false,
        ltotal=pipe.isnonempty,
        runique=pipe.ismonic,
        rtotal=pipe.iscovering)

ctxgen(pipe::SetPipe) =
    let set = symbol("#set#", pipe.tag)
        [Pair{Symbol,Any}(set, pipe.set)]
    end

codegen(pipe::SetPipe, X) =
    let set = symbol("#set#", pipe.tag),
        T = eltype(pipe.set)
        quote
            Seq{$T}(_.$set)
        end
    end


#
# IsoMap makes a function from a dictionary of input/output pairs.
#
#   IsoMap(map) :: I -> O
#   IsoMap(map) = x -> map[x]
#
# The dictionary must contain all possible input keys.
#

immutable IsoMapPipe <: AbstractPipe
    tag::Symbol
    map::Dict
    ismonic::Bool
    iscovering::Bool
end

IsoMapPipe(tag::Symbol, map::Dict; ismonic::Bool=false, iscovering::Bool=false) =
    IsoMapPipe(tag, map, ismonic, iscovering)

show(io::IO, pipe::IsoMapPipe) = print(io, "IsoMap(<$(pipe.tag)>)")

input(pipe::IsoMapPipe) = Input(keytype(pipe.map))
output(pipe::IsoMapPipe) =
    Output(
        valtype(pipe.map),
        runique=pipe.ismonic,
        rtotal=pipe.iscovering)

ctxgen(pipe::IsoMapPipe) =
    let map = symbol("#map#", pipe.tag)
        if keytype(pipe.map) <: Entity
            mapvec = Vector{valtype(pipe.map)}(length(pipe.map))
            for (key, val) in pipe.map
                mapvec[key.id] = val
            end
            [Pair{Symbol,Any}(map, mapvec)]
        else
            [Pair{Symbol,Any}(map, pipe.map)]
        end
    end

codegen(pipe::IsoMapPipe, X) =
    let map = symbol("#map#", pipe.tag),
        T = valtype(pipe.map)
        if keytype(pipe.map) <: Entity
            quote
                Iso{$T}(_.$map[data($X).id])
            end
        else
            quote
                Iso{$T}(_.$map[data($X)])
            end
        end
    end


#
# OptMap makes a partial mapping from a dictionary of input/output pairs.
#
#   OptMap(map) :: I -> O?
#   OptMap(map) = x -> x in keys(map) ? map[x] : null
#

immutable OptMapPipe <: AbstractPipe
    tag::Symbol
    map::Dict
    ismonic::Bool
    iscovering::Bool
end

OptMapPipe(tag::Symbol, map::Dict; ismonic::Bool=false, iscovering::Bool=false) =
    OptMapPipe(tag, map, ismonic, iscovering)

show(io::IO, pipe::OptMapPipe) = print(io, "OptMap(<$(pipe.tag)>)")

input(pipe::OptMapPipe) = Input(keytype(pipe.map))
output(pipe::OptMapPipe) =
    Output(
        valtype(pipe.map),
        lunique=true,
        ltotal=false,
        runique=pipe.ismonic,
        rtotal=pipe.iscovering)

ctxgen(pipe::OptMapPipe) =
    let map = symbol("#map#", pipe.tag)
        [Pair{Symbol,Any}(map, pipe.map)]
    end

codegen(pipe::OptMapPipe, X) =
    let map = symbol("#map#", pipe.tag),
        S = keytype(pipe.map),
        T = valtype(pipe.map),
        x = gensym(:x)
        quote
            let $x = data($X)::$S
                haskey(_.$map, $x) ? Opt{$T}(_.$map[$x]) : Opt{$T}()
            end
        end
    end


#
# SeqMap makes a plural mapping from a dictionary of input/output pairs.
#
#   SeqMap(map) :: I -> O*
#   SeqMap(map) = x -> x in keys(map) ? [map[x]...] : []
#
# The dictionary must map an input key to a vector of output values.
#

immutable SeqMapPipe <: AbstractPipe
    tag::Symbol
    map::Dict
    isnonempty::Bool
    ismonic::Bool
    iscovering::Bool
end

SeqMapPipe(tag::Symbol, map::Dict; isnonempty::Bool=false, ismonic::Bool=false, iscovering::Bool=false) =
    SeqMapPipe(tag, map, isnonempty, ismonic, iscovering)

show(io::IO, pipe::SeqMapPipe) = print(io, "SeqMap(<$(pipe.tag)>)")

input(pipe::SeqMapPipe) = Input(keytype(pipe.map))
output(pipe::SeqMapPipe) =
    Output(
        eltype(valtype(pipe.map)),
        lunique=false,
        ltotal=pipe.isnonempty,
        runique=pipe.ismonic,
        rtotal=pipe.iscovering)

ctxgen(pipe::SeqMapPipe) =
    let map = symbol("#map#", pipe.tag)
        [Pair{Symbol,Any}(map, pipe.map)]
    end

codegen(pipe::SeqMapPipe, X) =
    let map = symbol("#map#", pipe.tag),
        S = keytype(pipe.map),
        T = eltype(valtype(pipe.map)),
        x = gensym(:x)
        quote
            let $x = data($X)::$S
                haskey(_.$map, $x) ? Seq{$T}(_.$map[$x]) : Seq{$T}($T[])
            end
        end
    end


#
# Specialized map for entity attributes.
#

immutable EntityMapPipe <: AbstractPipe
    tag::Symbol
    domain::Type
    map::Vector
    mode::OutputMode
end

show(io::IO, pipe::EntityMapPipe) = print(io, "EntityMap(<$(pipe.tag)>)")

input(pipe::EntityMapPipe) = Input(pipe.domain)
output(pipe::EntityMapPipe) = Output(eltype(eltype(pipe.map)), pipe.mode)

ctxgen(pipe::EntityMapPipe) =
    let map = symbol("#map#", pipe.tag)
        [Pair{Symbol,Any}(map, pipe.map)]
    end

codegen(pipe::EntityMapPipe, X) =
    let map = symbol("#map#", pipe.tag)
        quote
            _.$map[data($X).id]
        end
    end


#
# Adapts a combinator to a different output structure.
#

# Converts any combinator to a plain function.  Expects the combinator to
# emit one output value on any input; raises an error otherwise.

immutable IsoPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    IsoPipe(F::AbstractPipe) =
        if isplain(F)
            F
        else
            new(F, input(F), Output(output(F), lunique=true, ltotal=true))
        end
end

show(io::IO, pipe::IsoPipe) = print(io, "Iso($(pipe.F))")

arms(pipe::IsoPipe) = AbstractPipe[pipe.F]

codegen(pipe::IsoPipe, X, I) =
    let T = odomain(pipe)
        @gensym Y
        if isplural(pipe.F)
            quote
                $Y = $(codegen(pipe.F, X, I))
                @assert length($Y) == 1
                Iso{$T}($Y[1])
            end
        elseif ispartial(pipe.F)
            quote
                $Y = $(codegen(pipe.F, X, I))
                @assert !isnull($Y)
                Iso{$T}(get($Y))
            end
        end
    end

# Converts any combinator to a partial mapping.  Expect the combinator
# to produce no more than one output value on any input; raises an error
# otherwise.

immutable OptPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    OptPipe(F::AbstractPipe) =
        if ispartial(F)
            F
        else
            new(F, input(F), Output(output(F), lunique=true, ltotal=false))
        end
end

show(io::IO, pipe::OptPipe) = print(io, "Opt($(pipe.F))")

arms(pipe::OptPipe) = AbstractPipe[pipe.F]

codegen(pipe::OptPipe, X, I) =
    let T = odomain(pipe)
        @gensym Y
        if isplural(pipe.F)
            quote
                $Y = $(codegen(pipe.F, X, I))
                @assert length($Y) <= 1
                !isempty($Y) ? Opt{$T}($Y[1]) : Opt{$T}()
            end
        elseif isplain(pipe.F)
            quote
                lift(Opt{$T}, $(codegen(pipe.F, X, I)))
            end
        end
    end

# Converts any combinator to a plural mapping.

immutable SeqPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    SeqPipe(F::AbstractPipe) =
        if isplural(F)
            F
        else
            new(F, input(F), Output(output(F), lunique=false))
        end
end

show(io::IO, pipe::SeqPipe) = print(io, "Seq($(pipe.F))")

arms(pipe::SeqPipe) = AbstractPipe[pipe.F]

codegen(pipe::SeqPipe, X, I) =
    let T = odomain(pipe)
        quote
            lift(Seq{$T}, $(codegen(pipe.F, X, I)))
        end
    end


#
# (F >> G) composes combinators F and G by sending the output of F
# to the input of G.
#
#   (F >> G) :: W{I} -> M{O}
#   where
#       F :: W{I} -> M{T}
#       G :: W{T} -> M{O}
#   for some comonad W and monad M.
#
# For plain functions F :: I -> T and G :: T -> O, combinator (F >> G) is
# a regular function composition.
#
#   (F >> G) = x -> G(F(x))
#
# In general case, given F :: W_1{I} -> M_1{T} and G :: W_2{T} -> M_2{O},
# composition (F >> G) :: W{I} -> M{O} is defined by:
#
#   (F >> G) = x -> flat(G(dist(F(dup(x)))))
#
#          dup                  W_2{F}
#   W{I} -------> W_2{W_1{I}} ----------> W_2{M_1{T}}
#
#
#                 dist                  M_1{G}                  flat
#   W_2{M_1{T}} --------> M_1{W_2{T}} ----------> M_1{M_2{O}} --------> M{O}
#
# Here, W = max(W_1, W_2), M = max(M_1, M_2), flat and dup are (co)monadic
# (co)joins, and dist is a mixed distributive law.
#

immutable ComposePipe <: AbstractPipe
    F::AbstractPipe
    G::AbstractPipe
    input::Input
    output::Output

    ComposePipe(F::AbstractPipe, G::AbstractPipe) =
        begin
            @assert(
                odomain(F) <: idomain(G),
                "$(repr(F)) and $(repr(G)) are not composable")
            input = Input(idomain(F), max(imode(F), imode(G)))
            output = Output(odomain(G), max(omode(F), omode(G)))
            if !(idomain(G) <: odomain(F))
                output = Output(output, rtotal=false)
            end
            return new(F, G, input, output)
        end
end

>>(F::AbstractPipe, G::AbstractPipe) = ComposePipe(F, G)

show(io::IO, pipe::ComposePipe) = print(io, "$(pipe.F) >> $(pipe.G)")

arms(pipe::ComposePipe) = AbstractPipe[pipe.F, pipe.G]

codegen(pipe::ComposePipe, X, I) =
    codegen_compose(pipe.G, pipe.F, X, I)


#
# Generates a tuple.
# 
#   Tuple(F_1, F_2, ...) :: I -> Tuple{O_1, O_2, ...}
#   Tuple(F_1, F_2, ...) = X -> tuple(F_1(X), F_2(X), ...)
#   where
#       F_1 :: I -> O_1
#       F_2 :: I -> O_2
#       ...
#
# Partial and plural field constructors generate fields of Nullable and
# Vector types respectively.
#

immutable TuplePipe <: AbstractPipe
    Fs::Vector{AbstractPipe}
    input::Input
    output::Output

    TuplePipe(Fs::Vector{AbstractPipe}) =
        begin
            if isempty(Fs)
                return ConstPipe(Any, ())
            end
            input = max(map(RBT.input, Fs)...)
            odomain = Tuple{map(odata, Fs)...}
            runique =
                iszero(input.domain) ||
                isunit(input.domain) ||
                any(F -> isplain(F) && ismonic(F), Fs)
            rtotal =
                length(Fs) == 1 && isplain(Fs[1]) && iscovering(Fs[1])
            output = Output(odomain, runique=runique, rtotal=rtotal)
            return new(Fs, input, output)
        end
end

TuplePipe(Fs) = TuplePipe(collect(AbstractPipe, Fs))
TuplePipe(Fs::AbstractPipe...) = TuplePipe(collect(AbstractPipe, Fs))

show(io::IO, pipe::TuplePipe) = print(io, "Tuple($(join(pipe.Fs, ", ")))")

arms(pipe::TuplePipe) = pipe.Fs

codegen(pipe::TuplePipe, X, I) =
    let O = odomain(pipe)
        @gensym X0
        items = [:( data($(codegen(F, X0, I))) ) for F in pipe.Fs]
        quote
            $X0 = $X
            Iso{$O}(tuple($(items...)))
        end
    end


#
# Extracts an element from a tuple.
#

immutable ItemPipe <: AbstractPipe
    domain::Type
    idx::Int
    mode::OutputMode

    ItemPipe(domain::Type, idx::Int, mode::OutputMode) =
        begin
            Ts = domain <: Tuple ? domain.parameters : domain.types
            @assert(1 <= idx <= length(Ts), "index is out of range")
            T = Ts[idx]
            @assert(
                (!isplural(mode) || T <: Vector) && (!ispartial(mode) || T <: Nullable),
                "incompatible output mode")
            return new(domain, idx, mode)
        end
end

ItemPipe(domain::Type, idx::Symbol; lunique::Bool=true, ltotal::Bool=true, runique::Bool=false, rtotal::Bool=false) =
    ItemPipe(domain, findfirst(fieldnames(domain), idx), OutputMode(lunique, ltotal, runique, rtotal))
ItemPipe(domain::Type, idx::Int; lunique::Bool=true, ltotal::Bool=true, runique::Bool=false, rtotal::Bool=false) =
    ItemPipe(domain, idx, OutputMode(lunique, ltotal, runique, rtotal))
ItemPipe(pipe::TuplePipe, idx) =
    let mode = omode(pipe.Fs[idx])
        ItemPipe(
            odomain(pipe), idx,
            lunique=mode.lunique, ltotal=mode.ltotal,
            runique=(length(pipe.Fs) == 1), rtotal=(length(pipe.Fs) == 1))
    end

show(io::IO, pipe::ItemPipe) = print(io, "Item($(pipe.idx))")

input(pipe::ItemPipe) = Input(pipe.domain)
output(pipe::ItemPipe) =
    let T = (pipe.domain <: Tuple ? pipe.domain.parameters : pipe.domain.types)[pipe.idx]
        Output(isplain(pipe.mode) ? T : eltype(T), pipe.mode)
    end

codegen(pipe::ItemPipe, X) =
    let O = okind(pipe)
        if pipe.domain <: Tuple
            quote
                $O(data($X)[$(pipe.idx)])
            end
        else
            field = fieldnames(pipe.domain)[pipe.idx]
            quote
                $O(data($X).$field)
            end
        end
    end


#
# Generates a vector.
#
#   Vector(F_1, F_2, ...) :: I -> O*
#   Vector(F_1, F_2, ...) = x -> [F_1(x), F_2(x), ...]
#   where
#       F_1 :: I -> O
#       F_2 :: I -> O
#       ...
#
# Partial or plural F_1, F_2, ... have all their output values added
# to the output.
#

immutable VectorPipe <: AbstractPipe
    Fs::Vector{AbstractPipe}
    input::Input
    output::Output

    VectorPipe(Fs::Vector{AbstractPipe}) =
        begin
            if isempty(Fs)
                return EmptyPipe(Any)
            elseif length(Fs) == 1
                return SeqPipe(Fs[1])
            end
            input = max(map(RBT.input, Fs)...)
            output = max(map(RBT.output, Fs)...)
            output = Output(
                output.domain,
                lunique=false,
                ltotal=any(isnonempty, Fs),
                runique=false,
                rtotal=any(F -> output.domain <: odomain(F) && iscovering(F), Fs))
            return new(Fs, input, output)
        end
end

VectorPipe(Fs) = VectorPipe(collect(AbstractPipe, Fs))
VectorPipe(Fs::AbstractPipe...) = VectorPipe(collect(AbstractPipe, Fs))

show(io::IO, pipe::VectorPipe) = print(io, "Vector($(join(pipe.Fs, ", ")))")

arms(pipe::VectorPipe) = pipe.Fs

codegen(pipe::VectorPipe, X, I) =
    begin
        O = odomain(pipe)
        @gensym X0 ys
        body = quote
            $X0 = $X
        end
        for (n, F) in enumerate(pipe.Fs)
            Y = codegen(F, X0, I)
            if isplural(F)
                body = quote
                    $body
                    append!($ys, data($Y))
                end
            elseif ispartial(F)
                @gensym y
                body = quote
                    $body
                    $y = data($Y)
                    if !isnull($y)
                        push!($ys, get($y))
                    end
                end
            else
                body = quote
                    $body
                    push!($ys, data($Y))
                end
            end
        end
        return quote
            let $ys = $O[]
                $body
                Seq{$O}($ys)
            end
        end
    end


#
# Evaluates an arbitrary scalar Julia function.
#
#   Op(op, F_1, F_2, ...) :: I -> O
#   Op(op, F_1, F_2, ...) = x -> op(F_1(x), F_2(x), ...)
#   where
#       op is a scalar function {I_1, I_2, ...} -> O
#       F_1 :: I_1 -> O
#       F_2 :: I_2 -> O
#       ...
#
# Produces plural output if any of F_1, F_2, ... is plural, or
# partial output if any of F_1, F_2, ... is partial.
#

immutable OpPipe <: AbstractPipe
    op::Function
    itypes::Vector{Type}
    otype::Type
    Fs::Vector{AbstractPipe}
    input::Input
    output::Output

    OpPipe(op::Function, itypes::Vector{Type}, otype::Type, Fs::Vector{AbstractPipe}) =
        begin
            @assert length(itypes) == length(Fs) "$Fs and $itypes differ in length"
            for (itype, F) in zip(itypes, Fs)
                @assert odomain(F) <: itype "$(repr(F)) is not of type $itype"
            end
            input = isempty(Fs) ? typemin(Input) : max(map(RBT.input, Fs)...)
            output = Output(otype, lunique=all(issingular, Fs), ltotal=all(isnonempty, Fs))
            return new(op, itypes, otype, Fs, input, output)
        end
end

OpPipe(op, itypes, otype, Fs) =
    OpPipe(op, collect(Type, itypes), otype, collect(AbstractPipe, Fs))
OpPipe(op, itypes, otype, Fs::AbstractPipe...) =
    OpPipe(op, collect(Type, itypes), otype, collect(AbstractPipe, Fs))

.==(F::AbstractPipe, G::AbstractPipe) = OpPipe(==, [odomain(F), odomain(G)], Bool, [F, G])
.!=(F::AbstractPipe, G::AbstractPipe) = OpPipe(!=, [odomain(F), odomain(G)], Bool, [F, G])
.<(F::AbstractPipe, G::AbstractPipe) = OpPipe(<, [odomain(F), odomain(G)], Bool, [F, G])
.<=(F::AbstractPipe, G::AbstractPipe) = OpPipe(<=, [odomain(F), odomain(G)], Bool, [F, G])
.>(F::AbstractPipe, G::AbstractPipe) = OpPipe(>, [odomain(F), odomain(G)], Bool, [F, G])
.>=(F::AbstractPipe, G::AbstractPipe) = OpPipe(>=, [odomain(F), odomain(G)], Bool, [F, G])

(~)(F::AbstractPipe) = OpPipe(!, [Bool], Bool, [F])
(&)(F::AbstractPipe, G::AbstractPipe) = OpPipe(&, [Bool, Bool], Bool, [F, G])
(|)(F::AbstractPipe, G::AbstractPipe) = OpPipe(|, [Bool, Bool], Bool, [F, G])

show(io::IO, pipe::OpPipe) = print(io, "($(pipe.op))($(join(pipe.Fs, ", ")))")

arms(pipe::OpPipe) = pipe.Fs

codegen(pipe::OpPipe, X, I) =
    begin
        T = odomain(pipe)
        N = length(pipe.itypes)
        @gensym X0 Z
        Ys = [gensym(symbol(:Y, n)) for n = 1:N]
        ys = [gensym(symbol(:y, n)) for n = 1:N]
        body =
            isplural(pipe) ? :( push!(data($Z), $(pipe.op)($(ys...))) ) :
            ispartial(pipe) ? :( $Z = Opt{$T}($(pipe.op)($(ys...))) ) :
            :( $Z = Iso{$T}($(pipe.op)($(ys...))) )
        for n = N:-1:1
            F = pipe.Fs[n]
            Y = Ys[n]
            y = ys[n]
            body =
                isplural(F) ? :( for $y in $Y; $body; end ) :
                ispartial(F) ? :( $y = get($Y); $body ) :
               :( $y = data($Y); $body )
        end
        for n = N:-1:1
            F = pipe.Fs[n]
            Y = Ys[n]
            y = ys[n]
            body =
                isplural(F) ? :( $Y = $(codegen(F, X0, I)); if !isempty($Y); $body; end ) :
                ispartial(F) ? :( $Y = $(codegen(F, X0, I)); if !isnull($Y); $body; end ) :
                :( $Y = $(codegen(F, X0, I)); $body )
        end
        body =
            isplural(pipe) ? :( $X0 = $X; $Z = Seq{$T}($T[]); $body; $Z ) :
            ispartial(pipe) ? :( $X0 = $X; $Z = Opt{$T}(); $body; $Z ) :
            :( $X0 = $X; $body; $Z )
        return body
    end


#
# AggregateOp(op, F) evaluates an aggregate function op on the output array
# produced by F.
#
#   AggregateOp(op, F) :: I -> O
#   where
#       F :: I -> T*
#       op :: T* -> O
#

immutable AggregateOpPipe <: AbstractPipe
    op::Function
    itype::Type
    otype::Type
    haszero::Bool
    F::AbstractPipe
    input::Input
    output::Output

    AggregateOpPipe(op::Function, itype::Type, otype::Type, haszero::Bool, F::AbstractPipe) =
        begin
            @assert odomain(F) <: itype "$(repr(F)) is not of type $itype"
            F = SeqPipe(F)
            input = RBT.input(F)
            output = Output(otype, ltotal=(haszero || isnonempty(F)))
            return new(op, itype, otype, haszero, F, input, output)
        end
end

AnyPipe(F::AbstractPipe) =
    isplain(F) && odomain(F) <: Bool ? F : AggregateOpPipe(any, Bool, Bool, true, F)
AllPipe(F::AbstractPipe) =
    isplain(F) && odomain(F) <: Bool ? F : AggregateOpPipe(all, Bool, Bool, true, F)
CountPipe(F::AbstractPipe) =
    AggregateOpPipe(length, Any, Int, true, F)
IntMaxPipe(F::AbstractPipe) =
    issingular(F) && odomain(F) <: Int ? F : AggregateOpPipe(maximum, Int, Int, false, F)
IntMinPipe(F::AbstractPipe) =
    issingular(F) && odomain(F) <: Int ? F : AggregateOpPipe(minimum, Int, Int, false, F)
IntSumPipe(F::AbstractPipe) =
    isplain(F) && odomain(F) <: Int ? F : AggregateOpPipe(sum, Int, Int, true, F)
IntMeanPipe(F::AbstractPipe) =
    AggregateOpPipe(mean, Int, Float64, false, F)
FirstPipe(F::AbstractPipe, rev::Bool=false) =
    issingular(F) ? F : AggregateOpPipe(!rev ? first : last, Any, odomain(F), false, F)

show(io::IO, pipe::AggregateOpPipe) = print(io, "($(pipe.op))($(pipe.F))")

arms(pipe::AggregateOpPipe) = AbstractPipe[pipe.F]

codegen(pipe::AggregateOpPipe, X, I) =
    let T = pipe.otype,
        Y = codegen(pipe.F, X, I)
        if ispartial(pipe)
            @gensym y
            quote
                $y = data($Y)
                isempty($y) ? Opt{$T}() : Opt{$T}($(pipe.op)($y))
            end
        else
            quote
                Iso{$T}($(pipe.op)(data($Y)))
            end
        end
    end


#
# Tests if a value is in an array.
#

immutable InPipe <: AbstractPipe
    F::AbstractPipe
    G::AbstractPipe
    input::Input
    output::Output

    InPipe(F::AbstractPipe, G::AbstractPipe) =
        begin
            F = IsoPipe(F)
            G = SeqPipe(G)
            @assert typejoin(odomain(G), odomain(F)) != Any "$(repr(F)) and $(repr(G)) are not comparable"
            input = max(RBT.input(F), RBT.input(G))
            output = Output(Bool)
            return new(F, G, input, output)
        end
end

show(io::IO, pipe::InPipe) = print(io, "In($(pipe.F), $(pipe.G))")

arms(pipe::InPipe) = AbstractPipe[pipe.F, pipe.G]

codegen(pipe::InPipe, X, I) =
    begin
        @gensym X0
        return quote
            $X0 = $X
            Iso{Bool}(data($(codegen(pipe.F, X0, I))) in data($(codegen(pipe.G, X0, I))))
        end
    end


#
# Generates a sequence start:step:stop.
#

immutable RangePipe <: AbstractPipe
    start::AbstractPipe
    step::AbstractPipe
    stop::AbstractPipe
    input::Input
    output::Output

    RangePipe(start::AbstractPipe, step::AbstractPipe, stop::AbstractPipe) =
        begin
            for F in [start, step, stop]
                @assert isplain(F) && odomain(F) <: Int "$(repr(F)) is not of type $Int"
            end
            input = max(map(RBT.input, [start, step, stop])...)
            output = Output(Int, lunique=false, ltotal=false, runique=true, rtotal=false)
            new(start, step, stop, input, output)
        end
end

RangePipe(start::AbstractPipe, stop::AbstractPipe) =
    RangePipe(start, ConstPipe(typeintersect(idomain(start), idomain(stop)), 1), stop)

show(io::IO, pipe::RangePipe) = print(io, "Range($(pipe.start), $(pipe.step), $(pipe.stop))")

arms(pipe::RangePipe) = AbstractPipe[pipe.start, pipe.step, pipe.stop]

codegen(pipe::RangePipe, X, I) =
    begin
        @gensym X0
        start = codegen(pipe.start, X, I)
        step = codegen(pipe.step, X, I)
        stop = codegen(pipe.stop, X, I)
        return quote
            $X0 = $X
            Seq{Int}(collect(Int, data($start):data($step):data($stop)))
        end
    end


#
# Generates a Cartesian product.
#

MixPipe(Fs::Vector{AbstractPipe}) =
    if isempty(Fs)
        ConstPipe(Any, ())
    else
        itypes = Type[odomain(F) for F in Fs]
        otype = Tuple{itypes...}
        OpPipe(tuple, itypes, otype, Fs)
    end
MixPipe(Fs) = MixPipe(collect(AbstractPipe, Fs))
MixPipe(Fs::AbstractPipe...) = MixPipe(collect(AbstractPipe, Fs))

(*)(F1::AbstractPipe, F2::AbstractPipe, Fs::AbstractPipe...) = MixPipe(F1, F2, Fs...)


#
# Tags a value.
#

immutable TagPipe <: AbstractPipe
    tag::Symbol
    domain::Type
end

show(io::IO, pipe::TagPipe) = print(io, "Tag($(pipe.tag))")

input(pipe::TagPipe) = Input(pipe.domain)
output(pipe::TagPipe) = Output(Pair{Symbol,pipe.domain}, runique=true)

codegen(pipe::TagPipe, X) =
    quote
        Iso(Pair{Symbol,$(pipe.domain)}($(QuoteNode(pipe.tag)), data($X)))
    end


#
# Generates a tagged union.
#

typealias TaggedPipe Pair{Symbol,AbstractPipe}

PackPipe(tagged_Fs::Vector{TaggedPipe}) =
    if isempty(tagged_Fs)
        EmptyPipe(Any)
    else
        domain = RBT.domain(max([output(F) for (tag, F) in tagged_Fs]...))
        VectorPipe(AbstractPipe[F >> TagPipe(tag, domain) for (tag, F) in tagged_Fs])
    end
PackPipe(tagged_Fs) =
    PackPipe(TaggedPipe[TaggedPipe(tag, F) for (tag, F) in tagged_Fs])
PackPipe(tagged_Fs::Pair{Symbol}...) = PackPipe(tagged_Fs)


#
# Unpacks a tagged union.
#

immutable CasePipe <: AbstractPipe
    domain::Type
    full::Bool
    tagged_Fs::Vector{TaggedPipe}
    input::Input
    output::Output

    CasePipe(domain::Type, full::Bool, tagged_Fs::Vector{TaggedPipe}) =
        if isempty(tagged_Fs)
            NullPipe(domain)
        else
            input = Input(
                Pair{Symbol,domain},
                max([imode(F) for (tag, F) in tagged_Fs]...))
            output = max([RBT.output(F) for (tag, F) in tagged_Fs]...)
            if !full
                output = Output(output, ltotal=false)
            end
            new(domain, full, tagged_Fs, input, output)
        end
end

CasePipe(domain, full, tagged_Fs) =
    CasePipe(domain, full, TaggedPipe[TaggedPipe(tag, F) for (tag, F) in tagged_Fs])
CasePipe(domain, full, tagged_Fs::Pair{Symbol}...) = CasePipe(domain, full, tagged_Fs)

show(io::IO, pipe::CasePipe) = print(io, "Case($(join(["$tag => $F" for (tag, F) in pipe.tagged_Fs], ", "))")

arms(pipe::CasePipe) = AbstractPipe[F for (tag, F) in pipe.tagged_Fs]

codegen(pipe::CasePipe, X, I) =
    begin
        O = okind(pipe)
        @gensym X0 xtag
        if pipe.full
            body = :( throw(DomainError()) )
        else
            body = :( $O() )
        end
        for (tag, F) in reverse(pipe.tagged_Fs)
            T = idomain(F)
            Y = codegen_compose(
                F, ikind(F), okind(F),
                (X, I) -> :( Iso{$T}(get($X0).second) ), Iso{Pair{Symbol,pipe.domain}}, Iso{T},
                X0, I)
            body = quote
                $xtag == $(QuoteNode(tag)) ? lift($O, $Y) : $body
            end
        end
        return quote
            $X0 = $X
            $xtag = get($X0).first
            $body
        end
    end


#
# Selects a record from the input.
#
#   Select(F, G_1, G_2, ...) :: I -> ((O_1, O_2, ...), I)
#   Select(F, G_1, G_2, ...) = F >> ((G_1, G_2, ...), Here)
#   where
#       F :: I -> T
#       G_1 :: T -> O_1
#       G_2 :: T -> O_2
#       ...
#

SelectPipe(F::AbstractPipe, Gs::Vector{AbstractPipe}) =
    F >> TuplePipe(TuplePipe(Gs), HerePipe(odomain(F)))
SelectPipe(F::AbstractPipe, Gs) = SelectPipe(F, collect(AbstractPipe, Gs))
SelectPipe(F::AbstractPipe, Gs::AbstractPipe...) = SelectPipe(F, collect(AbstractPipe, Gs))


#
# Filters the input on the given predicate combinator.
#
#   Sieve(P) :: I -> I?
#   Sieve(P) = x -> P(x) ? x : null
#   where
#       P :: I -> Bool
#

immutable SievePipe <: AbstractPipe
    P::AbstractPipe
    input::Input

    SievePipe(domain::Type, P::AbstractPipe) =
        begin
            @assert(
                domain <: idomain(P) && odomain(P) <: Bool,
                "$(repr(P)) is not of type $domain -> $Bool")
            P = AnyPipe(P)
            return new(P, Input(domain, imode(P)))
        end
end

FilterPipe(F, P) =
    let T = odomain(F)
        F >> SievePipe(T, P)
    end

show(io::IO, pipe::SievePipe) = print(io, "Sieve($(pipe.P))")

output(pipe::SievePipe) =
    Output(idomain(pipe), lunique=true, ltotal=false, runique=true, rtotal=false)

arms(pipe::SievePipe) = AbstractPipe[pipe.P]

codegen(pipe::SievePipe, X, I) =
    begin
        T = idomain(pipe)
        @gensym X0
        P = codegen(pipe.P, X0, I)
        return quote
            $X0 = $X
            data($P) ? Opt{$T}(get($X0)) : Opt{$T}()
        end
    end


#
# Sorts an array.
#
#   Sort(F) :: I -> O*
#   Sort(F) = x -> sort(F(x))
#   where
#       F :: I -> O*
#

immutable SortPipe <: AbstractPipe
    F::AbstractPipe
    rev::Bool
    input::Input
    output::Output

    SortPipe(F::AbstractPipe, rev::Bool=false) =
        let F = SeqPipe(F)
            new(F, rev, input(F), output(F))
        end
end

show(io::IO, pipe::SortPipe) = print(io, "Sort($(pipe.F))")

arms(pipe::SortPipe) = AbstractPipe[pipe.F]

codegen(pipe::SortPipe, X, I) =
    let O = okind(pipe)
        quote
            $O(sort(data($(codegen(pipe.F, X, I))), rev=$(pipe.rev)))
        end
    end


#
# Sorts an array by a key.
#
#   SortBy(F, G) :: I -> O*
#   SortBy(F, G) = x -> sort(F(x), by=G)
#   where
#       F :: I -> O*
#       G :: O -> T
#

immutable SortByPipe <: AbstractPipe
    F::AbstractPipe
    G::AbstractPipe
    rev::Bool
    input::Input
    output::Output

    SortByPipe(F::AbstractPipe, G::AbstractPipe, rev::Bool=false) =
        begin
            F = SeqPipe(F)
            G = IsoPipe(G)
            @assert(
                odomain(F) <: idomain(G),
                "$(repr(F)) and $(repr(G)) are not composable")
            input = Input(idomain(F), max(imode(F), imode(G)))
            return new(F, G, rev, input, output(F))
        end
end

SortByPipe(F::AbstractPipe, G::AbstractPipe, rev::Bool, arg1, args...) =
    SortByPipe(SortByPipe(F, arg1, args...), G, rev)
SortByPipe(F::AbstractPipe, G1::AbstractPipe, arg1, args...) =
    SortByPipe(SortByPipe(F, arg1, args...), G)
SortByPipe(F::AbstractPipe, G_rev::Tuple{AbstractPipe,Bool}, args...) =
    SortByPipe(F, G_rev..., args...)

show(io::IO, pipe::SortByPipe) = print(io, "SortBy($(pipe.F), $(pipe.G))")

arms(pipe::SortByPipe) = AbstractPipe[pipe.F, pipe.G]

codegen(pipe::SortByPipe, X, I) =
    begin
        T = odomain(pipe.F)
        W = odomain(pipe.G)
        @gensym ws Y0 Z0 l
        Z = codegen_compose(ikind(pipe.G), Iso{T}, pipe.F, X, I) do Y, O
            quote
                $Y0 = $Y
                $l = $(pipe.rev ? (-) : (+))(length($ws))
                push!($ws, (data($(codegen(pipe.G, Y0, O))), $l))
                Iso{$T}(data($Y0))
            end
        end
        return quote
            $ws = Tuple{$W,Int}[]
            $Z0 = $Z
            sort!($ws, rev=$(pipe.rev))
            Seq{$T}($T[$Z0[$(pipe.rev ? (-) : (+))(1, idx)] for (w, idx) in $ws])
        end
    end


#
# Takes the greatest/smallest elements by a key.
#
#   FirstBy(F, G) :: I -> O?
#   FirstBy(F, G) = x -> first(sort(F(x), by=G))
#   where
#       F :: I -> O*
#       G :: O -> T
#

immutable FirstByPipe <: AbstractPipe
    F::AbstractPipe
    G::AbstractPipe
    rev::Bool
    input::Input
    output::Output

    FirstByPipe(F::AbstractPipe, G::AbstractPipe, rev::Bool=false) =
        begin
            F = SeqPipe(F)
            G = IsoPipe(G)
            @assert(
                odomain(F) <: idomain(G),
                "$(repr(F)) and $(repr(G)) are not composable")
            input = Input(idomain(F), max(imode(F), imode(G)))
            output = Output(RBT.output(F), lunique=true, rtotal=false)
            return new(F, G, rev, input, output)
        end
end

FirstByPipe(F::AbstractPipe, G_rev::Tuple{AbstractPipe,Bool}) =
    FirstByPipe(F, G_rev...)

LastByPipe(F, G) = FirstByPipe(F, G, true)

show(io::IO, pipe::FirstByPipe) = print(io, "$(!pipe.rev ? "FirstBy" : "LastBy")($(pipe.F), $(pipe.G))")

arms(pipe::FirstByPipe) = AbstractPipe[pipe.F, pipe.G]

codegen(pipe::FirstByPipe, X, I) =
    begin
        T = odomain(pipe.F)
        W = odomain(pipe.G)
        @gensym ws Y0 Z0
        Z = codegen_compose(ikind(pipe.G), Iso{T}, pipe.F, X, I) do Y, O
            quote
                $Y0 = $Y
                push!($ws, data($(codegen(pipe.G, Y0, O))))
                Iso{$T}(get($Y0))
            end
        end
        idx = :( ($(pipe.rev) ? indmin : indmax )($ws) )
        if isnonempty(pipe)
            return quote
                $ws = $W[]
                $Z0 = $Z
                Iso{$T}($Z0[$idx])
            end
        else
            return quote
                $ws = $W[]
                $Z0 = $Z
                isempty($Z0) ? Opt{$T}() : Opt{$T}($Z0[$idx])
            end
        end
    end


#
# Takes/skips the first N elements (or the last -N elements).
#
#   Take(F, N) :: I -> O*
#   Take(F, N) = x -> F(x)[1:N(x)]
#   where
#       F :: I -> O*
#       N :: I -> Int
#

immutable TakePipe <: AbstractPipe
    F::AbstractPipe
    N::AbstractPipe
    rev::Bool
    input::Input
    output::Output

    TakePipe(F::AbstractPipe, N::AbstractPipe, rev::Bool=false) =
        begin
            F = SeqPipe(F)
            N = IsoPipe(N)
            @assert odomain(N) <: Int "$(repr(N)) is not of type $Int"
            return new(F, N, rev, max(input(F), input(N)), Output(output(F), rtotal=false))
        end
end

SkipPipe(F, N) = TakePipe(F, N, true)

show(io::IO, pipe::TakePipe) = print(io, "$(!pipe.rev ? "Take" : "Skip")($(pipe.F), $(pipe.N))")

arms(pipe::TakePipe) = AbstractPipe[pipe.F, pipe.N]

codegen(pipe::TakePipe, X, I) =
    let T = odomain(pipe)
        @gensym X0 ys n
        quote
            $X0 = $X
            $ys = data($(codegen(pipe.F, X0, I)))
            $n = data($(codegen(pipe.N, X0, I)))
            Seq{$T}(
                $(!pipe.rev ?
                    :( $n >= 0 ? $ys[1:min($n,end)] : $ys[1:$n+end] ) :
                    :( $n >= 0 ? $ys[1+$n:end] : $ys[max(1,1+$n+end):end] )))
        end
    end


#
# Reverses an array.
#
#   Reverse(F) :: I -> O*
#   Reverse(F) = x -> reverse(F(x))
#   where
#       F :: I -> O*
#

immutable ReversePipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    ReversePipe(F::AbstractPipe) =
        begin
            F = SeqPipe(F)
            return new(F, input(F), output(F))
        end
end

show(io::IO, pipe::ReversePipe) = print(io, "Reverse($(pipe.F))")

arms(pipe::ReversePipe) = AbstractPipe[pipe.F]

codegen(pipe::ReversePipe, X, I) =
    let T = odomain(pipe)
        quote
            Seq{$T}(reverse(data($(codegen(pipe.F, X, I)))))
        end
    end


#
# Picks an element by key.
#
#   Get(F, D, Key) :: I -> O?
#   Get(F, D, Key) = x -> y for y in F(x) such that Key(y) == D(x)
#   where
#       F :: I -> O*
#       D :: I -> K
#       Key :: O -> K
#

immutable GetPipe <: AbstractPipe
    F::AbstractPipe
    FKey::AbstractPipe
    D::AbstractPipe
    input::Input
    output::Output

    GetPipe(F::AbstractPipe, FKey::AbstractPipe, D::AbstractPipe) =
        begin
            F = SeqPipe(F)
            D = IsoPipe(D)
            @assert ismonic(F) "$(repr(F)) is not exclusive"
            @assert(
                isfree(FKey) && isplain(FKey) && ismonic(FKey),
                "$(repr(FKey)) is not a key mapping")
            @assert(
                odomain(F) <: idomain(FKey),
                "$(repr(F)) and $(repr(FKey)) are not composable")
            return new(F, FKey, D, max(input(F), input(D)), Output(output(F), lunique=true, rtotal=false))
        end
end

GetPipe(F, D) = GetPipe(F, HerePipe(odomain(F)), D)

show(io::IO, pipe::GetPipe) = print(io, "Get($(pipe.F), $(pipe.D))")

arms(pipe::GetPipe) = AbstractPipe[pipe.F, pipe.FKey, pipe.D]

codegen(pipe::GetPipe, X, I) =
    let T = odomain(pipe)
        @gensym X0 Z d y
        Y = codegen(pipe.F, X0, I)
        quote
            $X0 = $X
            $d = data($(codegen(pipe.D, X0, I)))
            $Z = Opt{$T}()
            for $y in $Y
                if data($(codegen(pipe.FKey, :( Iso{$T}($y) ), Iso{T}))) == $d
                    $Z = Opt{$T}($y)
                    break
                end
            end
            $Z
        end
    end


#
# Transitive closure.
#

immutable ConnectPipe <: AbstractPipe
    F::AbstractPipe
    self::Bool
    input::Input
    output::Output

    ConnectPipe(F::AbstractPipe, self::Bool=false) =
        begin
            F = SeqPipe(F)
            @assert odomain(F) <: idomain(F) "$(repr(F)) is not connectable"
            return new(F, self, input(F), Output(RBT.output(F), domain=idomain(F), ltotal=self, runique=false))
        end
end

show(io::IO, pipe::ConnectPipe) = print(io, "Connect($(pipe.F))")

arms(pipe::ConnectPipe) = AbstractPipe[pipe.F]

codegen(pipe::ConnectPipe, X) =
    begin
        T = idomain(pipe)
        I = ikind(pipe)
        II = Kind(I, I)
        @gensym X0 Xstk xs fst
        return quote
            $Xstk = $I[$X]
            $xs = $T[]
            $fst = $(!pipe.self)
            while !isempty($Xstk)
                $X0 = pop!($Xstk)
                if $fst
                    $fst = false
                else
                    push!($xs, get($X0))
                end
                append!($Xstk, reverse(data(dist($(codegen_map(pipe.F, :( dup($II, $X0) ), II))))))
            end
            Seq{$T}($xs)
        end
    end


#
# Height of the tree formed by the transitive closure.
#

immutable DepthPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    DepthPipe(F::AbstractPipe) =
        begin
            F = SeqPipe(F)
            @assert odomain(F) <: idomain(F) "$(repr(F)) is not connectable"
            return new(F, input(F), Output(Int))
        end
end

show(io::IO, pipe::DepthPipe) = print(io, "Depth($(pipe.F))")

arms(pipe::DepthPipe) = AbstractPipe[pipe.F]

codegen(pipe::DepthPipe, X) =
    begin
        T = idomain(pipe)
        I = ikind(pipe)
        II = Kind(I, I)
        @gensym X0 Xstk d max_d
        return quote
            $Xstk = Tuple{$I,Int}[($X,0)]
            $max_d = 0
            while !isempty($Xstk)
                $X0, $d = pop!($Xstk)
                $max_d = max($d, $max_d)
                for $X0 in dist($(codegen_map(pipe.F, :( dup($II, $X0) ), II)))
                    push!($Xstk, ($X0, $d+1))
                end
            end
            Iso{Int}($max_d)
        end
    end


#
# Sorting with respect to the hierarchy.
#

immutable SortConnectPipe <: AbstractPipe
    F::AbstractPipe
    FKey::AbstractPipe
    G::AbstractPipe
    input::Input
    output::Output

    SortConnectPipe(F::AbstractPipe, FKey::AbstractPipe, G::AbstractPipe) =
        begin
            F = SeqPipe(F)
            G = SeqPipe(G)
            @assert odomain(F) <: idomain(FKey) "$(repr(F)) and $(repr(FKey)) are not composable"
            @assert odomain(F) <: idomain(G) "$(repr(F)) and $(repr(G)) are not composable"
            @assert isfree(FKey) && isplain(FKey) && ismonic(FKey) "$(repr(FKey)) is not a key mapping"
            @assert odomain(G) <: idomain(G) "$(repr(G)) is not connectable"
            input = Input(idomain(F), max(imode(F), imode(G)))
            return new(F, FKey, G, input, output(F))
        end
end

SortConnectPipe(F, G) = SortConnectPipe(F, HerePipe(odomain(F)), G)

show(io::IO, pipe::SortConnectPipe) = print(io, "SortConnect($(pipe.F), $(pipe.G))")

arms(pipe::SortConnectPipe) = AbstractPipe[pipe.F, pipe.FKey, pipe.G]

codegen(pipe::SortConnectPipe, X, I) =
    begin
        T = odomain(pipe.F)
        K = odomain(pipe.FKey)
        @gensym keys deps Y0 ys key idx srcidx dstidx key2idxs edges weight sorted stk
        Y = codegen_compose(ikind(pipe.G), Iso{T}, pipe.F, X, I) do Y, O
            quote
                $Y0 = $Y
                push!($keys, data($(codegen(pipe.FKey, Y0, O))))
                push!($deps, data($(codegen_compose(pipe.FKey, pipe.G, Y0, O))))
                Iso{$T}(get($Y0))
            end
        end
        return quote
            $keys = $K[]
            $deps = Vector{$K}[]
            $ys = data($Y)
            $key2idxs = Dict{$K,Vector{Int}}()
            for ($idx, $key) in enumerate($keys)
                if !haskey($key2idxs, $key)
                    $key2idxs[$key] = Int[$idx]
                else
                    push!($key2idxs[$key], $idx)
                end
            end
            $edges = Vector{Int}[Int[] for $idx = 1:length($ys)]
            $weight = zeros(Int, length($ys))
            for $dstidx in eachindex($deps)
                for $key in $deps[$dstidx]
                    if haskey($key2idxs, $key)
                        for $srcidx in $key2idxs[$key]
                            push!($edges[$srcidx], $dstidx)
                            $weight[$dstidx] += 1
                        end
                    end
                end
            end
            $sorted = $T[]
            $stk = Int[]
            for $idx = length($ys):-1:1
                if $weight[$idx] == 0
                    push!($stk, $idx)
                end
            end
            while !isempty($stk)
                $srcidx = pop!($stk)
                push!($sorted, $ys[$srcidx])
                for $dstidx in reverse($edges[$srcidx])
                    $weight[$dstidx] -= 1
                    if $weight[$dstidx] == 0
                        push!($stk, $dstidx)
                    end
                end
            end
            Seq{$T}($sorted)
        end
    end


#
# All unique elements in a sequence.
#

immutable UniquePipe <: AbstractPipe
    F::AbstractPipe
    FKey::AbstractPipe
    rev::Bool
    input::Input
    output::Output

    UniquePipe(F::AbstractPipe, FKey::AbstractPipe, rev::Bool=false) =
        begin
            F = SeqPipe(F)
            @assert odomain(F) <: idomain(FKey) "$(repr(F)) and $(repr(FKey)) are not composable"
            @assert isfree(FKey) && isplain(FKey) && ismonic(FKey) "$(repr(FKey)) is not a key mapping"
            return new(F, FKey, rev, input(F), Output(output(F), runique=true))
        end
end

UniquePipe(F, rev::Bool=false) = UniquePipe(F, HerePipe(odomain(F)), rev)

show(io::IO, pipe::UniquePipe) = print(io, "Unique($(pipe.F))")

arms(pipe::UniquePipe) = AbstractPipe[pipe.F, pipe.FKey]

codegen(pipe::UniquePipe, X, I) =
    let T = odomain(pipe.F),
        K = odomain(pipe.FKey)
        @gensym y key keyed seen
        quote
            $keyed = Tuple{$K,$T}[]
            $seen = Set{$K}()
            for $y in $(codegen(pipe.F, X, I))
                $key = data($(codegen(pipe.FKey, :( Iso{$T}($y) ), Iso{T})))
                if !($key in $seen)
                    push!($keyed, ($key, $y))
                    push!($seen, $key)
                end
            end
            sort!($keyed, rev=$(pipe.rev))
            Seq{$T}($T[$y for ($key, $y) in $keyed])
        end
    end


#
# Quotient.
#

immutable GroupItem
    Q::AbstractPipe
    QKey::AbstractPipe
    rev::Bool

    GroupItem(Q::AbstractPipe, QKey::AbstractPipe, rev::Bool=false) =
        begin
            @assert isplain(Q) "$(repr(Q)) is not a plain function"
            @assert odomain(Q) <: idomain(QKey) "$(repr(Q)) and $(repr(QKey)) are not composable"
            @assert isfree(QKey) && isplain(QKey) && ismonic(QKey) "$(repr(QKey)) is not a key mapping"
            return new(Q, QKey, rev)
        end
end

GroupItem(Q, rev::Bool=false) = GroupItem(Q, HerePipe(odomain(Q)), rev)
GroupItem(args::Tuple) = GroupItem(args...)

show(io::IO, dim::GroupItem) = show(io, dim.Q)

input(dim::GroupItem) = input(dim.Q)
output(dim::GroupItem) = output(dim.Q)

immutable GroupPipe <: AbstractPipe
    F::AbstractPipe
    cube::Bool
    items::Vector{GroupItem}
    input::Input
    output::Output

    GroupPipe(F::AbstractPipe, cube::Bool, items::Vector{GroupItem}) =
        begin
            F = SeqPipe(F)
            mode = imode(F)
            for item in items
                @assert odomain(F) <: idomain(item) "$(repr(F)) and $(repr(item)) are not composable"
                mode = max(mode, imode(item))
            end
            input = Input(idomain(F), mode)
            Qs = [!cube ? odomain(item) : Nullable{odomain(item)} for item in items]
            T = Tuple{Tuple{Qs...}, Vector{odomain(F)}}
            output = Output(T, lunique=false, ltotal=isnonempty(F), runique=true)
            return new(F, cube, items, input, output)
        end
end

GroupPipe(F, cube::Bool, args...) = GroupPipe(F, cube, GroupItem[GroupItem(arg) for arg in args])
GroupPipe(F, args...) = GroupPipe(F, false, args...)

show(io::IO, pipe::GroupPipe) = print(io, "Group($(pipe.F), $(join(pipe.items, ", ")))")

arms(pipe::GroupPipe) =
    let arms = AbstractPipe[pipe.F]
        for item in pipe.items
            push!(arms, item.Q, item.QKey)
        end
        arms
    end

ItemPipe(pipe::GroupPipe, idx) =
    if idx == 1
        ItemPipe(odomain(pipe), idx; runique=true)
    elseif idx == 2
        ItemPipe(odomain(pipe), idx, OutputMode(omode(pipe.F), ltotal=true, runique=(!pipe.cube && ismonic(pipe.F))))
    else
        throw(BoundsError())
    end

ItemPipe(pipe::GroupPipe, idx1, idx2) =
    if idx1 == 1
        T = odomain(pipe).parameters[idx1]
        ItemPipe(pipe, idx1) >> ItemPipe(T, idx2, ltotal=!pipe.cube)
    else
        throw(BoundsError())
    end

codegen(pipe::GroupPipe, X, I) =
    begin
        T = Tuple{Tuple{map(odomain, pipe.items)...}, odomain(pipe.F)}
        K = isempty(pipe.items) ? Iso{odomain(pipe.F)} : ikind(max([input(item) for item in pipe.items]...))
        @gensym Y0 q
        W = codegen_compose(K, Iso{T}, pipe.F, X, I) do Y, O
            quote
                $Y0 = $Y
                $q = tuple($([:( data($(codegen(item.Q, Y0, O))) ) for item in pipe.items]...))
                Iso{$T}(($q, get($Y0)))
            end
        end
        PWs = :( [((), data($W))] )
        P = Tuple{}
        for (idx, item) in enumerate(pipe.items)
            L = odomain(item.QKey)
            R = odomain(item)
            Q = Tuple{P.parameters..., pipe.cube? Nullable{R} : R}
            @gensym QWs qws p ws key2idx key keys w ws d
            PWs = quote
                $QWs = Tuple{$Q,Vector{$T}}[]
                for ($p, $ws) in $PWs
                    $qws = Tuple{$Q,Vector{$T}}[]
                    $key2idx = Dict{$L,Int}()
                    $keys = $L[]
                    for $w in $ws
                        $d = $w[1][$idx]
                        $key = data($(codegen(item.QKey, :( Iso{$R}($d) ), Iso{R})))
                        if $key in keys($key2idx)
                            push!($qws[$key2idx[$key]][2], $w)
                        else
                            push!($qws, (($p..., $(pipe.cube ? :( Nullable{$R}($d) ) : :( $d ))), $T[$w]))
                            push!($keys, $key)
                            $key2idx[$key] = length($keys)
                        end
                    end
                    sort!($keys, rev=$(item.rev))
                    for $key in $keys
                        push!($QWs, $qws[$key2idx[$key]])
                    end
                    $(if pipe.cube; :( push!($QWs, (($p..., Nullable{$R}()), $ws)) ); end)
                end
                $QWs
            end
            P = Q
        end
        O = odomain(pipe)
        T = odomain(pipe.F)
        @gensym qws w
        return quote
            Seq{$O}($O[($qws[1], $T[$w[2] for $w in $qws[2]]) for $qws in $PWs])
        end
    end



#
# Partition.
#

immutable PartitionItem
    D::AbstractPipe
    Q::AbstractPipe
    QKey::AbstractPipe
    rev::Bool

    PartitionItem(D::AbstractPipe, Q::AbstractPipe, QKey::AbstractPipe, rev::Bool=false) =
        begin
            D = SeqPipe(D)
            @assert isplain(Q) "$(repr(Q)) is not a plain function"
            @assert odomain(D) <: idomain(QKey) "$(repr(D)) and $(repr(QKey)) are not composable"
            @assert odomain(Q) <: idomain(QKey) "$(repr(Q)) and $(repr(QKey)) are not composable"
            @assert isfree(QKey) && isplain(QKey) && ismonic(QKey) "$(repr(QKey)) is not a key mapping"
            return new(D, Q, QKey, rev)
        end
end

PartitionItem(D, Q, rev::Bool=false) = PartitionItem(D, Q, HerePipe(odomain(Q)), rev)
PartitionItem(args::Tuple) = PartitionItem(args...)

show(io::IO, dim::PartitionItem) = show(io, dim.Q)

input(dim::PartitionItem) = input(dim.Q)
output(dim::PartitionItem) = output(dim.D)

immutable PartitionPipe <: AbstractPipe
    F::AbstractPipe
    cube::Bool
    items::Vector{PartitionItem}
    input::Input
    output::Output

    PartitionPipe(F::AbstractPipe, cube::Bool, items::Vector{PartitionItem}) =
        begin
            F = SeqPipe(F)
            mode = imode(F)
            for item in items
                @assert odomain(F) <: idomain(item) "$(repr(F)) and $(repr(item)) are not composable"
                mode = max(mode, imode(item))
            end
            input = max(RBT.input(F), [RBT.input(item.D) for item in items]...)
            Qs = [!cube ? odomain(item) : Nullable{odomain(item)} for item in items]
            T = Tuple{Tuple{Qs...}, Vector{odomain(F)}}
            output = Output(
                T,
                lunique=false,
                ltotal=all([isnonempty(item.D) for item in items]),
                runique=all([ismonic(item.D) for item in items]))
            return new(F, cube, items, input, output)
        end
end

PartitionPipe(F, cube::Bool, args...) = PartitionPipe(F, cube, PartitionItem[PartitionItem(arg) for arg in args])
PartitionPipe(F, args...) = PartitionPipe(F, false, args...)

show(io::IO, pipe::PartitionPipe) = print(io, "Partition($(pipe.F), $(join(pipe.items, ", ")))")

arms(pipe::PartitionPipe) =
    let arms = AbstractPipe[pipe.F]
        for item in pipe.items
            push!(arms, item.D, item.Q, item.QKey)
        end
        arms
    end

ItemPipe(pipe::PartitionPipe, idx) =
    if idx == 1
        ItemPipe(odomain(pipe), idx; runique=(all([ismonic(item.D) for item in pipe.items])))
    elseif idx == 2
        ItemPipe(odomain(pipe), idx, OutputMode(omode(pipe.F), ltotal=false))
    else
        throw(BoundsError())
    end

ItemPipe(pipe::PartitionPipe, idx1, idx2) =
    if idx1 == 1
        T = odomain(pipe).parameters[idx1]
        ItemPipe(pipe, idx1) >> ItemPipe(T, idx2, ltotal=!pipe.cube)
    else
        throw(BoundsError())
    end

codegen(pipe::PartitionPipe, X, I) =
    begin
        T = Tuple{Tuple{map(odomain, pipe.items)...}, odomain(pipe.F)}
        K = isempty(pipe.items) ? Iso{odomain(pipe.F)} : ikind(max([input(item) for item in pipe.items]...))
        @gensym X0 Y0 q
        W = codegen_compose(K, Iso{T}, pipe.F, X0, I) do Y, O
            quote
                $Y0 = $Y
                $q = tuple($([:( data($(codegen(item.Q, Y0, O))) ) for item in pipe.items]...))
                Iso{$T}(($q, get($Y0)))
            end
        end
        PWs = :( [((), data($W))] )
        P = Tuple{}
        for (pos, item) in enumerate(pipe.items)
            L = odomain(item.QKey)
            R = odomain(item)
            Q = Tuple{P.parameters..., pipe.cube? Nullable{R} : R}
            @gensym QWs qws p ws key2idxs key keys w ws allws dim d idx
            PWs = quote
                $dim = data($(codegen(item.D, X0, I)))
                $QWs = Tuple{$Q,Vector{$T}}[]
                for ($p, $ws) in $PWs
                    $qws = Tuple{$Q,Vector{$T}}[]
                    $key2idxs = Dict{$L,Vector{Int}}()
                    $keys = $L[]
                    for $d in $dim
                        $key = data($(codegen(item.QKey, :( Iso{$R}($d) ), Iso{R})))
                        push!($keys, $key)
                        if $key in keys($key2idxs)
                            push!($key2idxs[$key], length($keys))
                        else
                            $key2idxs[$key] = Int[length($keys)]
                        end
                        push!($qws, (($p..., $(pipe.cube ? :( Nullable{$R}($d) ) : :( $d ))), $T[]))
                    end
                    $(if pipe.cube; :( $allws = $T[] ); end)
                    for $w in $ws
                        $d = $w[1][$pos]
                        $key = data($(codegen(item.QKey, :( Iso{$R}($d) ), Iso{R})))
                        if $key in keys($key2idxs)
                            for $idx in $key2idxs[$key]
                                push!($qws[$idx][2], $w)
                            end
                            $(if pipe.cube; :( push!($allws, $w) ); end)
                        end
                    end
                    sort!($keys, rev=$(item.rev))
                    for $key in unique($keys)
                        for $idx in $key2idxs[$key]
                            push!($QWs, $qws[$idx])
                        end
                    end
                    $(if pipe.cube; :( push!($QWs, (($p..., Nullable{$R}()), $allws)) ); end)
                end
                $QWs
            end
            P = Q
        end
        O = odomain(pipe)
        T = odomain(pipe.F)
        @gensym qws w
        return quote
            $X0 = $X
            Seq{$O}($O[($qws[1], $T[$w[2] for $w in $qws[2]]) for $qws in $PWs])
        end
    end


#
# Converts Null to Void().
#

immutable NullToVoidPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    NullToVoidPipe(F::AbstractPipe) =
        begin
            if isnonempty(F)
                return F
            end
            F = OptPipe(F)
            output = Output(Union{odomain(F),Void}, omode(F))
            output = Output(output, ltotal=true, runique=false)
            return new(F, input(F), output)
        end
end

show(io::IO, pipe::NullToVoidPipe) = show(io, pipe.F)

arms(pipe::NullToVoidPipe) = AbstractPipe[pipe.F]

codegen(pipe::NullToVoidPipe, X, I) =
    let T = odomain(pipe)
        @gensym Y
        quote
            $Y = $(codegen(pipe.F, X, I))
            isnull($Y) ? Iso{$T}(nothing) : Iso{$T}(get($Y))
        end
    end


#
# Generates a JSON object.
#

immutable DictPipe <: AbstractPipe
    tagged_Fs::Vector{TaggedPipe}
    input::Input
    output::Output

    DictPipe(tagged_Fs::Vector{TaggedPipe}) =
        if isempty(tagged_Fs)
            ConstPipe(Any, Dict{Any,Any}())
        else
            input = max([RBT.input(F) for (tag, F) in tagged_Fs]...)
            output = Output(Dict{Any,Any})
            new(tagged_Fs, input, output)
        end
end

DictPipe(tagged_Fs) = DictPipe(TaggedPipe[TaggedPipe(tag, F) for (tag, F) in tagged_Fs])
DictPipe(tagged_Fs::Pair{Symbol}...) = DictPipe(tagged_Fs)

show(io::IO, pipe::DictPipe) = print(io, "Dict($(join(["$tag => $F" for (tag, F) in pipe.tagged_Fs], ", "))")

arms(pipe::DictPipe) = AbstractPipe[F for (tag, F) in pipe.tagged_Fs]

codegen(pipe::DictPipe, X, I) =
    begin
        @gensym X0
        return quote
            $X0 = $X
            Iso(Dict{Any,Any}($([
                :( $(QuoteNode(tag)) => data($(codegen(F, X0, I))) )
                for (tag, F) in pipe.tagged_Fs]...)))
        end
    end


#
# Extracts a parameter from the input context.
#

immutable ParamPipe <: AbstractPipe
    tag::Symbol
    output::Output
end

ParamPipe(T::Type, args...) =
    T <: Unit ? ParamPipe(args...) : UnitPipe(T) >> ParamPipe(args...)
ParamPipe(tag::Symbol, domain::Type, mode::OutputMode) =
    ParamPipe(tag, Output(domain, mode))
ParamPipe(tag::Symbol, domain::Type; lunique::Bool=true, ltotal::Bool=true, runique::Bool=false, rtotal::Bool=false) =
    ParamPipe(tag, Output(domain, OutputMode(lunique, ltotal, runique, rtotal)))

show(io::IO, pipe::ParamPipe) = print(io, "Param($(pipe.tag))")

input(pipe::ParamPipe) = Input(Unit, params=Params((pipe.tag,), (data(pipe.output),)))
output(pipe::ParamPipe) = pipe.output

codegen(pipe::ParamPipe, X) =
    let O = okind(pipe)
        @gensym param val
        quote
            ($param,), $val = data($X)
            $O($param)
        end
    end


#
# Extracts the relative context.
#

immutable RelativePipe <: AbstractPipe
    domain::Type
    before::Bool
    self::Bool
    after::Bool
end

show(io::IO, pipe::RelativePipe) = print(io, "Relative($(pipe.before), $(pipe.self), $(pipe.after))")

input(pipe::RelativePipe) = Input(pipe.domain, relative=true)
output(pipe::RelativePipe) = Output(pipe.domain, lunique=false, ltotal=pipe.self)

codegen(pipe::RelativePipe, X) =
    let T = pipe.domain
        @gensym ptr vals
        slice =
            pipe.before && pipe.self && pipe.after ?
                vals :
            pipe.before && !pipe.self && pipe.after ?
                :( $T[$vals[1:$ptr-1]; $vals[$ptr+1:end]] ) :
            pipe.before && pipe.self && !pipe.after ?
                :( $vals[$ptr:-1:1] ) :
            pipe.before && !pipe.self && !pipe.after ?
                :( $vals[$ptr-1:-1:1] ) :
            !pipe.before && pipe.self && pipe.after ?
                :( $vals[$ptr:end] ) :
            !pipe.before && !pipe.self && pipe.after ?
                :( $vals[$ptr+1:end] ) :
            !pipe.before && pipe.self && !pipe.after ?
                :( $vals[$ptr:$ptr] ) : :( $T[] )
        quote
            $ptr, $vals = data($X)
            Seq{$T}($slice)
        end
    end


#
# Extracts the relative context based on some property.
#

immutable RelativeByPipe <: AbstractPipe
    F::AbstractPipe
    before::Bool
    self::Bool
    after::Bool
    input::Input
    output::Output

    RelativeByPipe(F::AbstractPipe, before::Bool, self::Bool, after::Bool) =
        begin
            F = IsoPipe(F)
            input = Input(RBT.input(F), relative=true)
            output = Output(idomain(F), lunique=false, ltotal=self)
            return new(F, before, self, after, input, output)
        end
end

show(io::IO, pipe::RelativeByPipe) = print(io, "RelativeBy($(pipe.F), $(pipe.before), $(pipe.self), $(pipe.after))")

arms(pipe::RelativeByPipe) = AbstractPipe[pipe.F]

codegen(pipe::RelativeByPipe, X, I) =
    let T = odomain(pipe),
        II = Rel{ikind(pipe.F)}
        @gensym X0 ptr vals qs q ys idxs idx
        slice =
            pipe.before && pipe.self && pipe.after ?
                :( (1:endof($vals),) ) :
            pipe.before && !pipe.self && pipe.after ?
                :( (1:$ptr-1, $ptr+1:endof($vals)) ) :
            pipe.before && pipe.self && !pipe.after ?
                :( ($ptr:-1:1,) ) :
            pipe.before && !pipe.self && !pipe.after ?
                :( ($ptr-1:-1:1,) ) :
            !pipe.before && pipe.self && pipe.after ?
                :( ($ptr:endof($vals),) ) :
            !pipe.before && !pipe.self && pipe.after ?
                :( ($ptr+1:endof($vals),) ) :
            !pipe.before && pipe.self && !pipe.after ?
                :( ($ptr:$ptr,) ) : :( () )
        quote
            $X0 = $X
            $ptr, $vals = data($X)
            $qs = data(data(dist($(codegen_map(pipe.F, :( dup($II, $X0) ), II)))))[2]
            $q = $qs[$ptr]
            $ys = $T[]
            for $idxs in $slice
                for $idx in $idxs
                    if $qs[$idx] == $q
                        push!($ys, $vals[$idx])
                    end
                end
            end
            Seq{$T}($ys)
        end
    end


#
# Binding surrounding context.
#

immutable BindRelPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    BindRelPipe(F::AbstractPipe) =
        !isrelative(F) ?
            F : new(F, Input(idomain(F), params=params(F)), output(F))
end

show(io::IO, pipe::BindRelPipe) = print(io, "BindRel($(pipe.F))")

arms(pipe::BindRelPipe) = AbstractPipe[pipe.F]

codegen(pipe::BindRelPipe, X) =
    let I = ikind(pipe)
        codegen(pipe.F, :( bind_rel($X) ), I)
    end


#
# Binding environment variables.
#

immutable BindEnvPipe <: AbstractPipe
    F::AbstractPipe
    tag::Symbol
    G::AbstractPipe
    input0::Input
    input::Input
    output::Output

    BindEnvPipe(F::AbstractPipe, tag::Symbol, G::AbstractPipe) =
        begin
            params0 = params(F)
            pos = findfirst(params0.first, tag)
            if pos == 0
                return F
            end
            T = params0.second[pos]
            @assert(odata(G) <: T, "$(repr(G)) is not of type $T")
            params1 = Params(
                (params0.first[1:pos-1]..., params0.first[pos+1:end]...),
                (params0.second[1:pos-1]..., params0.second[pos+1:end]...))
            input0 = Input(RBT.input(F), params=params1)
            input = Input(domain(input0), max(mode(input0), imode(G)))
            return new(F, tag, G, input0, input, output(F))
        end
end

BindEnvPipe(F::AbstractPipe, p::Pair) = BindEnvPipe(F, p.first, p.second)

show(io::IO, pipe::BindEnvPipe) = print(io, "BindEnv($(pipe.F), $(pipe.tag) => $(pipe.G))")

arms(pipe::BindEnvPipe) = AbstractPipe[pipe.F, pipe.G]

codegen(pipe::BindEnvPipe, X, I) =
    begin
        I0 = ikind(pipe.input0)
        I1 = ikind(pipe.F)
        Ns = Val{(pipe.tag,)}
        @gensym X0 env
        return quote
            $X0 = $X
            $env = (data($(codegen(pipe.G, X0, I))),)
            $(codegen(pipe.F, :( bind_env(lift($I0, $X0), $Ns, $env) ), I1))
        end
    end

