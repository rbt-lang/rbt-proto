if !any([dirname(path) == dirname(@__FILE__) for path in LOAD_PATH])
    push!(LOAD_PATH, dirname(@__FILE__))
end

ENV["LINES"] = 10

using RBT: Entity, ToyDatabase, Schema, Class, Arrow, Instance, Iso, Opt, Seq, Monetary

RBT.formatdf()

CSV_DIR = joinpath(dirname(@__FILE__), "../data/tpch")

schema = Schema(
    Class(
        :region,
        Arrow(:name, ASCIIString),
        Arrow(:comment, ASCIIString),
        Arrow(
            :nation,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:region),
        select=(:name, :comment)),
    Class(
        :nation,
        Arrow(:name, ASCIIString),
        Arrow(:region, select=:name),
        Arrow(:comment, ASCIIString),
        Arrow(
            :customer,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:nation),
        Arrow(
            :supplier,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:nation),
        select=(:name, :region, :comment)),
    Class(
        :customer,
        Arrow(:name, ASCIIString),
        Arrow(:address, ASCIIString),
        Arrow(:nation, select=:name),
        Arrow(:phone, ASCIIString),
        Arrow(:acctbal, Monetary{:USD}),
        Arrow(:mktsegment, ASCIIString),
        Arrow(:comment, ASCIIString),
        Arrow(
            :order,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:customer),
        select=(:name, :address, :nation, :phone, :acctbal, :mktsegment, :comment)),
    Class(
        :supplier,
        Arrow(:name, ASCIIString),
        Arrow(:address, ASCIIString),
        Arrow(:nation, select=:name),
        Arrow(:phone, ASCIIString),
        Arrow(:acctbal, Monetary{:USD}),
        Arrow(:comment, ASCIIString),
        Arrow(
            :partsupp,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:supplier),
        Arrow(
            :lineitem,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:supplier),
        select=(:name, :address, :nation, :phone, :acctbal, :comment)),
    Class(
        :part,
        Arrow(:name, ASCIIString),
        Arrow(:mfgr, ASCIIString),
        Arrow(:brand, ASCIIString),
        Arrow(:type, ASCIIString),
        Arrow(:size, Int),
        Arrow(:container, ASCIIString),
        Arrow(:retailprice, Monetary{:USD}),
        Arrow(:comment, ASCIIString),
        Arrow(
            :partsupp,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:part),
        Arrow(
            :lineitem,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:part),
        select=(:name, :mfgr, :brand, :type, :size, :container, :retailprice, :comment)),
    Class(
        :partsupp,
        Arrow(:part, select=:name),
        Arrow(:supplier, select=:name),
        Arrow(:availqty, Int),
        Arrow(:supplycost, Monetary{:USD}),
        Arrow(:comment, ASCIIString),
        Arrow(
            :lineitem,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:partsupp),
        select=(:part, :supplier, :availqty, :supplycost, :comment)),
    Class(
        :order,
        Arrow(:customer, select=:name),
        Arrow(:orderstatus, ASCIIString),
        Arrow(:totalprice, Monetary{:USD}),
        Arrow(:orderdate, Date),
        Arrow(:orderpriority, ASCIIString),
        Arrow(:clerk, ASCIIString),
        Arrow(:shippriority, Int),
        Arrow(:comment, ASCIIString),
        Arrow(
            :lineitem,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            inverse=:order),
        select=(:customer, :orderstatus, :totalprice, :orderdate, :orderpriority, :clerk, :shippriority, :comment)),
    Class(
        :lineitem,
        Arrow(:order, select=:customer),
        Arrow(:part, select=:name),
        Arrow(:supplier, select=:name),
        Arrow(:partsupp, select=(:part, :supplier)),
        Arrow(:linenumber, Int),
        Arrow(:quantity, Int),
        Arrow(:extendedprice, Monetary{:USD}),
        Arrow(:discount, Float64),
        Arrow(:tax, Float64),
        Arrow(:returnflag, ASCIIString),
        Arrow(:linestatus, ASCIIString),
        Arrow(:shipdate, Date),
        Arrow(:commitdate, Date),
        Arrow(:receiptdate, Date),
        Arrow(:shipinstruct, ASCIIString),
        Arrow(:shipmode, ASCIIString),
        Arrow(:comment, ASCIIString),
        select=(
            :order, :part, :supplier, :linenumber, :quantity, :extendedprice, :discount, :tax,
            :returnflag, :linestatus, :shipdate, :commitdate, :receiptdate, :shipinstruct, :shipmode, :comment)))

