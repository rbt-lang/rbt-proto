#
# Field extractor.
#

immutable FieldTool <: AbstractTool
    fields::Vector{Output}
    pos::Int


    function FieldTool(dom::Domain, pos::Int)
        @assert isrecord(dom)
        @assert 1 <= pos <= length(fields(dom))

        return new(Output[fields(dom)...], pos)
    end
end

FieldTool(dom, pos) = FieldTool(convert(Domain, dom), convert(Int, pos))

input(tool::FieldTool) = Input((tool.fields...))

output(tool::FieldTool) = tool.fields[tool.pos]

run(tool::FieldTool, iflow::InputFlow) =
    flows(values(iflow)::DataSet)[tool.pos]

Field(pos::Int) =
    Combinator(P -> P >> FieldTool(domain(output(P)), pos))

