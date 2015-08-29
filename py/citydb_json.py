"""
Import this module to download the list of all employees of the City of
Chicago.  The list is saved as a JSON file ``citydb.json`` in the format::

    {
      "departments": [
        {
          "name": ...,
          "employees": [
            {
              "name": ...,
              "surname": ...,
              "position": ...,
              "salary": ...
            },
            ... ]
        },
        ... ]
    }
"""


URL = 'https://data.cityofchicago.org/api/views/xzkq-xp2w/rows.csv?accessType=DOWNLOAD'
CSV = 'Current_Employee_Names,_Salaries,_and_Position_Titles.csv'
JSON = 'citydb.json'


import csv
import json
import os
import sys
try:
    import urllib.request
except ImportError:
    import urllib
    urllib.request = urllib
try:
    unicode
except NameError:
    unicode = str

BASE = os.path.join(os.path.dirname(__file__), 'data')
if not os.path.exists(BASE):
    os.mkdir(BASE)
CSV = os.path.join(BASE, CSV)
JSON = os.path.join(BASE, JSON)

if not os.path.exists(CSV):
    csv_data = urllib.request.urlopen(URL).read()
    if not isinstance(csv_data, str):
        csv_data = csv_data.decode('utf-8')
    with open(CSV, 'w') as stream:
        stream.write(csv_data)

if not os.path.exists(JSON):
    json_data = { "departments": [] }
    with open(CSV) as stream:
        csv_data = csv.DictReader(stream)
        department_data = json_data["departments"]
        department_by_name = {}
        for line in csv_data:
            if not line["Name"]:
                continue
            surname, name = line["Name"].split(',  ')
            surname = surname[:1]
            name = name.split()[0]
            position = line["Position Title"]
            department_name = line["Department"]
            salary = int(float(line["Employee Annual Salary"][1:]))
            department = department_by_name.get(department_name)
            if department is None:
                department = department_by_name[department_name] = \
                        { "name": department_name, "employees": [] }
                department_data.append(department)
            department["employees"].append(
                    { "surname": surname, "name": name, "position": position, "salary": salary })
    with open(JSON, 'w') as stream:
        json.dump(json_data, stream, indent=2)

with open(JSON) as stream:
    citydb = json.load(stream)

def u2s(data):
    if isinstance(data, unicode):
        return str(data)
    if isinstance(data, list):
        return [u2s(item) for item in data]
    if isinstance(data, dict):
        return dict([(str(key), u2s(item)) for key, item in data.items()])
    return data

citydb = u2s(citydb)

