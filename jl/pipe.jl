
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


immutable AttachPipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    P::IsoPipe{Tuple{I,O},Bool}
end

show(io::IO, pipe::AttachPipe) = print(io, "Attach(", pipe.F, ", ", pipe.P, ")")

function execute{I,O}(pipe::AttachPipe{I,O}, x::I)
    ys = O[]
    for y in execute(pipe.F, x)::Vector{O}
        if execute(pipe.P, (x,y))::Bool
            push!(ys, y)
        end
    end
    return ys
end


immutable IsoProductPipe{I,O1,O2} <: IsoPipe{I,Tuple{O1,O2}}
    F::IsoPipe{I,O1}
    G::IsoPipe{I,O2}
end

show(io::IO, pipe::IsoProductPipe) = print(io, "(", pipe.F, " * ", pipe.G, ")")

execute{I,O1,O2}(pipe::IsoProductPipe{I,O1,O2}, x::I) =
    (execute(pipe.F, x)::O1, execute(pipe.G, x)::O2)::Tuple{O1,O2}


immutable OptProductPipe{I,O1,O2} <: OptPipe{I,Tuple{O1,O2}}
    F::OptPipe{I,O1}
    G::OptPipe{I,O2}
end

show(io::IO, pipe::OptProductPipe) = print(io, "(", pipe.F, " * ", pipe.G, ")")

execute{I,O1,O2}(pipe::OptProductPipe{I,O1,O2}, x::I) =
    let y1 = pipe.F(x)::Nullable{O1}
        if !isnull(y1)
            let y2 = pipe.G(x)::Nullable{O2}
                if !isnull(y2)
                    return Nullable{Tuple{O1,O2}}((get(y1), get(y2)))
                end
            end
        end
        return Nullable{Tuple{O1,O2}}()
    end


immutable SeqProductPipe{I,O1,O2} <: SeqPipe{I,Tuple{O1,O2}}
    F::SeqPipe{I,O1}
    G::SeqPipe{I,O2}
end

show(io::IO, pipe::SeqProductPipe) = print(io, "(", pipe.F, " * ", pipe.G, ")")

execute{I,O1,O2}(pipe::SeqProductPipe{I,O1,O2}, x::I) =
    let y1s = execute(pipe.F, x)::Vector{O1},
        y2s = execute(pipe.G, x)::Vector{O2},
        ys = Vector{Tuple{O1,O2}}()
        for y1 in y1s
            for y2 in y2s
                push!(ys, (y1, y2))
            end
        end
        ys
    end


*{I,O1,O2}(F::IsoPipe{I,O1}, G::IsoPipe{I,O2}) =
    IsoProductPipe{I,O1,O2}(F, G)
*{I,O1,O2}(F::IsoPipe{I,O1}, G::OptPipe{I,O2}) =
    OptProductPipe{I,O1,O2}(IsoToOptPipe{I,O1}(F), G)
*{I,O1,O2}(F::IsoPipe{I,O1}, G::SeqPipe{I,O2}) =
    SeqProductPipe{I,O1,O2}(IsoToSeqPipe{I,O1}(F), G)
*{I,O1,O2}(F::OptPipe{I,O1}, G::IsoPipe{I,O2}) =
    OptProductPipe{I,O1,O2}(F, IsoToOptPipe{I,O2}(G))
*{I,O1,O2}(F::OptPipe{I,O1}, G::OptPipe{I,O2}) =
    OptProductPipe{I,O1,O2}(F, G)
*{I,O1,O2}(F::OptPipe{I,O1}, G::SeqPipe{I,O2}) =
    SeqProductPipe{I,O1,O2}(OptToSeqPipe{I,O1}(F), G)
*{I,O1,O2}(F::SeqPipe{I,O1}, G::IsoPipe{I,O2}) =
    SeqProductPipe{I,O1,O2}(F, IsoToSeqPipe{I,O2}(G))
*{I,O1,O2}(F::SeqPipe{I,O1}, G::OptPipe{I,O2}) =
    SeqProductPipe{I,O1,O2}(F, OptToSeqPipe{I,O2}(G))
*{I,O1,O2}(F::SeqPipe{I,O1}, G::SeqPipe{I,O2}) =
    SeqProductPipe{I,O1,O2}(F, G)


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


immutable IsoIfNullPipe{I,O} <: IsoPipe{I,O}
    F::OptPipe{I,O}
    R::IsoPipe{I,O}
end

show(io::IO, pipe::IsoIfNullPipe) = print(io, "IsoIfNullPipe(", pipe.F, ", ", pipe.R, ")")

