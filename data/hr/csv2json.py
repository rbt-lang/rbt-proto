
import sys
import csv
import json

icsv = csv.DictReader(sys.stdin)
ojson = { "departments": [] }

dept_data = ojson["departments"]
dept_name_idx = {}
for line in icsv:
    dept_name = line["dept_name"]
    dept = dept_name_idx.get(dept_name)
    if dept is None:
        dept = dept_name_idx[dept_name] = { "name": dept_name, "employees": [] }
        dept_data.append(dept)
    dept["employees"].append({
            "name": line["empl_name"],
            "surname": line["empl_surname"],
            "position": line["empl_position"],
            "salary": int(line["empl_salary"]) })

json.dump(ojson, sys.stdout, indent=2, sort_keys=True, separators=(',', ': '))

