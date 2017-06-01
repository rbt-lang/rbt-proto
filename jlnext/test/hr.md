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

Next, we convert this data to query primitives.

    using RBT:
        CollectionQuery,
        Domain,
        MappingQuery,
        decorate

    dept_set =
        CollectionQuery(
            Domain(:Dept)
                |> decorate(:tag => :department)
                |> decorate(:fmt => :name),
            dept_data)
    emp_set =
        CollectionQuery(
            Domain(:Emp)
                |> decorate(:tag => :employee)
                |> decorate(:fmt => [:name, :department, :position, :salary]),
            emp_data)

    dept_name_map =
        MappingQuery(
            Domain(:Dept),
            Domain(String)
                |> decorate(:tag => :name),
            dept_name_data)
    dept_employee_map =
        MappingQuery(
            Domain(:Dept),
            Domain(:Emp)
                |> decorate(:tag => :employee)
                |> decorate(:fmt => [:name, :position, :salary]),
            dept_employee_data)

    emp_name_map =
        MappingQuery(
            Domain(:Emp),
            Domain(String)
                |> decorate(:tag => :name),
            emp_name_data)
    emp_position_map =
        MappingQuery(
            Domain(:Emp),
            Domain(String)
                |> decorate(:tag => :position),
            emp_position_data)
    emp_salary_map =
        MappingQuery(
            Domain(:Emp),
            Domain(Int)
                |> decorate(:tag => :salary),
            emp_salary_data)
    emp_department_map =
        MappingQuery(
            Domain(:Emp),
            Domain(:Dept)
                |> decorate(:tag => :department)
                |> decorate(:fmt => :name),
            emp_department_data)
    emp_manager_map =
        MappingQuery(
            Domain(:Emp),
            Domain(:Emp)
                |> decorate(:tag => :manager)
                |> decorate(:fmt => [:name, :position]),
            emp_manager_data)
    emp_subordinate_map =
        MappingQuery(
            Domain(:Emp),
            Domain(:Emp)
                |> decorate(:tag => :employee)
                |> decorate(:fmt => [:name, :position]),
            emp_subordinate_data)

Finally, we register the primitives with the database.

    using RBT:
        attach!

    attach!(:department, dept_set)
    attach!(:employee, emp_set)

    attach!(:name, dept_name_map)
    attach!(:employee, dept_employee_map)

    attach!(:name, emp_name_map)
    attach!(:position, emp_position_map)
    attach!(:salary, emp_salary_map)
    attach!(:department, emp_department_map)
    attach!(:manager, emp_manager_map)
    attach!(:subordinate, emp_subordinate_map)


Extracting data
---------------

    using RBT:
        @query,
        execute

*Show the name of each department.*

    q = @query(department.name)
    #-> Void -> String[tag=:name]*

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

    q = @query(department.employee.name)
    #-> Void -> String[tag=:name]*

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

    q = @query(employee.name)
    #-> Void -> String[tag=:name]*

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

    q = @query(employee.department.name)
    #-> Void -> String[tag=:name]*

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

    q = @query(employee.position)
    #-> Void -> String[tag=:position]*

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

    q = @query(employee)
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    32181-element composite vector of {String, String, String, Int64}:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ⋮
     ("CARLO Z","POLICE","POLICE OFFICER",86520)
     ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)
    =#

We can also construct the same queries dynamically, using combinator notation.

    using RBT:
        Field,
        Query

    Department = Field(:department)
    Employee = Field(:employee)
    Name = Field(:name)
    Position = Field(:position)
    Salary = Field(:salary)
    Manager = Field(:manager)
    Subordinate = Field(:subordinate)

*Show the name of each department.*

    q = Query(Department >> Name)
    #-> Void -> String[tag=:name]*

    display(execute(q))
    #=>
    35-element Array{String,1}:
     "WATER MGMNT"
     ⋮
    =#

*For each department, show the name of each employee.*

    q = Query(Department >> Employee >> Name)
    #-> Void -> String[tag=:name]*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "ELVIA A"
     ⋮
    =#

*Show the name of each employee.*

    q = Query(Employee >> Name)
    #-> Void -> String[tag=:name]*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "ELVIA A"
     ⋮
    =#

*For each employee, show the name of their department.*

    q = Query(Employee >> Department >> Name)
    #-> Void -> String[tag=:name]*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "WATER MGMNT"
     ⋮
    =#