R = Entity{:region}
N = Entity{:nation}
C = Entity{:customer}
S = Entity{:supplier}
P = Entity{:part}
PS = Entity{:partsupp}
O = Entity{:order}
L = Entity{:lineitem}

rkey = Dict{Int, R}()
nkey = Dict{Int, N}()
ckey = Dict{Int, C}()
skey = Dict{Int, S}()
pkey = Dict{Int, P}()
pskey = Dict{Tuple{Int,Int}, PS}()
okey = Dict{Int, O}()

rs = Vector{R}()
ns = Vector{N}()
cs = Vector{C}()
ss = Vector{S}()
ps = Vector{P}()
pss = Vector{PS}()
os = Vector{O}()
ls = Vector{L}()

r_name = Vector{Iso{ASCIIString}}()
r_comment = Vector{Iso{ASCIIString}}()
r_nation = Vector{Seq{N}}()

n_name = Vector{Iso{ASCIIString}}()
n_region = Vector{Iso{R}}()
n_comment = Vector{Iso{ASCIIString}}()
n_customer = Vector{Seq{C}}()
n_supplier = Vector{Seq{S}}()

c_name = Vector{Iso{ASCIIString}}()
c_address = Vector{Iso{ASCIIString}}()
c_nation = Vector{Iso{N}}()
c_phone = Vector{Iso{ASCIIString}}()
c_acctbal = Vector{Iso{Monetary{:USD}}}()
c_mktsegment = Vector{Iso{ASCIIString}}()
c_comment = Vector{Iso{ASCIIString}}()
c_order = Vector{Seq{O}}()

s_name = Vector{Iso{ASCIIString}}()
s_address = Vector{Iso{ASCIIString}}()
s_nation = Vector{Iso{N}}()
s_phone = Vector{Iso{ASCIIString}}()
s_acctbal = Vector{Iso{Monetary{:USD}}}()
s_comment = Vector{Iso{ASCIIString}}()
s_partsupp = Vector{Seq{PS}}()
s_lineitem = Vector{Seq{L}}()

p_name = Vector{Iso{ASCIIString}}()
p_mfgr = Vector{Iso{ASCIIString}}()
p_brand = Vector{Iso{ASCIIString}}()
p_type = Vector{Iso{ASCIIString}}()
p_size = Vector{Iso{Int}}()
p_container = Vector{Iso{ASCIIString}}()
p_retailprice = Vector{Iso{Monetary{:USD}}}()
p_comment = Vector{Iso{ASCIIString}}()
p_partsupp = Vector{Seq{PS}}()
p_lineitem = Vector{Seq{L}}()

ps_part = Vector{Iso{P}}()
ps_supplier = Vector{Iso{S}}()
ps_availqty = Vector{Iso{Int}}()
ps_supplycost = Vector{Iso{Monetary{:USD}}}()
ps_comment = Vector{Iso{ASCIIString}}()
ps_lineitem = Vector{Seq{L}}()

o_customer = Vector{Iso{C}}()
o_orderstatus = Vector{Iso{ASCIIString}}()
o_totalprice = Vector{Iso{Monetary{:USD}}}()
o_orderdate = Vector{Iso{Date}}()
o_orderpriority = Vector{Iso{ASCIIString}}()
o_clerk = Vector{Iso{ASCIIString}}()
o_shippriority = Vector{Iso{Int}}()
o_comment = Vector{Iso{ASCIIString}}()
o_lineitem = Vector{Seq{L}}()

