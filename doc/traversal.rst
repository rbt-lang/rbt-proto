Traversal, Aggregates, Selection, Filtering
===========================================


.. slide:: Querying Database
   :level: 2

   Consider a textbook database schema:

   .. graphviz:: citydb-unfolding-step-1.dot

   How to *query* this database?

   Example:

   *For each department, show the number of employees with salary higher than
   100k.*


.. slide:: Querying Database: Combinators
   :level: 3

   How to query a database?  Example:

   *For each department, show the number of employees with salary higher than
   100k.*

   To construct this query, we will introduce query combinators for:

   1. *Traversing* data.
   2. *Summarizing* data.
   3. *Selecting* data.
   4. *Filtering* data.

   More combinators later.


.. slide:: Traversing Data
   :level: 2

   Consider a query: *Show the name of each department.*

   First, we transform the database schema into hierarchical form:

   .. graphviz:: citydb-unfolded-data-model.dot

   We query the database by traversing its hierarchical structure.


.. slide:: :math:`\operatorname{department}{.}\operatorname{name}`
   :level: 3

   *Show the name of each department.*

   .. graphviz:: citydb-unfolded-department-name.dot

   Traversing nodes :math:`\operatorname{department}` and
   :math:`\operatorname{name}` gives us a query:

   .. math:: \operatorname{department}{.}\operatorname{name}


.. slide:: :math:`\operatorname{department}{.}\operatorname{name}` (Signature)
   :level: 3

   *Show the name of each department.*

   We construct this query by composing two primitives:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   Their composition is a query with signature:

   .. math::

      \operatorname{department}{.}\operatorname{name} :
      \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Text}\}

   What exactly does it do?  We can express it with an imperative program:

   .. math::

      &\textbf{for each }\; d\in\operatorname{Dept} \\
      &\qquad\textbf{print }\; d{.}\operatorname{name}


.. slide:: :math:`\operatorname{department}{.}\operatorname{name}` (Output)
   :level: 3

   *Show the name of each department.*

   Let us run it:

   .. code-block:: julia

      department.name

   Output is a sequence of text values:

   .. code-block:: julia

      "WATER MGMNT"
      "POLICE"
      ⋮
      "LICENSE APPL COMM"

   *Data source:* `City of Chicago
   <https://data.cityofchicago.org/Administration-Finance/Current-Employee-Names-Salaries-and-Position-Title/xzkq-xp2w>`__.


.. slide:: :math:`\operatorname{department}{.}\operatorname{employee}{.}\operatorname{name}`
   :level: 2

   We can traverse the database to any depth.

   *For each department, show the name of each employee.*

   .. graphviz:: citydb-unfolded-department-employee-name.dot

   This gives a query:
   :math:`\operatorname{department}{.}\operatorname{employee}{.}\operatorname{name}`.


.. slide:: :math:`\operatorname{department}{.}\operatorname{employee}{.}\operatorname{name}` (Signature)
   :level: 3

   *For each department, show the name of each employee.*

   The signature of this query is:

   .. math::

      \operatorname{department}{.}\operatorname{employee}{.}\operatorname{name} :
      \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of three primitives:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   And it represents the following program:

   .. math::

      &\textbf{for each }\; d\in\operatorname{Dept} \\
      &\qquad\textbf{for each }\; e\in\operatorname{Empl} \textbf{ such that }
        e{.}\operatorname{department} = d \\
      &\qquad\qquad\textbf{print }\; e{.}\operatorname{name}


.. slide:: :math:`\operatorname{department}{.}\operatorname{employee}{.}\operatorname{name}` (Output)
   :level: 3

   *For each department, show the name of each employee.*

   .. code-block:: julia

      department.employee.name

   .. code-block:: julia

      "ELVIA A"
      "VICENTE A"
      "MUHAMMAD A"
      "GIRLEY A"
      ⋮
      "MICHELLE G"

   We got a list where each employee appears once.  Why?

   Because each employee belongs to one and only one department.

   Can we get the same data without going through
   :math:`\operatorname{department}`?


.. slide:: :math:`\operatorname{employee}{.}\operatorname{name}`
   :level: 2

   We can get a list of employee names directly.

   *Show the name of each employee.*

   .. graphviz:: citydb-unfolded-employee-name.dot

   The respective query is:
   :math:`\operatorname{employee}{.}\operatorname{name}`.


