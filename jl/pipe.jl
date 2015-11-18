
immutable HerePipe{T} <: AbstractPipe{Iso{T}, Iso{T}}
end

HerePipe(T::Type=Any) = HerePipe{T}()

show(io::IO, ::HerePipe) = print(io, "HERE")

apply{T}(::HerePipe{T}, X::Iso{T}) = X


immutable ConstPipe{IT,OT} <: AbstractPipe{Iso{IT}, Iso{OT}}
    val::OT
end

ConstPipe(IT::Type, val) = ConstPipe{IT,typeof(val)}(val)
ConstPipe(val) = ConstPipe(Unit, val)

show(io::IO, pipe::ConstPipe) = print(io, pipe.val)

apply{IT,OT}(pipe::ConstPipe{IT,OT}, ::Iso{IT}) = Iso(pipe.val)


immutable NullPipe{IT} <: AbstractPipe{Iso{IT}, Opt{Any}}
end

NullPipe(IT::Type=Unit) = NullPipe{IT}()

show(io::IO, ::NullPipe) = print(io, "NULL")

apply{IT}(pipe::NullPipe{IT}, ::Iso{IT}) = Opt{Any}()


immutable SetPipe{T} <: AbstractPipe{Iso{Unit},Seq{T}}
    name::Symbol
    set::Vector{T}
end

show(io::IO, pipe::SetPipe) = print(io, "Set(<$(pipe.name)>)")

apply{T}(pipe::SetPipe{T}, ::Iso{Unit}) = wrap(Seq{T}, pipe.set)


immutable IsoMapPipe{IT,OT} <: AbstractPipe{Iso{IT},Iso{OT}}
    name::Symbol
    map::Dict{IT,OT}
end

show(io::IO, pipe::IsoMapPipe) = print(io, "IsoMap(<$(pipe.name)>)")

apply{IT,OT}(pipe::IsoMapPipe{IT,OT}, X::Iso{IT}) =
    wrap(Iso{OT}, pipe.map[unwrap(X)])


immutable OptMapPipe{IT,OT} <: AbstractPipe{Iso{IT},Opt{OT}}
    name::Symbol
    map::Dict{IT,OT}
end

show(io::IO, pipe::OptMapPipe) = print(io, "OptMap(<$(pipe.name)>)")

apply{IT,OT}(pipe::OptMapPipe{IT,OT}, X::Iso{IT}) =
    wrap(Opt{OT}, get(pipe.map, unwrap(X), nothing))


immutable SeqMapPipe{IT,OT} <: AbstractPipe{Iso{IT},Seq{OT}}
    name::Symbol
    map::Dict{IT,Vector{OT}}
end

show(io::IO, pipe::SeqMapPipe) = print(io, "SeqMap(<$(pipe.name)>)")

apply{IT,OT}(pipe::SeqMapPipe{IT,OT}, X::Iso{IT}) =
    wrap(Seq{OT}, get(pipe.map, unwrap(X), OT[]))


immutable LiftPipe{I,O,I0,O0} <: AbstractPipe{I,O}
    F::AbstractPipe{I0,O0}
end

LiftPipe{I0,O0}(I, F::AbstractPipe{I0,O0}, O) =
    let I = functor(I), O = functor(O)
        I = eltype(I) == Any ? functor(I, eltype(I0)) : I
        O = eltype(O) == Any ? functor(O, eltype(O0)) : O
        I == I0 && O == O0 ? F : LiftPipe{I, O, I0, O0}(F)
    end
LiftPipe{I0,O0}(I::Union{Type,Input}, F::AbstractPipe{I0,O0}) = LiftPipe(I, F, O0)
LiftPipe{I0,O0}(F::AbstractPipe{I0,O0}, O::Union{Type,Output}) = LiftPipe(I0, F, O)
^(I::Union{Type,Input}, F::AbstractPipe) = LiftPipe(I, F)
^(F::AbstractPipe, O::Union{Type,Input}) = LiftPipe(F, O)

show(io::IO, pipe::LiftPipe) = show(io, pipe.F)

apply{I,O,I0,O0}(pipe::LiftPipe{I,O,I0,O0}, X::I) =
    rewrap(O, apply(pipe.F, rewrap(I0, X)::I0)::O0)::O


immutable ComposePipe{I,O,I1,O1,I2,O2} <: AbstractPipe{I,O}
    F::AbstractPipe{I1,O1}
    G::AbstractPipe{I2,O2}
end

ComposePipe{I1,O1,I2,O2}(F::AbstractPipe{I1,O1}, G::AbstractPipe{I2,O2}) =
    let I = max(I1, functor(I2, eltype(I1))),
        O = max(O2, functor(O1, eltype(O2)))
        @assert eltype(O1) == eltype(I2) "$F >> $G"
        ComposePipe{I,O,I1,O1,I2,O2}(F, G)
    end
>>(F::AbstractPipe, G::AbstractPipe) = ComposePipe(F, G)

show(io::IO, pipe::ComposePipe) = print(io, pipe.F, " >> ", pipe.G)

# Given F :: W_1{A} -> M_1{B} and G :: W_2{B} -> M_2{C}, composition
# F.G :: W{A} -> M{C} is defined by:
#   W{A} --dup--> W{W_1{A}} --F--> W{M_1{B}} --rewrap--> W_2{M_1{B}}
#   --dist--> M_1{W_2{B}} --G--> M_1{M_2{C}} --flat--> M{C}.
# Here, W = max(W_1, W_2), M = max(M_1, M_2).
apply{I,O}(pipe::ComposePipe{I,O}, X::I) =
    rapply(pipe.G, lapply(pipe.F, X))::O

lapply{I,I1,O1}(F::AbstractPipe{I1,O1}, X::I) =
    fmap(F, dup(functor(I, I1), X))

rapply{I,I2,O2}(G::AbstractPipe{I2,O2}, YY::I) =
     flat(fmap(G, dist(rewrap(functor(I2, eltype(I)), YY))))


immutable IsoProductPipe{I,T1,T2} <: IsoPipe{I,Tuple{T1,T2}}
    F::IsoPipe{I,T1}
    G::IsoPipe{I,T2}
end

IsoProductPipe{I1,T1,I2,T2}(F::IsoPipe{I1,T1}, G::IsoPipe{I2,T2}) =
    let I = max(I1, I2)
        IsoProductPipe{I,T1,T2}(I ^ F, I ^ G)
    end

show(io::IO, pipe::IsoProductPipe) = print(io, "($(pipe.F) * $(pipe.G))")

apply{I,T1,T2}(pipe::IsoProductPipe{I,T1,T2}, X::I) =
    Iso((unwrap(apply(pipe.F, X))::T1, unwrap(apply(pipe.G, X))::T2))


immutable OptProductPipe{I,T1,T2} <: OptPipe{I,Tuple{T1,T2}}
    F::OptPipe{I,T1}
    G::OptPipe{I,T2}
end

OptProductPipe{I1,T1,I2,T2}(F::OptPipe{I1,T1}, G::OptPipe{I2,T2}) =
    let I = max(I1, I2)
        OptProductPipe{I,T1,T2}(I ^ F, I ^ G)
    end
OptProductPipe{I1,T1,I2,T2}(F::OptPipe{I1,T1}, G::IsoPipe{I2,T2}) =
    OptProductPipe(F, G ^ Opt)