l_order = Vector{Iso{O}}()
l_part = Vector{Iso{P}}()
l_supplier = Vector{Iso{S}}()
l_partsupp = Vector{Iso{PS}}()
l_linenumber = Vector{Iso{Int}}()
l_quantity = Vector{Iso{Int}}()
l_extendedprice = Vector{Iso{Monetary{:USD}}}()
l_discount = Vector{Iso{Float64}}()
l_tax = Vector{Iso{Float64}}()
l_returnflag = Vector{Iso{ASCIIString}}()
l_linestatus = Vector{Iso{ASCIIString}}()
l_shipdate = Vector{Iso{Date}}()
l_commitdate = Vector{Iso{Date}}()
l_receiptdate = Vector{Iso{Date}}()
l_shipinstruct = Vector{Iso{ASCIIString}}()
l_shipmode = Vector{Iso{ASCIIString}}()
l_comment = Vector{Iso{ASCIIString}}()

csv = readcsv("$CSV_DIR/region.csv", comments=false)
for k = 1:size(csv, 1)
    key, name, comment = csv[k, :]
    r = R(k)
    rkey[key] = r
    push!(rs, r)
    push!(r_name, Iso{ASCIIString}(name))
    push!(r_comment, Iso{ASCIIString}(comment))
    push!(r_nation, Seq{N}(N[]))
end

csv = readcsv("$CSV_DIR/nation.csv", comments=false)
for k = 1:size(csv, 1)
    key, name, regionkey, comment = csv[k, :]
    region = rkey[regionkey]
    n = N(k)
    nkey[key] = n
    push!(ns, n)
    push!(n_name, Iso{ASCIIString}(name))
    push!(n_region, Iso{R}(region))
    push!(n_comment, Iso{ASCIIString}(comment))
    push!(n_customer, Seq{C}(C[]))
    push!(n_supplier, Seq{S}(S[]))
    push!(r_nation[region.id].data, n)
end

csv = readcsv("$CSV_DIR/customer.csv", comments=false)
for k = 1:size(csv, 1)
    key, name, address, nationkey, phone, acctbal, mktsegment, comment = csv[k, :]
    nation = nkey[nationkey]
    c = C(k)
    ckey[key] = c
    push!(cs, c)
    push!(c_name, Iso{ASCIIString}(name))
    push!(c_address, Iso{ASCIIString}(address))
    push!(c_nation, Iso{N}(nation))
    push!(c_phone, Iso{ASCIIString}(phone))
    push!(c_acctbal, Iso{Monetary{:USD}}(acctbal))
    push!(c_mktsegment, Iso{ASCIIString}(mktsegment))
    push!(c_comment, Iso{ASCIIString}(comment))
    push!(c_order, Seq{O}(O[]))
    push!(n_customer[nation.id].data, c)
end

csv = readcsv("$CSV_DIR/supplier.csv", comments=false)
for k = 1:size(csv, 1)
    key, name, address, nationkey, phone, acctbal, comment = csv[k, :]
    nation = nkey[nationkey]
    s = S(k)
    skey[key] = s
    push!(ss, s)
    push!(s_name, Iso{ASCIIString}(name))
    push!(s_address, Iso{ASCIIString}(address))
    push!(s_nation, Iso{N}(nation))
    push!(s_phone, Iso{ASCIIString}(phone))
    push!(s_acctbal, Iso{Monetary{:USD}}(acctbal))
    push!(s_comment, Iso{ASCIIString}(comment))
    push!(s_partsupp, Seq{PS}(PS[]))
    push!(s_lineitem, Seq{L}(L[]))
    push!(n_supplier[nation.id].data, s)
end

