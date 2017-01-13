
THIS_DIR = dirname(@__FILE__)
CSV_PATH = joinpath(THIS_DIR, "../../data/hr/hr.csv")

TREASURER_DEPT = "TREASURER"
TREASURER_HEAD = "CITY TREASURER"
ACC_HEAD = "DIR OF ACCOUNTING"
ACCS = ["AUDITOR IV", "ACCOUNTANT IV", "ACCOUNTANT III", "STAFF ASST", "ACCOUNTANT I"]

csv = readcsv(CSV_PATH, header=true)[1]
N = size(csv, 1)

dept_name_set = Set{String}()

tr_head = nothing
trs = []
acc_head = nothing
accs = []

for eid = 1:N
    department_name = csv[eid, 1]
    push!(dept_name_set, department_name)
    if department_name == TREASURER_DEPT
        position = csv[eid, 4]
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
end

M = length(dept_name_set)

dept_data = 1:M
emp_data = 1:N

dept_name_data = String[]
dept_employee_data = Vector{Int}[]

emp_name_data = String[]
emp_position_data = String[]
emp_salary_data = Int[]
emp_department_data = Int[]
emp_manager_data = Nullable{Int}[]
emp_subordinate_data = Vector{Int}[]

did_by_name = Dict{String, Int}()

for eid = 1:N
    department_name, name, surname, position, salary = csv[eid, :]
    if !(department_name in keys(did_by_name))
        did = length(did_by_name)+1
        push!(dept_name_data, department_name)
        push!(dept_employee_data, Int[])
        did_by_name[department_name] = did
    end
    did = did_by_name[department_name]
    push!(dept_employee_data[did], eid)
    push!(emp_name_data, name * " " * surname[1:1])
    push!(emp_position_data, position)
    push!(emp_salary_data, salary)
    push!(emp_department_data, did)
    if department_name == TREASURER_DEPT
        if position == TREASURER_HEAD
            push!(emp_manager_data, nothing)
            push!(emp_subordinate_data, trs)
        elseif position == ACC_HEAD
            push!(emp_manager_data, tr_head)
            push!(emp_subordinate_data, accs)
        elseif position in ACCS
            push!(emp_manager_data, acc_head)
            push!(emp_subordinate_data, Int[])
        else
            push!(emp_manager_data, tr_head)
            push!(emp_subordinate_data, Int[])
        end
    else
        push!(emp_manager_data, nothing)
        push!(emp_subordinate_data, Int[])
    end
end