OptProductPipe{I1,T1,I2,T2}(F::IsoPipe{I1,T1}, G::OptPipe{I2,T2}) =
    OptProductPipe(F ^ Opt, G)

show(io::IO, pipe::OptProductPipe) = print(io, "($(pipe.F) * $(pipe.G))")

apply{I,T1,T2}(pipe::OptProductPipe{I,T1,T2}, X::I) =
    let Y1 = apply(pipe.F, X)::Opt{T1}
        if !isnull(Y1)
            let Y2 = apply(pipe.G, X)::Opt{T2}
                if !isnull(Y2)
                    return Opt((get(Y1), get(Y2)))
                end
            end
        end
        return Opt{Tuple{T1,T2}}()
    end


immutable SeqProductPipe{I,T1,T2} <: SeqPipe{I,Tuple{T1,T2}}
    F::SeqPipe{I,T1}
    G::SeqPipe{I,T2}
end

SeqProductPipe{I1,T1,I2,T2}(F::SeqPipe{I1,T1}, G::SeqPipe{I2,T2}) =
    let I = max(I1, I2)
        SeqProductPipe{I, T1, T2}(I ^ F, I ^ G)
    end
SeqProductPipe{I1,T1,I2,T2}(F::SeqPipe{I1,T1}, G::IsoPipe{I2,T2}) =
    SeqProductPipe(F, G ^ Seq)
SeqProductPipe{I1,T1,I2,T2}(F::SeqPipe{I1,T1}, G::OptPipe{I2,T2}) =
    SeqProductPipe(F, G ^ Seq)
SeqProductPipe{I1,T1,I2,T2}(F::IsoPipe{I1,T1}, G::SeqPipe{I2,T2}) =
    SeqProductPipe(F ^ Seq, G)
SeqProductPipe{I1,T1,I2,T2}(F::OptPipe{I1,T1}, G::SeqPipe{I2,T2}) =
    SeqProductPipe(F ^ Seq, G)

show(io::IO, pipe::SeqProductPipe) = print(io, "($(pipe.F) * $(pipe.G))")

apply{I,T1,T2}(pipe::SeqProductPipe{I,T1,T2}, X::I) =
    let Y1 = apply(pipe.F, X)::Seq{T1},
        Y2 = !isempty(Y1) ? apply(pipe.G, X)::Seq{T2} : Seq(T2[]),
        ys = Tuple{T1,T2}[]
        for y1 in Y1
            for y2 in Y2
                push!(ys, (y1, y2))
            end
        end
        Seq(ys)
    end


*{I1,T1,I2,T2}(F::IsoPipe{I1,T1}, G::IsoPipe{I2,T2}) = IsoProductPipe(F, G)
*{I1,T1,I2,T2}(F::IsoPipe{I1,T1}, G::OptPipe{I2,T2}) = OptProductPipe(F, G)
*{I1,T1,I2,T2}(F::IsoPipe{I1,T1}, G::SeqPipe{I2,T2}) = SeqProductPipe(F, G)
*{I1,T1,I2,T2}(F::OptPipe{I1,T1}, G::IsoPipe{I2,T2}) = OptProductPipe(F, G)
*{I1,T1,I2,T2}(F::OptPipe{I1,T1}, G::OptPipe{I2,T2}) = OptProductPipe(F, G)
*{I1,T1,I2,T2}(F::OptPipe{I1,T1}, G::SeqPipe{I2,T2}) = SeqProductPipe(F, G)
*{I1,T1,I2,T2}(F::SeqPipe{I1,T1}, G::IsoPipe{I2,T2}) = SeqProductPipe(F, G)
*{I1,T1,I2,T2}(F::SeqPipe{I1,T1}, G::OptPipe{I2,T2}) = SeqProductPipe(F, G)
*{I1,T1,I2,T2}(F::SeqPipe{I1,T1}, G::SeqPipe{I2,T2}) = SeqProductPipe(F, G)


immutable CoproductPipe{I,U} <: SeqPipe{I,Pair{Symbol,U}}
    Fs::Vector{Pair{Symbol,AbstractPipe}}
end

CoproductPipe(pairs::Pair{Symbol,AbstractPipe}...) =
    let I = max([ifunctor(F) for (n, F) in pairs]...),
        U = Union{[otype(F) for (n, F) in pairs]...}
        CoproductPipe{I,U}([Pair{Symbol,AbstractPipe}(n, I ^ (F ^ Seq)) for (n, F) in pairs])
    end


show(io::IO, pipe::CoproductPipe) = print(io, "[", join(["$n => $F" for (n,F) in pipe.Fs], " | "), "]")

function apply{I,U}(pipe::CoproductPipe{I,U}, X::I)
    out = Vector{Pair{Symbol,U}}()
    for (tag, F) in pipe.Fs
        for y in apply(F, X)
            push!(out, Pair{Symbol,U}(tag, y))
        end
    end
    return Seq(out)
end


immutable CoproductMapPipe{U,V} <: AbstractPipe{Iso{Pair{Symbol,U}},Iso{Pair{Symbol,V}}}
    Fs::Dict{Symbol,AbstractPipe}
end

CoproductMapPipe(pairs::Pair{Symbol,AbstractPipe}...) =
    let U = Union{[itype(F) for (n, F) in pairs]...},
        V = Union{[otype(F) for (n, F) in pairs]...}
        CoproductMapPipe{U,V}(Dict(pairs))
    end

show(io::IO, pipe::CoproductMapPipe) = print(io, "[", join(["$n => $F" for (n,F) in pipe.Fs], " | "), "]")

function apply{U,V}(pipe::CoproductMapPipe{U,V}, X::Iso{Pair{Symbol,U}})
    tag, y = unwrap(X)
    z = unwrap(apply(pipe.Fs[tag], Iso(y)))
    return Iso(Pair{Symbol,V}(tag, z))
end


immutable SwitchPipe{U,T} <: AbstractPipe{Iso{Pair{Symbol,U}},Opt{T}}
    tag::Symbol
end

SwitchPipe(U, T, tag) = SwitchPipe{U,T}(tag)

show(io::IO, pipe::SwitchPipe) = print(io, "Switch($(pipe.tag))")

apply{U,T}(pipe::SwitchPipe{U,T}, X::Iso{Pair{Symbol,U}}) =
    begin
        (tag, x) = unwrap(X)
        tag == pipe.tag ? Opt{T}(x) : Opt{T}()
    end


immutable CountPipe{I,T} <: IsoPipe{I,Int}
    F::SeqPipe{I,T}
end

show(io::IO, pipe::CountPipe) = print(io, "Count($(self.F))")

apply{I,T}(pipe::CountPipe{I,T}, X::I) =
    Iso{Int}(length(apply(pipe.F, X)::Seq{T}))


immutable SumPipe{I} <: IsoPipe{I,Int}
    F::SeqPipe{I,Int}
end

show(io::IO, pipe::SumPipe) = print(io, "Sum($(self.F))")

apply{I}(pipe::SumPipe{I}, X::I) =
    Iso{Int}(sum(unwrap(apply(pipe.F, X))::Vector{Int}))


immutable MaxPipe{I} <: IsoPipe{I,Int}
    F::SeqPipe{I,Int}
end

show(io::IO, pipe::MaxPipe) = print(io, "Max($(self.F))")

apply{I}(pipe::MaxPipe{I}, X::I) =
    Iso{Int}(maximum(unwrap(apply(pipe.F, X))::Vector{Int}))