csv = readcsv("$CSV_DIR/part.csv", comments=false)
for k = 1:size(csv, 1)
    key, name, mfgr, brand, type_, size, container, retailprice, comment = csv[k, :]
    p = P(k)
    pkey[key] = p
    push!(ps, p)
    push!(p_name, Iso{ASCIIString}(name))
    push!(p_mfgr, Iso{ASCIIString}(mfgr))
    push!(p_brand, Iso{ASCIIString}(brand))
    push!(p_type, Iso{ASCIIString}(type_))
    push!(p_size, Iso{Int}(size))
    push!(p_container, Iso{ASCIIString}(container))
    push!(p_retailprice, Iso{Monetary{:USD}}(retailprice))
    push!(p_comment, Iso{ASCIIString}(comment))
    push!(p_partsupp, Seq{PS}(PS[]))
    push!(p_lineitem, Seq{L}(L[]))
end

csv = readcsv("$CSV_DIR/partsupp.csv", comments=false)
for k = 1:size(csv, 1)
    partkey, suppkey, availqty, supplycost, comment = csv[k, :]
    ps_ = PS(k)
    part = pkey[partkey]
    supplier = skey[suppkey]
    pskey[partkey, suppkey] = ps_
    push!(pss, ps_)
    push!(ps_part, Iso{P}(part))
    push!(ps_supplier, Iso{S}(supplier))
    push!(ps_availqty, Iso{Int}(availqty))
    push!(ps_supplycost, Iso{Monetary{:USD}}(supplycost))
    push!(ps_comment, Iso{ASCIIString}(comment))
    push!(ps_lineitem, Seq{L}(L[]))
    push!(s_partsupp[supplier.id].data, ps_)
    push!(p_partsupp[part.id].data, ps_)
end

csv = readcsv("$CSV_DIR/orders.csv", comments=false)
for k = 1:size(csv, 1)
    orderkey, custkey, orderstatus, totalprice, orderdate, orderpriority, clerk, shippriority, comment = csv[k, :]
    o = O(k)
    customer = ckey[custkey]
    okey[orderkey] = o
    push!(os, o)
    push!(o_customer, Iso{C}(customer))
    push!(o_orderstatus, Iso{ASCIIString}(orderstatus))
    push!(o_totalprice, Iso{Monetary{:USD}}(totalprice))
    push!(o_orderdate, Iso{Date}(Date(orderdate)))
    push!(o_orderpriority, Iso{ASCIIString}(orderpriority))
    push!(o_clerk, Iso{ASCIIString}(clerk))
    push!(o_shippriority, Iso{Int}(shippriority))
    push!(o_comment, Iso{ASCIIString}(comment))
    push!(o_lineitem, Seq{L}(L[]))
    push!(c_order[customer.id].data, o)
end

csv = readcsv("$CSV_DIR/lineitem.csv", comments=false)
for k = 1:size(csv, 1)
    orderkey, partkey, suppkey, linenumber, quantity, extendedprice, discount, tax,
    returnflag, linestatus, shipdate, commitdate, receiptdate,
    shipinstruct, shipmode, comment = csv[k, :]
    l = L(k)
    order = okey[orderkey]
    part = pkey[partkey]
    supplier = skey[suppkey]
    partsupp = pskey[partkey, suppkey]
    push!(ls, l)
    push!(l_order, Iso{O}(order))
    push!(l_part, Iso{P}(part))
    push!(l_supplier, Iso{S}(supplier))
    push!(l_partsupp, Iso{PS}(partsupp))
    push!(l_linenumber, Iso{Int}(linenumber))
    push!(l_quantity, Iso{Int}(quantity))
    push!(l_extendedprice, Iso{Monetary{:USD}}(extendedprice))
    push!(l_discount, Iso{Float64}(discount))
    push!(l_tax, Iso{Float64}(tax))
    push!(l_returnflag, Iso{ASCIIString}(returnflag))
    push!(l_linestatus, Iso{ASCIIString}(linestatus))
    push!(l_shipdate, Iso{Date}(Date(shipdate)))
    push!(l_commitdate, Iso{Date}(Date(commitdate)))
    push!(l_receiptdate, Iso{Date}(Date(receiptdate)))
    push!(l_shipinstruct, Iso{ASCIIString}(shipinstruct))
    push!(l_shipmode, Iso{ASCIIString}(shipmode))
    push!(l_comment, Iso{ASCIIString}(comment))
    push!(o_lineitem[order.id].data, l)
    push!(p_lineitem[part.id].data, l)
    push!(s_lineitem[supplier.id].data, l)
    push!(ps_lineitem[partsupp.id].data, l)
