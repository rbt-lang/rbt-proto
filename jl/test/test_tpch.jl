
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

# Q1
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

# Q2
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
        supplier.comment)
    :take(100),
    SIZE=8, TYPE="BRASS", REGION="EUROPE")

# Q3
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

# Q4
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

# Q5
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

# Q6
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

# Q7
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

# Q8
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

# Q9
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

# Q10
@query(
    customer
    :define(
        returned =>
            order:filter(DATE <= orderdate < DATE+3_months).lineitem:filter(returnflag == "R"))
    :select(
        id,
        name,
        revenue => sum(returned.(extendedprice*(1-discount))),
        acctbal,
        nation,
        address,
        phone,
        comment)
    :sort(revenue:desc)
    :take(20),
    DATE=Date("1993-10-01"))

# Q11
@query(
    partsupp
    :filter(supplier.nation.name == NATION)
    :group(part)
    :define(value => sum(partsupp.(supplycost * availqty)))
    :filter(value > sum(and_around.value)*FRACTION)
    :select(part.id, value)
    :sort(value:desc),
    NATION="GERMANY", FRACTION=0.0001)

# Q12
@query(
    lineitem
    :define(
        high => order.orderpriority in ["1-URGENT", "2-HIGH"])
    :filter(
        shipmode in SHIPMODES &&
        shipdate < commitdate < receiptdate &&
        DATE <= receiptdate < DATE + 1_year)
    :group(shipmode)
    :select(
        shipmode,
        high_line_count => count(lineitem:filter(high)),
        low_line_count => count(lineitem:filter(!high))),
    SHIPMODES=["MAIL", "SHIP"], DATE=Date("1994-01-01"))

# Q13
@query(
    customer
    :group(
        c_count => count(order:filter(!contains(comment, WORDS))))
    :select(
        c_count,
        custdist => count(customer))
    :sort(
        custdist:desc,
        c_count:desc),
    WORDS=r".*special.*requests.*")

# Q14
@query(
    lineitem
    :define(
        volume => extendedprice*(1-discount),
        promo => startswith(part.type_, "PROMO"))
    :filter(DATE <= shipdate < DATE + 1_month)
    :group
    :select(
        promo_revenue =>
            100*sum(lineitem:filter(promo).volume)/sum(lineitem.volume)),
    DATE=Date("1995-09-01"))

# Q15
@query(
    supplier
    :define(
        total_revenue =>
            sum(lineitem:filter(DATE <= shipdate < DATE+3_months).(extendedprice*(1-discount))))
    :first(total_revenue)
    :select(
        id,
        name,
        address,
        phone,
        total_revenue),
    DATE=Date("1996-01-01"))

# Q16
@query(
    partsupp
    :filter(
        part.brand != BRAND &&
        !startswith(part.type_, TYPE) &&
        part.size in SIZES &&
        !contains(supplier.comment, r".*Customer.*Complaints.*"))
    :group(
        part.brand,
        part.type_,
        part.size)
    :select(
        brand,
        type_,
        size,
        supplier_cnt => count(unique(partsupp.supplier)))
    :sort(supplier_cnt:desc),
    BRAND="Brand#45", TYPE="MEDIUM POLISHED", SIZES=[49, 14, 23, 45, 19, 3, 36, 9])

# Q17
@query(
    lineitem
    :filter(part.brand == BRAND && part.container == CONTAINER)
    :filter(quantity < 0.2 * mean(and_around(part).quantity))
    :group
    :select(
        avg_yearly => sum(lineitem.extendedprice)/7),
    BRAND="Brand#23", CONTAINER="MED JAR")

# Q18
@query(
    order
    :select(
        customer.name,
        custkey => customer.id,
        orderkey => id,
        orderdate,
        totalprice,
        quantity => sum(lineitem.quantity))
    :filter(quantity > QUANTITY)
    :sort(
        totalprice:desc,
        orderdate)
    :take(100),
    QUANTITY=300)

# Q19
@query(
    lineitem
    :filter(
        (
            part.brand == BRAND1 &&
            part.container in ["SM CASE", "SM BOX", "SM PACK", "SM PKG"] &&
            QUANTITY1 <= quantity <= QUANTITY1+10 &&
            1 <= part.size <= 5 &&
            shipmode in ["AIR", "AIR REG"] &&
            shipinstruct == "DELIVER IN PERSON"
        )
        ||
        (
            part.brand == BRAND2 &&
            part.container in ["MED BAG", "MED BOX", "MED PKG", "MED PACK"] &&
            QUANTITY2 <= quantity <= QUANTITY2+10 &&
            1 <= part.size <= 10 &&
            shipmode in ["AIR", "AIR REG"] &&
            shipinstruct == "DELIVER IN PERSON"
        )
        ||
        (
            part.brand == BRAND3 &&
            part.container in ["LG CASE", "LG BOX", "LG PACK", "LG PKG"] &&
            QUANTITY3 <= quantity <= QUANTITY3+10 &&
            1 <= part.size <= 15 &&
            shipmode in ["AIR", "AIR REG"] &&
            shipinstruct == "DELIVER IN PERSON"
        ))
    :group
    :select(
        revenue => sum(lineitem.(extendedprice*(1-discount)))),
    QUANTITY1=1, QUANTITY2=10, QUANTITY3=20,
    BRAND1="Brand#53", BRAND2="Brand#35", BRAND3="Brand#32")

# Q20
@query(
    partsupp
    :define(
        expectedqty =>
            sum(lineitem:filter(DATE <= shipdate < DATE + 1_year).quantity))
    :filter(
        supplier.nation.name == NATION &&
        startswith(part.name, COLOR) &&
        availqty > 0.5*expectedqty)
    :group(supplier)
    :select(
        supplier.name,
        supplier.address)
    :sort(name),
    COLOR="forest", DATE=Date("1994-01-01"), NATION="CANADA")

# Q21
@query(
    lineitem
    :filter((
        order.orderstatus == "F" &&
        supplier.nation.name == NATION &&
        receiptdate > commitdate &&
        any(order.lineitem.supplier != SUPP) &&
        !any(order.lineitem.(supplier != SUPP && receiptdate > commitdate)))
        :given(SUPP => supplier))
    :group(supplier)
    :select(
        supplier.name,
        numwait => count(lineitem))
    :sort(
        numwait:desc,
        name)
    :take(100),
    NATION="SAUDI ARABIA")

# Q22
@query(
    customer
    :define(
        cntrycode => substr(phone, 1, 2))
    :filter(
        cntrycode in IS &&
        acctbal > 0_usd)
    :filter(
        !exists(order) &&
        acctbal > mean(and_around.acctbal))
    :group(cntrycode)
    :select(
        cntrycode,
        numcust => count(customer),
        totacctbal => sum(customer.acctbal)),
    IS=["13", "31", "23", "29", "30", "18", "17"])

