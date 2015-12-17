
CREATE TABLE region (
    r_regionkey     INTEGER NOT NULL,
    r_name          CHAR(25) NOT NULL,
    r_comment       VARCHAR(152) NOT NULL);

CREATE TABLE nation (
    n_nationkey     INTEGER NOT NULL,
    n_name          CHAR(25) NOT NULL,
    n_regionkey     INTEGER NOT NULL,
    n_comment       VARCHAR(152) NOT NULL);

CREATE TABLE customer (
    c_custkey       INTEGER NOT NULL,
    c_name          VARCHAR(25) NOT NULL,
    c_address       VARCHAR(40) NOT NULL,
    c_nationkey     INTEGER NOT NULL,
    c_phone         CHAR(15) NOT NULL,
    c_acctbal       DECIMAL(15,2) NOT NULL,
    c_mktsegment    CHAR(10) NOT NULL,
    c_comment       VARCHAR(117) NOT NULL);

CREATE TABLE supplier (
    s_suppkey       INTEGER NOT NULL,
    s_name          CHAR(25) NOT NULL,
    s_address       VARCHAR(40) NOT NULL,
    s_nationkey     INTEGER NOT NULL,
    s_phone         CHAR(15) NOT NULL,
    s_acctbal       DECIMAL(15,2) NOT NULL,
    s_comment       VARCHAR(101) NOT NULL);

CREATE TABLE part (
    p_partkey       INTEGER NOT NULL,
    p_name          VARCHAR(55) NOT NULL,
    p_mfgr          CHAR(25) NOT NULL,
    p_brand         CHAR(10) NOT NULL,
    p_type          VARCHAR(25) NOT NULL,
    p_size          INTEGER NOT NULL,
    p_container     CHAR(10) NOT NULL,
    p_retailprice   DECIMAL(15,2) NOT NULL,
    p_comment       VARCHAR(23) NOT NULL);

CREATE TABLE partsupp (
    ps_partkey      INTEGER NOT NULL,
    ps_suppkey      INTEGER NOT NULL,
    ps_availqty     INTEGER NOT NULL,
    ps_supplycost   DECIMAL(15,2) NOT NULL,
    ps_comment      VARCHAR(199) NOT NULL);

CREATE TABLE orders (
    o_orderkey      INTEGER NOT NULL,
    o_custkey       INTEGER NOT NULL,
    o_orderstatus   CHAR(1) NOT NULL,
    o_totalprice    DECIMAL(15,2) NOT NULL,
    o_orderdate     DATE NOT NULL,
    o_orderpriority CHAR(15) NOT NULL,  
    o_clerk         CHAR(15) NOT NULL, 
    o_shippriority  INTEGER NOT NULL,
    o_comment       VARCHAR(79) NOT NULL);

CREATE TABLE lineitem (
    l_orderkey      INTEGER NOT NULL,
    l_partkey       INTEGER NOT NULL,
    l_suppkey       INTEGER NOT NULL,
    l_linenumber    INTEGER NOT NULL,
    l_quantity      DECIMAL(15,2) NOT NULL,
    l_extendedprice DECIMAL(15,2) NOT NULL,
    l_discount      DECIMAL(15,2) NOT NULL,
    l_tax           DECIMAL(15,2) NOT NULL,
    l_returnflag    CHAR(1) NOT NULL,
    l_linestatus    CHAR(1) NOT NULL,
    l_shipdate      DATE NOT NULL,
    l_commitdate    DATE NOT NULL,
    l_receiptdate   DATE NOT NULL,
    l_shipinstruct  CHAR(25) NOT NULL,
    l_shipmode      CHAR(10) NOT NULL,
    l_comment       VARCHAR(44) NOT NULL);

\COPY region FROM 'region.csv' (FORMAT CSV);
\COPY nation FROM 'nation.csv' (FORMAT CSV);
\COPY customer FROM 'customer.csv' (FORMAT CSV);
\COPY supplier FROM 'supplier.csv' (FORMAT CSV);
\COPY part FROM 'part.csv' (FORMAT CSV);
\COPY partsupp FROM 'partsupp.csv' (FORMAT CSV);
\COPY orders FROM 'orders.csv' (FORMAT CSV);
\COPY lineitem FROM 'lineitem.csv' (FORMAT CSV);

ALTER TABLE region
    ADD PRIMARY KEY (r_regionkey);
ALTER TABLE nation
    ADD PRIMARY KEY (n_nationkey);
ALTER TABLE customer
    ADD PRIMARY KEY (c_custkey);
ALTER TABLE supplier
    ADD PRIMARY KEY (s_suppkey);
ALTER TABLE part
    ADD PRIMARY KEY (p_partkey);
ALTER TABLE partsupp
    ADD PRIMARY KEY (ps_partkey, ps_suppkey);
ALTER TABLE orders
    ADD PRIMARY KEY (o_orderkey);
ALTER TABLE lineitem
    ADD PRIMARY KEY (l_orderkey, l_linenumber);

ALTER TABLE nation
    ADD FOREIGN KEY (n_regionkey) REFERENCES region (r_regionkey);
ALTER TABLE customer
    ADD FOREIGN KEY (c_nationkey) REFERENCES nation (n_nationkey);
ALTER TABLE supplier
    ADD FOREIGN KEY (s_nationkey) REFERENCES nation (n_nationkey);
ALTER TABLE partsupp
    ADD FOREIGN KEY (ps_suppkey) REFERENCES supplier (s_suppkey);
ALTER TABLE partsupp
    ADD FOREIGN KEY (ps_partkey) REFERENCES part (p_partkey);
ALTER TABLE orders
    ADD FOREIGN KEY (o_custkey) REFERENCES customer (c_custkey);
ALTER TABLE lineitem
    ADD FOREIGN KEY (l_orderkey) REFERENCES orders (o_orderkey);
ALTER TABLE lineitem
    ADD FOREIGN KEY (l_partkey) REFERENCES part (p_partkey);
ALTER TABLE lineitem
    ADD FOREIGN KEY (l_suppkey) REFERENCES supplier (s_suppkey);
ALTER TABLE lineitem
    ADD FOREIGN KEY (l_partkey, l_suppkey) REFERENCES partsupp (ps_partkey, ps_suppkey);

VACUUM ANALYZE;