*Show the position of each employee.*

    q = Query(Employee >> Position)
    #-> Void -> String[tag=:position]*

    display(execute(q))
    #=>
    32181-element Array{String,1}:
     "WATER RATE TAKER"
     ⋮
    =#

*Show all employees.*

    q = Query(Employee)
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    32181-element composite vector of {String, String, String, Int64}:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ⋮
    =#


Summarizing data
----------------

*Show the number of departments.*

    q = @query(count(department))
    #-> Void -> Int64

    execute(q)
    #-> 35

*What is the highest employee salary?*

    q = @query(max(employee.salary))
    #-> Void -> Int64?

    execute(q)
    #-> Nullable{Int64}(260004)

*For each department, show the number of employees.*

    q = @query(department.count(employee))
    #-> Void -> Int64*

    execute(q)
    #-> [1848,13570,924  …  39,1]

*How many employees are in the largest department?*

    q = @query(max(department.count(employee)))
    #-> Void -> Int64?

    execute(q)
    #-> Nullable{Int64}(13570)

Using combinator notation, these queries could be constructed as follows.

    using RBT:
        Count,
        MaxOf

*Show the number of departments.*

    q = Query(Count(Department))
    #-> Void -> Int64

    execute(q)
    #-> 35

*What is the highest employee salary?*

    q = Query(MaxOf(Employee >> Salary))
    #-> Void -> Int64?

    execute(q)
    #-> Nullable{Int64}(260004)

*For each department, show the number of employees.*

    q = Query(Department >> Count(Employee))
    #-> Void -> Int64*

    execute(q)
    #-> [1848,13570,924  …  39,1]

*How many employees are in the largest department?*

    q = Query(MaxOf(q))
    #-> Void -> Int64?

    execute(q)
    #-> Nullable{Int64}(13570)


Pipeline notation
-----------------

*Show the top 10 highest paid employees in the Police department.*

    q = @query(
        employee
        :filter(department.name == "POLICE")
        :sort(salary:desc)
        :select(name, position, salary)
        :take(10))
    #-> Void -> {String[tag=:name], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    10-element composite vector of {String, String, Int64}:
     ("GARRY M","SUPERINTENDENT OF POLICE",260004)
     ("ALFONZA W","FIRST DEPUTY SUPERINTENDENT",197736)
     ("ROBERT T","CHIEF",194256)
     ("JOHN E","CHIEF",185364)
     ("WAYNE G","CHIEF",185364)
     ("ANTHONY R","CHIEF",185364)
     ("JUAN R","CHIEF",185364)
     ("EUGENE W","CHIEF",185364)
     ("DANA A","DEPUTY CHIEF",170112)
     ("CONSTANTINE A","DEPUTY CHIEF",170112)
    =#

We can construct the same query using combinator notation.

    using RBT:
        Desc,
        ThenFilter,
        ThenSelect,
        ThenSort,
        ThenTake

*Show the top 10 highest paid employees in the Police department.*

    q = Query(
            Employee
            >> ThenFilter(Department >> Name .== "POLICE")
            >> ThenSort(Salary >> Desc)
            >> ThenSelect(Name, Position, Salary)
            >> ThenTake(10))
    #-> Void -> {String[tag=:name], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    10-element composite vector of {String, String, Int64}:
     ("GARRY M","SUPERINTENDENT OF POLICE",260004)
     ⋮
    =#


Filtering data
--------------

*Which employees have a salary higher than $150k?*

    q = @query(employee:filter(salary > 150000))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    151-element composite vector of {String, String, String, Int64}:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ("VERDIE A","FIRE","ASST DEPUTY CHIEF PARAMEDIC",156360)
     ("SCOTT A","IPRA","CHIEF ADMINISTRATOR",161856)
     ⋮
     ("ALFONZA W","POLICE","FIRST DEPUTY SUPERINTENDENT",197736)
     ("GARY Y","POLICE","COMMANDER",162684)
    =#

*How many departments have more than 1000 employees?*

    q = @query(
        department
        :filter(count(employee) > 1000)
        :count)
    #-> Void -> Int64

    execute(q)
    #-> 7

Now, using the combinator notation.

    using RBT:
        ThenCount,
        ThenFilter

