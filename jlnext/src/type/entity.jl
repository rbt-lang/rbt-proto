#
# The nominal type of database entities.
#

immutable Entity{C}
    val
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