immutable OptMaxPipe{I} <: OptPipe{I,Int}
    F::SeqPipe{I,Int}
end

show(io::IO, pipe::OptMaxPipe) = print(io, "OptMax($(self.F))")

apply{I}(pipe::OptMaxPipe{I}, X::I) =
    let y = unwrap(apply(pipe.F, X))::Vector{Int}
        isempty(y) ? Opt{Int}() : Opt{Int}(maximum(y))
    end


immutable TuplePipe{I,T} <: IsoPipe{I,T}
    Fs::Vector{AbstractPipe{I}}
end

TuplePipe() = TuplePipe{Iso{Any},Tuple{}}()
TuplePipe(F1::AbstractPipe, Fs::AbstractPipe...) =
    let Fs = (F1, Fs...),
        I = max([ifunctor(F) for F in Fs]...),
        T = Tuple{[unwrap(ofunctor(F)) for F in Fs]...}
        TuplePipe{I,T}(AbstractPipe{I}[I ^ F for F in Fs])
    end

show(io::IO, pipe::TuplePipe) = print(io, "Tuple($(join(pipe.Fs, ", ")))")

apply{I,T}(pipe::TuplePipe{I,T}, X::I) =
    Iso(([unwrap(apply(F, X)) for F in pipe.Fs]...)::T)


immutable ArrayPipe{I,T} <: SeqPipe{I,T}
    Fs::Vector{IsoPipe{I,T}}
end

ArrayPipe(Fs::AbstractPipe...) =
    let I = max([ifunctor(F) for F in Fs]...),
        T = otype(Fs[1])
        ArrayPipe{I,T}([I ^ F for F in Fs])
    end

show(io::IO, pipe::ArrayPipe) = print(io, "Array($(join(pipe.Fs, ", ")))")

apply{I,T}(pipe::ArrayPipe{I,T}, X::I) =
    Seq(T[unwrap(apply(F, X))::T for F in pipe.Fs])


immutable RangePipe{I} <: SeqPipe{I,Int}
    start::IsoPipe{I,Int}
    step::IsoPipe{I,Int}
    stop::IsoPipe{I,Int}
end

RangePipe{I1,I2,I3}(start::IsoPipe{I1,Int}, step::IsoPipe{I2,Int}, stop::IsoPipe{I3,Int}) =
    let I = max(I1, I2, I3)
        RangePipe{I}(I ^ start, I ^ step, I ^ stop)
    end

show(io::IO, pipe::RangePipe) = print(io, "Range($(pipe.start), $(pipe.step), $(pipe.stop))")

apply{I}(pipe::RangePipe{I}, X::I) =
    let start = unwrap(apply(pipe.start, X))::Int,
        step = unwrap(apply(pipe.step, X))::Int,
        stop = unwrap(apply(pipe.stop, X))::Int
        Seq(collect(start:step:stop))
    end


immutable SievePipe{I,T} <: OptPipe{I,T}
    P::IsoPipe{I,Bool}
end

SievePipe{I}(P::AbstractPipe{I}) =
    let T = eltype(I),
        P = ofunctor(P) <: Iso ? P : IsoIfNullPipe(P, ConstPipe(T, false))
        SievePipe{I,T}(P)
    end

show(io::IO, pipe::SievePipe) = print(io, "Sieve($(pipe.P))")

apply{I,T}(pipe::SievePipe{I,T}, X::I) =
    unwrap(apply(pipe.P, X))::Bool ? Opt{T}(unwrap(X)) : Opt{T}()


immutable IsoIfNullPipe{I,T} <: IsoPipe{I,T}
    F::OptPipe{I,T}
    R::IsoPipe{I,T}
end

IsoIfNullPipe{I1,I2,T}(F::OptPipe{I1,T}, R::IsoPipe{I2,T}) =
    let I = max(I1, I2)
        IsoIfNullPipe{I,T}(I ^ F, I ^ R)
    end

show(io::IO, pipe::IsoIfNullPipe) = print(io, "IsoIfNullPipe($(pipe.F), $(pipe.R))")

apply{I,T}(pipe::IsoIfNullPipe{I,T}, X::I) =
    let Y = apply(pipe.F, X)
        !isnull(Y) ? Iso(get(Y)) : apply(pipe.R, X)
    end


immutable IsoFirstPipe{I,T} <: IsoPipe{I,T}
    F::SeqPipe{I,T}
    dir::Int
end

show(io::IO, pipe::IsoFirstPipe) = print(io, "IsoFirst($(pipe.F), $(pipe.dir))")

apply{I,T}(pipe::IsoFirstPipe{I,T}, X::I) =
    wrap(Iso{T}, apply(pipe.F, X)[(pipe.dir >= 0 ? 1 : end)]::T)


immutable OptFirstPipe{I,T} <: OptPipe{I,T}
    F::SeqPipe{I,T}
    dir::Int
end

show(io::IO, pipe::OptFirstPipe) = print(io, "OptFirst($(pipe.F), $(pipe.dir))")

apply{I,T}(pipe::OptFirstPipe{I,T}, X::I) =
    let Y = apply(pipe.F, X)::Seq{T}
        isempty(Y) ? Opt{T}() : Opt(Y[(pipe.dir >= 0 ? 1 : end)])
    end


immutable IsoFirstByPipe{I,T,J,K} <: IsoPipe{I,T}
    F::SeqPipe{I,T}
    key::IsoPipe{J,K}
    dir::Int
end

IsoFirstByPipe{I,T,J,K}(F::SeqPipe{I,T}, key::IsoPipe{J,K}, dir::Int) =
    let I = max(I, functor(J, eltype(I))),
        F = I ^ F
        IsoFirstByPipe{I,T,J,K}(F, key, dir)
    end

show(io::IO, pipe::IsoFirstByPipe) = print(io, "IsoFirstBy($(pipe.F), $(pipe.key), $(pipe.dir))")

apply{I,T,J,K}(pipe::IsoFirstByPipe{I,T,J,K}, X::I) =
    let YY = lapply(pipe.F, X),
        ys = unwrap(unwrap(YY)),
        weights = unwrap(rapply(pipe.key, YY)),
        j = (pipe.dir >= 0 ? indmax : indmin)(weights)
        Iso(ys[j])
    end


immutable OptFirstByPipe{I,T,J,K} <: OptPipe{I,T}
    F::SeqPipe{I,T}
    key::IsoPipe{J,K}
    dir::Int
end

OptFirstByPipe{I,T,J,K}(F::SeqPipe{I,T}, key::IsoPipe{J,K}, dir::Int) =
    let I = max(I, functor(J, eltype(I))),
        F = I ^ F
        OptFirstByPipe{I,T,J,K}(F, key, dir)
    end

show(io::IO, pipe::OptFirstByPipe) = print(io, "OptFirstBy(", pipe.F, ", ", pipe.val, ", ", pipe.dir, ")")

apply{I,T,J,K}(pipe::OptFirstByPipe{I,T,J,K}, X::I) =
    let YY = lapply(pipe.F, X),
        ys = unwrap(unwrap(YY)),
        weights = unwrap(rapply(pipe.key, YY))
        isempty(ys) ? Opt{T}() : Opt(ys[(pipe.dir >= 0 ? indmax : indmin)(weights)])
    end


immutable TakePipe{I,T} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    N::IsoPipe{I,Int}
    dir::Int
