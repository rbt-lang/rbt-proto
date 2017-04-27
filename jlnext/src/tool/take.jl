#
# Pagination.
#

immutable TakeTool <: AbstractTool
    F::Tool
    N::Tool

    function TakeTool(F::Tool, N::Tool)
        @assert fits(domain(output(N)), Int)
        @assert !isplural(output(N))
        return new(F, N)
    end
end

immutable SkipTool <: AbstractTool
    F::Tool
    N::Tool

    function SkipTool(F::Tool, N::Tool)
        @assert fits(domain(output(N)), Int)
        @assert !isplural(output(N))
        return new(F, N)
    end
end

TakeTool(F, N) = TakeTool(convert(Tool, F), convert(Tool, N))
SkipTool(F, N) = SkipTool(convert(Tool, F), convert(Tool, N))

input(tool::Union{TakeTool, SkipTool}) =
    ibound(input(tool.F), input(tool.N))

output(tool::Union{TakeTool, SkipTool}) =
    output(tool.F) |> setoptional()

run(tool::Union{TakeTool, SkipTool}, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::TakeTool) =
    RecordTool(prim(tool.F), prim(tool.N)) >>
    TakeSkipPrimTool(output(tool), false)

prim(tool::SkipTool) =
    RecordTool(prim(tool.F), prim(tool.N)) >>
    TakeSkipPrimTool(output(tool), true)

ThenTake(N::Combinator) =
    Combinator(
        P ->
            let Q = HereTool(domain(input(P)))
                TakeTool(P, N(Q))
            end)

ThenSkip(N::Combinator) =
    Combinator(
        P ->
            let Q = HereTool(domain(input(P)))
                SkipTool(P, N(Q))
            end)

ThenTake(N::Int) = ThenTake(Const(N))
ThenSkip(N::Int) = ThenSkip(Const(N))

# Pagination primitive.

immutable TakeSkipPrimTool <: AbstractTool
    sig::Output
    rev::Bool
end

input(tool::TakeSkipPrimTool) =
    Input((tool.sig, Output(Int) |> setoptional()))

output(tool::TakeSkipPrimTool) = tool.sig

run_prim(tool::TakeSkipPrimTool, ds::DataSet) =
    run_takeskip(tool.rev, column(ds, 1), column(ds, 2))

function run_takeskip(rev::Bool, icol::Column, ncol::Column)
    len = length(icol)
    ioffs = offsets(icol)
    ivals = values(icol)
    noffs = offsets(ncol)
    nvals = values(ncol)
    size = 0
    for k = 1:len
        W = ioffs[k+1] - ioffs[k]
        if noffs[k+1] == noffs[k]
            size += W
        else
            w = nvals[noffs[k]]
            size +=
                !rev ?
                    (w >= 0 ? min(w, W) : max(0, W + w)) :
                    (w >= 0 ? max(W - w, 0) : min(W, -w))
        end
    end
    if size == length(ivals)
        return icol
    end
    offs = Vector{Int}(len+1)
    idxs = Vector{Int}(size)
    n = 1
    offs[1] = 1
    for k = 1:len
        L = ioffs[k]
        W = ioffs[k+1] - ioffs[k]
        if noffs[k+1] == noffs[k]
            l = 1
            r = W
        else
            w = nvals[noffs[k]]
            if !rev
                l = 1
                r = w >= 0 ? min(w, W) : max(0, W + w)
            else
                l = w >= 0 ? min(w + 1, W + 1) : max(1, W + w + 1)
                r = W
            end
        end
        for i = (L + l - 1):(L + r - 1)
            idxs[n] = i
            n += 1
        end
        offs[k+1] = n
    end
    return Column(offs, ivals[idxs])
end