*Which employees have a salary higher than $150k?*

    q = Query(Employee >> ThenFilter(Salary .> 150000))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    151-element composite vector of {String, String, String, Int64}:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ⋮
    =#

*How many departments have more than 1000 employees?*

    q = Query(
            Department
            >> ThenFilter(Count(Employee) .> 1000)
            >> ThenCount)
    #-> Void -> Int64

    execute(q)
    #-> 7


Sorting and paginating data
---------------------------

*Show the names of all departments in alphabetical order.*

    q = @query(sort(department.name))
    #-> Void -> String[tag=:name]*

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

    q = @query(employee:sort(salary))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    32181-element composite vector of {String, String, String, Int64}:
     ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)
     ("BETTY A","FAMILY & SUPPORT","FOSTER GRANDPARENT",2756)
     ("VICTOR A","FAMILY & SUPPORT","SENIOR COMPANION",2756)
     ⋮
     ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
    =#

*Show all employees ordered by salary, highest paid first.*

    q = @query(employee:sort(salary:desc))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    32181-element composite vector of {String, String, String, Int64}:
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
     ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
     ("JOSE S","FIRE","FIRE COMMISSIONER",202728)
     ⋮
     ("MING Y","FAMILY & SUPPORT","SENIOR COMPANION",2756)
     ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)
    =#

*Who are the top 1% of the highest paid employees?*

    q = @query(
        employee
        :sort(salary:desc)
        :take(count(employee) ÷ 100))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    321-element composite vector of {String, String, String, Int64}:
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
     ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
     ("JOSE S","FIRE","FIRE COMMISSIONER",202728)
     ⋮
     ("KEVIN B","FIRE","BATTALION CHIEF",135480)
     ("MARJORIE B","FIRE","PARAMEDIC FIELD CHIEF",135480)
    =#

Using combinator notation.

*Show the names of all departments in alphabetical order.*

    using RBT:
        Sort

    q = Query(Sort(Department >> Name))
    #-> Void -> String[tag=:name]*

    display(execute(q))
    #=>
    35-element Array{String,1}:
     "ADMIN HEARNG"
     ⋮
    =#

*Show all employees ordered by salary.*

    q = Query(Employee >> ThenSort(Salary))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    32181-element composite vector of {String, String, String, Int64}:
     ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)
     ⋮
    =#

*Show all employees ordered by salary, highest paid first.*

    q = Query(Employee >> ThenSort(Salary >> Desc))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    32181-element composite vector of {String, String, String, Int64}:
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
     ⋮
    =#

*Who are the top 1% of the highest paid employees?*

    q = Query(
            Employee
            >> ThenSort(Salary >> Desc)
            >> ThenTake(Count(Employee) .÷ 100))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    321-element composite vector of {String, String, String, Int64}:
     ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
     ⋮
    =#


Query output
------------

*For each department, show its name and the number of employees.*

    q = @query(
        department
        :select(
            name,
            size => count(employee)))
    #-> Void -> {String[tag=:name], Int64[tag=:size]}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, Int64}:
     ("WATER MGMNT",1848)
     ("POLICE",13570)
     ("GENERAL SERVICES",924)
     ⋮
     ("ADMIN HEARNG",39)
     ("LICENSE APPL COMM",1)
    =#

*For every department, show the top salary and a list of managers with their
salaries.*

    q = @query(
        department
        :select(
            name,
            top_salary =>
                max(employee.salary),
            manager =>
                employee
                :filter(exists(subordinate))
                :select(name, salary)))
    #-> Void -> {String[tag=:name], Int64[tag=:top_salary]?, {String[tag=:name], Int64[tag=:salary]}[tag=:manager]*}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, Int64?, {String, Int64}*}:
     ("WATER MGMNT",169512,[])
     ("POLICE",260004,[])
     ("GENERAL SERVICES",157092,[])
     ⋮
     ("ADMIN HEARNG",156420,[])
     ("LICENSE APPL COMM",69888,[])
    =#

Using combinator notation.

    using RBT:
        Exists

*For each department, show its name and the number of employees.*

    q = Query(
            Department
            >> ThenSelect(
                Name,
                :size => Count(Employee)))
    #-> Void -> {String[tag=:name], Int64[tag=:size]}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, Int64}:
     ("WATER MGMNT",1848)
     ⋮
    =#