end

TakePipe{I1,I2,T}(F::SeqPipe{I1,T}, N::SeqPipe{I2,T}, dir::Int) =
    let I = max(I1, I2)
        TakePipe{I,T}(I ^ F, I ^ N, dir)
    end

show(io::IO, pipe::TakePipe) = print(io, "Take($(pipe.F), $(pipe.N), $(pipe.dir))")

apply{I,T}(pipe::TakePipe{I,T}, X::I) =
    let ys = unwrap(apply(pipe.F, X))::Vector{T},
        N = unwrap(apply(pipe.N, X))::Int
        if pipe.dir >= 0
            Seq(N >= 0 ? ys[1:min(N,end)] : ys[1:N+end])
        else
            Seq(N >= 0 ? ys[1+N:end] : ys[max(1,1+N+end):end])
        end
    end


immutable GetPipe{I,T,J,K} <: OptPipe{I,T}
    F::SeqPipe{I,T}
    key::IsoPipe{J,K}
    idx::IsoPipe{I,K}
end

GetPipe{I1,I2,T,J,K}(F::SeqPipe{I1,T}, key::IsoPipe{J,K}, idx::IsoPipe{I2,K}) =
    let I = max(I1, I2, functor(J, eltype(I1))),
        F = I ^ F,
        idx = I ^ idx
        @assert otype(F) == itype(key)
        GetPipe{I,T,J,K}(F, key, idx)
    end

show(io::IO, pipe::GetPipe) = print(io, "Get($(pipe.F), $(pipe.key), $(pipe.val))")

function apply{I,T,J,K}(pipe::GetPipe{I,T,J,K}, X::I)
    idx = unwrap(apply(pipe.idx, X))::K
    YY = lapply(pipe.F, X)
    zs = unwrap(rapply(pipe.key, YY))
    ys = unwrap(unwrap(YY))::Vector{T}
    for j = 1:length(ys)
        if zs[j] == idx
            return Opt(ys[j])
        end
    end
    return Opt{T}()
end


immutable ReversePipe{I,T} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
end

show(io::IO, pipe::ReversePipe) = print(io, "Reverse($(pipe.F))")

apply{I,T}(pipe::ReversePipe{I,T}, X::I) =
    Seq(reverse(unwrap(apply(pipe.F, X))::Vector{T}))


immutable SortPipe{I,T} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    dir::Int
end

show(io::IO, pipe::SortPipe) = print(io, "Sort($(pipe.F), $(pipe.dir))")

apply{I,T}(pipe::SortPipe{I,T}, X::I) =
    wrap(Seq{T}, sort(unwrap(apply(pipe.F, X))::Vector{T}, rev=(pipe.dir<0)))


immutable SortByPipe{I,T,J,K} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    key::IsoPipe{J,K}
    dir::Int
end

SortByPipe{I,T,J,K}(F::SeqPipe{I,T}, key::IsoPipe{J,K}, dir::Int) =
    let I = max(I, functor(J, eltype(I))),
        F = I ^ F
        SortByPipe{I,T,J,K}(F, key, dir)
    end
SortByPipe{I,T}(F::SeqPipe{I,T}, keys::Tuple{AbstractPipe, Int}...) =
    let pipe = F
        for (key, dir) in reverse(keys)
            pipe = SortByPipe(pipe, key, dir)
        end
        pipe
    end

show(io::IO, pipe::SortByPipe) =
    print(io, "SortBy($(pipe.F), $(pipe.key), $(pipe.dir))")

apply{I,T}(pipe::SortByPipe{I,T}, X::I) =
    let YY = lapply(pipe.F, X),
        ys = unwrap(unwrap(YY)),
        weights = unwrap(rapply(pipe.key, YY)),
        indexes = collect(1:length(ys))
        sort!(
            indexes,
            alg=MergeSort,
            by=(j -> weights[j]),
            rev=(pipe.dir<0))
        wrap(Seq{T}, T[ys[j] for j in indexes])
    end


immutable ConnectPipe{I,T} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    reflexive::Bool
end

ConnectPipe{I,O}(F::AbstractPipe{I,O}, reflexive::Bool) =
    let T = eltype(I)
        @assert T == eltype(O)
        ConnectPipe{I,T}(F ^ Seq, reflexive)
    end

show(io::IO, pipe::ConnectPipe) = print(io, "Connect($(pipe.F), $(pipe.reflexive))")

function apply{I,T}(pipe::ConnectPipe{I,T}, X::I)
    Xs = pipe.reflexive ? I[X] : reverse(unwrap(dist(fmap(pipe.F, dup(X)))))
    out = T[]
    while !isempty(Xs)
        X = pop!(Xs)
        push!(out, unwrap(X))
        append!(Xs, reverse(unwrap(dist(fmap(pipe.F, dup(X))))))
    end
    return Seq(out)
end


immutable DepthPipe{I,T} <: IsoPipe{I,Int}
    F::SeqPipe{I,T}
end

DepthPipe{I,O}(F::AbstractPipe{I,O}) =
    let T = eltype(I)
        @assert T == eltype(O)
        DepthPipe{I,T}(F ^ Seq)
    end

show(io::IO, pipe::DepthPipe) = print(io, "Depth($(pipe.F))")

function apply{I,T}(pipe::DepthPipe{I,T}, X::I)
    Xs = Tuple{I,Int}[(X,0)]
    max_d = 0
    k = 1
    while k <= length(Xs)
        X, d = Xs[k]
        max_d = max(max_d, d)
        for Y in unwrap(dist(fmap(pipe.F, dup(X))))
            push!(Xs, (Y,d+1))
        end
        k = k+1
    end
    return Iso(max_d)
end


immutable SortConnectPipe{I,T,J,K} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    L::SeqPipe{J,T}
    key::IsoPipe{J,K}
end

SortConnectPipe{I,T,J1,J2,K}(F::SeqPipe{I,T}, L::SeqPipe{J1,T}, key::IsoPipe{J2,K}) =
    let J = max(J1, J2),
        I = max(I, functor(J, eltype(I)))
        @assert T == eltype(J)
        SortConnectPipe{I,T,J,K}(I ^ F, J ^ L, J ^ key)
    end
SortConnectPipe{I,T,J1,J2,K}(F::SeqPipe{I,T}, L::OptPipe{J1,T}, key::IsoPipe{J2,K}) =
    SortConnectPipe(F, L ^ Seq, key)
SortConnectPipe{I,T}(F::SeqPipe{I,T}, L::AbstractPipe) =
    SortConnectPipe(F, L, HerePipe(T))

show(io::IO, pipe::SortConnectPipe) = print(io, "SortConnect($(pipe.F), $(pipe.L), $(pipe.key))")

function apply{I,T,J,K}(pipe::SortConnectPipe{I,T,J,K}, X::I)
    YY = lapply(pipe.F, X)
    ys = unwrap(unwrap(YY))
    keyidx = Dict{K,Int}()
    edges = Vector{Vector{Int}}()
    weight = Vector{Int}()
    for (k, key) in enumerate(rapply(pipe.key, YY))
        keyidx[key] = k
        push!(edges, [])
        push!(weight, 0)
    end
    for (k, Y) in enumerate(dist(rewrap(functor(J, eltype(YY)), YY)))
        for Z in unwrap(dist(fmap(pipe.L, dup(Y))))
            key = unwrap(apply(pipe.key, Z))
            if key in keys(keyidx)
                m = keyidx[key]
                push!(edges[m], k)
                weight[k] = weight[k]+1
            end
        end
    end
    out = Vector{T}()
    stack = Vector{Int}()
    for k = length(ys):-1:1
        if weight[k] == 0
            push!(stack, k)
        end
    end
    while !isempty(stack)
        m = pop!(stack)
        push!(out, ys[m])
        for k in reverse(edges[m])
            weight[k] = weight[k]-1
            if weight[k] == 0
                push!(stack, k)
            end
        end
    end
    return Seq(out)
