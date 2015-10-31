
push!(LOAD_PATH, "./jl")
using RBT
include("../citydb.jl")

setdb(citydb)

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

@query(department:select(name,count(employee)))
@query(department:select(name,count(employee),max(employee.salary)))
@query(employee:select(name,surname,position,department))

@query(employee:filter(salary>200000))
@query(employee:select(name,surname,position):filter(salary>200000))
@query(department:filter(count(employee)>1000).name)
@query(department:select(name,count(employee:filter(salary>100000))))

@query(department:first)
@query(department:first(5))
@query(department:first(-15))
@query(department:first(count(department)/2))
@query(department:select(name,count(employee)):sort(count(employee):desc):first)
@query(department:last)
@query(department:last(2))
@query(department:last(-25))
@query(department:select(name,count(employee)):sort(count(employee)):last)
@query(department:select(name,count(employee)):max(count(employee)))
@query(department:take(5))
@query(department:take(5,10))
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

@query(employee.position:unique)
@query(employee.position:desc:unique)
@query(department:select(name,count(unique(employee.position)),count(employee)))

@query(employee:by(position))
@query(employee:by(position):select(position,count(employee)))
@query(employee:by(position):select(position, count(employee)):sort(count(employee):desc))
@query(
    employee:by(position)
    :define(department => unique(employee.department))
    :filter(count(department)>=5)
    :select(position, department)
    :sort(count(department):desc))
@query(employee:by(name):select(name, count(employee)):sort(count(employee):desc))
@query(
    employee:by(name)
    :filter(count(employee)>=10)
    :select(name, max(employee.salary))
    :sort(max(employee.salary):desc))

@query(department:json)
@query(department:select(name,head => employee:max(salary)):json)
@query(employee:dataframe)
@query(department:select(name,size => count(employee), max_salary => max(employee.salary)):dataframe)

@query((max(employee.salary) > 100000) & (max(employee.salary) < 300000))

