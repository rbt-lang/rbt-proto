
immutable ThisPipe{I} <: IsoPipe{I,I}
end

show(io::IO, pipe::ThisPipe) = print(io, "THIS")

execute{I}(::ThisPipe, x::I) = x


immutable ConstPipe{I,O} <: IsoPipe{I,O}
    val::O
end

show(io::IO, pipe::ConstPipe) = print(io, "Const(", repr(pipe.val), ")")

execute{I,O}(pipe::ConstPipe{I,O}, ::I) = pipe.val


immutable NullPipe{I,O} <: OptPipe{I,O}
end

show(io::IO, ::NullPipe) = print(io, "NULL")


immutable SetPipe{I,O} <: SeqPipe{I,O}
    name::Symbol
    set::Vector{O}
end

show(io::IO, pipe::SetPipe) = print(io, "Set(<", pipe.name, ">)")

execute{I,O}(pipe::SetPipe{I,O}, ::I) = pipe.set


immutable IsoMapPipe{I,O} <: IsoPipe{I,O}
    name::Symbol
    map::Dict{I,O}
end

show(io::IO, pipe::IsoMapPipe) = print(io, "IsoMap(<", pipe.name, ">)")

execute{I,O}(pipe::IsoMapPipe{I,O}, x::I) = pipe.map[x]


immutable OptMapPipe{I,O} <: OptPipe{I,O}
    name::Symbol
    map::Dict{I,O}
end

show(io::IO, pipe::OptMapPipe) = print(io, "OptMap(<", pipe.name, ">)")

execute{I,O}(pipe::OptMapPipe{I,O}, x::I) =
    x in keys(pipe.map) ? Nullable{O}(pipe.map[x]) : Nullable{O}()


immutable SeqMapPipe{I,O} <: SeqPipe{I,O}
    name::Symbol
    map::Dict{I,Vector{O}}
end

show(io::IO, pipe::SeqMapPipe) = print(io, "SeqMap(<", pipe.name, ">)")

execute{I,O}(pipe::SeqMapPipe{I,O}, x::I) =
    x in keys(pipe.map) ? pipe.map[x] : O[]


immutable IsoToOptPipe{I,O} <: OptPipe{I,O}
    F::IsoPipe{I,O}
end

show(io::IO, pipe::IsoToOptPipe) = show(io, pipe.F)

execute{I,O}(pipe::IsoToOptPipe{I,O}, x::I) =
    Nullable{O}(execute(pipe.F, x))


immutable IsoToSeqPipe{I,O} <: SeqPipe{I,O}
    F::IsoPipe{I,O}
end

show(io::IO, pipe::IsoToSeqPipe) = show(io, pipe.F)

execute{I,O}(pipe::IsoToSeqPipe{I,O}, x::I) =
    O[execute(pipe.F, x)]


immutable OptToSeqPipe{I,O} <: SeqPipe{I,O}
    F::OptPipe{I,O}
end

show(io::IO, pipe::OptToSeqPipe) = show(io, pipe.F)

execute{I,O}(pipe::OptToSeqPipe{I,O}, x::I) =
    let y = execute(pipe.F, x)
        isnull(y) ? O[] : O[get(y)]
    end


immutable IsoComposePipe{I,T,O} <: IsoPipe{I,O}
    F::IsoPipe{I,T}
    G::IsoPipe{T,O}
end

show(io::IO, pipe::IsoComposePipe) = print(io, pipe.F, " >> ", pipe.G)

execute{I,T,O}(pipe::IsoComposePipe{I,T,O}, x::I) =
    execute(pipe.G, execute(pipe.F, x)::T)::O


immutable OptComposePipe{I,T,O} <: OptPipe{I,O}
    F::OptPipe{I,T}
    G::OptPipe{T,O}
end

show(io::IO, pipe::OptComposePipe) = print(io, pipe.F, " >> ", pipe.G)

execute{I,T,O}(pipe::OptComposePipe{I,T,O}, x::I) =
    let y = execute(pipe.F, x)::Nullable{T}
        isnull(y) ? Nullable{O}() : execute(pipe.G, get(y))::Nullable{O}
    end


immutable SeqComposePipe{I,T,O} <: SeqPipe{I,O}
    F::SeqPipe{I,T}
    G::SeqPipe{T,O}
end

show(io::IO, pipe::SeqComposePipe) = print(io, pipe.F, " >> ", pipe.G)

execute{I,T,O}(pipe::SeqComposePipe{I,T,O}, x::I) =
    let y = execute(pipe.F, x)::Vector{T}, z = O[]
        for yi in y
            append!(z, execute(pipe.G, yi)::Vector{O})
        end
        z
    end


>>{I,T,O}(F::IsoPipe{I,T}, G::IsoPipe{T,O}) =
    IsoComposePipe{I,T,O}(F, G)
>>{I,T,O}(F::IsoPipe{I,T}, G::OptPipe{T,O}) =
    OptComposePipe{I,T,O}(IsoToOptPipe{I,T}(F), G)
