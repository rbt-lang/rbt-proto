
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
