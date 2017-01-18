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
        ThenTag

    Department() = Combinator(dept_query) |> ThenTag(:department)
    Employee() = Combinator(emp_query) |> ThenTag(:employee)

    DeptName() = Combinator(dept_name_query) |> ThenTag(:name)
    DeptEmployee() = Combinator(dept_employee_query) |> ThenTag(:employee)

    EmpName() = Combinator(emp_name_query) |> ThenTag(:name)
    EmpPosition() = Combinator(emp_position_query) |> ThenTag(:position)
    EmpSalary() = Combinator(emp_salary_query) |> ThenTag(:salary)
    EmpDepartment() = Combinator(emp_department_query) |> ThenTag(:department)
    EmpManager() = Combinator(emp_manager_query) |> ThenTag(:manager)
    EmpSubordinate() = Combinator(emp_subordinate_query) |> ThenTag(:subordinate)

We also prepare the standard selectors for both entities.

    using RBT:
        Record

    DeptRecord() = Record(DeptName()) |> ThenTag(:department)

    EmpRecord() =
        Record(
            EmpName(),
            EmpDepartment() |> DeptName() |> ThenTag(:department),
            EmpPosition(),
            EmpSalary()) |>
        ThenTag(:employee)


Extracting data
---------------

    using RBT:
        Start,
        execute

*Show the name of each department.*

    q = Start() |> Department() |> DeptName()
    #-> Unit -> String* [tag=:name]

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
    #-> Unit -> String* [tag=:name]

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
    #-> Unit -> String* [tag=:name]

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
    #-> Unit -> String* [tag=:name]

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
    #-> Unit -> String* [tag=:position]

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
    #-> Unit -> Emp* [tag=:employee]

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


Pipeline notation
-----------------

    using RBT:
        Const,
        ThenDesc,
        ThenFilter,
        ThenSort,
        ThenSelect,
        ThenTake

*Show the top 10 highest paid employees in the Police department.*

    q = (Start()
        |> Employee()
        |> ThenFilter(EmpDepartment() |> DeptName() .== Const("POLICE"))
        |> ThenSort(EmpSalary() |> ThenDesc())
        |> ThenSelect(EmpName(), EmpPosition(), EmpSalary())
        |> ThenTake(Const(10)))
    #-> Unit -> {Emp [tag=:employee], String [tag=:name], String [tag=:position], Int64 [tag=:salary]}*

    display(execute(q))
    #=>
    DataSet[10 × {Emp [tag=:employee], String [tag=:name], String [tag=:position], Int64 [tag=:salary]}]:
     (Emp(18040),"GARRY M","SUPERINTENDENT OF POLICE",260004)
     (Emp(31712),"ALFONZA W","FIRST DEPUTY SUPERINTENDENT",197736)
     (Emp(29026),"ROBERT T","CHIEF",194256)
     (Emp(31020),"EUGENE W","CHIEF",185364)
     (Emp(24184),"JUAN R","CHIEF",185364)
     (Emp(23936),"ANTHONY R","CHIEF",185364)
     (Emp(11020),"WAYNE G","CHIEF",185364)
     (Emp(8066),"JOHN E","CHIEF",185364)
     (Emp(30573),"EDDIE W","DEPUTY CHIEF",170112)
     (Emp(30355),"ERIC W","DEPUTY CHIEF",170112)
    =#


Filtering data
--------------

    using RBT:
        Const,
        Record,
        ThenCount

