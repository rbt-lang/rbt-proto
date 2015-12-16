
using JSON

JSON_PATH = joinpath(dirname(@__FILE__), "../data/hr/hr.json")
citydb = JSON.parsefile(JSON_PATH)

