#
# Hierarchical closure.
#

immutable ConnectTool <: AbstractTool
    F::Tool
    here::Bool

    function ConnectTool(F::Tool, here::Bool)
        @assert fits(output(F), input(F))
        @assert isoptional(output(F))
        return new(F, here)
    end
end

ConnectTool(F::AbstractTool, here::Bool=false) =
    ConnectTool(convert(Tool, F), here)

input(tool::ConnectTool) = input(tool.F)
output(tool::ConnectTool) = output(tool.F) |> setoptional(!tool.here) |> setplural()

prim(tool::ConnectTool) =
    ConnectTool(prim(tool.F), tool.here)

function run(tool::ConnectTool, iflow::InputFlow)
    cols = Column[]
    if tool.here
        push!(cols, Column(OneTo(length(iflow)+1), values(iflow)))
    end
    oflow = run(tool.F, iflow)
    while length(values(oflow)) > 0
        push!(cols, column(oflow))
        iflow = distribute(iflow, oflow)
        oflow = run(tool.F, iflow)
    end
    if isempty(cols)
        pile = column(oflow)
    else
        pile = cols[end]
        for k = endof(cols)-1:-1:1
            pile = run_connect(cols[k], pile)
        end
    end
    return OutputFlow(output(tool), pile)
end

function run_connect(col1::Column, col2::Column)
    len1 = length(col1)
    len2 = length(col2)
    offs1 = offsets(col1)
    offs2 = offsets(col2)
    vals1 = values(col1)
    vals2 = values(col2)
    L = length(vals1)
    offs = Vector{Int}(len1+1)
    offs[1] = 1
    vals = vcat(vals1, vals2)
    idxs = Vector{Int}(length(vals))
    n = 1
    for i = 1:len1
        l1 = offs1[i]
        r1 = offs1[i+1]
        for j = l1:r1-1
            idxs[n] = j
            n += 1
            l2 = offs2[j]
            r2 = offs2[j+1]
            for k = l2:r2-1
                idxs[n] = L + k
                n += 1
            end
        end
        offs[i+1] = n
    end
    return Column(offs, vals[idxs])
end

Connect(F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> ConnectTool(F(Q), false)
            end)

ThenConnect() =
    Combinator(P -> ConnectTool(P, false))

HereAndConnect(F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> ConnectTool(F(Q), true)
            end)

ThenHereAndConnect() =
    Combinator(P -> ConnectTool(P, true))