.. slide:: :math:`\operatorname{employee}{.}\operatorname{name}` (Signature)
   :level: 3

   *Show the name of each employee.*

   We have a query with signature:

   .. math::

      \operatorname{employee}{.}\operatorname{name} :
      \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of two primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   And it represents a program:

   .. math::

      &\textbf{for each }\; e\in\operatorname{Empl} \\
      &\qquad\textbf{print }\; e{.}\operatorname{name}


.. slide:: :math:`\operatorname{employee}{.}\operatorname{name}` (Output)
   :level: 3

   *Show the name of each employee.*

   .. code-block:: julia

      employee.name

   .. code-block:: julia

      "ELVIA A"
      "JEFFERY A"
      "KARINA A"
      "KIMBERLEI A"
      ⋮
      "DARIUSZ Z"

   Compare this with the output of:

   .. code-block:: julia

      department.employee.name

   We got a list of the same items, but not necessarily in the same order.


.. slide:: :math:`\operatorname{employee}{.}\operatorname{department}{.}\operatorname{name}`
   :level: 2

   What if we traverse :math:`\operatorname{department}` through
   :math:`\operatorname{employee}`?

   *For each employee, show the name of their department.*

   .. graphviz:: citydb-unfolded-employee-department-name.dot

   The query:
   :math:`\operatorname{employee}{.}\operatorname{department}{.}\operatorname{name}`.


.. slide:: :math:`\operatorname{employee}{.}\operatorname{department}{.}\operatorname{name}` (Signature)
   :level: 3

   *For each employee, show the name of their department.*

   This query has signature:

   .. math::

      \operatorname{employee}{.}\operatorname{department}{.}\operatorname{name} :
      \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of three primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   And it represents a program:

   .. math::

      &\textbf{for each }\; e\in\operatorname{Empl} \\
      &\qquad\textbf{print }\; e{.}\operatorname{department}{.}\operatorname{name}


.. slide:: :math:`\operatorname{employee}{.}\operatorname{department}{.}\operatorname{name}` (Output)
   :level: 3

   *For each employee, show the name of their department.*

   .. code-block:: julia

      employee.department.name

   .. code-block:: julia

      "WATER MGMNT"
      "POLICE"
      "POLICE"
      "GENERAL SERVICES"
      ⋮
      "DoIT"

   This is *not* the same as the query ``department.name``.

   * One line for each *employee* entity.
   * Most department names appear more than once.
   * It may happen that some departments do not appear at all.


.. slide:: :math:`\operatorname{employee}{.}\operatorname{position}`
   :level: 2

   Can we get a list of employee positions?  Let us try:

   *Show the position of each employee.*

   .. graphviz:: citydb-unfolded-employee-position.dot

   The query:
   :math:`\operatorname{employee}{.}\operatorname{position}`.


.. slide:: :math:`\operatorname{employee}{.}\operatorname{position}` (Signature)
   :level: 3

   *Show the position of each employee.*

   The signature of this query is:

   .. math::

      \operatorname{employee}{.}\operatorname{position} :
      \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of two primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{position} & : \operatorname{Empl}&\to\operatorname{Text}

   It represents a program:

   .. math::

      &\textbf{for each }\; e\in\operatorname{Empl} \\
      &\qquad\textbf{print }\; e{.}\operatorname{position}


.. slide:: :math:`\operatorname{employee}{.}\operatorname{position}` (Output)
   :level: 3

   *Show the position of each employee.*

   .. code-block:: julia

      employee.position

   .. code-block:: julia

      "WATER RATE TAKER"
      "POLICE OFFICER"
      "POLICE OFFICER"
      "CHIEF CONTRACT EXPEDITER"
      ⋮
      "CHIEF DATA BASE ANALYST"

   You can spot duplicates in the output.

   Again, this is because we asked for one value for each *employee* entity.

   Is it possible to get a list of *unique* positions?  We will get back to
   this question when we discuss *quotients*.


.. slide:: :math:`\operatorname{employee}`
   :level: 2

   What happens if we ask for a list of entities?

   *Show all employees.*

   .. graphviz:: citydb-unfolded-employee.dot

   For convenience, an entity value is substituted with a tuple of its
   attributes.


