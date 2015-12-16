
import os
import json
try:
    unicode
except NameError:
    unicode = str

JSON = os.path.join(os.path.dirname(__file__), '../data/hr/hr.json')

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

