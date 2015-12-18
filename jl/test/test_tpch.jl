
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

@query(
    order
    :filter(
        (customer.mktsegment == SEGMENT) &
        (orderdate < DATE))
    :select(
        id,
        revenue =>
            lineitem:filter(shipdate > DATE).(extendedprice*(1-discount)):sum,
        orderdate,
        shippriority)
    :sort(revenue:desc, orderdate)
    :take(10),
    SEGMENT="BUILDING", DATE=Date("1995-03-15"))

@query(
    order
    :filter(
        DATE <= orderdate < DATE + 3_months &&
        any(lineitem.(commitdate < receiptdate)))
    :group(orderpriority)
    :select(
        orderpriority,
        order_count => count(order)),
    DATE=Date("1993-07-01"))

@query(
    lineitem
    :filter(
        DATE <= order.orderdate < DATE + 1_year &&
        supplier.nation == order.customer.nation &&
        supplier.nation.region.name == REGION)
    :group(supplier.nation)
    :select(
        nation,
        revenue => sum(lineitem.(extendedprice*(1-discount))))
    :sort(revenue:desc),
    REGION="ASIA", DATE=Date("1994-01-01"))

@query(
    lineitem
    :filter(
        DATE <= shipdate < DATE + 1_year &&
        DISCOUNT-0.011 <= discount <= DISCOUNT+0.011 &&
        quantity < QUANTITY)
    :group
    :select(
        revenue => sum(lineitem.(extendedprice*discount))),
    DATE=Date("1994-01-01"), DISCOUNT=0.06, QUANTITY=24)

@query(
    lineitem
    :define(
        supp_nation => supplier.nation.name,
        cust_nation => order.customer.nation.name)
    :filter(
        date("1995-01-01") <= shipdate <= date("1996-12-31") && (
            (supp_nation == NATION1 && cust_nation == NATION2) ||
            (supp_nation == NATION2 && cust_nation == NATION1)))
    :group(
        supp_nation,
        cust_nation,
        year => year(shipdate))
    :select(
        supp_nation,
        cust_nation,
        year,
        revenue => sum(lineitem.(extendedprice*(1-discount)))),
    NATION1="FRANCE", NATION2="GERMANY")

@query(
    lineitem
    :define(
        year => year(order.orderdate),
        supp_nation => supplier.nation.name,
        volume => extendedprice*(1-discount))
    :filter(
        part.type_ == TYPE &&
        order.customer.nation.region.name == REGION &&
        1995 <= year <= 1996)
    :group(year)
    :select(
        year,
        mkt_share =>
            sum(lineitem:filter(supp_nation == NATION).volume) / sum(lineitem.volume)),
    NATION="CANADA", REGION="AMERICA", TYPE="ECONOMY ANODIZED STEEL")

@query(
    lineitem
    :define(
        amount =>
            extendedprice*(1-discount) - partsupp.supplycost*quantity)
    :filter(contains(part.name, COLOR))
    :group(
        nation => supplier.nation.name,
        year => year(order.orderdate))
    :sort(nation, year:desc)
    :select(
        nation,
        year,
        sum_profit => sum(lineitem.amount)),
    COLOR="green")

@query(
    customer
    :define(
        returns =>
            order:filter(DATE <= orderdate < DATE+3_months).lineitem:filter(returnflag == "R"))
    :select(
        id,
        name,
        revenue => sum(returns.(extendedprice*(1-discount))),
        acctbal,
        nation,
        address,
        phone,
        comment)
    :sort(revenue:desc)
    :take(20),
    DATE=Date("1993-10-01"))

