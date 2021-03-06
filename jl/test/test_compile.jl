
using Base.Test

push!(LOAD_PATH, "./jl")
using RBT
include("../citydb.jl")

setdb(citydb)

function RBT.query(state, expr; params...)
    params_signature = ([(name, typeof(param)) for (name, param) in params]...)
    q = RBT.prepare(state, expr; params_signature...)
    println(repr(q))
    println(repr(q.pipe))
    r = RBT.execute(q; params...)
    #display(r)
    #println()
    return r
end

@query(6*(3+4))
@query(department)
@query(department.name)
@query(department.employee)
@query(department.employee.name)
@query(employee)
@query(employee.name)
@query(employee.department)
@query(employee.department.name)

@query(count(department))
@query(count(employee))
@query(department.count(employee))
@query(count(department.employee))
@query(max(employee.salary))
@query(max(department.count(employee)))
@query(sum(employee.salary))

@query(department:select(name,count(employee)))
@query(department:select(name,count(employee),max(employee.salary)))
@query(employee:select(name,surname,position,department))

@query(record(count(employee), max(employee.salary), employee))
@query(department.record(name, count(employee), max(employee.salary), employee))

@query(employee:filter(salary>200000))
@query(employee:select(name,surname,position):filter(employee.salary>200000))
@query(department:filter(count(employee)>1000).name)
@query(department:select(name,count(employee:filter(salary>100000))))

@query(department:first)
@query(department:select(name,size => count(employee)):sort(size:desc):first)
@query(department:select(name,size => count(employee)):first(size))
@query(department:last)
@query(department:select(name,size => count(employee)):sort(size):last)
@query(department:select(name,size => count(employee)):last(size:desc))
@query(department:take(5))
@query(department:skip(10):take(5))
@query(department:skip(-5))
@query(department:take(count(department)/2))
@query(department:reverse)

@query(department:select(id,name))
@query(department:get(5))
@query(department:get(-1))
@query(department[5]:select(id,name,count(employee)))
@query(department[5].employee)

@query(department.name:sort)
@query(department:desc:sort:select(id,name))
@query(employee:sort(salary))
@query(employee:sort(salary:desc))
@query(employee:sort(salary:desc,surname:asc,name:asc))

@query(department:select(name,count(employee):as(size)))
@query(department:define(size => count(employee)):filter(size>1000):select(name,size))

@query(employee:filter(salary>managed_by.salary):select(name,surname,position,managed_by))
@query(department[26].employee:select(name,surname,position,connect(managed_by),count(connect(manages))))
@query(department[26].employee:sort_connect(managed_by):select(depth(managed_by),name,surname,position))

@query(employee.position:unique)
@query(employee.position:desc:unique)
@query(department:select(name,count(unique(employee.position)),count(employee)))

@query(employee:group(position))
@query(employee:group(position):select(position,count(employee)))
@query(employee:group(position):select(position, size => count(employee)):sort(size:desc))
@query(
    employee:group(position)
    :define(department => unique(employee.department))
    :filter(count(department)>=5)
    :sort(count(department):desc)
    :select(position, department))
@query(employee:group(name):select(name, size => count(employee)):sort(size:desc))
@query(
    employee:group(name)
    :filter(count(employee)>=10)
    :select(name, max_salary => max(employee.salary))
    :sort(max_salary:desc))
@query(
    employee
    :group(department, salary_bracket => salary/10000*10000 :desc)
    :select(department, salary_bracket, salary_bracket+9999, count(employee)))
@query(
    employee
    :group_cube(department, salary_bracket => salary/10000*10000 :desc)
    :select(department, salary_bracket, salary_bracket+9999, count(employee)))
@query(
    employee
    :partition(department:take(3))
    :select(department.name, count(unique(employee.position)), count(employee), max(employee.salary)))
@query(
    employee
    :partition_cube(department:take(3))
    :select(department.name, count(unique(employee.position)), count(employee), max(employee.salary)))
@query(
    employee
    :define(salary_bracket => salary/60000*60000)
    :partition(
        department:take(3),
        name => ["ANTHONY", "BRIAN"],
        salary_bracket => range(0, 60000, max(employee.salary)))
    :select(
        dept => department.name,
        name,
        low => salary_bracket,
        high => salary_bracket+59999,
        pop_position => employee:group(position):first(count(employee)).position,
        num_pos => count(unique(employee.position)),
        num_empl => count(employee)))

@query(
    mix(a => range(2,1,10), b => range(2,1,10), c => range(2,1,10))
    :filter((a <= b) & (b <= c))
    :select(a, b, c, (a*b)*c))
@query(
    mix(department, department)
    :filter((left.id != right.id) & (left.count(employee)/10 == right.count(employee)/10))
    :select(left.name, left.count(employee), right.name, right.count(employee)))
@query(pack(a => range(1,1,5), z => range(95,1,99)))
@query(pack(department, employee))
@query(pack(size => department.count(employee), position => employee.position))
@query(pack(department, employee).department)
@query(pack(department, employee).employee)
@query(pack(department, employee):select(department.name, employee.name))
@query(employee:take(100):filter(salary>max(unlink(employee).salary)/2))
@query(
    employee[10]
    :define(namesake => link((left.id!=right.id)&(left.name==right.name), employee))
    :select(name, count(namesake), namesake))

@query(department:json)
@query(department:select(name,head => employee:first(salary)):json)
@query(department:json(name,head => employee:first(salary)))
@query(employee:dataframe)
@query(department:select(name,size => count(employee), max_salary => max(employee.salary)):dataframe)
@query(department:dataframe(name,size => count(employee), max_salary => max(employee.salary)))

@query((max(employee.salary) > 100000) & (max(employee.salary) < 300000))

@query(X*X, X=5)
@query(X*Y, X=5, Y=Nullable(4))
@query(X*(Y*Z), X=5, Y=Nullable(4), Z=[2,3,4,5])

q = RBT.@prepare(X*(Y*Z), X=Int, Y=Nullable{Int}, Z=Vector{Int})
q(X=5, Y=4, Z=[2,3,4,5])

@query(employee:filter((position==POSITION) & (name==NAME)), POSITION="POLICE OFFICER", NAME="CHARLES")
@query(department:filter(count(employee)>SIZE):select(name,count(employee)-SIZE), SIZE=1000)
@query(employee:filter(department.name in DEPTS), DEPTS=["POLICE", "FIRE"])

@query(department:select(name, previous_name => first(before).name, next_name => first(after).name))
@query(department:select(name, past_names => before.name))
@query(department:select(1+count(before), name))
@query(department:define(size => count(employee)):select(name, size, total => sum(and_before.size)))
@query(department:define(size => count(employee)):filter(size == max(and_around.size)):select(name, size))
@query(
    employee
    :filter(department.name == DEPT)
    :dataframe(
        name, surname, position, salary, salary_diff => max(and_around(position).salary)-salary),
    DEPT="TREASURER")
@query(department:select(name, employee:filter(salary==max(and_around.salary)):frame))
@query(employee:filter(salary==MAX_SALARY):given(MAX_SALARY => max(employee.salary)))
@query(department:select(name, employee:filter(salary==MAX_SALARY):given(MAX_SALARY => max(employee.salary))))

