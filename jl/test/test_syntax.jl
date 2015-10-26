
push!(LOAD_PATH, "./jl")

using Base.Test
using RBT: LiteralSyntax, ApplySyntax, ComposeSyntax, syntax


q1 = syntax("department")

@test string(q1) == "department"
@test typeof(q1) == ApplySyntax
@test q1.fn == :department
@test q1.args == []


q2 = syntax("department.name")

@test string(q2) == "department.name"
@test typeof(q2) == ComposeSyntax
@test string(q2.f) == "department"
@test string(q2.g) == "name"


q3 = syntax("""
    department
    :filter(count(employee)>100)
    :sort(count(employee):desc)
    :select(
        name,
        count(employee),
        employee)
""")

@test string(q3) ==
    "select(" *
        "sort(filter(department,>(count(employee),100)),desc(count(employee)))," *
        "name," *
        "count(employee)," *
        "employee)"
@test typeof(q3) == ApplySyntax
@test q3.fn == :select


q4 = syntax("""
    employee
    :by(position)
    :select(
        position,
        count(employee),
        max(employee.salary),
        mean(employee.salary))
""")

@test string(q4) ==
    "select(" *
        "by(employee,position)," *
        "position," *
        "count(employee)," *
        "max(employee.salary)," *
        "mean(employee.salary))"


q5 = syntax("""
    department
    :filter(count(employee)>100)
    .employee
    .name
""")

@test string(q5) == "filter(department,>(count(employee),100)).employee.name"


q6 = syntax("6 * (3 + 4)")

@test string(q6) == "*(6,+(3,4))"
@test typeof(q6) == ApplySyntax
@test typeof(q6.args[1]) == LiteralSyntax{Int}
@test q6.args[1].val == 6