.. slide:: :math:`\operatorname{employee}` (Signature)
   :level: 3

   *Show all employees.*

   The query signature is:

   .. math::

      \operatorname{employee} : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}

   The *formatter* converts this query to the form:

   .. math::

      &\operatorname{employee}{.}(
      \operatorname{name},\;
      \operatorname{department}{.}\operatorname{name},\;
      \operatorname{position},\;
      \operatorname{salary}): \\
      &\qquad\qquad \operatorname{Void} \to
      \operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Text},\operatorname{Text},\operatorname{Int}\}\}

   The formatted query corresponds to a program:

   .. math::

      &\textbf{for each }\; e\in\operatorname{Empl} \\
      &\qquad\textbf{print }\;
      e{.}\operatorname{name},\;
      e{.}\operatorname{department}{.}\operatorname{name},\;
      e{.}\operatorname{position},\;
      e{.}\operatorname{salary}\;


.. slide:: :math:`\operatorname{employee}` (Output)
   :level: 3

   *Show all employees.*

   .. code-block:: julia

      employee

   .. code-block:: julia

      ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
      ("JEFFERY A","POLICE","POLICE OFFICER",80778)
      ("KARINA A","POLICE","POLICE OFFICER",80778)
      ("KIMBERLEI A","GENERAL SERVICES","CHIEF CONTRACT EXPEDITER",84780)
      ⋮
      ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)


.. slide:: Summarizing Data
   :level: 2

   We learned to use composition to traverse the data.

   How can we *summarize* data?

   Consider a query:

   *Show the number of all departments.*

   * We know how to get a sequence of all departments:

     .. math::

        \operatorname{department} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Dept}\}

   * How to get *the number* of all departments?


.. slide:: Number of Departments
   :level: 3

   *Show the number of all departments.*

   What is the signature of this query?  It produces a single number, so:

   .. math::

      \operatorname{Void} \to \operatorname{Int}

   We start with a sequence of all departments:

   .. math::

      \operatorname{department} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Dept}\}

   We need to transform it to *the number* of departments.

   That is, we need an operation with a signature:

   .. math::

      (\operatorname{Void} \to \operatorname{Seq}\{\operatorname{Dept}\})
      \to (\operatorname{Void} \to \operatorname{Int})

   We call this operation: the :math:`\operatorname{count}` combinator.


.. slide:: The :math:`\operatorname{count}` Combinator
   :level: 3

   Combinator :math:`\operatorname{count}` has signature:

   .. math::

      \operatorname{count} : (A \to \operatorname{Seq}\{B\})
      \to (A \to \operatorname{Int})

   Here, :math:`A`, :math:`B` stand for arbitrary types.

   Compare it with a familiar function:

   .. math:: \operatorname{length} : \operatorname{Seq}\{B\} \to \operatorname{Int}

   * :math:`\operatorname{length}(s)` returns an integer, the number of
     elements in sequence :math:`s`.

   * :math:`\operatorname{count}(Q)` returns a *query* represented by a function:

     .. math::

        &\textbf{function }\; (a:A) \\
        &\qquad\textbf{return }\; \operatorname{length}(Q(a))

.. slide:: :math:`\operatorname{count}(\operatorname{department})`
   :level: 3

   *Show the number of all departments.*

   Use the combinator:

   .. math::

      \operatorname{count}(Q:A\to\operatorname{Seq}\{B\}) : A\to\operatorname{Int}

   Substitute: :math:`Q` with :math:`\operatorname{department}`, :math:`A` with
   :math:`\operatorname{Void}`, :math:`B` with :math:`\operatorname{Dept}`.

   We obtain query:

   .. math::

      \operatorname{count}(\operatorname{department}) : \operatorname{Void} \to \operatorname{Int}

   .. code-block:: julia

      count(department)

   .. code-block:: julia

      35


.. slide:: Aggregates
   :level: 2

    A combinator that maps a plural query to a singular query is called an
    *aggregate*.

    Examples:

   .. math::

      &\operatorname{count} & : (A\to\operatorname{Seq}\{B\})&\to(A\to\operatorname{Int}) \\
      &\operatorname{exists} & : (A\to\operatorname{Seq}\{B\})&\to(A\to\operatorname{Bool}) \\
      &\operatorname{any},\operatorname{all} & :
      (A\to\operatorname{Seq}\{\operatorname{Bool}\})&\to(A\to\operatorname{Bool}) \\
      &\operatorname{sum} & :
      (A\to\operatorname{Seq}\{\operatorname{Int}\})&\to(A\to\operatorname{Int}) \\
      &\operatorname{max},\operatorname{min} & :
      (A\to\operatorname{Seq}\{B\})&\to(A\to\operatorname{Opt}\{B\})

   Why :math:`\operatorname{Opt}` on the output of :math:`\operatorname{max}`
   and :math:`\operatorname{min}`?  What if the input is empty?


