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
     (Emp(8066),"JOHN E","CHIEF",185364)
     (Emp(11020),"WAYNE G","CHIEF",185364)
     (Emp(23936),"ANTHONY R","CHIEF",185364)
     (Emp(24184),"JUAN R","CHIEF",185364)
     (Emp(31020),"EUGENE W","CHIEF",185364)
     (Emp(370),"DANA A","DEPUTY CHIEF",170112)
     (Emp(780),"CONSTANTINE A","DEPUTY CHIEF",170112)
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
     ("MING Y","FAMILY & SUPPORT","SENIOR COMPANION",2756)
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
     ("KEVIN B","FIRE","BATTALION CHIEF",135480)
     ("MARJORIE B","FIRE","PARAMEDIC FIELD CHIEF",135480)
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


Hierarchical relationships
--------------------------

    using RBT:
        AnyOf,
        Connect

*Find all employees whose salary is higher than the salary of their manager.*

    q = (Start()
        |> Employee()
        |> ThenFilter(EmpSalary() .> (EmpManager() |> EmpSalary()))
        |> EmpRecord())
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[1 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("BRIAN L","TREASURER","AUDITOR IV",114492)
    =#

*Find all direct and indirect subordinates of the City Treasurer.*

    q = (Start()
        |> Employee()
        |> ThenFilter(
                AnyOf((Connect(EmpManager()) |> EmpPosition()) .== Const("CITY TREASURER")))
        |> EmpRecord())
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[23 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("SAEED A","TREASURER","ASST CITY TREASURER",85020)
     ("ELIZABETH A","TREASURER","ACCOUNTANT I",72840)
     ("KONSTANTINES A","TREASURER","ASSISTANT DIRECTOR OF FINANCE",73080)
     ⋮
     ("KENNETH S","TREASURER","ASST CITY TREASURER",75000)
     ("ALEXANDRA S","TREASURER","DEPUTY CITY TREASURER",90000)
    =#


Quotient classes
----------------

    using RBT:
        Field,
        MeanOf,
        ThenConnect,
        ThenGroup,
        ThenRollUp,
        ThenUnique

*Show all departments, and, for each department, list the associated
employees.*

    q = (Start()
        |> Department()
        |> ThenSelect(
                DeptName(),
                DeptEmployee()))
    #-> Unit -> {Dept [tag=:department], String [tag=:name], Emp* [tag=:employee]}*

    display(execute(q))
    #=>
    DataSet[35 × {Dept [tag=:department], String [tag=:name], Emp* [tag=:employee]}]:
     (Dept(1),"WATER MGMNT",Emp[Emp(1)  …  Emp(32171)])
     (Dept(2),"POLICE",Emp[Emp(2)  …  Emp(32180)])
     (Dept(3),"GENERAL SERVICES",Emp[Emp(4)  …  Emp(32177)])
     ⋮
     (Dept(34),"ADMIN HEARNG",Emp[Emp(2813)  …  Emp(31533)])
     (Dept(35),"LICENSE APPL COMM",Emp[Emp(11126)])
    =#

*Show all positions, and, for each position, list the associated employees.*

    PosPosition() = Field(:position)
    PosEmployee() = Field(:employee)

    q = (Start()
        |> Employee()
        |> ThenGroup(EmpPosition())
        |> ThenSelect(
                PosPosition(),
                PosEmployee()))
    #-> Unit -> {{Emp+ [tag=:employee], String [tag=:position]}, String [tag=:position], Emp+ [tag=:employee]}*

    display(execute(q))
    #=>
    DataSet[1094 × {{Emp+ [tag=:employee], String [tag=:position]}, String [tag=:position], Emp+ [tag=:employee]}]:
     ((Emp[Emp(8293)],"1ST DEPUTY INSPECTOR GENERAL"),"1ST DEPUTY INSPECTOR GENERAL",Emp[Emp(8293)])
     ((Emp[Emp(10877)],"A/MGR COM SVC-ELECTIONS"),"A/MGR COM SVC-ELECTIONS",Emp[Emp(10877)])
     ((Emp[Emp(29045)],"A/MGR OF MIS-ELECTIONS"),"A/MGR OF MIS-ELECTIONS",Emp[Emp(29045)])
     ⋮
     ((Emp[Emp(23375)],"ZONING INVESTIGATOR"),"ZONING INVESTIGATOR",Emp[Emp(23375)])
     ((Emp[Emp(1594)  …  Emp(12339)],"ZONING PLAN EXAMINER"),"ZONING PLAN EXAMINER",Emp[Emp(1594)  …  Emp(12339)])
    =#

*In the Police department, show all positions with the number of employees and
the top salary.*

    q = (Start()
        |> Employee()
        |> ThenFilter(EmpDepartment() |> DeptName() .== Const("POLICE"))
        |> ThenGroup(EmpPosition())
        |> ThenSelect(
                PosPosition(),
                Count(PosEmployee()),
                MaxOf(PosEmployee() |> EmpSalary())))
    #-> Unit -> {{Emp+ [tag=:employee], String [tag=:position]}, String [tag=:position], Int64, Int64}*

    display(execute(q))
    #=>
    DataSet[129 × {{Emp+ [tag=:employee], String [tag=:position]}, String [tag=:position], Int64, Int64}]:
     ((Emp[Emp(26755)],"ACCOUNTANT I"),"ACCOUNTANT I",1,72840)
     ((Emp[Emp(7319),Emp(28313)],"ACCOUNTANT II"),"ACCOUNTANT II",2,80424)
     ((Emp[Emp(6681)],"ACCOUNTANT III"),"ACCOUNTANT III",1,65460)
     ⋮
     ((Emp[Emp(13404)  …  Emp(30503)],"WARRANT AND EXTRADITION AIDE"),"WARRANT AND EXTRADITION AIDE",5,80328)
     ((Emp[Emp(28702),Emp(30615)],"YOUTH SERVICES COORD"),"YOUTH SERVICES COORD",2,80916)
    =#

*Arrange employees into a hierarchy: first by position, then by department.*

    q = (Start()
        |> Employee()
        |> ThenGroup(EmpPosition())
        |> ThenSelect(
                Field(:position),
                Field(:employee)
                |> ThenGroup(EmpDepartment())
                |> ThenSelect(
                        Field(:department) |> DeptName(),
                        Field(:employee))))
    #-> Unit -> {{  …  }, String [tag=:position], {{  …  }, String [tag=:name], Emp+ [tag=:employee]}+}*

    display(execute(q))
    #=>
    DataSet[1094 × {{  …  }, String [tag=:position], {{  …  }, String [tag=:name], Emp+ [tag=:employee]}+}]:
     ((  …  ),"1ST DEPUTY INSPECTOR GENERAL",[((  …  ),"INSPECTOR GEN",Emp[Emp(8293)])])
     ((  …  ),"A/MGR COM SVC-ELECTIONS",[((  …  ),"BOARD OF ELECTION",Emp[Emp(10877)])])
     ((  …  ),"A/MGR OF MIS-ELECTIONS",[((  …  ),"BOARD OF ELECTION",Emp[Emp(29045)])])
     ⋮
     ((  …  ),"ZONING INVESTIGATOR",[((  …  ),"COMMUNITY DEVELOPMENT",Emp[Emp(23375)])])
     ((  …  ),"ZONING PLAN EXAMINER",[((  …  ),"COMMUNITY DEVELOPMENT",Emp[Emp(1594)  …  Emp(12339)])])
    =#

*Show all positions available in more than one department, and, for each
position, list the respective departments.*

    PosDepartment() =
        PosEmployee() |> EmpDepartment() |> ThenUnique()

    q = (Start()
        |> Employee()
        |> ThenGroup(EmpPosition())
        |> ThenFilter(Count(PosDepartment()) .> Const(1))
        |> ThenSelect(
                PosPosition(),
                PosDepartment() |> DeptName()))
    #-> Unit -> {{  …  }, String [tag=:position], String+ [tag=:name]}*

    display(execute(q))
    #=>
    DataSet[261 × {{  …  }, String [tag=:position], String+ [tag=:name]}]:
     ((  …  ),"ACCOUNTANT I",String["TREASURER","FINANCE","PUBLIC LIBRARY","POLICE"])
     ((  …  ),"ACCOUNTANT II",String["FINANCE","FAMILY & SUPPORT"  …  "PUBLIC LIBRARY"])
     ((  …  ),"ACCOUNTANT III",String["FAMILY & SUPPORT","PUBLIC LIBRARY"  …  "BUSINESS AFFAIRS"])
     ⋮
     ((  …  ),"WATCHMAN",String["GENERAL SERVICES","WATER MGMNT"])
     ((  …  ),"YOUTH SERVICES COORD",String["FAMILY & SUPPORT","POLICE"])
    =#

*How many employees at each level of the organization chart?*

    EmpLevel() = EmpManager() |> ThenConnect() |> ThenCount() |> ThenTag(:level)

    q = (Start()
        |> Employee()
        |> ThenGroup(EmpLevel())
        |> ThenSelect(
                Field(:level),
                Count(Field(:employee))))
    #-> Unit -> {{  …  }, Int64 [tag=:level], Int64}*

    display(execute(q))
    #=>
    DataSet[3 × {{  …  }, Int64 [tag=:level], Int64}]:
     ((  …  ),0,32158)
     ((  …  ),1,17)
     ((  …  ),2,6)
    =#

*Show the average salary by department and position, with subtotals for each
department and the grand total.*

    q = (Start()
        |> Employee()
        |> ThenRollUp(EmpDepartment(), EmpPosition())
        |> ThenSelect(
                Field(:department) |> DeptRecord(),
                Field(:position),
                MeanOf(Field(:employee) |> EmpSalary())))
    #-> Unit -> {{  …  }, {String [tag=:name]}? [tag=:department], String? [tag=:position], Float64}*

    display(execute(q))
    #=>
    DataSet[2001 × {{  …  }, {String [tag=:name]}? [tag=:department], String? [tag=:position], Float64}]:
     ((  …  ),("WATER MGMNT",),"ACCOUNTANT IV",95880.0)
     ((  …  ),("WATER MGMNT",),"ACCOUNTING TECHNICIAN I",63708.0)
     ((  …  ),("WATER MGMNT",),"ACCOUNTING TECHNICIAN III",66684.0)
     ⋮
     ((  …  ),("LICENSE APPL COMM",),#NULL,69888.0)
     ((  …  ),#NULL,#NULL,79167.5)
    =#


Query context
-------------

    using RBT:
        Given,
        HereAndAround,
        HereAndBefore,
        Parameter,
        SumOf,
        ThenFrame

*Show all employees in the given department D with the salary higher than S,
where D = "POLICE", S = 150000.*

    D() = Parameter(:D, String)
    S() = Parameter(:S, Int)

    q = (Start()
        |> Employee()
        |> ThenFilter((EmpDepartment() |> DeptName() .== D()) & (EmpSalary() .> S()))
        |> EmpRecord())
    #-> {Unit, D => String, S => Int64} -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q, D="POLICE", S=150000))
    #=>
    DataSet[62 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ("CONSTANTINE A","POLICE","DEPUTY CHIEF",170112)
     ("KENNETH A","POLICE","COMMANDER",162684)
     ⋮
     ("ALFONZA W","POLICE","FIRST DEPUTY SUPERINTENDENT",197736)
     ("GARY Y","POLICE","COMMANDER",162684)
    =#

*Which employees have higher than average salary?*

    MS() = Parameter(:MS, Output(Float64, optional=true))

    q = (Start()
        |> Employee()
        |> ThenFilter(EmpSalary() .> MS())
        |> EmpRecord()
        |> Given(MeanOf(Employee() |> EmpSalary()) |> ThenTag(:MS)))
    #-> Unit -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[19796 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ⋮
     ("CARLO Z","POLICE","POLICE OFFICER",86520)
     ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)
    =#

*Which employees have higher than average salary?*

    q = (Start()
        |> Employee()
        |> ThenTake(Const(100))     # FIXME
        |> ThenFilter(EmpSalary() .> MeanOf(HereAndAround() |> EmpSalary()))
        |> EmpRecord())
    #-> (Unit...) -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[65 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ⋮
    =#

*In the Police department, show employees whose salary is higher than the
average for their position.*

    q = (Start()
        |> Employee()
        |> ThenTake(Const(100))     # FIXME
        |> ThenFilter(EmpDepartment() |> DeptName() .== Const("POLICE"))
        |> ThenFilter(EmpSalary() .> MeanOf(HereAndAround(EmpPosition()) |> EmpSalary()))
        |> EmpRecord())
    #-> (Unit...) -> {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}* [tag=:employee]

    display(execute(q))
    #=>
    DataSet[29 × {String [tag=:name], String [tag=:department], String [tag=:position], Int64 [tag=:salary]}]:
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ("TERRY A","POLICE","POLICE OFFICER",86520)
     ⋮
    =#

*Show a numbered list of employees and their salaries along with the running total.*

    q = (Start()
        |> Employee()
        |> ThenTake(Const(100))     # FIXME
        |> ThenSelect(
                Count(HereAndBefore()) |> ThenTag(:no),
                EmpName(),
                EmpSalary(),
                SumOf(HereAndBefore() |> EmpSalary()) |> ThenTag(:total)))
    #-> (Unit...) -> {Emp [tag=:employee], Int64 [tag=:no], String [tag=:name], Int64 [tag=:salary], Int64 [tag=:total]}*

    display(execute(q))
    #=>
    DataSet[100 × {Emp [tag=:employee], Int64 [tag=:no], String [tag=:name], Int64 [tag=:salary], Int64 [tag=:total]}]:
     (Emp(1),1,"ELVIA A",88968,88968)
     (Emp(2),2,"JEFFERY A",80778,169746)
     (Emp(3),3,"KARINA A",80778,250524)
     ⋮
    =#

*For each department, show employee salaries along with the running total; the
total should be reset at the department boundary.*

    q = (Start()
        |> Department()
        |> ThenSelect(
                DeptName(),
                DeptEmployee()
                |> ThenTake(Const(100))     # FIXME
                |> ThenSelect(
                        EmpName(),
                        EmpSalary(),
                        SumOf(HereAndBefore() |> EmpSalary()))
                |> ThenFrame()))
    #-> Unit -> {Dept [tag=:department], String [tag=:name], {Emp [tag=:employee], String [tag=:name], Int64 [tag=:salary], Int64}*}*

    display(execute(q))
    #=>
    DataSet[35 × {Dept [tag=:department], String [tag=:name], {Emp [tag=:employee], String [tag=:name], Int64 [tag=:salary], Int64}*}]:
     (Dept(1),"WATER MGMNT",[(Emp(1),"ELVIA A",88968,88968),(Emp(5),"VICENTE A",104736,193704)  …  ])
     (Dept(2),"POLICE",[(Emp(2),"JEFFERY A",80778,80778),(Emp(3),"KARINA A",80778,161556)  …  ])
     (Dept(3),"GENERAL SERVICES",[(Emp(4),"KIMBERLEI A",84780,84780),(Emp(23),"RASHAD A",91520,176300)  …  ])
     ⋮
     (Dept(34),"ADMIN HEARNG",[(Emp(2813),"JAMIE B",63708,63708),(Emp(3020),"ELOUISE B",66684,130392)  …  ])
     (Dept(35),"LICENSE APPL COMM",[(Emp(11126),"MICHELLE G",69888,69888)])
    =#