*For every department, show the top salary and a list of managers with their
salaries.*

    q = Query(
            Department
            >> ThenSelect(
                Name,
                :top_salary =>
                    MaxOf(Employee >> Salary),
                :manager =>
                    Employee
                    >> ThenFilter(Exists(Subordinate))
                    >> ThenSelect(Name, Salary)))
    #-> Void -> {String[tag=:name], Int64[tag=:top_salary]?, {String[tag=:name], Int64[tag=:salary]}[tag=:manager]*}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, Int64?, {String, Int64}*}:
     ("WATER MGMNT",169512,[])
     ⋮
    =#


Query aliases
-------------

*Show the top 3 largest departments and their sizes.*

    q = @query(
        department
        :define(size => count(employee))
        :sort(size:desc)
        :select(name, size)
        :take(3))
    #-> Void -> {String[tag=:name], Int64[tag=:size]}[tag=:department]*

    display(execute(q))
    #=>
    3-element composite vector of {String, Int64}:
     ("POLICE",13570)
     ("FIRE",4875)
     ("STREETS & SAN",2090)
    =#

In pure Julia code, we can use regular variables.

*Show the top 3 largest departments and their sizes.*

    Size = Count(Employee)

    q = Query(
            Department
            >> ThenSort(Size >> Desc)
            >> ThenSelect(Name, :size => Size)
            >> ThenTake(3))
    #-> Void -> {String[tag=:name], Int64[tag=:size]}[tag=:department]*

    display(execute(q))
    #=>
    3-element composite vector of {String, Int64}:
     ("POLICE",13570)
     ("FIRE",4875)
     ("STREETS & SAN",2090)
    =#


Hierarchical relationships
--------------------------

*Find all employees whose salary is higher than the salary of their manager.*

    q = @query(
        employee
        :filter(salary > manager.salary))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    1-element composite vector of {String, String, String, Int64}:
     ("BRIAN L","TREASURER","AUDITOR IV",114492)
    =#

*Find all direct and indirect subordinates of the City Treasurer.*

    q = @query(
        employee
        :filter(any(connect(manager).position == "CITY TREASURER")))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    23-element composite vector of {String, String, String, Int64}:
     ("SAEED A","TREASURER","ASST CITY TREASURER",85020)
     ("ELIZABETH A","TREASURER","ACCOUNTANT I",72840)
     ("KONSTANTINES A","TREASURER","ASSISTANT DIRECTOR OF FINANCE",73080)
     ⋮
     ("KENNETH S","TREASURER","ASST CITY TREASURER",75000)
     ("ALEXANDRA S","TREASURER","DEPUTY CITY TREASURER",90000)
    =#

Using combinators.

    using RBT:
        AnyOf,
        Connect

*Find all employees whose salary is higher than the salary of their manager.*

    q = Query(
            Employee
            >> ThenFilter(Salary .> Manager >> Salary))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    1-element composite vector of {String, String, String, Int64}:
     ("BRIAN L","TREASURER","AUDITOR IV",114492)
    =#

*Find all direct and indirect subordinates of the City Treasurer.*

    q = Query(
            Employee
            >> ThenFilter(AnyOf(Connect(Manager) >> Position .== "CITY TREASURER")))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    23-element composite vector of {String, String, String, Int64}:
     ("SAEED A","TREASURER","ASST CITY TREASURER",85020)
     ⋮
    =#


Quotient classes
----------------

*Show all departments, and, for each department, list the associated
employees.*

    q = @query(
        department
        :select(name, employee))
    #-> Void -> {String[tag=:name], {String[tag=:name], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, {String, String, Int64}*}:
     ("WATER MGMNT",[("ELVIA A","WATER RATE TAKER",88968)  …  ("THOMAS Z","POOL MOTOR TRUCK DRIVER",71781)])
     ("POLICE",[("JEFFERY A","POLICE OFFICER",80778)  …  ("CARLO Z","POLICE OFFICER",86520)])
     ("GENERAL SERVICES",[("KIMBERLEI A","CHIEF CONTRACT EXPEDITER",84780)  …  ("MICHAEL Z","FRM OF MACHINISTS - AUTOMOTIVE",97448)])
     ⋮
     ("ADMIN HEARNG",[("JAMIE B","ADMINISTRATIVE ASST II",63708)  …  ("RACHENETTE W","ADMINISTRATIVE ASST II",58020)])
     ("LICENSE APPL COMM",[("MICHELLE G","STAFF ASST",69888)])
    =#