execute{I,O}(pipe::IsoIfNullPipe{I,O}, x::I) =
    let y = execute(pipe.F, x)
        !isnull(y) ? get(y) : execute(pipe.R, x)
    end


immutable IsoFirstPipe{I,O} <: IsoPipe{I,O}
    F::SeqPipe{I,O}
    dir::Int
end

show(io::IO, pipe::IsoFirstPipe) = print(io, "IsoFirst(", pipe.F, ", ", pipe.dir, ")")

execute{I,O}(pipe::IsoFirstPipe{I,O}, x::I) =
    (execute(pipe.F, x)::Vector{O})[(pipe.dir >= 0 ? 1 : end)]::O


immutable OptFirstPipe{I,O} <: OptPipe{I,O}
    F::SeqPipe{I,O}
    dir::Int
end

show(io::IO, pipe::OptFirstPipe) = print(io, "OptFirst(", pipe.F, ", ", pipe.dir, ")")

execute{I,O}(pipe::OptFirstPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O}
        isempty(ys) ? Nullable{O}() : Nullable{O}(ys[(pipe.dir >= 0 ? 1 : end)])
    end


immutable IsoFirstByPipe{I,O} <: IsoPipe{I,O}
    F::SeqPipe{I,O}
    val::IsoPipe{O,Int}
    dir::Int
end

show(io::IO, pipe::IsoFirstByPipe) = print(io, "IsoFirstBy(", pipe.F, ", ", pipe.val, ", ", pipe.dir, ")")

execute{I,O}(pipe::IsoFirstByPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O},
        vs = [execute(pipe.val, y)::Int for y in ys]
        ys[(pipe.dir >= 0 ? indmax : indmin)(vs)]
    end


immutable OptFirstByPipe{I,O} <: OptPipe{I,O}
    F::SeqPipe{I,O}
    val::IsoPipe{O,Int}
    dir::Int
end

show(io::IO, pipe::OptFirstByPipe) = print(io, "OptFirstBy(", pipe.F, ", ", pipe.val, ", ", pipe.dir, ")")

execute{I,O}(pipe::OptFirstByPipe{I,O}, x::I) =
    let ys = execute(pipe.F, x)::Vector{O},
        vs = [execute(pipe.val, y)::Int for y in ys]
        isempty(vs) ? Nullable{O}() : Nullable{O}(ys[(pipe.dir >= 0 ? indmax : indmin)(vs)])
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
        skip = execute(pipe.M, x)::Int
        (take >= 0 && skip >= 0) ? ys[1+skip:min(take+skip,end)] :
        (take >= 0 && skip < 0) ? ys[1:min(take+skip,end)] :
        (take < 0 && skip >= 0) ? ys[max(end+take-skip+1,1):end-skip] :
        ys[max(end+take-skip+1,1):end]
    end


immutable GetPipe{I,O,K} <: OptPipe{I,O}
    F::SeqPipe{I,O}
    key::IsoPipe{O,K}
    val::IsoPipe{I,K}
end

show(io::IO, pipe::GetPipe) = print(io, "Get(", pipe.F, ", ", pipe.key, ", ", pipe.val, ")")

function execute{I,O,K}(pipe::GetPipe{I,O,K}, x::I)
    z0 = execute(pipe.val, x)::K
    for y in execute(pipe.F, x)::Vector{O}
        if execute(pipe.key, y)::K == z0
            return Nullable{O}(y)
        end
    end
    return Nullable{O}()
end


immutable ReversePipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
end

show(io::IO, pipe::ReversePipe) = print(io, "Reverse(", pipe.F, ")")

execute{I,O}(pipe::ReversePipe{I,O}, x::I) =
    reverse(execute(pipe.F, x)::Vector{O})


immutable SortPipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    dir::Int
end

show(io::IO, pipe::SortPipe) = print(io, "Sort(", pipe.F, ", ", pipe.dir, ")")

execute{I,O}(pipe::SortPipe{I,O}, x::I) =
    sort(execute(pipe.F, x)::Vector{O}, rev=(pipe.dir<0))


immutable SortByPipe{I,O,K} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    key::IsoPipe{O,K}
    dir::Int
end

show(io::IO, pipe::SortByPipe) =
    print(io, "SortBy(", pipe.F, ", ", pipe.key, ", ", pipe.dir, ")")

execute{I,O,K}(pipe::SortByPipe{I,O,K}, x::I) =
    sort(
        execute(pipe.F, x)::Vector{O},
        alg=MergeSort,
        by=(y::O -> execute(pipe.key, y)::K),
        rev=(pipe.dir<0))


immutable ConnectPipe{I} <: SeqPipe{I,I}
    F::SeqPipe{I,I}
    reflexive::Bool
