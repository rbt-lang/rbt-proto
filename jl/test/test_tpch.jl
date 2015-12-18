
push!(LOAD_PATH, "./jl")
using RBT
include("../tpch.jl")

setdb(tpch)

function RBT.query(state, expr; params...)
    params_signature = ([(name, typeof(param)) for (name, param) in params]...)
    q = RBT.prepare(state, expr; params_signature...)
    println(repr(q))
    println(repr(q.pipe))
    r = RBT.execute(q; params...)
    #display(r)
    #println()
    return r
end

@query(region)
@query(nation)
@query(customer)
@query(supplier)
@query(part)
@query(partsupp)
@query(order)
@query(lineitem)

@query(
    lineitem
    :filter(shipdate <= date("1998-12-01") - DELTA*days)
    :group(returnflag, linestatus)
    :select(
        returnflag,
        linestatus,
        sum_qty => sum(lineitem.quantity),
        sum_base_price => sum(lineitem.extendedprice),
        sum_disc_price => sum(lineitem.(extendedprice*(1-discount))),
        sum_charge => sum(lineitem.(extendedprice*(1-discount)*(1+tax))),
        avg_qty => mean(lineitem.quantity),
        avg_price => mean(lineitem.extendedprice),
        avg_disc => mean(lineitem.discount),
        count_order => count(lineitem)),
    DELTA=90)

@query(
    partsupp
    :filter(
        (part.size == SIZE) &
        contains(part.type_, TYPE) &
        (supplier.nation.region.name == REGION))
    :filter(supplycost == min(and_around(part).supplycost))
    :sort(
        supplier.acctbal:desc,
        supplier.nation.name,
        part.name,
        part.id)
    :select(
        supplier.acctbal,
        supplier.name,
        supplier.nation,
        part.id,
        part.mfgr,
        supplier.address,
        supplier.phone,
        supplier.comment),
    SIZE=8, TYPE="BRASS", REGION="EUROPE")