>>{I,T,O}(F::IsoPipe{I,T}, G::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(IsoToSeqPipe{I,T}(F), G)
>>{I,T,O}(F::OptPipe{I,T}, G::IsoPipe{T,O}) =
    OptComposePipe{I,T,O}(F, IsoToOptPipe{T,O}(G))
>>{I,T,O}(F::OptPipe{I,T}, G::OptPipe{T,O}) =
    OptComposePipe{I,T,O}(F, G)
>>{I,T,O}(F::OptPipe{I,T}, G::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(OptToSeqPipe{I,T}(F), G)
>>{I,T,O}(F::SeqPipe{I,T}, G::IsoPipe{T,O}) =
    SeqComposePipe{I,T,O}(F, IsoToSeqPipe{T,O}(G))
>>{I,T,O}(F::SeqPipe{I,T}, G::OptPipe{T,O}) =
    SeqComposePipe{I,T,O}(F, OptToSeqPipe{T,O}(G))
>>{I,T,O}(F::SeqPipe{I,T}, G::SeqPipe{T,O}) =
    SeqComposePipe{I,T,O}(F, G)


immutable CountPipe{I,O} <: IsoPipe{I,Int}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::CountPipe) = print(io, "Count(", pipe.F, ")")

execute{I,O}(pipe::CountPipe{I,O}, x::I) =
    length(execute(pipe.F, x)::Vector{O})


immutable MaxPipe{I} <: OptPipe{I,Int}
    F::SeqPipe{I,Int}
end

show(io::IO, pipe::MaxPipe) = print(io, "Max(", pipe.F, ")")

execute{I}(pipe::MaxPipe{I}, x::I) =
    maximum(execute(pipe.F, x)::Vector{Int})


immutable OptMaxPipe{I} <: OptPipe{I,Int}
    F::SeqPipe{I,Int}
end

show(io::IO, pipe::OptMaxPipe) = print(io, "OptMax(", pipe.F, ")")

execute{I}(pipe::OptMaxPipe{I}, x::I) =
    let y = execute(pipe.F, x)::Vector{Int}
        isempty(y) ? Nullable{Int}() : Nullable{Int}(maximum(y))
    end


immutable TuplePipe{I,O} <: IsoPipe{I,O}
    Fs::Vector{AbstractPipe{I}}
end

show(io::IO, pipe::TuplePipe) = print(io, "Tuple(", join(pipe.Fs, ", "), ")")

execute{I,O}(pipe::TuplePipe{I,O}, x::I) =
    tuple(map(F -> execute(F, x), pipe.Fs)...)::O


immutable SievePipe{I} <: OptPipe{I,I}
    P::IsoPipe{I,Bool}
end

show(io::IO, pipe::SievePipe) = print(io, "Sieve(", pipe.P, ")")

execute{I}(pipe::SievePipe{I}, x::I) =
    execute(pipe.P, x)::Bool ? Nullable{I}(x) : Nullable{I}()


immutable SortPipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    order::Int
end

show(io::IO, pipe::SortPipe) = print(io, "Sort(", pipe.F, ", ", pipe.order, ")")

execute{I,O}(pipe::SortPipe{I,O}, x::I) =
    sort(execute(pipe.F, x)::Vector{O}, rev=(pipe.order<0))


immutable SortByPipe{I,O,K} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    key::IsoPipe{O,K}
    order::Int
end

show(io::IO, pipe::SortByPipe) =
    print(io, "SortBy(", pipe.F, ", ", pipe.key, ", ", pipe.order, ")")

execute{I,O,K}(pipe::SortByPipe{I,O,K}, x::I) =
    sort(
        execute(pipe.F, x)::Vector{O},
        alg=MergeSort,
        by=(y::O -> execute(pipe.key, y)::K),
        rev=(pipe.order<0))


macro defunarypipe(Name, op, T1, T2)
    return esc(quote
        immutable $Name{I} <: IsoPipe{I,$T2}
            F::IsoPipe{I,$T1}
        end
        show(io::IO, pipe::$Name) = print(io, "(", $op, " ", pipe.F, ")")
        execute{I}(pipe::$Name, x::I) = $op(execute(p.P, x)::$T1)::$T2
    end)
end

macro defbinarypipe(Name, op, T1, T2, T3)
    return esc(quote
        immutable $Name{I} <: IsoPipe{I,$T3}
            F::IsoPipe{I,$T1}
            G::IsoPipe{I,$T2}
        end
        show(io::IO, pipe::$Name) = print(io, "(", pipe.F, " ", $op, " ", pipe.G, ")")
        execute{I}(pipe::$Name, x::I) = $op(execute(pipe.F, x)::$T1, execute(pipe.G, x)::$T2)::$T3
    end)
end

@defunarypipe(NotPipe, (!), Bool, Bool)
@defunarypipe(PosPipe, (+), Int, Int)
@defunarypipe(NegPipe, (-), Int, Int)

@defbinarypipe(LTPipe, (<), Int, Int, Bool)
@defbinarypipe(LEPipe, (<=), Int, Int, Bool)
@defbinarypipe(EQPipe, (==), Int, Int, Bool)
@defbinarypipe(NEPipe, (!=), Int, Int, Bool)
@defbinarypipe(GEPipe, (>=), Int, Int, Bool)
@defbinarypipe(GTPipe, (>), Int, Int, Bool)
@defbinarypipe(AndPipe, (&), Bool, Bool, Bool)
@defbinarypipe(OrPipe, (|), Bool, Bool, Bool)
@defbinarypipe(AddPipe, (+), Int, Int, Int)
@defbinarypipe(SubPipe, (-), Int, Int, Int)
@defbinarypipe(MulPipe, (*), Int, Int, Int)
@defbinarypipe(DivPipe, div, Int, Int, Int)

