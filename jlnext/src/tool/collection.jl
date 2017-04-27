#
# A plural constant.
#

immutable CollectionTool <: AbstractTool
    dom::Domain
    set::AbstractVector
end

CollectionTool(set::AbstractVector) = CollectionTool(eltype(set), set)

input(tool::CollectionTool) = Input(Any)

output(tool::CollectionTool) = Output(tool.dom) |> setoptional() |> setplural()

run(tool::CollectionTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        run_collection(length(iflow), tool.set))

function run_collection(len::Int, set::AbstractVector)
    card = length(set)
    if len == 1
        return Column(Int[1, card+1], set)
    end
    offs = Int[1 + i*card for i = 0:len]
    idxs = len > 0 ? Int[j for i = 1:len for j = 1:card] : Int[]
    vals = set[idxs]
    return Column(offs, vals)
end

Collection(set) = Combinator(CollectionTool(set))

Collection(dom, set) = Combinator(CollectionTool(dom, set))