*Show all positions, and, for each position, list the associated employees.*

    q = @query(
        employee
        :group(position)
        :select(position, employee))
    #-> Void -> {String[tag=:position], {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]+}*

    display(execute(q))
    #=>
    1094-element composite vector of {String, {String, String, String, Int64}+}:
     ("1ST DEPUTY INSPECTOR GENERAL",[("SHARON F","INSPECTOR GEN","1ST DEPUTY INSPECTOR GENERAL",137052)])
     ("A/MGR COM SVC-ELECTIONS",[("LAURA G","BOARD OF ELECTION","A/MGR COM SVC-ELECTIONS",99816)])
     ("A/MGR OF MIS-ELECTIONS",[("TIEN T","BOARD OF ELECTION","A/MGR OF MIS-ELECTIONS",94932)])
     ⋮
     ("ZONING INVESTIGATOR",[("CARLOS R","COMMUNITY DEVELOPMENT","ZONING INVESTIGATOR",97596)])
     ("ZONING PLAN EXAMINER",[("KYLE B","COMMUNITY DEVELOPMENT","ZONING PLAN EXAMINER",50004)  …  ("JANICE H","COMMUNITY DEVELOPMENT","ZONING PLAN EXAMINER",69888)])
    =#

*In the Police department, show all positions with the number of employees and
the top salary.*

    q = @query(
        employee
        :filter(department.name == "POLICE")
        :group(position)
        :select(
            position,
            count(employee),
            max(employee.salary)))
    #-> Void -> {String[tag=:position], Int64, Int64}*

    display(execute(q))
    #=>
    129-element composite vector of {String, Int64, Int64}:
     ("ACCOUNTANT I",1,72840)
     ("ACCOUNTANT II",2,80424)
     ("ACCOUNTANT III",1,65460)
     ⋮
     ("WARRANT AND EXTRADITION AIDE",5,80328)
     ("YOUTH SERVICES COORD",2,80916)
    =#

*Arrange employees into a hierarchy: first by position, then by department.*

    q = @query(
        employee
        :group(position)
        :select(
            position,
            employee
            :group(department)
            :select(department.name, employee)))
    #-> Void -> {String[tag=:position], {String[tag=:name], {  …  }[tag=:employee]+}+}*

    display(execute(q))
    #=>
    1094-element composite vector of {String, {String, {String, String, String, Int64}+}+}:
     ("1ST DEPUTY INSPECTOR GENERAL",[("INSPECTOR GEN",[("SHARON F","INSPECTOR GEN","1ST DEPUTY INSPECTOR GENERAL",137052)])])
     ("A/MGR COM SVC-ELECTIONS",[("BOARD OF ELECTION",[("LAURA G","BOARD OF ELECTION","A/MGR COM SVC-ELECTIONS",99816)])])
     ("A/MGR OF MIS-ELECTIONS",[("BOARD OF ELECTION",[("TIEN T","BOARD OF ELECTION","A/MGR OF MIS-ELECTIONS",94932)])])
     ⋮
     ("ZONING INVESTIGATOR",[("COMMUNITY DEVELOPMENT",[("CARLOS R","COMMUNITY DEVELOPMENT","ZONING INVESTIGATOR",97596)])])
     ("ZONING PLAN EXAMINER",[("COMMUNITY DEVELOPMENT",[("KYLE B","COMMUNITY DEVELOPMENT","ZONING PLAN EXAMINER",50004)  …  ("JANICE H","COMMUNITY DEVELOPMENT","ZONING PLAN EXAMINER",69888)])])
    =#

*Show all positions available in more than one department, and, for each
position, list the respective departments.*

    q = @query(
        employee
        :group(position)
        :define(department => unique(employee.department))
        :filter(count(department) > 1)
        :select(position, department.name))
    #-> Void -> {String[tag=:position], String[tag=:name]+}*

    display(execute(q))
    #=>
    261-element composite vector of {String, String+}:
     ("ACCOUNTANT I",String["TREASURER","FINANCE","PUBLIC LIBRARY","POLICE"])
     ("ACCOUNTANT II",String["FINANCE","FAMILY & SUPPORT"  …  "PUBLIC LIBRARY"])
     ("ACCOUNTANT III",String["FAMILY & SUPPORT","PUBLIC LIBRARY"  …  "BUSINESS AFFAIRS"])
     ⋮
     ("WATCHMAN",String["GENERAL SERVICES","WATER MGMNT"])
     ("YOUTH SERVICES COORD",String["FAMILY & SUPPORT","POLICE"])
    =#

