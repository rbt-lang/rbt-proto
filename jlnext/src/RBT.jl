# Copyright (c) 2015 Prometheus Research, LLC
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
# option.  All the files in this project may not be copied, modified,
# or distributed except according to those terms.

#
# Rabbit, a combinator-based query language.
#

__precompile__()

module RBT

include("export.jl")
include("importbase.jl")
include("syntax.jl")
include("immdict.jl")
include("type.jl")
include("data.jl")
include("query.jl")
include("bind.jl")
include("combinator.jl")
include("pgsql.jl")

end

