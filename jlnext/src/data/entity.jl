#
# The nominal type of database entities.
#

immutable Entity{C}
    val::Int
end

show{C}(io::IO, ::Type{Entity{C}}) =
    print(io, C)
Base.print{C}(io::IO, ::Type{Entity{C}}) =
    print(io, C)

show{C}(io::IO, e::Entity{C}) =
    print(io, "$(string(C))($(e.val))")

classname{C}(::Type{Entity{C}}) = C
classname{C}(::Entity{C}) = C

get(e::Entity) = e.val

convert{T<:Entity}(::Type{T}, val::Int) = T(val)

immutable EntityVector{C,V<:AbstractVector{Int}} <: AbstractVector{Entity{C}}
    vals::V
end

classname{C,T}(::Type{EntityVector{C,T}}) = C
classname{C,T}(::EntityVector{C,T}) = C

size(ev::EntityVector) = size(ev.vals)

length(ev::EntityVector) = length(ev.vals)

getindex{C}(ev::EntityVector{C}, i::Int) = Entity{C}(ev.vals[i])

getindex{C}(ev::EntityVector{C}, idxs::AbstractVector{Int}) =
    let vals = ev.vals[idxs]
        EntityVector{C,eltype(vals)}(vals)
    end

Base.array_eltype_show_how(::EntityVector) = (true, "")

convert{C,V<:AbstractVector{Int}}(::Type{EntityVector{C}}, vals::V) =
    EntityVector{C,V}(vals)

convert{C,V<:AbstractVector{Int}}(::Type{EntityVector{C,V}}, vals::V) =
    EntityVector{C,V}(vals)

