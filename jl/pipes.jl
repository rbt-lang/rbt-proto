
module Pipes

export
    AbstractPipe,
    IsoPipe,
    OptPipe,
    SeqPipe,
    ConstPipe,
    NullPipe,
    SetPipe,
    IsoMapPipe,
    OptMapPipe,
    SeqMapPipe,
    LiftToOptPipe,
    LiftToSeqPipe,
    LiftOptToSeqPipe,
    IsoComposePipe,
    OptComposePipe,
    SeqComposePipe,
    CountPipe,
    MaxPipe,
    TuplePipe

import Base: >>, show, call


abstract AbstractPipe{I,O}
abstract IsoPipe{I,O} <: AbstractPipe{I,O}
abstract OptPipe{I,O} <: AbstractPipe{I,Nullable{O}}
abstract SeqPipe{I,O} <: AbstractPipe{I,Vector{O}}

call(p::AbstractPipe{Tuple{}}) = p(())

domain{I,O}(::IsoPipe{I,O}) = I
domain{I,O}(::OptPipe{I,O}) = I
domain{I,O}(::SeqPipe{I,O}) = I

codomain{I,O}(::IsoPipe{I,O}) = O
codomain{I,O}(::OptPipe{I,O}) = O
codomain{I,O}(::SeqPipe{I,O}) = O


immutable ConstPipe{I,O} <: IsoPipe{I,O}
    val::O
end

show(io::IO, p::ConstPipe) = print(io, "Const(", repr(p.val), ")")

call{I,O}(p::ConstPipe{I,O}, ::I) = p.val


immutable NullPipe{I,O} <: OptPipe{I,O}
end

show(io::IO, ::NullPipe) = print(io, "NULL")


immutable SetPipe{I,O} <: SeqPipe{I,O}
    name::Symbol
    set::Vector{O}
end

show(io::IO, p::SetPipe) = print(io, "Set(<", p.name, ">)")

call{I,O}(p::SetPipe{I,O}, ::I) = p.set


immutable IsoMapPipe{I,O} <: IsoPipe{I,O}
    name::Symbol
    map::Dict{I,O}
end

show(io::IO, p::IsoMapPipe) = print(io, "IsoMap(<", p.name, ">)")

call{I,O}(p::IsoMapPipe{I,O}, x::I) = p.map[x]


immutable OptMapPipe{I,O} <: OptPipe{I,O}
    name::Symbol
    map::Dict{I,O}
end

show(io::IO, p::OptMapPipe) = print(io, "OptMap(<", p.name, ">)")

call{I,O}(p::OptMapPipe{I,O}, x::I) =
    x in keys(p.map) ? Nullable{O}(p.map[x]) : Nullable{O}()


immutable SeqMapPipe{I,O} <: SeqPipe{I,O}
    name::Symbol
    map::Dict{I,Vector{O}}
end

show(io::IO, p::SeqMapPipe) = print(io, "SeqMap(<", p.name, ">)")

call{I,O}(p::SeqMapPipe{I,O}, x::I) =
    x in keys(p.map) ? p.map[x] : O[]


immutable LiftToOptPipe{I,O} <: OptPipe{I,O}
    P::IsoPipe{I,O}
end

show(io::IO, p::LiftToOptPipe) = show(io, p.P)

call{I,O}(p::LiftToOptPipe{I,O}, x::I) = Nullable{O}(p.P(x))


immutable LiftToSeqPipe{I,O} <: SeqPipe{I,O}
    P::IsoPipe{I,O}
end

show(io::IO, p::LiftToSeqPipe) = show(io, p.P)

call{I,O}(p::LiftToSeqPipe{I,O}, x::I) = O[p.P(x)]


immutable LiftOptToSeqPipe{I,O} <: SeqPipe{I,O}
    P::OptPipe{I,O}
end

show(io::IO, p::LiftOptToSeqPipe) = show(io, p.P)