end


immutable UniquePipe{I,T} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    dir::Int
end

show(io::IO, pipe::UniquePipe) = print(io, "Unique($(pipe.F), $(pipe.dir))")

apply{I,T}(pipe::UniquePipe{I,T}, X::I) =
    wrap(Seq{T}, sort(unique(unwrap(apply(pipe.F, X))::Vector{T}), rev=(pipe.dir<0)))


immutable UniqueByPipe{I,T,J,K} <: SeqPipe{I,T}
    F::SeqPipe{I,T}
    key::IsoPipe{J,K}
    dir::Int
end

UniqueByPipe{I,T,J,K}(F::SeqPipe{I,T}, key::IsoPipe{J,K}, dir::Int) =
    let I = max(I, functor(J, eltype(I)))
        @assert T == eltype(J)
        UniqueByPipe{I,T,J,K}(I ^ F, key, dir)
    end

show(io::IO, pipe::UniqueByPipe) =
    print(io, "UniqueBy($(pipe.F), $(pipe.key), $(pipe.dir))")

function apply{I,T,J,K}(pipe::UniqueByPipe{I,T,J,K}, X::I)
    YY = lapply(pipe.F, X)
    ys = unwrap(unwrap(YY))::Vector{T}
    ks = unwrap(rapply(pipe.key, YY))::Vector{K}
    kys = Vector{Tuple{K,T}}()
    seen = Set{K}()
    for (k, y) in enumerate(ys)
        key = ks[k]
        if !in(key, seen)
            push!(kys, (key, y))
            push!(seen, key)
        end
    end
    sort!(kys, rev=(pipe.dir<0))
    return Seq(T[y for (k, y) in kys])
end


immutable GroupStartPipe{I,V,T} <: IsoPipe{I,Tuple{Unit, Vector{V}}}
    F::SeqPipe{I,T}
end

show(io::IO, pipe::GroupStartPipe) = print(io, "GroupStart($(pipe.F))")

apply{I,V,T}(pipe::GroupStartPipe{I,V,T}, X::I) =
    let vs = unwrap(dist(fmap(pipe.F, dup(X))))::Vector{V}
        Iso(((), vs))
    end


immutable GroupEndPipe{P,V,T} <: AbstractPipe{Iso{Tuple{P, Vector{V}}}, Iso{Tuple{P, Vector{T}}}}
end

show(io::IO, pipe::GroupEndPipe) = print(io, "GroupEnd()")

apply{P,V,T}(pipe::GroupEndPipe{P,V,T}, X::Iso{Tuple{P, Vector{V}}}) =
    begin
        (p, vs) = unwrap(X)
        ys = T[unwrap(v) for v in vs]
        Iso((p, ys))
    end


immutable GroupByPipe{P,Q,V,R,J,K} <: AbstractPipe{Iso{Tuple{P, Vector{V}}}, Seq{Tuple{Q, Vector{V}}}}
    img::IsoPipe{V,R}
    key::IsoPipe{J,K}
    dir::Int
end

GroupByPipe{I0,T}(F::SeqPipe{I0,T}, groups::Tuple...) =
    let groups = ([length(t) == 3 ? t : (t[1], HerePipe(otype(t[1])), t[2]) for t in groups]...)
        V = functor(I0, T)
        for (img, key, dir) in groups
            V = max(V, functor(ifunctor(img), T), functor(ifunctor(key), T))
        end
        I = functor(V, eltype(I0))
        pipe = GroupStartPipe{I,V,T}(I ^ F)
        P = Tuple{}
        for (img, key, dir) in groups
            R = otype(img)
            Q = Tuple{P.parameters..., R}
            J = ifunctor(key)
            K = otype(key)
            pipe = pipe >> GroupByPipe{P,Q,V,R,J,K}(V ^ img, key, dir)
            P = Q
        end
        pipe = pipe >> GroupEndPipe{P,V,T}()
        pipe
    end

show(io::IO, pipe::GroupByPipe) = print(io, "GroupBy($(pipe.img), $(pipe.key), $(pipe.dir))")

function apply{P,Q,V,R,J,K}(pipe::GroupByPipe{P,Q,V,R,J,K}, X::Iso{Tuple{P, Vector{V}}})
    p, Ys = unwrap(X)
    ks = K[]
    qYs = Tuple{Q,Vector{V}}[]
    k2idx = Dict{K,Int}()
    for Y in Ys
        ZZ = lapply(pipe.img, Y)
        z = unwrap(unwrap(ZZ))
        k = unwrap(rapply(pipe.key, ZZ))
        if k in keys(k2idx)
            push!(qYs[k2idx[k]][2], Y)
        else
            push!(qYs, ((p..., z), V[Y]))
            push!(ks, k)
            k2idx[k] = length(ks)
        end
    end
    sort!(ks, rev=(pipe.dir<0))
    return Seq(Tuple{Q, Vector{V}}[qYs[k2idx[k]] for k in ks])
end


immutable CubeGroupByPipe{P,Q,V,R,J,K} <: AbstractPipe{Iso{Tuple{P, Vector{V}}}, Seq{Tuple{Q, Vector{V}}}}
    img::IsoPipe{V,R}
    key::IsoPipe{J,K}
    dir::Int
end

CubeGroupByPipe{I0,T}(F::SeqPipe{I0,T}, groups::Tuple...) =
    let groups = ([length(t) == 3 ? t : (t[1], HerePipe(otype(t[1])), t[2]) for t in groups]...)
        V = functor(I0, T)
        for (img, key, dir) in groups
            V = max(V, functor(ifunctor(img), T), functor(ifunctor(key), T))
        end
        I = functor(V, eltype(I0))
        pipe = GroupStartPipe{I,V,T}(I ^ F)
        P = Tuple{}
        for (img, key, dir) in groups
            R = otype(img)
            Q = Tuple{P.parameters..., Nullable{R}}
            J = ifunctor(key)
            K = otype(key)
            pipe = pipe >> CubeGroupByPipe{P,Q,V,R,J,K}(V ^ img, key, dir)
            P = Q
        end
        pipe = pipe >> GroupEndPipe{P,V,T}()
        pipe
    end

show(io::IO, pipe::CubeGroupByPipe) = print(io, "CubeGroupBy($(pipe.img), $(pipe.key), $(pipe.dir))")

function apply{P,Q,V,R,J,K}(pipe::CubeGroupByPipe{P,Q,V,R,J,K}, X::Iso{Tuple{P, Vector{V}}})
    p, Ys = unwrap(X)
    ks = K[]
    qYs = Tuple{Q,Vector{V}}[]
    k2idx = Dict{K,Int}()
    for Y in Ys
        ZZ = lapply(pipe.img, Y)
        z = unwrap(unwrap(ZZ))
        k = unwrap(rapply(pipe.key, ZZ))
        if k in keys(k2idx)
            push!(qYs[k2idx[k]][2], Y)
        else
            push!(qYs, ((p..., Nullable{R}(z)), V[Y]))
            push!(ks, k)
            k2idx[k] = length(ks)
        end
    end
    sort!(ks, rev=(pipe.dir<0))
    qYs = Tuple{Q, Vector{V}}[qYs[k2idx[k]] for k in ks]
    push!(qYs, ((p..., Nullable{R}()), Ys))
    return Seq(qYs)
