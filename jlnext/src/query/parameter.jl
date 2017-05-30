#
# Extracting a slot from the environment.
#

SlotQuery(tag::Symbol, oty::Output) =
    Query(
        SlotSig(tag),
        Input(Any) |> setslots([InputSlot(tag, oty)]),
        oty)

SlotQuery(tag::Symbol, oty) =
    SlotQuery(tag, convert(Output, oty))

SlotQuery(ity::Input, tag::Symbol) =
    SlotQuery(tag, slot(ity, tag))

immutable SlotSig <: AbstractPrimitive
    tag::Symbol
end

function ev(sig::SlotSig, ::Input, oty::Output, iflow::InputFlow)
    for (name, flow) in slotflows(iflow)
        if name == sig.tag
            return flow
        end
    end
end

