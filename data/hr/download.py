
import sys
import csv
import io
try:
    import urllib.request
except ImportError:
    import urllib
    urllib.request = urllib
try:
    unicode
except NameError:
    unicode = str

URL = sys.argv[1]
DATA = urllib.request.urlopen(URL).read()
if not isinstance(DATA, unicode):
    DATA = DATA.decode('utf-8')
stream = io.StringIO(DATA)

icsv = csv.DictReader(stream)

ocsv = csv.writer(sys.stdout)
ocsv.writerow(["dept_name", "empl_name", "empl_surname", "empl_position", "empl_salary"])

for line in icsv:
    if not line["Name"]:
        continue
    dept_name = line["Department"]
    empl_surname, empl_name = line["Name"].split(',  ')
    empl_surname = empl_surname[:1]
    empl_name = empl_name.split()[0]
    empl_position = line["Position Title"]
    empl_salary = int(round(float(line["Employee Annual Salary"][1:])))
    ocsv.writerow([dept_name, empl_name, empl_surname, empl_position, empl_salary])

