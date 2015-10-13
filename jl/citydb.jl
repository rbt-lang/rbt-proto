
include("citydb_json.jl")

using RBT: Entity, Database, Schema, Class, Arrow, Instance


schema = Schema(
    Class(
        :department,
        Arrow(:name, UTF8String, unique=true),
        Arrow(:employee, plural=true)),
    Class(
        :employee,
        Arrow(:name, UTF8String),
        Arrow(:surname, UTF8String),
        Arrow(:position, UTF8String),
        Arrow(:salary, Int),
        Arrow(:department)))


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


for d in citydb["departments"]
    did = D(length(dept)+1)
    push!(dept, did)
    dept_name[did] = d["name"]
    dept_empl[did] = []
    for e in d["employees"]
        eid = E(length(empl)+1)
        push!(empl, eid)
        push!(dept_empl[did], eid)
        empl_name[eid] = e["name"]
        empl_surname[eid] = e["surname"]
        empl_position[eid] = e["position"]
        empl_salary[eid] = round(e["salary"])
        empl_dept[eid] = did
    end
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