end

instance = Instance(
    Dict(
        :region => rs,
        :nation => ns,
        :customer => cs,
        :supplier => ss,
        :part => ps,
        :partsupp => pss,
        :order => os,
        :lineitem => ls),
    Dict(
        (:region, :name) => r_name,
        (:region, :comment) => r_comment,
        (:region, :nation) => r_nation,
        (:nation, :name) => n_name,
        (:nation, :region) => n_region,
        (:nation, :comment) => n_comment,
        (:nation, :customer) => n_customer,
        (:nation, :supplier) => n_supplier,
        (:customer, :name) => c_name,
        (:customer, :address) => c_address,
        (:customer, :nation) => c_nation,
        (:customer, :phone) => c_phone,
        (:customer, :acctbal) => c_acctbal,
        (:customer, :mktsegment) => c_mktsegment,
        (:customer, :comment) => c_comment,
        (:customer, :order) => c_order,
        (:supplier, :name) => s_name,
        (:supplier, :address) => s_address,
        (:supplier, :nation) => s_nation,
        (:supplier, :phone) => s_phone,
        (:supplier, :acctbal) => s_acctbal,
        (:supplier, :comment) => s_comment,
        (:supplier, :partsupp) => s_partsupp,
        (:supplier, :lineitem) => s_lineitem,
        (:part, :name) => p_name,
        (:part, :mfgr) => p_mfgr,
        (:part, :brand) => p_brand,
        (:part, :type) => p_type,
        (:part, :size) => p_size,
        (:part, :container) => p_container,
        (:part, :retailprice) => p_retailprice,
        (:part, :comment) => p_comment,
        (:part, :partsupp) => p_partsupp,
        (:part, :lineitem) => p_lineitem,
        (:partsupp, :part) => ps_part,
        (:partsupp, :supplier) => ps_supplier,
        (:partsupp, :availqty) => ps_availqty,
        (:partsupp, :supplycost) => ps_supplycost,
        (:partsupp, :comment) => ps_comment,
        (:partsupp, :lineitem) => ps_lineitem,
        (:order, :customer) => o_customer,
        (:order, :orderstatus) => o_orderstatus,
        (:order, :totalprice) => o_totalprice,
        (:order, :orderdate) => o_orderdate,
        (:order, :orderpriority) => o_orderpriority,
        (:order, :clerk) => o_clerk,
        (:order, :shippriority) => o_shippriority,
        (:order, :comment) => o_comment,
        (:order, :lineitem) => o_lineitem,
        (:lineitem, :order) => l_order,
        (:lineitem, :part) => l_part,
        (:lineitem, :supplier) => l_supplier,
        (:lineitem, :partsupp) => l_partsupp,
        (:lineitem, :linenumber) => l_linenumber,
        (:lineitem, :quantity) => l_quantity,
        (:lineitem, :extendedprice) => l_extendedprice,
        (:lineitem, :discount) => l_discount,
        (:lineitem, :tax) => l_tax,
        (:lineitem, :returnflag) => l_returnflag,
        (:lineitem, :linestatus) => l_linestatus,
        (:lineitem, :shipdate) => l_shipdate,
        (:lineitem, :commitdate) => l_commitdate,
        (:lineitem, :receiptdate) => l_receiptdate,
        (:lineitem, :shipinstruct) => l_shipinstruct,
        (:lineitem, :shipmode) => l_shipmode,
        (:lineitem, :comment) => l_comment))

tpch = ToyDatabase(schema, instance)

