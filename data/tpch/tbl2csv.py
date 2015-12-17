
import sys
import csv

icsv = csv.reader(sys.stdin, delimiter='|')
ocsv = csv.writer(sys.stdout)

for line in icsv:
    ocsv.writerow(line[:-1])

