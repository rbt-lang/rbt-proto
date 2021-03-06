
if !any([dirname(path) == dirname(@__FILE__) for path in LOAD_PATH])
    push!(LOAD_PATH, dirname(@__FILE__))
end

ENV["LINES"] = 15

using RBT: Entity, ToyDatabase, Schema, Class, Arrow, Instance, Iso, Opt, Seq

CSV_PATH = joinpath(dirname(@__FILE__), "../data/hr/hr.csv")

TREASURER_DEPT = "TREASURER"
TREASURER_HEAD = "CITY TREASURER"
ACC_HEAD = "DIR OF ACCOUNTING"
ACCS = ["AUDITOR IV", "ACCOUNTANT IV", "ACCOUNTANT III", "STAFF ASST", "ACCOUNTANT I"]


schema = Schema(
    Class(
        :department,
        Arrow(:name, String, runique=true),
        Arrow(
            :employee,
            lunique=false, ltotal=false, runique=true, rtotal=true,
            select=(:name, :surname), inverse=:department),
        select=(:name,)),
    Class(
        :employee,
        Arrow(:name, String),
        Arrow(:surname, String),
        Arrow(:position, String),
        Arrow(:salary, Int),
        Arrow(:department, select=:name),
        Arrow(
            :managed_by, :employee,
            ltotal=false,
            select=(:name, :surname, :position)),
        Arrow(
            :manages, :employee,
            lunique=false, ltotal=false, runique=true,
            select=(:name, :surname, :position),
            inverse=:managed_by),
        select=(:name, :surname, :department, :position, :salary)))


D = Entity{:department}
E = Entity{:employee}

dept = Vector{D}()
empl = Vector{E}()

dept_name = Vector{Iso{String}}()
dept_empl = Vector{Seq{E}}()

empl_name = Vector{Iso{String}}()
empl_surname = Vector{Iso{String}}()
empl_position = Vector{Iso{String}}()
empl_salary = Vector{Iso{Int}}()
empl_dept = Vector{Iso{D}}()
empl_managed_by = Vector{Opt{E}}()
empl_manages = Vector{Seq{E}}()

tr_head = nothing
trs = []
acc_head = nothing
accs = []


csv = readcsv(CSV_PATH, header=true)[1]
did_by_name = Dict{String, D}()
for i = 1:size(csv, 1)
    department_name, name, surname, position, salary = csv[i, :]
    if !haskey(did_by_name, department_name)
        did = D(length(dept)+1)
        push!(dept, did)
        push!(dept_name, Iso{String}(department_name))
        push!(dept_empl, Seq{E}(E[]))
        did_by_name[department_name] = did
    end
    did = did_by_name[department_name]
    eid = E(length(empl)+1)
    push!(empl, eid)
    push!(dept_empl[did.id].data, eid)
    push!(empl_name, Iso{String}(name))
    push!(empl_surname, Iso{String}(surname))
    push!(empl_position, Iso{String}(position))
    push!(empl_salary, Iso{Int}(salary))
    push!(empl_dept, Iso{D}(did))
    if department_name == TREASURER_DEPT
        if position == TREASURER_HEAD
            tr_head = eid
        elseif position == ACC_HEAD
            acc_head = eid
            push!(trs, eid)
        elseif position in ACCS
            push!(accs, eid)
        else
            push!(trs, eid)
        end
    end
    push!(empl_manages, Seq{E}(E[]))
    push!(empl_managed_by, Opt{E}())
end

empl_manages[tr_head.id] = Seq{E}(trs)
empl_manages[acc_head.id] = Seq{E}(accs)
for tr in trs
    empl_managed_by[tr.id] = Opt{E}(tr_head)
end
for acc in accs
    empl_managed_by[acc.id] = Opt{E}(acc_head)
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
        (:employee, :department) => empl_dept,
        (:employee, :managed_by) => empl_managed_by,
        (:employee, :manages) => empl_manages))


citydb = ToyDatabase(schema, instance)