end


immutable PartitionStartPipe{I,V,T} <: IsoPipe{I, Tuple{I, Tuple{Unit, Vector{V}}}}
    F::SeqPipe{I,T}
end

show(io::IO, pipe::PartitionStartPipe) = print(io, "PartitionStart($(pipe.F))")

apply{I,V,T}(pipe::PartitionStartPipe{I,V,T}, X::I) =
    let vs = unwrap(dist(fmap(pipe.F, dup(X))))::Vector{V}
        Iso((X, ((), vs)))
    end


immutable PartitionEndPipe{I,P,V,T} <: AbstractPipe{Iso{Tuple{I, Tuple{P, Vector{V}}}}, Iso{Tuple{P, Vector{T}}}}
end

show(io::IO, pipe::PartitionEndPipe) = print(io, "PartitionEnd()")

apply{I,P,V,T}(pipe::PartitionEndPipe{I,P,V,T}, X::Iso{Tuple{I, Tuple{P, Vector{V}}}}) =
    begin
        (p, vs) = unwrap(X)[2]
        ys = T[unwrap(v) for v in vs]
        Iso((p, ys))
    end

immutable PartitionByPipe{I,P,Q,V,R,J,K} <:
        AbstractPipe{Iso{Tuple{I, Tuple{P, Vector{V}}}}, Seq{Tuple{I, Tuple{Q, Vector{V}}}}}
    dim::SeqPipe{I,R}
    img::IsoPipe{V,R}
    key::IsoPipe{J,K}
    dir::Int
end

PartitionByPipe{I0,T}(F::SeqPipe{I0,T}, groups::Tuple...) =
    let groups = ([length(t) == 4 ? t : (t[1], t[2], HerePipe(otype(t[1])), t[3]) for t in groups]...)
        V = functor(I0, T)
        for (dim, img, key, dir) in groups
            V = max(V, functor(ifunctor(img), T), functor(ifunctor(key), T), functor(ifunctor(dim), T))
        end
        I = functor(V, eltype(I0))
        pipe = PartitionStartPipe{I,V,T}(I ^ F)
        P = Tuple{}
        for (dim,img, key, dir) in groups
            R = otype(img)
            Q = Tuple{P.parameters..., R}
            J = ifunctor(key)
            K = otype(key)
            pipe = pipe >> PartitionByPipe{I,P,Q,V,R,J,K}(I ^ dim, V ^ img, key, dir)
            P = Q
        end
        pipe = pipe >> PartitionEndPipe{I,P,V,T}()
        pipe
    end

show(io::IO, pipe::PartitionByPipe) = print(io, "PartitionBy($(pipe.dim), $(pipe.img), $(pipe.key), $(pipe.dir))")

function apply{I,P,Q,V,R,J,K}(pipe::PartitionByPipe{I,P,Q,V,R,J,K}, X::Iso{Tuple{I, Tuple{P, Vector{V}}}})
    S, (p, Ys) = unwrap(X)
    ks = K[]
    qYs = Tuple{I,Tuple{Q,Vector{V}}}[]
    k2idx = Dict{K,Int}()
    ZZ = lapply(pipe.dim, S)
    zs = unwrap(unwrap(ZZ))
    dks = unwrap(rapply(pipe.key, ZZ))
    for j = 1:length(zs)
        z = zs[j]
        k = dks[j]
        push!(qYs, (S, ((p..., z), V[])))
        push!(ks, k)
        k2idx[k] = length(ks)
    end
    for Y in Ys
        ZZ = lapply(pipe.img, Y)
        z = unwrap(unwrap(ZZ))
        k = unwrap(rapply(pipe.key, ZZ))
        if k in keys(k2idx)
            push!(qYs[k2idx[k]][2][2], Y)
        end
    end
    sort!(ks, rev=(pipe.dir<0))
    return Seq(Tuple{I, Tuple{Q, Vector{V}}}[qYs[k2idx[k]] for k in ks])
end


immutable CubePartitionByPipe{I,P,Q,V,R,J,K} <:
        AbstractPipe{Iso{Tuple{I, Tuple{P, Vector{V}}}}, Seq{Tuple{I, Tuple{Q, Vector{V}}}}}
    dim::SeqPipe{I,R}
    img::IsoPipe{V,R}
    key::IsoPipe{J,K}
    dir::Int
end

CubePartitionByPipe{I0,T}(F::SeqPipe{I0,T}, groups::Tuple...) =
    let groups = ([length(t) == 4 ? t : (t[1], t[2], HerePipe(otype(t[1])), t[3]) for t in groups]...)
        V = functor(I0, T)
        for (dim, img, key, dir) in groups
            V = max(V, functor(ifunctor(img), T), functor(ifunctor(key), T), functor(ifunctor(dim), T))
        end
        I = functor(V, eltype(I0))
        pipe = PartitionStartPipe{I,V,T}(I ^ F)
        P = Tuple{}
        for (dim,img, key, dir) in groups
            R = otype(img)
            Q = Tuple{P.parameters..., Nullable{R}}
            J = ifunctor(key)
            K = otype(key)
            pipe = pipe >> CubePartitionByPipe{I,P,Q,V,R,J,K}(I ^ dim, V ^ img, key, dir)
            P = Q
        end
        pipe = pipe >> PartitionEndPipe{I,P,V,T}()
        pipe
    end

show(io::IO, pipe::CubePartitionByPipe) = print(io, "CubePartitionBy($(pipe.dim), $(pipe.img), $(pipe.key), $(pipe.dir))")

function apply{I,P,Q,V,R,J,K}(pipe::CubePartitionByPipe{I,P,Q,V,R,J,K}, X::Iso{Tuple{I, Tuple{P, Vector{V}}}})
    S, (p, Ys) = unwrap(X)
    ks = K[]
    qYs = Tuple{I,Tuple{Q,Vector{V}}}[]
    k2idx = Dict{K,Int}()
    ZZ = lapply(pipe.dim, S)
    zs = unwrap(unwrap(ZZ))
    dks = unwrap(rapply(pipe.key, ZZ))
    for j = 1:length(zs)
        z = zs[j]
        k = dks[j]
        push!(qYs, (S, ((p..., Nullable(z)), V[])))
        push!(ks, k)
        k2idx[k] = length(ks)
    end
    allYs = Vector{V}()
    for Y in Ys
        ZZ = lapply(pipe.img, Y)
        z = unwrap(unwrap(ZZ))
        k = unwrap(rapply(pipe.key, ZZ))
        if k in keys(k2idx)
            push!(qYs[k2idx[k]][2][2], Y)
            push!(allYs, Y)
        end
    end
    sort!(ks, rev=(pipe.dir<0))
    qYs = Tuple{I, Tuple{Q, Vector{V}}}[qYs[k2idx[k]] for k in ks]
    push!(qYs, (S, ((p..., Nullable{R}()), allYs)))
    return Seq(qYs)
end


