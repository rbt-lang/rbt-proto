#
# Query output data.
#

immutable OutputFlow <: AbstractVector{Any}
    sig::Output
    col::Column
end

OutputFlow(sig, offs, vals) = OutputFlow(sig, Column(offs, vals))

# Array interface.

size(data::OutputFlow) = (data.col.len,)
length(data::OutputFlow) = data.col.len
getindex(data::OutputFlow, i::Int) =
    let offs = offsets(data), vals = values(data),
        l = offs[i], r = offs[i+1], T = eltype(vals)
        isplural(data.sig) ?
            view(vals, l:r-1) :
        isoptional(data.sig) ?
            (l < r ? Nullable{T}(vals[l]) : Nullable{T}()) :
            vals[l]
    end
Base.array_eltype_show_how(::OutputFlow) = (true, "")
summary(data::OutputFlow) = "OutputFlow[$(length(data.col)) \ud7 $(data.sig)]"

# Data components.

column(data::OutputFlow) = data.col
offsets(data::OutputFlow) = offsets(data.col)
values(data::OutputFlow) = values(data.col)

# Output signature and its properties.

output(data::OutputFlow) = data.sig
domain(data::OutputFlow) = domain(data.sig)
mode(data::OutputFlow) = mode(data.sig)
decorations(data::OutputFlow) = decorations(data.sig)

