
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


immutable MaxPipe{I} <: IsoPipe{I,Int}
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
    tuple([execute(F, x) for F in pipe.Fs]...)::O


immutable SievePipe{I} <: OptPipe{I,I}
    P::IsoPipe{I,Bool}
end

show(io::IO, pipe::SievePipe) = print(io, "Sieve(", pipe.P, ")")

execute{I}(pipe::SievePipe{I}, x::I) =
    execute(pipe.P, x)::Bool ? Nullable{I}(x) : Nullable{I}()


immutable IsoFirstPipe{I,O} <: IsoPipe{I,O}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::IsoFirstPipe) = print(io, "IsoFirst(", pipe.F, ")")

execute{I,O}(pipe::IsoFirstPipe{I,O}, x::I) =
    (execute(pipe.F, x)::Vector{O})[1]::O


immutable OptFirstPipe{I,O} <: OptPipe{I,O}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::OptFirstPipe) = print(io, "OptFirst(", pipe.F, ")")

execute{I,O}(pipe::OptFirstPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O}
        isempty(ys) ? Nullable{O}() : Nullable{O}(ys[1])
    end


immutable SeqFirstPipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    N::IsoPipe{I,Int}
end

show(io::IO, pipe::SeqFirstPipe) = print(io, "SeqFirst(", pipe.F, ", ", pipe.N, ")")

execute{I,O}(pipe::SeqFirstPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O}, n = execute(pipe.N, x)::Int
        n >= 0 ? ys[1:n] : ys[1:end+n]
    end


immutable IsoLastPipe{I,O} <: IsoPipe{I,O}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::IsoLastPipe) = print(io, "IsoLast(", pipe.F, ")")

execute{I,O}(pipe::IsoLastPipe{I,O}, x::I) =
    (execute(pipe.F, x)::Vector{O})[end]::O


immutable OptLastPipe{I,O} <: OptPipe{I,O}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::OptLastPipe) = print(io, "OptLast(", pipe.F, ")")

execute{I,O}(pipe::OptLastPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O}
        isempty(ys) ? Nullable{O}() : Nullable{O}(ys[end])
    end


immutable SeqLastPipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    N::IsoPipe{I,Int}
end

show(io::IO, pipe::SeqLastPipe) = print(io, "SeqLast(", pipe.F, ", ", pipe.N, ")")

execute{I,O}(pipe::SeqLastPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O},
        n = execute(pipe.N, x)::Int
        n >= 0 ? ys[end-n+1:end] : ys[1-n:end]
    end


immutable TakePipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    N::IsoPipe{I,Int}
    M::IsoPipe{I,Int}
end

show(io::IO, pipe::TakePipe) = print(io, "Take(", pipe.F, ", ", pipe.N, ", ", pipe.M, ")")

execute{I,O}(pipe::TakePipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O},
        take = execute(pipe.N, x)::Int,
        skip = execute(pipe.M, x)::Int,
        zs = (skip >= 0 ? ys[1+skip:end] : ys[end+skip+1:end])
        take >= 0 ? zs[1:take] : zs[1:end+take]
    end


immutable ReversePipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::ReversePipe) = print(io, "Reverse(", pipe.F, ")")

execute{I,O}(pipe::ReversePipe{I,O}, x::I) =
    reverse(execute(pipe.F, x)::Vector{O})


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


immutable UniquePipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    order::Int
end

show(io::IO, pipe::UniquePipe) = print(io, "Unique(", pipe.F, ", ", pipe.order, ")")

execute{I,O}(pipe::UniquePipe{I,O}, x::I) =
    sort(unique(execute(pipe.F, x)::Vector{O}), rev=(pipe.order<0))


immutable UniqueByPipe{I,O,K} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    key::IsoPipe{O,K}
    order::Int
end

show(io::IO, pipe::UniqueByPipe) =
    print(io, "UniqueBy(", pipe.F, ", ", pipe.key, ", ", pipe.order, ")")

function execute{I,O,K}(pipe::UniqueByPipe{I,O,K}, x::I)
    ys = execute(pipe.F, x)::Vector{O}
    kys = Vector{Tuple{K,O}}()
    seen = Set{K}()
    for y in ys
        k = execute(pipe.key, y)::K
        if !in(k, seen)
            push!(kys, (k, y))
            push!(seen, k)
        end
    end
    sort!(kys, rev=(pipe.order<0))
    return O[y for (k, y) in kys]
end


immutable GroupByPipe{I,K,U,V} <: SeqPipe{I,Tuple{K,Vector{V}}}
    F::SeqPipe{I,V}
    kernel::IsoPipe{V,K}
    key::IsoPipe{K,U}
    order::Int
end

show(io::IO, pipe::GroupByPipe) =
    print(io, "GroupBy(", pipe.F, ", ", pipe.kernel, ", ", pipe.key, ", ", pipe.order, ")")


function execute{I,K,U,V}(pipe::GroupByPipe{I,K,U,V}, x::I)
    ys = execute(pipe.F, x)::Vector{V}
    kys = Vector{Tuple{U,Vector{V}}}()
    idx = Dict{U,Int}()
    ker = Dict{U,K}()
    for y in ys
        q = execute(pipe.kernel, y)::K
        k = execute(pipe.key, q)::U
        if k in keys(idx)
            push!(kys[idx[k]][2], y)
        else
            push!(kys, (k, V[y]))
            idx[k] = length(kys)
            ker[k] = q
        end
    end
    sort!(kys, rev=(pipe.order<0))
    return Tuple{K,Vector{V}}[(ker[k], ys) for (k, ys) in kys]
end


immutable IsoFieldPipe{I,O} <: IsoPipe{I,O}
    field::Symbol
end

show(io::IO, pipe::IsoFieldPipe) =
    print(io, "IsoField(<", pipe.field, ">)")

execute{I,O}(pipe::IsoFieldPipe{I,O}, x::I) =
    getfield(x, pipe.field)::O


immutable OptFieldPipe{I,O} <: OptPipe{I,O}
    field::Symbol
end

show(io::IO, pipe::OptFieldPipe) =
    print(io, "OptField(<", pipe.field, ">)")

execute{I,O}(pipe::OptFieldPipe{I,O}, x::I) =
    getfield(x, pipe.field)::Nullable{O}


immutable SeqFieldPipe{I,O} <: SeqPipe{I,O}
    field::Symbol
end

show(io::IO, pipe::SeqFieldPipe) =
    print(io, "SeqField(<", pipe.field, ">)")

execute{I,O}(pipe::SeqFieldPipe{I,O}, x::I) =
    getfield(x, pipe.field)::Vector{O}


immutable IsoItemPipe{I,O} <: IsoPipe{I,O}
    index::Int
end

show(io::IO, pipe::IsoItemPipe) =
    print(io, "IsoItem(", pipe.index, ")")

execute{I,O}(pipe::IsoItemPipe{I,O}, x::I) =
    x[pipe.index]::O


immutable OptItemPipe{I,O} <: OptPipe{I,O}
    index::Int
end

show(io::IO, pipe::OptItemPipe) =
    print(io, "OptItem(", pipe.index, ")")

execute{I,O}(pipe::OptItemPipe{I,O}, x::I) =
    x[pipe.index]::Nullable{O}


immutable SeqItemPipe{I,O} <: SeqPipe{I,O}
    index::Int
end

show(io::IO, pipe::SeqItemPipe) =
    print(io, "SeqItem(", pipe.index, ")")

execute{I,O}(pipe::SeqItemPipe{I,O}, x::I) =
    x[pipe.index]::Vector{O}


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