*How many employees at each level of the organization chart?*

    q = @query(
        employee
        :group(level => count(connect(manager)))
        :select(level, count(employee)))
    #-> Void -> {Int64[tag=:level], Int64}*

    display(execute(q))
    #=>
    3-element composite vector of {Int64, Int64}:
     (0,32158)
     (1,17)
     (2,6)
    =#

*Show the average salary by department and position, with subtotals for each
department and the grand total.*

    q = @query(
        employee
        :rollup(department, position)
        :select(
            department,
            position,
            mean(employee.salary)))
    #-> Void -> {String[tag=:department]?, String[tag=:position]?, Float64}*

    display(execute(q))
    #=>
    2001-element composite vector of {String?, String?, Float64}:
     ("WATER MGMNT","ACCOUNTANT IV",95880.0)
     ("WATER MGMNT","ACCOUNTING TECHNICIAN I",63708.0)
     ("WATER MGMNT","ACCOUNTING TECHNICIAN III",66684.0)
     ⋮
     ("LICENSE APPL COMM",#NULL,69888.0)
     (#NULL,#NULL,79167.5)
    =#

Using combinator notation.

    using RBT:
        MeanOf,
        ThenGroup,
        ThenRollUp,
        Unique

*Show all departments, and, for each department, list the associated
employees.*

    q = Query(
            Department
            >> ThenSelect(Name, Employee))
    #-> Void -> {String[tag=:name], {String[tag=:name], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, {String, String, Int64}*}:
     ("WATER MGMNT",[("ELVIA A","WATER RATE TAKER",88968)  …  ("THOMAS Z","POOL MOTOR TRUCK DRIVER",71781)])
     ⋮
    =#

*Show all positions, and, for each position, list the associated employees.*

    q = Query(
            Employee
            >> ThenGroup(Position)
            >> ThenSelect(Position, Employee))
    #-> Void -> {String[tag=:position], {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]+}*

    display(execute(q))
    #=>
    1094-element composite vector of {String, {String, String, String, Int64}+}:
     ("1ST DEPUTY INSPECTOR GENERAL",[("SHARON F","INSPECTOR GEN","1ST DEPUTY INSPECTOR GENERAL",137052)])
     ⋮
    =#

*In the Police department, show all positions with the number of employees and
the top salary.*

    q = Query(
            Employee
            >> ThenFilter(Department >> Name .== "POLICE")
            >> ThenGroup(Position)
            >> ThenSelect(
                Position,
                Count(Employee),
                MaxOf(Employee >> Salary)))
    #-> Void -> {String[tag=:position], Int64, Int64}*

    display(execute(q))
    #=>
    129-element composite vector of {String, Int64, Int64}:
     ("ACCOUNTANT I",1,72840)
     ⋮
    =#

*Arrange employees into a hierarchy: first by position, then by department.*

    q = Query(
            Employee
            >> ThenGroup(Position)
            >> ThenSelect(
                Position,
                Employee
                >> ThenGroup(Department)
                >> ThenSelect(Department >> Name, Employee)))
    #-> Void -> {String[tag=:position], {String[tag=:name], {  …  }[tag=:employee]+}+}*

    display(execute(q))
    #=>
    1094-element composite vector of {String, {String, {String, String, String, Int64}+}+}:
     ("1ST DEPUTY INSPECTOR GENERAL",[("INSPECTOR GEN",[("SHARON F","INSPECTOR GEN","1ST DEPUTY INSPECTOR GENERAL",137052)])])
     ⋮
    =#

*Show all positions available in more than one department, and, for each
position, list the respective departments.*

    UniqueDepartment = Unique(Employee >> Department)

    q = Query(
            Employee
            >> ThenGroup(Position)
            >> ThenFilter(Count(UniqueDepartment) .> 1)
            >> ThenSelect(Position, UniqueDepartment >> Name))
    #-> Void -> {String[tag=:position], String[tag=:name]+}*

    display(execute(q))
    #=>
    261-element composite vector of {String, String+}:
     ("ACCOUNTANT I",String["TREASURER","FINANCE","PUBLIC LIBRARY","POLICE"])
     ⋮
    =#

*How many employees at each level of the organization chart?*

    Level = Field(:level)

    q = Query(
            Employee
            >> ThenGroup(:level => Count(Connect(Manager)))
            >> ThenSelect(Level, Count(Employee)))
    #-> Void -> {Int64[tag=:level], Int64}*

    display(execute(q))
    #=>
    3-element composite vector of {Int64, Int64}:
     (0,32158)
     (1,17)
     (2,6)
    =#

*Show the average salary by department and position, with subtotals for each
department and the grand total.*

    q = Query(
            Employee
            >> ThenRollUp(Department, Position)
            >> ThenSelect(
                Department,
                Position,
                MeanOf(Employee >> Salary)))
    #-> Void -> {String[tag=:department]?, String[tag=:position]?, Float64}*

    display(execute(q))
    #=>
    2001-element composite vector of {String?, String?, Float64}:
     ("WATER MGMNT","ACCOUNTANT IV",95880.0)
     ⋮
    =#


Query context
-------------

*Show all employees in the given department D with the salary higher than S,
where D = "POLICE", S = 150000.*

    q = @query(
        employee
        :filter(department.name == D && salary > S)
        :given(D => "POLICE", S => 150000))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    62-element composite vector of {String, String, String, Int64}:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ("CONSTANTINE A","POLICE","DEPUTY CHIEF",170112)
     ("KENNETH A","POLICE","COMMANDER",162684)
     ⋮
     ("ALFONZA W","POLICE","FIRST DEPUTY SUPERINTENDENT",197736)
     ("GARY Y","POLICE","COMMANDER",162684)
    =#

*Show all employees in the given department D with the salary higher than S,
where D = "POLICE", S = 150000.*

    q = @query(
        employee
        :filter(department.name == D && salary > S),
        D::String, S::Int)
    #-> {Void, D => String, S => Int64} -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q, D="POLICE", S=150000))
    #=>
    62-element composite vector of {String, String, String, Int64}:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ("CONSTANTINE A","POLICE","DEPUTY CHIEF",170112)
     ("KENNETH A","POLICE","COMMANDER",162684)
     ⋮
     ("ALFONZA W","POLICE","FIRST DEPUTY SUPERINTENDENT",197736)
     ("GARY Y","POLICE","COMMANDER",162684)
    =#

*Which employees have higher than average salary?*

    q = @query(
        employee
        :filter(salary > MS)
        :given(MS => mean(employee.salary)))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    19796-element composite vector of {String, String, String, Int64}:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ⋮
     ("CARLO Z","POLICE","POLICE OFFICER",86520)
     ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)
    =#

*Which employees have higher than average salary?*

    q = @query(
        employee
        :take(100)
        :filter(salary > mean(around.salary)))
    #-> (Void...) -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    65-element composite vector of {String, String, String, Int64}:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ⋮
    =#

*In the Police department, show employees whose salary is higher than the
average for their position.*

    q = @query(
        employee
        :take(100)
        :filter(department.name == "POLICE")
        :filter(salary > mean(around(position).salary)))
    #-> (Void...) -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    29-element composite vector of {String, String, String, Int64}:
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ("KARINA A","POLICE","POLICE OFFICER",80778)
     ("TERRY A","POLICE","POLICE OFFICER",86520)
     ⋮
    =#

*Show a numbered list of employees and their salaries along with the running total.*

    q = @query(
        employee
        :take(100)
        :select(
            no => count(before),
            name,
            salary,
            total => sum(before.salary)))
    #-> (Void...) -> {Int64[tag=:no], String[tag=:name], Int64[tag=:salary], Int64[tag=:total]}[tag=:employee]*

    display(execute(q))
    #=>
    100-element composite vector of {Int64, String, Int64, Int64}:
     (1,"ELVIA A",88968,88968)
     (2,"JEFFERY A",80778,169746)
     (3,"KARINA A",80778,250524)
     ⋮
    =#

*For each department, show employee salaries along with the running total; the
total should be reset at the department boundary.*

    q = @query(
        department
        :select(
            name,
            employee
            :take(100)
            :select(name, salary, sum(before.salary))
            :frame))
    #-> Void -> {String[tag=:name], {String[tag=:name], Int64[tag=:salary], Int64}[tag=:employee]*}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, {String, Int64, Int64}*}:
     ("WATER MGMNT",[("ELVIA A",88968,88968),("VICENTE A",104736,193704)  …  ])
     ("POLICE",[("JEFFERY A",80778,80778),("KARINA A",80778,161556)  …  ])
     ("GENERAL SERVICES",[("KIMBERLEI A",84780,84780),("RASHAD A",91520,176300)  …  ])
     ⋮
     ("ADMIN HEARNG",[("JAMIE B",63708,63708),("ELOUISE B",66684,130392)  …  ])
     ("LICENSE APPL COMM",[("MICHELLE G",69888,69888)])
    =#

Using combinator notation.

    using RBT:
        Around,
        Before,
        Given,
        Parameter,
        SumOf,
        ThenFrame

*Show all employees in the given department D with the salary higher than S,
where D = "POLICE", S = 150000.*

    D = Parameter(:D, String)
    S = Parameter(:S, Int)

    q = Query(
            Employee
            >> ThenFilter((Department >> Name .== D) & (Salary .> S))
            >> Given(:D => "POLICE", :S => 150000))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    62-element composite vector of {String, String, String, Int64}:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ⋮
    =#

*Show all employees in the given department D with the salary higher than S,
where D = "POLICE", S = 150000.*

    q = Query(
            Employee
            >> ThenFilter((Department >> Name .== D) & (Salary .> S)))
    #-> {Void, D => String, S => Int64} -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q, D="POLICE", S=150000))
    #=>
    62-element composite vector of {String, String, String, Int64}:
     ("DANA A","POLICE","DEPUTY CHIEF",170112)
     ⋮
    =#

*Which employees have higher than average salary?*

    MS = Parameter(:MS, Float64)

    q = Query(
            Employee
            >> ThenFilter(Salary .> MS)
            >> Given(:MS => MeanOf(Employee >> Salary)))
    #-> Void -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    19796-element composite vector of {String, String, String, Int64}:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ⋮
    =#

*Which employees have higher than average salary?*

    q = Query(
            Employee
            >> ThenTake(100)
            >> ThenFilter(Salary .> MeanOf(Around() >> Salary)))
    #-> (Void...) -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    65-element composite vector of {String, String, String, Int64}:
     ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
     ⋮
    =#

*In the Police department, show employees whose salary is higher than the
average for their position.*

    q = Query(
            Employee
            >> ThenTake(100)
            >> ThenFilter(Department >> Name .== "POLICE")
            >> ThenFilter(Salary .> MeanOf(Around(Position) >> Salary)))
    #-> (Void...) -> {String[tag=:name], String[tag=:department], String[tag=:position], Int64[tag=:salary]}[tag=:employee]*

    display(execute(q))
    #=>
    29-element composite vector of {String, String, String, Int64}:
     ("JEFFERY A","POLICE","POLICE OFFICER",80778)
     ⋮
    =#

*Show a numbered list of employees and their salaries along with the running total.*

    q = Query(
            Employee
            >> ThenTake(100)
            >> ThenSelect(
                :no => Count(Before()),
                Name,
                Salary,
                :total => SumOf(Before() >> Salary)))
    #-> (Void...) -> {Int64[tag=:no], String[tag=:name], Int64[tag=:salary], Int64[tag=:total]}[tag=:employee]*

    display(execute(q))
    #=>
    100-element composite vector of {Int64, String, Int64, Int64}:
     (1,"ELVIA A",88968,88968)
     ⋮
    =#

*For each department, show employee salaries along with the running total; the
total should be reset at the department boundary.*

    q = Query(
            Department
            >> ThenSelect(
                Name,
                Employee
                >> ThenTake(100)
                >> ThenSelect(Name, Salary, SumOf(Before() >> Salary))
                >> ThenFrame))
    #-> Void -> {String[tag=:name], {String[tag=:name], Int64[tag=:salary], Int64}[tag=:employee]*}[tag=:department]*

    display(execute(q))
    #=>
    35-element composite vector of {String, {String, Int64, Int64}*}:
     ("WATER MGMNT",[("ELVIA A",88968,88968),("VICENTE A",104736,193704)  …  ])
     ⋮
    =#

