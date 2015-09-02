
push!(LOAD_PATH, "./jl")

using Base.Test
using BQL

include("../citydb_json.jl")

C = Const(42)
@test C(citydb) == 42

I = This()
@test I(42) == 42

Departments = Field(:departments)
departments = Departments(citydb)
@test isa(departments, Array)

O = Select(:x => Const(42))
@test O(citydb) == Dict("x" => 42)

Name = Field(:name)
Department_Names = Departments >> Name
department_names = Department_Names(citydb)
@test "POLICE" in department_names

Num_Dept = Count(Departments)
@test Num_Dept(citydb) == 35

Employees = Field(:employees)
Departments_With_Num_Empl = Departments >> Select(:name => Name, :num_empl => Count(Employees))
departments_with_num_empl = Departments_With_Num_Empl(citydb)
@test Dict("name" => "POLICE", "num_empl" => 13570) in departments_with_num_empl