immutable FieldPipe{IT,O} <: AbstractPipe{Iso{IT},O}
    field::Symbol
end

FieldPipe(IT, field, O) = FieldPipe{IT,O}(field)

show{IT,O}(io::IO, pipe::FieldPipe{IT,O}) = print(io, "[$(pipe.field)]")

apply{IT,O}(pipe::FieldPipe{IT,O}, X::Iso{IT}) =
    wrap(O, getfield(unwrap(X), pipe.field))


immutable ItemPipe{IT,O} <: AbstractPipe{Iso{IT},O}
    index::Int
end

ItemPipe(IT, index) = ItemPipe{IT, Iso{IT.parameters[index]}}(index)
ItemPipe(IT, index, O) =
    ItemPipe{IT, functor(O, O <: Iso? IT.parameters[index] : eltype(IT.parameters[index]))}(index)

#show{IT,O}(io::IO, pipe::ItemPipe{IT,O}) = print(io, "[$(pipe.index)]")

apply{IT,O}(pipe::ItemPipe{IT,O}, X::Iso{IT}) =
    wrap(O, unwrap(X)[pipe.index])


immutable IsoNotPipe{I} <: IsoPipe{I,Bool}
    F::IsoPipe{I,Bool}
end

show(io::IO, pipe::IsoNotPipe) = print(io, "OptNot($(pipe.F))")

apply{I}(pipe::IsoNotPipe{I}, X::I) = wrap(Iso{Bool}, !unwrap(apply(pipe.F, X)::Iso{Bool}))


immutable OptNotPipe{I} <: OptPipe{I,Bool}
    F::OptPipe{I,Bool}
end

show(io::IO, pipe::OptNotPipe) = print(io, "OptNot($(pipe.F))")

apply{I}(pipe::OptNotPipe{I}, X::I) =
    let y = unwrap(apply(pipe.F, X))::Nullable{Bool}
        wrap(Opt{Bool}, !isnull(y) ? Nullable{Bool}(!get(y)) : Nullable{Bool}())
    end


NotPipe(F::AbstractPipe) =
    ofunctor(F) <: Iso ? IsoNotPipe(F) : OptNotPipe(F)


immutable IsoAndPipe{I} <: IsoPipe{I,Bool}
    F::IsoPipe{I,Bool}
    G::IsoPipe{I,Bool}
end

IsoAndPipe{I1,I2}(F::IsoPipe{I1,Bool}, G::IsoPipe{I2,Bool}) =
    let I = max(I1, I2)
        IsoAndPipe{I}(I ^ F, I ^ G)
    end

show(io::IO, pipe::IsoAndPipe) = print(io, "IsoAnd($(pipe.F), $(pipe.G))")

apply{I}(pipe::IsoAndPipe{I}, X::I) =
    wrap(Iso{Bool}, unwrap(apply(pipe.F, X))::Bool && unwrap(apply(pipe.G, X))::Bool)


immutable OptAndPipe{I} <: OptPipe{I,Bool}
    F::OptPipe{I,Bool}
    G::OptPipe{I,Bool}
end

show(io::IO, pipe::OptAndPipe) = print(io, "OptAnd($(pipe.F), $(pipe.G))")

apply{I}(pipe::OptAndPipe{I}, X::I) =
    let Y1 = apply(pipe.F, X)::Opt{Bool}
        if !isnull(Y1)
            if get(Y1)
                return apply(pipe.G, X)::Opt{Bool}
            end
        else
            Y2 = apply(pipe.G, X)::Opt{Bool}
            if isnull(Y2) || get(Y2)
                return Opt{Bool}()
            end
        end
        return Opt{Bool}(false)
    end


AndPipe{I1,O1,I2,O2}(F::AbstractPipe{I1,O1}, G::AbstractPipe{I2,O2}) =
    let I = max(I1, I2)
        O1 <: Iso && O2 <: Iso ?
            IsoAndPipe(I ^ F, I ^ G) :
            OptAndPipe(I ^ (F ^ Opt), I ^ (G ^ Opt))
    end


immutable IsoOrPipe{I} <: IsoPipe{I,Bool}
    F::IsoPipe{I,Bool}
    G::IsoPipe{I,Bool}
end

show(io::IO, pipe::IsoOrPipe) = print(io, "IsoOr($(pipe.F), $(pipe.G))")

apply{I}(pipe::IsoOrPipe{I}, X::I) =
    wrap(Iso{Bool}, (unwrap(apply(pipe.F, X))::Bool || unwrap(apply(pipe.G, X))::Bool))


immutable OptOrPipe{I} <: OptPipe{I,Bool}
    F::OptPipe{I,Bool}
    G::OptPipe{I,Bool}
end

show(io::IO, pipe::OptOrPipe) = print(io, "OptOr($(pipe.F), $(pipe.G))")

apply{I}(pipe::OptOrPipe{I}, X::I) =
    let Y1 = apply(pipe.F, X)::Opt{Bool}
        if !isnull(Y1)
            if !get(Y1)
                return apply(pipe.G, X)::Opt{Bool}
            end
        else
            Y2 = apply(pipe.G, X)::Opt{Bool}
            if isnull(Y2) || !get(Y2)
                return Opt{Bool}()
            end
        end
        return Opt{Bool}(true)
    end


OrPipe{I1,O1,I2,O2}(F::AbstractPipe{I1,O1}, G::AbstractPipe{I2,O2}) =
    let I = max(I1, I2)
        O1 <: Iso && O2 <: Iso ?
            IsoOrPipe(I ^ F, I ^ G) :
            OptOrPipe(I ^ (F ^ Opt), I ^ (G ^ Opt))
    end


immutable EQPipe{I,T<:Union{Int,UTF8String}} <: IsoPipe{I,Bool}
    F::IsoPipe{I,T}
    G::IsoPipe{I,T}
end

EQPipe{I1,I2,T}(F::IsoPipe{I1,T}, G::IsoPipe{I2,T}) =
    let I = max(I1, I2)
        EQPipe{I,T}(I ^ F, I ^ G)
    end

show(io::IO, pipe::EQPipe) = print(io, "EQ($(pipe.F), $(pipe.G))")

apply{I,T}(pipe::EQPipe{I,T}, X::I) =
    Iso(unwrap(apply(pipe.F, X))::T == unwrap(apply(pipe.G, X))::T)


immutable NEPipe{I,T<:Union{Int,UTF8String}} <: IsoPipe{I,Bool}
    F::IsoPipe{I,T}
    G::IsoPipe{I,T}
end

NEPipe{I1,I2,T}(F::IsoPipe{I1,T}, G::IsoPipe{I2,T}) =
    let I = max(I1, I2)
        NEPipe{I,T}(I ^ F, I ^ G)
    end

show(io::IO, pipe::NEPipe) = print(io, "NE($(pipe.F), $(pipe.G))")

apply{I,T}(pipe::NEPipe{I,T}, X::I) =
    Iso(unwrap(apply(pipe.F, X))::T != unwrap(apply(pipe.G, X))::T)


immutable InPipe{I,T<:Union{Int,UTF8String}} <: IsoPipe{I,Bool}
    F::IsoPipe{I,T}
    G::SeqPipe{I,T}
end

InPipe{I1,I2,T}(F::IsoPipe{I1,T}, G::SeqPipe{I2,T}) =
    let I = max(I1, I2)
        InPipe{I,T}(I ^ F, I ^ G)
    end

