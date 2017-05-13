#!/usr/bin/env julia

# LD_LIBRARY_PATH=/usr/lib/llvm-3.7/lib

using Clang.wrap_c

ctx = wrap_c.init(
        headers=["/usr/include/postgresql/libpq-fe.h"],
        common_file="common.jl",
        output_file="output.jl",
        header_library="libpq",
        header_wrapped=(header, cursorname) -> startswith(cursorname, "/usr/include/postgresql/"))
wrap_c.run(ctx)

