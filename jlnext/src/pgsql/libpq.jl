
const libpq = Libdl.find_library("libpq")
const UINT_MAX = typemax(UInt32)

include("libpq/common.jl")
include("libpq/output.jl")

