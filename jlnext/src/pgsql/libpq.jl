
const libpq = Libdl.find_library("libpq")
const UINT_MAX = typemax(UInt32)
typealias FILE Void

include("libpq/common.jl")
include("libpq/output.jl")

