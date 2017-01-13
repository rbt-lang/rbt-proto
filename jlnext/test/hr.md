Departments & employees
=======================


Preparing the data
------------------

We start with loading the raw data.

    include("hr_data.jl")

    dept_data
    #-> 1:35

    emp_data
    #-> 1:32181

    dept_name_data
    #-> String["WATER MGMNT"  …  "LICENSE APPL COMM"]

    dept_employee_data
    #-> Array{Int64,1}[[1  …  32171]  …  [11126]]

    emp_name_data
    #-> String["ELVIA A"  …  "DARIUSZ Z"]

    emp_position_data
    #-> String["WATER RATE TAKER"  …  "CHIEF DATA BASE ANALYST"]

    emp_salary_data
    #-> [88968  …  110352]

    emp_department_data
    #-> [1  …  11]

    emp_manager_data
    #-> Nullable{Int64}[#NULL  …  #NULL]

    emp_subordinate_data
    #-> Array{Int64,1}[Int64[]  …  Int64[]]

Next, we convert this data to primitive queries.

    using RBT:
        CollectionTool,
        Column,
        MappingTool,
        Output

    dept_query = CollectionTool(:Dept, dept_data)
    #-> Any -> Dept*

    emp_query = CollectionTool(:Emp, emp_data)
    #-> Any -> Emp*

    dept_name_query = MappingTool(:Dept, String, dept_name_data)
    #-> Dept -> String

    dept_employee_query =
        MappingTool(:Dept, Output(:Emp, optional=true, plural=true), dept_employee_data)
    #-> Dept -> Emp*

    emp_name_query = MappingTool(:Emp, String, emp_name_data)
    #-> Emp -> String

    emp_position_query = MappingTool(:Emp, String, emp_position_data)
    #-> Emp -> String

    emp_salary_query = MappingTool(:Emp, Int, emp_salary_data)
    #-> Emp -> Int64

    emp_department_query = MappingTool(:Emp, :Dept, emp_department_data)
    #-> Emp -> Dept

    emp_manager_query =
        MappingTool(:Emp, Output(:Emp, optional=true), emp_manager_data)
    #-> Emp -> Emp?

    emp_subordinate_query =
        MappingTool(:Emp, Output(:Emp, optional=true, plural=true), emp_subordinate_data)
    #-> Emp -> Emp*

Finally, we will convert the queries to combinators.

    using RBT:
        Combinator,
        Start

    UnitDepartment() = Combinator(dept_query)
    UnitEmployee() = Combinator(emp_query)

    DeptName() = Combinator(dept_name_query)
    DeptEmployee() = Combinator(dept_employee_query)

    EmpName() = Combinator(emp_name_query)
    EmpPosition() = Combinator(emp_position_query)
    EmpSalary() = Combinator(emp_salary_query)
    EmpDepartment() = Combinator(emp_department_query)
    EmpManager() = Combinator(emp_manager_query)
    EmpSubordinate() = Combinator(emp_subordinate_query)

    Department() = Start() |> UnitDepartment()
    Employee() = Start() |> UnitEmployee()


Extracting data
---------------

    using RBT:
        execute

*Show the name of each department.*

    q = Department() |> DeptName()
    #-> Unit -> String*

    display(execute(q))
    #=>
    35-element Array{String,1}:
     "WATER MGMNT"
     "POLICE"
     "GENERAL SERVICES"
     ⋮
     "ADMIN HEARNG"
     "LICENSE APPL COMM"
    =#

*For each department, show the name of each employee.*

    q = Department() |> DeptEmployee() |> EmpName()
    #-> Unit -> String*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "ELVIA A"
     "VICENTE A"
     "MUHAMMAD A"
     ⋮
     "RACHENETTE W"
     "MICHELLE G"
    =#

*Show the name of each employee.*

    q = Employee() |> EmpName()
    #-> Unit -> String*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "ELVIA A"
     "JEFFERY A"
     "KARINA A"
     ⋮
     "CARLO Z"
     "DARIUSZ Z"
    =#

*For each employee, show the name of their department.*

    q = Employee() |> EmpDepartment() |> DeptName()
    #-> Unit -> String*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "WATER MGMNT"
     "POLICE"
     "POLICE"
     ⋮
     "POLICE"
     "DoIT"
    =#

*Show the position of each employee.*

    q = Employee() |> EmpPosition()
    #-> Unit -> String*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "WATER RATE TAKER"
     "POLICE OFFICER"
     "POLICE OFFICER"
     ⋮
     "POLICE OFFICER"
     "CHIEF DATA BASE ANALYST"
    =#

*Show all employees.*

    q = Employee()
    #-> Unit -> Emp*

    display(execute(q))
    #=>
    32181-element Array{Emp,1}:
     Emp(1)
     Emp(2)
     Emp(3)
     ⋮
     Emp(32180)
     Emp(32181)
    =#


Summarizing data
----------------

    using RBT:
        Count

*Show the number of departments.*

    q = Start() |> Count(UnitDepartment())
    #-> Unit -> Int64

    execute(q)
    #-> 35

