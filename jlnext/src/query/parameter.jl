#
# Extracting a parameter from the environment.
#

ParameterQuery(tag::Symbol, oty::Output) =
    Query(
        ParameterSig(tag),
        Input(Any) |> setparameters([InputParameter(tag, oty)]),
        oty)

ParameterQuery(tag::Symbol, oty) =
    ParameterQuery(tag, convert(Output, oty))

ParameterQuery(ity::Input, tag::Symbol) =
    ParameterQuery(tag, parameter(ity, tag))

immutable ParameterSig <: AbstractPrimitive
    tag::Symbol
end

function ev(sig::ParameterSig, ::Input, oty::Output, iflow::InputFlow)
    for (name, flow) in parameterflows(iflow)
        if name == sig.tag
            return flow
        end
    end
end