.. slide:: Aggregate over Composition
   :level: 3

   Just with aggregates and composition, we can construct complex queries.

   Example (an aggregate over composition):

   *Show the highest salary among all employees.*

   1. All salaries:

      .. math::

         \operatorname{employee}{.}\operatorname{salary} : \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   2. The maximum of all salaries:

      .. math::

         \operatorname{max}(\operatorname{employee}{.}\operatorname{salary}) : \operatorname{Void}\to\operatorname{Opt}\{\operatorname{Int}\}

   .. code-block:: julia

      max(employee.salary)

   .. code-block:: julia

      260004


.. slide:: Composition with Aggregate
   :level: 3

   Example (composition with an aggregate):

   *Show the number of employees in each department.*

   1. Number of employees for the given department:

      .. math::

         \operatorname{count}(\operatorname{employee}) : \operatorname{Dept}\to\operatorname{Int}

   2. Number of employees for each department:

      .. math::

         \operatorname{department}{.}\operatorname{count}(\operatorname{employee}) :
         \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   .. code-block:: julia

      department.count(employee)

   .. code-block:: julia

      1848
      13570
      ⋮
      1


.. slide:: Name Binding
   :level: 2

   *Show the number of employees in each department.*

   .. math::

      \operatorname{department}{.}\operatorname{count}(\operatorname{employee}) :
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   But there are *two* primitives called :math:`\operatorname{employee}`:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\}

   Which one is in the query?

   *Requirement:*

   * For a fixed input type, a primitive is uniquely determined by its name.

   This rule directs the name binding algorithm of Rabbit.


.. slide:: Name Binding Example (1 of 3)
   :level: 3

   1. The whole query has input of type :math:`\operatorname{Void}`:

      .. math::

         \underbrace{\operatorname{department}{.}\operatorname{count}(\operatorname{employee})}_{\operatorname{Void}\to ?}


   2. Input of a composition is the input of its left component:

      .. math::

         \underbrace{\operatorname{department}}_{\operatorname{Void}\to ?}{.}\operatorname{count}(\operatorname{employee})

   3. There is only one primitive :math:`\operatorname{department}` with input
      :math:`\operatorname{Void}`:

      .. math::

         \underbrace{\operatorname{department}}_{\operatorname{Void}\to \operatorname{Seq}\{\operatorname{Dept}\}}{.}\operatorname{count}(\operatorname{employee})


.. slide:: Name Binding Example (2 of 3)
   :level: 3

   4. In composition, left and right components agree on their intermediate
      type:

      .. math::

         \operatorname{department}{.}\underbrace{\operatorname{count}(\operatorname{employee})}_{\operatorname{Dept}\to ?}

   5. Input of an aggregate is the input of the aggregated query:

      .. math::

         \operatorname{department}{.}\operatorname{count}(\underbrace{\operatorname{employee}}_{\operatorname{Dept}\to ?})


   6. There is only one primitive :math:`\operatorname{employee}` with input
      :math:`\operatorname{Dept}`:

      .. math::

         \operatorname{department}{.}\operatorname{count}(\underbrace{\operatorname{employee}}_{\operatorname{Dept}\to\operatorname{Seq}\{\operatorname{Empl}\}})


.. slide:: Name Binding Example (3 of 3)
   :level: 3


   7. Signature of a combinator is determined by its components:

      .. math::

         \operatorname{department}{.}\underbrace{\operatorname{count}(\operatorname{employee})}_{\operatorname{Dept}\to\operatorname{Int}}

   8. Now we know the types of both components of composition:

      .. math::

         \underbrace{\operatorname{department}}_{\operatorname{Void}\to\operatorname{Seq}\{\operatorname{Dept}\}}{.}\underbrace{\operatorname{count}(\operatorname{employee})}_{\operatorname{Dept}\to\operatorname{Int}}

   9. So we can deduce the signature of the whole query:

      .. math::

         \underbrace{\operatorname{department}{.}\operatorname{count}(\operatorname{employee})}_{\operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}}


