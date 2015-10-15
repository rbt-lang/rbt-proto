
module Pipes

export
    AbstractPipe,
    domain,
    codomain,
    RegPipe,
    OptPipe,
    SeqPipe,
    ConstPipe,
    NullPipe,
    SetPipe,
    RegMapPipe,
    OptMapPipe,
    SeqMapPipe,
    LiftToOptPipe,
    LiftToSeqPipe,
    LiftOptToSeqPipe,
    RegComposePipe,
    OptComposePipe,
    SeqComposePipe,
    CountPipe,
    MaxPipe,
    TuplePipe

import Base: >>, show


abstract AbstractPipe{I,O}

domain{I,O}(::AbstractPipe{I,O}) = I
codomain{I,O}(::AbstractPipe{I,O}) = O


abstract RegPipe{I,O} <: AbstractPipe{I,O}
abstract OptPipe{I,O} <: AbstractPipe{I,Nullable{O}}
abstract SeqPipe{I,O} <: AbstractPipe{I,Vector{O}}


immutable ConstPipe{I,O} <: RegPipe{I,O}
    val::O
end

show(io::IO, p::ConstPipe) = print(io, "ConstPipe(", repr(p.val), ")")

call{I,O}(p::ConstPipe{I,O}, ::I) = p.val


immutable NullPipe{I,O} <: OptPipe{I,O}
end

show(io::IO, ::NullPipe) = print(io, "NullPipe()")


immutable SetPipe{I,O} <: SeqPipe{I,O}
    name::Symbol
    set::Vector{O}
end

show(io::IO, p::SetPipe) = print(io, "SetPipe(<", p.name, ">)")

call{I,O}(p::SetPipe{I,O}, ::I) = p.set


immutable RegMapPipe{I,O} <: RegPipe{I,O}
    name::Symbol
    map::Dict{I,O}
end

show(io::IO, p::RegMapPipe) = print(io, "RegMapPipe(<", p.name, ">)")

call{I,O}(p::RegMapPipe{I,O}, x::I) = p.map[x]


immutable OptMapPipe{I,O} <: OptPipe{I,O}
    name::Symbol
    map::Dict{I,O}
end

show(io::IO, p::OptMapPipe) = print(io, "OptMapPipe(<", p.name, ">)")

call{I,O}(p::OptMapPipe{I,O}, x::I) =
    x in keys(p.map) ? Nullable{O}(p.map[x]) : Nullable{O}()


immutable SeqMapPipe{I,O} <: SeqPipe{I,O}
    name::Symbol
    map::Dict{I,Vector{O}}
end

show(io::IO, p::SeqMapPipe) = print(io, "SeqMapPipe(<", p.name, ">)")

call{I,O}(p::SeqMapPipe{I,O}, x::I) =
    x in keys(p.map) ? p.map[x] : O[]


immutable LiftToOptPipe{I,O} <: OptPipe{I,O}
    P::RegPipe{I,O}
end

show(io::IO, p::LiftToOptPipe) = show(io, p.P)

call{I,O}(p::LiftToOptPipe{I,O}, x::I) = Nullable{O}(p.P(x))


immutable LiftToSeqPipe{I,O} <: SeqPipe{I,O}
    P::RegPipe{I,O}
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


immutable RegComposePipe{I,T,O} <: RegPipe{I,O}
    P::RegPipe{I,T}
    Q::RegPipe{T,O}
end

show(io::IO, p::RegComposePipe) = print(io, p.P, " >> ", p.Q)

call{I,T,O}(p::RegComposePipe{I,T,O}, x::I) = p.Q(p.P(x)::T)::O


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


>>{I,T,O}(P::RegPipe{I,T}, Q::RegPipe{T,O}) =
    RegComposePipe{I,T,O}(P, Q)
>>{I,T,O}(P::RegPipe{I,T}, Q::OptPipe{T,O}) =
    OptComposePipe{I,T,O}(LiftToOptPipe{I,T}(P), Q)
>>{I,T,O}(P::RegPipe{I,T}, Q::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(LiftToSeqPipe{I,T}(P), Q)
>>{I,T,O}(P::OptPipe{I,T}, Q::RegPipe{T,O}) =
    OptComposePipe{I,T,O}(P, LiftToOptPipe{T,O}(Q))
>>{I,T,O}(P::OptPipe{I,T}, Q::OptPipe{T,O}) =
    OptComposePipe{I,T,O}(P, Q)
>>{I,T,O}(P::OptPipe{I,T}, Q::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(LiftOptToSeqPipe{I,T}(P), Q)
>>{I,T,O}(P::SeqPipe{I,T}, Q::RegPipe{T,O}) =
    SeqComposePipe{I,T,O}(P, LiftToSeqPipe{T,O}(Q))
>>{I,T,O}(P::SeqPipe{I,T}, Q::OptPipe{T,O}) =
    SeqComposePipe{I,T,O}(P, LiftOptToSeqPipe{T,O}(Q))
>>{I,T,O}(P::SeqPipe{I,T}, Q::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(P, Q)


immutable CountPipe{I,O} <: RegPipe{I,Int}
    P::SeqPipe{I,O}
end

show(io::IO, p::CountPipe) = print(io, "CountPipe(", p.P, ")")

call{I,O}(p::CountPipe{I,O}, x::I) = length(p.P(x)::Vector{O})


immutable MaxPipe{I} <: OptPipe{I,Int}
    P::SeqPipe{I,Int}
end

show(io::IO, p::MaxPipe) = print(io, "MaxPipe(", p.P, ")")

call{I}(p::MaxPipe{I}, x::I) =
    let y = p.P(x)::Vector{Int}
        isempty(y) ? Nullable{Int}() : Nullable{Int}(maximum(y))
    end


immutable TuplePipe{I,O} <: RegPipe{I,O}
    fields::Vector{AbstractPipe{I}}
end

show(io::IO, p::TuplePipe) = print(io, "TuplePipe(", join(p.fields, ", "), ")")

call{I,O}(p::TuplePipe{I,O}, x::I) =
    tuple(map(field -> field(x), p.fields)...)::O

end