show(io::IO, pipe::InPipe) = print(io, "In($(pipe.F), $(pipe.G))")

apply{I,T}(pipe::InPipe{I,T}, X::I) =
    Iso(unwrap(apply(pipe.F, X))::T in unwrap(apply(pipe.G, X))::Vector{T})


macro defunarypipe(Name, op, T1, T2)
    return esc(quote
        immutable $Name{I} <: IsoPipe{I,$T2}
            F::IsoPipe{I,$T1}
        end
        show(io::IO, pipe::$Name) = print(io, "(", $op, ")(", pipe.F, ")")
        apply{I}(pipe::$Name, X::I) = wrap(Iso{$T2}, $op(unwrap(apply(pipe.F, X))::$T1)::$T2)
    end)
end

macro defbinarypipe(Name, op, T1, T2, T3)
    return esc(quote
        immutable $Name{I} <: IsoPipe{I,$T3}
            F::IsoPipe{I,$T1}
            G::IsoPipe{I,$T2}
        end
        $Name{I1,I2}(F::IsoPipe{I1,$T1}, G::IsoPipe{I2,$T2}) =
            let I = max(I1, I2)
                $Name{I}(I ^ F, I ^ G)
            end
        show(io::IO, pipe::$Name) = print(io, "(", $op, ")(", pipe.F, ", ", pipe.G, ")")
        apply{I}(pipe::$Name, X::I) =
            wrap(Iso{$T3}, $op(unwrap(apply(pipe.F, X))::$T1, unwrap(apply(pipe.G, X))::$T2)::$T3)
    end)
end

@defunarypipe(PosPipe, (+), Int, Int)
@defunarypipe(NegPipe, (-), Int, Int)

@defbinarypipe(LTPipe, (<), Int, Int, Bool)
@defbinarypipe(LEPipe, (<=), Int, Int, Bool)
@defbinarypipe(GEPipe, (>=), Int, Int, Bool)
@defbinarypipe(GTPipe, (>), Int, Int, Bool)
@defbinarypipe(AddPipe, (+), Int, Int, Int)
@defbinarypipe(SubPipe, (-), Int, Int, Int)
@defbinarypipe(MulPipe, (*), Int, Int, Int)
@defbinarypipe(DivPipe, div, Int, Int, Int)


immutable OptToVoidPipe{I,T} <: IsoPipe{I,Union{T,Void}}
    F::OptPipe{I,T}
end

show(io::IO, pipe::OptToVoidPipe) = print(io, "OptToVoid($(pipe.F))")

apply{I,T}(pipe::OptToVoidPipe{I,T}, X::I) =
    let Y = apply(pipe.F, X)::Opt{T}
        Iso{Union{T,Void}}(isnull(Y) ? nothing : get(Y))
    end


immutable DictPipe{I} <: IsoPipe{I,Dict{Any,Any}}
    fields::Tuple{Vararg{Pair{Symbol}}}
end

DictPipe(fields::Pair{Symbol,AbstractPipe}...) =
    let I = max([ifunctor(F) for (name, F) in fields]...)
        DictPipe{I}(([Pair{Symbol,AbstractPipe}(name, I ^ F) for (name, F) in fields]...))
    end

show(io::IO, pipe::DictPipe) =
    print(io, "DictPipe(", join(["$name => $F" for (name, F) in pipe.fields], ", "), ")")

apply{I}(pipe::DictPipe, X::I) =
    let d = Dict{Any,Any}()
        for (name, F) in pipe.fields
            d[string(name)] = unwrap(apply(F, X))
        end
        Iso(d)
    end


immutable IsoParamPipe{Ns,P,T} <: AbstractPipe{Ctx{Ns,Tuple{P},T}, Iso{P}}
end

show{Ns,P,T}(io::IO, pipe::IsoParamPipe{Ns,P,T}) = print(io, Ns[1])

IsoParamPipe(IT::Type, name::Symbol, P::Type) = IsoParamPipe{(name,),P,IT}()

apply{Ns,P,T}(pipe::IsoParamPipe{Ns,P,T}, X::Ctx{Ns,Tuple{P},T}) =
    wrap(Iso{P}, X.ctx[1])


immutable OptParamPipe{Ns,P,T} <: AbstractPipe{Ctx{Ns,Tuple{Nullable{P}},T}, Opt{P}}
end

OptParamPipe(IT::Type, name::Symbol, P::Type) = OptParamPipe{(name,),P,IT}()

show{Ns,P,T}(io::IO, pipe::OptParamPipe{Ns,P,T}) = print(io, Ns[1])

apply{Ns,P,T}(pipe::OptParamPipe{Ns,P,T}, X::Ctx{Ns,Tuple{Nullable{P}},T}) =
    wrap(Opt{P}, X.ctx[1])


immutable SeqParamPipe{Ns,P,T} <: AbstractPipe{Ctx{Ns,Tuple{Vector{P}},T}, Seq{P}}
end

SeqParamPipe(IT::Type, name::Symbol, P::Type) = SeqParamPipe{(name,),P,IT}()

show{Ns,P,T}(io::IO, pipe::SeqParamPipe{Ns,P,T}) = print(io, Ns[1])

apply{Ns,P,T}(pipe::SeqParamPipe{Ns,P,T}, X::Ctx{Ns,Tuple{Vector{P}},T}) =
    wrap(Seq{P}, X.ctx[1])


immutable ForkPipe{T} <: AbstractPipe{Temp{T}, Seq{T}}
end

ForkPipe(T::Type) = ForkPipe{T}()

show(io::IO, pipe::ForkPipe) = print(io, "Fork()")

apply{T}(pipe::ForkPipe{T}, X::Temp{T}) = Seq(X.vals)


immutable ForkByPipe{T,K} <: AbstractPipe{Temp{T}, Seq{T}}
    key::AbstractPipe{Iso{T}, Iso{K}}
end

show(io::IO, pipe::ForkByPipe) = print(io, "ForkBy($(pipe.dir))")

apply{T,K}(pipe::ForkByPipe{T,K}, X::Temp{T}) =
    let key = unwrap(apply(pipe.key, Iso(X.vals[X.idx]))),
        out = T[]
        for x in X.vals
            if unwrap(apply(pipe.key, Iso(x))) == key
                push!(out, x)
            end
        end
        Seq(out)
    end


immutable FuturePipe{T} <: AbstractPipe{Temp{T}, Seq{T}}
    dir::Int
end

FuturePipe(T::Type, dir::Int) = FuturePipe{T}(dir)

show(io::IO, pipe::FuturePipe) = print(io, "Future($(pipe.dir))")

apply{T}(pipe::FuturePipe{T}, X::Temp{T}) =
    Seq(pipe.dir >= 0 ? X.vals[X.idx+1:end] : reverse(X.vals[1:X.idx-1]))


immutable NextPipe{T} <: AbstractPipe{Temp{T}, Opt{T}}
    dir::Int
end

NextPipe(T::Type, dir::Int) = NextPipe{T}(dir)

show(io::IO, pipe::NextPipe) = print(io, "Next($(pipe.dir))")

apply{T}(pipe::NextPipe{T}, X::Temp{T}) =
    if pipe.dir >= 0
        X.idx < endof(X.vals) ? Opt(X.vals[X.idx+1]) : Opt{T}()
    else
        X.idx > 1 ? Opt(X.vals[X.idx-1]) : Opt{T}()
    end