.. slide:: Aggregates: Conclusion
   :level: 2

   We conclude with an example of an aggregate over another aggregate.

   *Show the highest number of employees per department.*

   1. Number of employees for each department:

      .. math::

         \operatorname{department}{.}\operatorname{count}(\operatorname{employee}) :
         \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   2. The highest number of employees for each department:

      .. math::

         \operatorname{max}(\operatorname{department}{.}\operatorname{count}(\operatorname{employee})) :
         \operatorname{Void}\to\operatorname{Opt}\{\operatorname{Int}\}

   .. code-block:: julia

      max(department.count(employee))

   .. code-block:: julia

      32181


.. slide:: Selection
   :level: 2

   Consider one of the previous examples:

   *Show the number of employees in each department.*

   We already constructed a query:

   .. code-block:: julia

      department.count(employee)

   .. code-block:: julia

      1848
      13570
      ⋮
      1

   But this is not very informative... Can we add the name of the department?

   *For every department, show its name and the number of employees.*

   Need a way to *select* fields for output.


.. slide:: Selection: Demonstration
   :level: 3

   Example:

   *For every department, show its name and the number of employees.*

   Here is how we will write this query:

   .. code-block:: julia

      department
      :select(name, count(employee))

   .. code-block:: julia

      ("WATER MGMNT",1848)
      ("POLICE",13570)
      ⋮
      ("LICENSE APPL COMM",1)

   This query introduces two new concepts:

   * Pipeline notation (the ``:`` symbol).
   * The :math:`\operatorname{select}` combinator.


.. slide:: Pipeline Notation
   :level: 2

   Example:

   .. code-block:: julia

      department:select(name, count(employee))

   Let us explain the meaning of ``:`` in front of ``select``.

   This is *the pipeline notation* for query combinators:

   .. math::

      &Q{:}F \quad &\text{is desugared to} \quad &F(Q) \\
      &Q_1{:}F(Q_2,\ldots) \quad &\text{is desugared to} \quad &F(Q_1,Q_2,\ldots)

   Thus, this query is desugared to:

   .. code-block:: julia

      select(department, name, count(employee))

   How is the pipeline notation used in practice?


.. slide:: Pipeline Notation: Usage
   :level: 3

   Pipeline notation:

   .. math::

      &Q{:}F \quad &\text{is desugared to} \quad &F(Q) \\
      &Q_1{:}F(Q_2,\ldots) \quad &\text{is desugared to} \quad &F(Q_1,Q_2,\ldots)

   How is this notation used in practice?

   * In principle, any combinator can be written using pipeline notation.

     For example, the query
     :math:`\operatorname{count}(\operatorname{department})` can be written as:

     .. math::

        \operatorname{department}{:}\operatorname{count}

   * In practice, we use pipeline notation to chain a sequence of combinators.

     What does it mean?


.. slide:: Building a Pipeline
   :level: 3

   We use pipeline notation to chain a sequence of combinators.

   Typical usage:

   .. code-block:: julia

      employee
      :filter(department.name == "POLICE")
      :group(position)
      :select(position, count(employee), mean(employee.salary))

   This example uses combinators we have not yet covered.  But the intent is
   clear:

   * start with a list of all employees;
   * filter the list by a predicate condition;
   * group it by an attribute;
   * select fields for output.


.. slide:: Building a Pipeline: Desugaring Example
   :level: 3

   Example (before and after desugaring):

   .. code-block:: julia

      employee
      :filter(department.name == "POLICE")
      :group(position)
      :select(position, count(employee), mean(employee.salary))

   .. code-block:: julia

      select(
          group(
              filter(
                  employee,
                  department.name == "POLICE"),
              position),
          position,
          count(employee),
          mean(employee.salary))

   Pipeline notation emphasises the structure and the intent of the query.


.. slide:: The :math:`\operatorname{select}` Combinator
   :level: 2

   Back to the example:

   *For every department, show its name and the number of employees.*

   The query, after desugaring, has the form:

   .. math::

      \operatorname{select}(
      \operatorname{department},
      \operatorname{name},
      \operatorname{count}(\operatorname{employee}))

   It produces a sequence of pairs, so its signature is:

   .. math::

      \operatorname{Void} \to
      \operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}\}

   * How does it work?
   * What is its general form?
   * More examples?


