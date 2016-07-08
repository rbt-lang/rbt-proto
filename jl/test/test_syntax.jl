
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

@test typeof(q3) == ApplySyntax
@test q3.fn == :select
@test string(q3.args[1]) == "department:filter(>(count(employee),100)):sort(count(employee):desc)"
@test string(q3.args[2]) == "name"
@test string(q3.args[3]) == "count(employee)"
@test string(q3.args[4]) == "employee"


q4 = syntax("""
    employee
    :group(position)
    :select(
        position,
        count(employee),
        max(employee.salary),
        mean(employee.salary))
""")

@test typeof(q4) == ApplySyntax
@test q4.fn == :select
@test string(q4.args[1]) == "employee:group(position)"
@test string(q4.args[2]) == "position"
@test string(q4.args[3]) == "count(employee)"
@test string(q4.args[4]) == "max(employee.salary)"
@test string(q4.args[5]) == "mean(employee.salary)"


q5 = syntax("""
    department:filter(count(employee)>100).employee.name
""")

@test typeof(q5) == ComposeSyntax
@test string(q5.f) == "department:filter(>(count(employee),100))"
@test string(q5.g) == "employee.name"


q6 = syntax("6 * (3 + 4)")

@test string(q6) == "*(6,+(3,4))"
@test typeof(q6) == ApplySyntax
@test typeof(q6.args[1]) == LiteralSyntax
@test q6.args[1].val == 6