call{I,O}(p::LiftOptToSeqPipe{I,O}, x::I) =
    let y = p.P(x)
        isnull(y) ? O[] : O[get(y)]
    end


immutable IsoComposePipe{I,T,O} <: IsoPipe{I,O}
    P::IsoPipe{I,T}
    Q::IsoPipe{T,O}
end

show(io::IO, p::IsoComposePipe) = print(io, p.P, " >> ", p.Q)

call{I,T,O}(p::IsoComposePipe{I,T,O}, x::I) = p.Q(p.P(x)::T)::O


immutable OptComposePipe{I,T,O} <: OptPipe{I,O}
    P::OptPipe{I,T}
    Q::OptPipe{T,O}
end

show(io::IO, p::OptComposePipe) = print(io, p.P, " >> ", p.Q)

call{I,T,O}(p::OptComposePipe{I,T,O}, x::I) =
    let y = p.P(x)::Nullable{T}
        isnull(y) ? Nullable{O}() : p.Q(get(y))::Nullable{O}
    end


immutable SeqComposePipe{I,T,O} <: SeqPipe{I,O}
    P::SeqPipe{I,T}
    Q::SeqPipe{T,O}
end

show(io::IO, p::SeqComposePipe) = print(io, p.P, " >> ", p.Q)

call{I,T,O}(p::SeqComposePipe{I,T,O}, x::I) =
    let y = p.P(x)::Vector{T}, z = O[]
        for yi in y
            append!(z, p.Q(yi)::Vector{O})
        end
        z
    end


>>{I,T,O}(P::IsoPipe{I,T}, Q::IsoPipe{T,O}) =
    IsoComposePipe{I,T,O}(P, Q)
>>{I,T,O}(P::IsoPipe{I,T}, Q::OptPipe{T,O}) =
    OptComposePipe{I,T,O}(LiftToOptPipe{I,T}(P), Q)
>>{I,T,O}(P::IsoPipe{I,T}, Q::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(LiftToSeqPipe{I,T}(P), Q)
>>{I,T,O}(P::OptPipe{I,T}, Q::IsoPipe{T,O}) =
    OptComposePipe{I,T,O}(P, LiftToOptPipe{T,O}(Q))
>>{I,T,O}(P::OptPipe{I,T}, Q::OptPipe{T,O}) =
    OptComposePipe{I,T,O}(P, Q)
>>{I,T,O}(P::OptPipe{I,T}, Q::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(LiftOptToSeqPipe{I,T}(P), Q)
>>{I,T,O}(P::SeqPipe{I,T}, Q::IsoPipe{T,O}) =
    SeqComposePipe{I,T,O}(P, LiftToSeqPipe{T,O}(Q))
>>{I,T,O}(P::SeqPipe{I,T}, Q::OptPipe{T,O}) =
    SeqComposePipe{I,T,O}(P, LiftOptToSeqPipe{T,O}(Q))
>>{I,T,O}(P::SeqPipe{I,T}, Q::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(P, Q)


immutable CountPipe{I,O} <: IsoPipe{I,Int}
    P::SeqPipe{I,O}
end

show(io::IO, p::CountPipe) = print(io, "Count(", p.P, ")")

call{I,O}(p::CountPipe{I,O}, x::I) = length(p.P(x)::Vector{O})


immutable MaxPipe{I} <: OptPipe{I,Int}
    P::SeqPipe{I,Int}
end

show(io::IO, p::MaxPipe) = print(io, "Max(", p.P, ")")

call{I}(p::MaxPipe{I}, x::I) =
    let y = p.P(x)::Vector{Int}
        isempty(y) ? Nullable{Int}() : Nullable{Int}(maximum(y))
    end


immutable TuplePipe{I,O} <: IsoPipe{I,O}
    fields::Vector{AbstractPipe{I}}
end

show(io::IO, p::TuplePipe) = print(io, "Tuple(", join(p.fields, ", "), ")")

call{I,O}(p::TuplePipe{I,O}, x::I) =
    tuple(map(field -> field(x), p.fields)...)::O

end

