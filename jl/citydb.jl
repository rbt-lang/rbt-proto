
using RBT: Entity, Database, Schema, Class, Arrow, Instance


URL = "https://data.cityofchicago.org/api/views/xzkq-xp2w/rows.csv?accessType=DOWNLOAD"
CSV_PATH = "Current_Employee_Names,_Salaries,_and_Position_Titles.csv"


schema = Schema(
    Class(
        :department,
        Arrow(:name, UTF8String, exclusive=true),
        Arrow(
            :employee,
            singular=false, complete=false, exclusive=true, reachable=true,
            select=(:name, :surname), inverse=:department),
        select=(:name,)),
    Class(
        :employee,
        Arrow(:name, UTF8String),
        Arrow(:surname, UTF8String),
        Arrow(:position, UTF8String),
        Arrow(:salary, Int),
        Arrow(:department, select=:name),
        select=(:name, :surname, :department, :position, :salary)))


D = Entity{:department}
E = Entity{:employee}

dept = Vector{D}()
empl = Vector{E}()

dept_name = Dict{D, UTF8String}()
dept_empl = Dict{D, Vector{E}}()

empl_name = Dict{E, UTF8String}()
empl_surname = Dict{E, UTF8String}()
empl_position = Dict{E, UTF8String}()
empl_salary = Dict{E, Int}()
empl_dept = Dict{E, D}()


BASE_PATH = joinpath(dirname(@__FILE__), "data")
if !isdir(BASE_PATH)
    mkdir(BASE_PATH)
end
CSV_PATH = joinpath(BASE_PATH, CSV_PATH)

if !isfile(CSV_PATH)
    download(URL, CSV_PATH)
end

csv = readcsv(CSV_PATH, header=true)[1]
did_by_name = Dict{UTF8String, D}()
for i = 1:size(csv, 1)
    name, position, department_name, salary = csv[i, :]
    if length(name) == 0
        continue
    end
    surname, name = split(name, ",  ")
    surname = surname[1:1]
    name = split(name)[1]
    salary = round(Int, parse(Float64, salary[2:end]))
    if !haskey(did_by_name, department_name)
        did = D(length(dept)+1)
        push!(dept, did)
        dept_name[did] = department_name
        dept_empl[did] = []
        did_by_name[department_name] = did
    end
    did = did_by_name[department_name]
    eid = E(length(empl)+1)
    push!(empl, eid)
    push!(dept_empl[did], eid)
    empl_name[eid] = name
    empl_surname[eid] = surname
    empl_position[eid] = position
    empl_salary[eid] = salary
    empl_dept[eid] = did
end

instance = Instance(
    Dict(
        :department => dept,
        :employee => empl),
    Dict(
        (:department, :name) => dept_name,
        (:department, :employee) => dept_empl,
        (:employee, :name) => empl_name,
        (:employee, :surname) => empl_surname,
        (:employee, :position) => empl_position,
        (:employee, :salary) => empl_salary,
        (:employee, :department) => empl_dept))


citydb = Database(schema, instance)