end

show(io::IO, pipe::ConnectPipe) = print(io, "Connect(", pipe.F, ", ", pipe.reflexive, ")")

function execute{I}(pipe::ConnectPipe{I}, x::I)
    xs = pipe.reflexive ? I[x] : reverse(execute(pipe.F, x)::Vector{I})
    out = I[]
    while !isempty(xs)
        x = pop!(xs)
        push!(out, x)
        append!(xs, reverse(execute(pipe.F, x)::Vector{I}))
    end
    return out
end


immutable DepthPipe{I} <: SeqPipe{I,Int}
    F::SeqPipe{I,I}
end

show(io::IO, pipe::DepthPipe) = print(io, "Depth(", pipe.F, ")")

function execute{I}(pipe::DepthPipe{I}, x::I)
    xs = Tuple{I,Int}[(x,0)]
    max_d = 0
    k = 1
    while k <= length(xs)
        x, d = xs[k]
        max_d = max(max_d, d)
        for y in execute(pipe.F, x)
            push!(xs, (y,d+1))
        end
        k = k+1
    end
    return max_d
end


immutable TopoSortPipe{I,O,J} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    L::SeqPipe{O,O}
    id::IsoPipe{O,J}
end

show(io::IO, pipe::TopoSortPipe) = print(io, "TopoSort(", pipe.F, ", ", pipe.L, ", ", pipe.id, ")")

function execute{I,O,J}(pipe::TopoSortPipe{I,O,J}, x::I)
    ys = execute(pipe.F, x)::Vector{O}
    ids = Dict{J,Int}()
    edges = Vector{Vector{Int}}()
    weight = Vector{Int}()
    for (k, y) in enumerate(ys)
        j = execute(pipe.id, y)::J
        ids[j] = k
        push!(edges, [])
        push!(weight, 0)
    end
    for (k, y) in enumerate(ys)
        for z in execute(pipe.L, y)::Vector{O}
            j = execute(pipe.id, z)::J
            if j in keys(ids)
                m = ids[j]
                push!(edges[m], k)
                weight[k] = weight[k]+1
            end
        end
    end
    out = Vector{O}()
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
    return out
end


immutable UniquePipe{I,O} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    dir::Int
end

show(io::IO, pipe::UniquePipe) = print(io, "Unique(", pipe.F, ", ", pipe.dir, ")")

execute{I,O}(pipe::UniquePipe{I,O}, x::I) =
    sort(unique(execute(pipe.F, x)::Vector{O}), rev=(pipe.dir<0))


immutable UniqueByPipe{I,O,K} <: SeqPipe{I,O}
    F::SeqPipe{I,O}
    key::IsoPipe{O,K}
    dir::Int
end

show(io::IO, pipe::UniqueByPipe) =
    print(io, "UniqueBy(", pipe.F, ", ", pipe.key, ", ", pipe.dir, ")")

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
    sort!(kys, rev=(pipe.dir<0))
    return O[y for (k, y) in kys]
end


immutable GroupByPipe{P,Q,V,K,J} <: SeqPipe{Tuple{P, Vector{V}}, Tuple{Q, Vector{V}}}
    # Q is Tuple{P..., K}
    ker::IsoPipe{V,K}
    id::IsoPipe{K,J}
    dir::Int
end

show(io::IO, pipe::GroupByPipe) =
    print(io, "GroupBy(", pipe.ker, ", ", pipe.id, ", ", pipe.dir, ")")

function execute{P,Q,V,K,J}(pipe::GroupByPipe{P,Q,V,K,J}, x::Tuple{P, Vector{V}})
    p, vs = x
    js = Vector{J}()
    qvs = Vector{Tuple{Q,Vector{V}}}()
    j2idx = Dict{J,Int}()
    for v in vs
        k = execute(pipe.ker, v)::K
        j = execute(pipe.id, k)::J
        if j in keys(j2idx)
            push!(qvs[j2idx[j]][2], v)
        else
            push!(qvs, ((p..., k), V[v]))
            push!(js, j)
            j2idx[j] = length(js)
        end
    end
    sort!(js, rev=(pipe.dir<0))
    return Tuple{Q, Vector{V}}[qvs[j2idx[j]] for j in js]
end


immutable CubeGroupByPipe{P,Q,V,K,J} <: SeqPipe{Tuple{P, Vector{V}}, Tuple{Q, Vector{V}}}
    # Q is Tuple{P..., Nullable{K}}
    ker::IsoPipe{V,K}
    id::IsoPipe{K,J}
    dir::Int
end

show(io::IO, pipe::CubeGroupByPipe) =
    print(io, "CubeGroupBy(", pipe.ker, ", ", pipe.id, ", ", pipe.dir, ")")

