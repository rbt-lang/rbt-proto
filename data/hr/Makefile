.PHONY: all clean

PYTHON = python
URL = "https://data.cityofchicago.org/api/views/xzkq-xp2w/rows.csv?accessType=DOWNLOAD"

all: hr.csv hr.json

hr.csv:
	${PYTHON} download.py ${URL} >hr.csv

hr.json: hr.csv
	${PYTHON} csv2json.py <hr.csv >hr.json

clean:
	rm -f *.csv *.json

