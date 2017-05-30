#
# The type of the query input.
#

# InputSlots with their types.

typealias InputSlot Pair{Symbol, Output}
typealias InputSlots Vector{InputSlot}

const NO_SLOTS = InputSlot[]

# Input context.

immutable InputMode
    # Depends on the preceeding and subsequent input values.
    relative::Bool
    # List of query slots.
    slots::Vector{InputSlot}
end

InputMode() = InputMode(false, NO_SLOTS)

setrelative(imode::InputMode, relative::Bool=true) =
    InputMode(relative, imode.slots)

setslots(imode::InputMode, slots::InputSlots=NO_SLOTS) =
    InputMode(imode.relative, slots)

setrelative(relative::Bool=true) =
    imode -> setrelative(imode, relative)

setslots(slots::InputSlots=NO_SLOTS) =
    imode -> setslots(imode, slots)

# Predicates and properties.

isfree(imode::InputMode) = !imode.relative && isempty(imode.slots)
isrelative(imode::InputMode) = imode.relative
slots(imode::InputMode) = imode.slots

function slot(imode::InputMode, tag::Symbol)
    for param in imode.slots
        if param.first == tag
            return param.second
        end
    end
    return Output(None)
end

# The type and the context of the input.

immutable Input
    dom::Domain
    mode::InputMode
end

Input(dom) = Input(convert(Domain, dom), InputMode())

decorate(ity::Input, d::Decoration) =
    Input(decorate(ity.dom, d), ity.mode)

setrelative(ity::Input, relative::Bool=true) =
    Input(ity.dom, setrelative(ity.mode, relative))

setslots(ity::Input, slots::InputSlots=NO_SLOTS) =
    Input(ity.dom, setslots(ity.mode, slots))

convert(::Type{Input}, dom::Union{Type, Symbol, Tuple, Vector, Domain}) =
    Input(convert(Domain, dom))

function show(io::IO, ity::Input)
    mode = ity.mode
    if !isempty(mode.slots)
        print(io, "{")
    end
    if mode.relative
        print(io, "(")
    end
    print(io, ity.dom)
    if mode.relative
        print(io, "...)")
    end
    for (n, o) in mode.slots
        print(io, ", $n => $o")
    end
    if !isempty(mode.slots)
        print(io, "}")
    end
end

# Predicates and properties.

domain(ity::Input) = ity.dom
mode(ity::Input) = ity.mode

isdata(ity::Input) = isdata(ity.dom)
isany(ity::Input) = isany(ity.dom)
isvoid(ity::Input) = isvoid(ity.dom)
isnone(ity::Input) = isnone(ity.dom)
isentity(ity::Input) = isentity(ity.dom)
isrecord(ity::Input) = isentity(ity.dom)

isfree(ity::Input) = isfree(ity.mode)
isrelative(ity::Input) = isrelative(ity.mode)
slots(ity::Input) = slots(ity.mode)
slot(ity::Input, tag::Symbol) = slot(ity, tag)

