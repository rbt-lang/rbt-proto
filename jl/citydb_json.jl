
using JSON

URL = "https://data.cityofchicago.org/api/views/xzkq-xp2w/rows.csv?accessType=DOWNLOAD"
CSV_PATH = "Current_Employee_Names,_Salaries,_and_Position_Titles.csv"
JSON_PATH = "citydb.json"

BASE_PATH = joinpath(dirname(@__FILE__), "data")
if !isdir(BASE_PATH)
    mkdir(BASE_PATH)
end
CSV_PATH = joinpath(BASE_PATH, CSV_PATH)
JSON_PATH = joinpath(BASE_PATH, JSON_PATH)

if !isfile(CSV_PATH)
    download(URL, CSV_PATH)
end

if !isfile(JSON_PATH)
    jsondata = Dict("departments" => [])
    departments = jsondata["departments"]
    department_by_name = Dict()
    csv = readcsv(CSV_PATH, header=true)[1]
    for i = 1:size(csv, 1)
        name, position, department_name, salary = csv[i, :]
        if length(name) == 0
            continue
        end
        surname, name = split(name, ",  ")
        surname = surname[1:1]
        name = split(name)[1]
        salary = round(Int, parse(Float64, salary[2:end]))
        if haskey(department_by_name, department_name)
            department = department_by_name[department_name]
        else
            department = Dict("name" => department_name, "employees" => [])
            department_by_name[department_name] = department
            push!(departments, department)
        end
        employee = Dict("name" => name, "surname" => surname, "position" => position, "salary" => salary)
        push!(department["employees"], employee)
    end
    open(JSON_PATH, "w") do f
        JSON.print(f, jsondata)
    end
end

citydb = JSON.parsefile(JSON_PATH)