.. slide:: The :math:`\operatorname{select}` Combinator: Components
   :level: 3

   *For every department, show its name and the number of employees:*

   .. math::

      \operatorname{select}(
      \operatorname{department},
      \operatorname{name},
      \operatorname{count}(\operatorname{employee}))

   * *Show each department:*

     .. math::

        \operatorname{department}:\operatorname{Void}\to\operatorname{Seq}\{\operatorname{Dept}\}

   * *For the given department, show its name:*

   .. math::

      \operatorname{name}:\operatorname{Dept}\to\operatorname{Text}

   * *For the given department, show the number of employees:*

     .. math::

        \operatorname{count}(\operatorname{employee}):\operatorname{Dept}\to\operatorname{Int}

   How does :math:`\operatorname{select}` combines these components?


.. slide:: The :math:`\operatorname{select}` Combinator: Signature
   :level: 3

   In general, the :math:`\operatorname{select}` combinator has the form:

   .. math::

      \operatorname{select}(Q,F_1,F_2,\ldots,F_n)

   * The first component is the base of selection:

     .. math::

        Q : A \to \operatorname{Seq}\{B\}

   * The remaining components are selected fields:

     .. math::

        F_k : B \to C_k \quad (k=1,2,\ldots,n)

   The :math:`\operatorname{select}` combinator has the signature:

   .. math::

      \operatorname{select}(Q,F_1,F_2,\ldots,F_n) :
      A \to \operatorname{Seq}\{\operatorname{Tuple}\{C_1,C_2,\ldots,C_n\}\}


.. slide:: The :math:`\operatorname{select}` Combinator: Implementation
   :level: 3

   The :math:`\operatorname{select}` combinator has the signature:

   .. math::

      \operatorname{select}(
      &Q : A \to \operatorname{Seq}\{B\}, \\
      &F_1 : B \to C_1, \\
      &F_2 : B \to C_2, \\
      &\ldots, \\
      &F_n : B \to C_n) :
      A \to \operatorname{Seq}\{\operatorname{Tuple}\{C_1,C_2,\ldots,C_n\}\}

   It represents the following query:

   .. math::

      &\textbf{function }\; (a:A) \\
      &\qquad\textbf{for each }\; b \in Q(a) \\
      &\qquad\qquad\textbf{yield }\; (F_1(b),F_2(b),\ldots,F_n(b))


.. slide:: The :math:`\operatorname{select}` Combinator: Clarification
   :level: 3

   .. math::

      \operatorname{select}(
      &Q : A \to \operatorname{Seq}\{B\}, \\
      &F_1 : B \to C_1, \\
      &F_2 : B \to C_2, \\
      &\ldots, \\
      &F_n : B \to C_n) :
      A \to \operatorname{Seq}\{\operatorname{Tuple}\{C_1,C_2,\ldots,C_n\}\}

   In fact, this signature is a lie:

   * The base :math:`Q` does not have to be plural.
   * Fields :math:`F_k` could be partial or plural.
   * The output of :math:`\operatorname{select}` also includes the base value.

   We will tell the full story later.


.. slide:: The :math:`\operatorname{select}` Combinator: Example
   :level: 3

   *For every employee, show their name, department, position and salary.*

   .. code-block:: julia

      employee
      :select(
          name,
          department.name,
          position,
          salary)

   .. code-block:: julia

      ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
      ("JEFFERY A","POLICE","POLICE OFFICER",80778)
      ("KARINA A","POLICE","POLICE OFFICER",80778)
      ("KIMBERLEI A","GENERAL SERVICES","CHIEF CONTRACT EXPEDITER",84780)
      ⋮
      ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)


.. slide:: The :math:`\operatorname{select}` Combinator: Another Example
   :level: 3

   *For every department, show its name and the name and the position of its
   employees.*

   .. code-block:: julia

      department
      :select(
          name,
          employee:select(name,position))

   .. code-block:: julia

      ("WATER MGMNT",[("ELVIA A","WATER RATE TAKER"),("VICENTE A","CIVIL ENGINEER IV"),…])
      ("POLICE",[("JEFFERY A","POLICE OFFICER"),("KARINA A","POLICE OFFICER"),…])
      ⋮
      ("LICENSE APPL COMM",[("MICHELLE G","STAFF ASST")])


