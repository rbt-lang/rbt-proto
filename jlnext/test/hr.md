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
        Combinator

    Department() = Combinator(dept_query)
    Employee() = Combinator(emp_query)

    DeptName() = Combinator(dept_name_query)
    DeptEmployee() = Combinator(dept_employee_query)

    EmpName() = Combinator(emp_name_query)
    EmpPosition() = Combinator(emp_position_query)
    EmpSalary() = Combinator(emp_salary_query)
    EmpDepartment() = Combinator(emp_department_query)
    EmpManager() = Combinator(emp_manager_query)
    EmpSubordinate() = Combinator(emp_subordinate_query)


Extracting data
---------------

    using RBT:
        Start,
        execute

*Show the name of each department.*

    q = Start() |> Department() |> DeptName()
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

    q = Start() |> Department() |> DeptEmployee() |> EmpName()
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

    q = Start() |> Employee() |> EmpName()
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

    q = Start() |> Employee() |> EmpDepartment() |> DeptName()
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

    q = Start() |> Employee() |> EmpPosition()
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

    q = Start() |> Employee()
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
        Count,
        MaxOf,
        ThenMax

*Show the number of departments.*

    q = Start() |> Count(Department())
    #-> Unit -> Int64

    execute(q)
    #-> 35

*What is the highest employee salary?*

    q = Start() |> MaxOf(Employee() |> EmpSalary())
    #-> Unit -> Int64?

    execute(q)
    #-> Nullable{Int64}(260004)

*For each department, show the number of employees.*

    q = Start() |> Department() |> Count(DeptEmployee())
    #-> Unit -> Int64*

    execute(q)
    #-> [1848,13570,924  …  39,1]

*How many employees are in the largest department?*

    q = q |> ThenMax()
    #-> Unit -> Int64?

    execute(q)
    #-> Nullable{Int64}(13570)


Filtering data
--------------

    using RBT:
        Const,
        Record,
        ThenCount,
        ThenFilter

*Which employees have a salary higher than $150k?*

    q = Start() |>
        Employee() |>
        ThenFilter(EmpSalary() .> Const(150000)) |>
        Record(EmpName(), EmpDepartment() |> DeptName(), EmpPosition(), EmpSalary())
    #-> Unit -> {String, String, String, Int64}*

    display(execute(q))
    #=>
    DataSet[151 × {String, String, String, Int64}]:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ("VERDIE A","FIRE","ASST DEPUTY CHIEF PARAMEDIC",156360)
     ("SCOTT A","IPRA","CHIEF ADMINISTRATOR",161856)
     ⋮
     ("ALFONZA W","POLICE","FIRST DEPUTY SUPERINTENDENT",197736)
     ("GARY Y","POLICE","COMMANDER",162684)
    =#

*How many departments have more than 1000 employees?*

    q = Start() |>
        Department() |>
        ThenFilter(Count(DeptEmployee()) .> Const(1000)) |>
        ThenCount()
    #-> Unit -> Int64

    execute(q)
    #-> 7

