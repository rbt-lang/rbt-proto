#
# Extracting a parameter from the environment.
#

immutable ParameterTool <: AbstractTool
    name::Symbol
    sig::Output
end

input(tool::ParameterTool) =
    Input(Any, parameters=(InputParameter(tool.name, tool.sig),))

output(tool::ParameterTool) = tool.sig

function run(tool::ParameterTool, iflow::InputFlow)
    for (name, flow) in parameterflows(iflow)
        if name == tool.name
            return flow
        end
    end
end

Parameter(name::Symbol, sig) =
    Combinator(ParameterTool(name, sig))