function execute{P,Q,V,K,J}(pipe::CubeGroupByPipe{P,Q,V,K,J}, x::Tuple{P, Vector{V}})
    p, vs = x
    js = Vector{J}()
    qvs = Vector{Tuple{Q,Vector{V}}}()
    j2idx = Dict{J,Int}()
    for v in vs
        k = execute(pipe.ker, v)::K
        j = execute(pipe.id, k)::J
        if j in keys(j2idx)
            push!(qvs[j2idx[j]][2], v)
        else
            push!(qvs, ((p..., Nullable{K}(k)), V[v]))
            push!(js, j)
            j2idx[j] = length(js)
        end
    end
    sort!(js, rev=(pipe.dir<0))
    qvs = Tuple{Q, Vector{V}}[qvs[j2idx[j]] for j in js]
    push!(qvs, ((p..., Nullable{K}()), vs))
    return qvs
end


immutable PartitionByPipe{I,P,Q,V,K,J} <: SeqPipe{Tuple{I, Tuple{P, Vector{V}}}, Tuple{I, Tuple{Q, Vector{V}}}}
    # Q is Tuple{P..., K}
    dim::SeqPipe{I,K}
    ker::IsoPipe{V,K}
    id::IsoPipe{K,J}
    dir::Int
end

show(io::IO, pipe::PartitionByPipe) =
    print(io, "PartitionBy(", pipe.dim, ", ", pipe.ker, ", ", pipe.id, ", ", pipe.dir, ")")

function execute{I,P,Q,V,K,J}(pipe::PartitionByPipe{I,P,Q,V,K,J}, x::Tuple{I, Tuple{P, Vector{V}}})
    s, (p, vs) = x
    js = Vector{J}()
    qvs = Vector{Tuple{I,Tuple{Q,Vector{V}}}}()
    j2idx = Dict{J,Int}()
    for k in execute(pipe.dim, s)::Vector{K}
        j = execute(pipe.id, k)::J
        push!(qvs, (s, ((p..., k), V[])))
        push!(js, j)
        j2idx[j] = length(js)
    end
    for v in vs
        k = execute(pipe.ker, v)::K
        j = execute(pipe.id, k)::J
        if j in keys(j2idx)
            push!(qvs[j2idx[j]][2][2], v)
        end
    end
    sort!(js, rev=(pipe.dir<0))
    return Tuple{I, Tuple{Q, Vector{V}}}[qvs[j2idx[j]] for j in js]
end


immutable CubePartitionByPipe{I,P,Q,V,K,J} <: SeqPipe{Tuple{I, Tuple{P, Vector{V}}}, Tuple{I, Tuple{Q, Vector{V}}}}
    # Q is Tuple{P..., Nullable{K}}
    dim::SeqPipe{I,K}
    ker::IsoPipe{V,K}
    id::IsoPipe{K,J}
    dir::Int
end

show(io::IO, pipe::CubePartitionByPipe) =
    print(io, "CubePartitionBy(", pipe.dim, ", ", pipe.ker, ", ", pipe.id, ", ", pipe.dir, ")")

function execute{I,P,Q,V,K,J}(pipe::CubePartitionByPipe{I,P,Q,V,K,J}, x::Tuple{I, Tuple{P, Vector{V}}})
    s, (p, vs) = x
    js = Vector{J}()
    qvs = Vector{Tuple{I,Tuple{Q,Vector{V}}}}()
    j2idx = Dict{J,Int}()
    for k in execute(pipe.dim, s)::Vector{K}
        j = execute(pipe.id, k)::J
        push!(qvs, (s, ((p..., Nullable{K}(k)), V[])))
        push!(js, j)
        j2idx[j] = length(js)
    end
    allvs = Vector{V}()
    for v in vs
        k = execute(pipe.ker, v)::K
        j = execute(pipe.id, k)::J
        if j in keys(j2idx)
            push!(qvs[j2idx[j]][2][2], v)
            push!(allvs, v)
        end
    end
    sort!(js, rev=(pipe.dir<0))
    qvs = Tuple{I, Tuple{Q, Vector{V}}}[qvs[j2idx[j]] for j in js]
    push!(qvs, (s, ((p..., Nullable{K}()), allvs)))
    return qvs
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


immutable IsoNotPipe{I} <: IsoPipe{I,Bool}
    F::IsoPipe{I,Bool}
end

show(io::IO, pipe::IsoNotPipe) = print(io, "(! ", pipe.F, ")")

execute{I}(pipe::IsoNotPipe{I}, x::I) = !(execute(pipe.F, x)::Bool)


