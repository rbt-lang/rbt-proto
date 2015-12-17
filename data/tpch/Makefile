.PHONY: all clean psql

PYTHON = python
DBGEN = dbgen
DSS_CONFIG = .

PSQL_DB = tpch

all: customer.csv lineitem.csv nation.csv orders.csv partsupp.csv part.csv region.csv supplier.csv

%.csv: %.tbl
	${PYTHON} tbl2csv.py <$< >$@

%.tbl:
	DSS_CONFIG=${DSS_CONFIG} ${DBGEN} -f -s 0.008

clean:
	rm -f *.tbl *.csv

psql:
	-dropdb ${PSQL_DB}
	createdb ${PSQL_DB}
	psql -q -f tpch.sql ${PSQL_DB}