*Which employees have a salary higher than $150k?*

    q = (Start()
        |> Employee()
        |> ThenFilter(EmpSalary() .> Const(150000))
        |> EmpRecord())
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[151 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ("VERDIE A","FIRE","ASST DEPUTY CHIEF PARAMEDIC",156360)
     ("SCOTT A","IPRA","CHIEF ADMINISTRATOR",161856)
     ⋮
     ("ALFONZA W","POLICE","FIRST DEPUTY SUPERINTENDENT",197736)
     ("GARY Y","POLICE","COMMANDER",162684)
    =#

*How many departments have more than 1000 employees?*

    q = (Start()
        |> Department()
        |> ThenFilter(Count(DeptEmployee()) .> Const(1000))
        |> ThenCount())
    #-> Unit -> Int64

    execute(q)
    #-> 7


Sorting and paginating data
---------------------------

    using RBT:
        Op

*Show the names of all departments in alphabetical order.*

    q = (Start()
        |> Department()
        |> DeptName()
        |> ThenSort())
    #-> Unit -> String* [tag=:name]

    display(execute(q))
    #=>
    35-element Array{String,1}:
     "ADMIN HEARNG"
     "ANIMAL CONTRL"
     "AVIATION"
     ⋮
     "TREASURER"
     "WATER MGMNT"
    =#

*Show all employees ordered by salary.*

    q = (Start()
        |> Employee()
        |> ThenSort(EmpSalary())
        |> EmpRecord())
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[32181 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)
     ("BETTY A","FAMILY & SUPPORT","FOSTER GRANDPARENT",2756)
     ("VICTOR A","FAMILY & SUPPORT","SENIOR COMPANION",2756)
     ⋮
     ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
    =#

*Show all employees ordered by salary, highest paid first.*

    q = (Start()
        |> Employee()
        |> ThenSort(EmpSalary() |> ThenDesc())
        |> EmpRecord())
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[32181 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
     ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
     ("JOSE S","FIRE","FIRE COMMISSIONER",202728)
     ⋮
     ("BETTY A","FAMILY & SUPPORT","FOSTER GRANDPARENT",2756)
     ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)
    =#

*Who are the top 1% of the highest paid employees?*

    Base.div(F::Combinator, G::Combinator) =
        Op(div, (Int, Int), Int, F, G)

    q = (Start()
        |> Employee()
        |> ThenSort(EmpSalary() |> ThenDesc())
        |> ThenTake(Count(Employee()) ÷ Const(100))
        |> EmpRecord())
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[321 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
     ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
     ("JOSE S","FIRE","FIRE COMMISSIONER",202728)
     ⋮
     ("JERRY W","FIRE","PARAMEDIC FIELD CHIEF",135480)
     ("ROBERT T","FIRE","BATTALION CHIEF",135480)
    =#


Query output
------------

    using RBT:
        Exists

*For each department, show its name and the number of employees.*

    q = (Start()
        |> Department()
        |> ThenSelect(
                DeptName(),
                Count(DeptEmployee()) |> ThenTag(:size)))
    #-> Unit -> {Dept [tag=:department], String [tag=:name], Int64 [tag=:size]}*

    display(execute(q))
    #=>
    DataSet[35 × {Dept [tag=:department], String [tag=:name], Int64 [tag=:size]}]:
     (Dept(1),"WATER MGMNT",1848)
     (Dept(2),"POLICE",13570)
     (Dept(3),"GENERAL SERVICES",924)
     ⋮
     (Dept(34),"ADMIN HEARNG",39)
     (Dept(35),"LICENSE APPL COMM",1)
    =#

*For every department, show the top salary and a list of managers with their
salaries.*

    q = (Start()
        |> Department()
        |> ThenSelect(
                DeptName(),
                DeptEmployee()
                |> EmpSalary()
                |> ThenMax()
                |> ThenTag(:top_salary),
                DeptEmployee()
                |> ThenFilter(Exists(EmpSubordinate()))
                |> ThenSelect(EmpName(), EmpSalary())
                |> ThenTag(:manager)))
    #-> Unit -> {Dept [tag=:department], String [tag=:name], Int64? [tag=:top_salary], {Emp [tag=:employee], String [tag=:name], Int64 [tag=:salary]}* [tag=:manager]}*

    display(execute(q))
    #=>
    DataSet[35 × {Dept [tag=:department], String [tag=:name], Int64? [tag=:top_salary], {Emp [tag=:employee], String [tag=:name], Int64 [tag=:salary]}* [tag=:manager]}]:
     (Dept(1),"WATER MGMNT",169512,[])
     (Dept(2),"POLICE",260004,[])
     (Dept(3),"GENERAL SERVICES",157092,[])
     ⋮
     (Dept(34),"ADMIN HEARNG",156420,[])
     (Dept(35),"LICENSE APPL COMM",69888,[])
    =#


Query aliases
-------------

*Show the top 3 largest departments and their sizes.*

    DeptSize() = Count(DeptEmployee()) |> ThenTag(:size)

    q = (Start()
        |> Department()
        |> ThenSort(DeptSize() |> ThenDesc())
        |> ThenSelect(DeptName(), DeptSize())
        |> ThenTake(Const(3)))
    #-> Unit -> {Dept [tag=:department], String [tag=:name], Int64 [tag=:size]}*

    display(execute(q))
    #=>
    DataSet[3 × {Dept [tag=:department], String [tag=:name], Int64 [tag=:size]}]:
     (Dept(2),"POLICE",13570)
     (Dept(7),"FIRE",4875)
     (Dept(5),"STREETS & SAN",2090)
    =#