immutable OptNotPipe{I} <: OptPipe{I,Bool}
    F::OptPipe{I,Bool}
end

show(io::IO, pipe::OptNotPipe) = print(io, "(! ", pipe.F, ")")

execute{I}(pipe::OptNotPipe{I}, x::I) =
    let y = execute(pipe.F, x)::Nullable{Bool}
        !isnull(y) ? Nullable{Bool}(!get(y)) : Nullable{Bool}()
    end


immutable IsoAndPipe{I} <: IsoPipe{I,Bool}
    F::IsoPipe{I,Bool}
    G::IsoPipe{I,Bool}
end

show(io::IO, pipe::IsoAndPipe) = print(io, "(", pipe.F, " & ", pipe.G, ")")

execute{I}(pipe::IsoAndPipe{I}, x::I) =
    (execute(pipe.F, x)::Bool && execute(pipe.G, x)::Bool)


immutable OptAndPipe{I} <: OptPipe{I,Bool}
    F::OptPipe{I,Bool}
    G::OptPipe{I,Bool}
end

show(io::IO, pipe::OptAndPipe) = print(io, "(", pipe.F, " & ", pipe.G, ")")

execute{I}(pipe::OptAndPipe{I}, x::I) =
    let y1 = execute(pipe.F, x)::Nullable{Bool}
        if !isnull(y1)
            if get(y1)
                return execute(pipe.G, x)::Nullable{Bool}
            end
        else
            y2 = execute(pipe.G, x)::Nullable{Bool}
            if isnull(y2) || get(y2)
                return Nullable{Bool}()
            end
        end
        return Nullable{Bool}(false)
    end


immutable IsoOrPipe{I} <: IsoPipe{I,Bool}
    F::IsoPipe{I,Bool}
    G::IsoPipe{I,Bool}
end

show(io::IO, pipe::IsoOrPipe) = print(io, "(", pipe.F, " | ", pipe.G, ")")

execute{I}(pipe::IsoOrPipe{I}, x::I) =
    (execute(pipe.F, x)::Bool || execute(pipe.G, x)::Bool)


immutable OptOrPipe{I} <: OptPipe{I,Bool}
    F::OptPipe{I,Bool}
    G::OptPipe{I,Bool}
end

show(io::IO, pipe::OptOrPipe) = print(io, "(", pipe.F, " | ", pipe.G, ")")

execute{I}(pipe::OptOrPipe{I}, x::I) =
    let y1 = execute(pipe.F, x)::Nullable{Bool}
        if !isnull(y1)
            if !get(y1)
                return execute(pipe.G, x)::Nullable{Bool}
            end
        else
            y2 = execute(pipe.G, x)::Nullable{Bool}
            if isnull(y2) || !get(y2)
                return Nullable{Bool}()
            end
        end
        return Nullable{Bool}(true)
    end


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

@defunarypipe(PosPipe, (+), Int, Int)
@defunarypipe(NegPipe, (-), Int, Int)

@defbinarypipe(LTPipe, (<), Int, Int, Bool)
@defbinarypipe(LEPipe, (<=), Int, Int, Bool)
@defbinarypipe(EQPipe, (==), Int, Int, Bool)
@defbinarypipe(NEPipe, (!=), Int, Int, Bool)
@defbinarypipe(GEPipe, (>=), Int, Int, Bool)
@defbinarypipe(GTPipe, (>), Int, Int, Bool)
@defbinarypipe(AddPipe, (+), Int, Int, Int)
@defbinarypipe(SubPipe, (-), Int, Int, Int)
@defbinarypipe(MulPipe, (*), Int, Int, Int)
@defbinarypipe(DivPipe, div, Int, Int, Int)


immutable OptToVoidPipe{I,O} <: IsoPipe{I,Union{O,Void}}
    F::OptPipe{I,O}
end

show(io::IO, pipe::OptToVoidPipe) =
    print(io, "OptToVoid(<", pipe.F, ">)")

execute{I,O}(pipe::OptToVoidPipe{I,O}, x::I) =
    let y = execute(pipe.F, x)::Nullable{O}
        isnull(y) ? nothing : get(y)
    end


immutable DictPipe{I} <: IsoPipe{I,Dict}
    fields::Tuple{Vararg{Pair{Symbol}}}
end

show(io::IO, pipe::DictPipe) =
    print(io, "DictPipe(", join(["$name => $F" for (name, F) in pipe.fields], ", "), ")")

execute{I}(pipe::DictPipe, x::I) =
    let d = Dict{Any,Any}()
        for (name, F) in pipe.fields
            d[string(name)] = execute(F, x)
        end
        d
    end

