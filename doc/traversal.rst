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

   .. code-block:: jlcon

      >>> department.name

   Output is a sequence of text values:

   .. code-block:: jlcon

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

   .. code-block:: jlcon

      >>> department.employee.name

   .. code-block:: jlcon

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

   .. code-block:: jlcon

      >>> employee.name

   .. code-block:: jlcon

      "ELVIA A"
      "JEFFERY A"
      "KARINA A"
      "KIMBERLEI A"
      ⋮
      "DARIUSZ Z"

   Compare this with the output of:

   .. code-block:: jlcon

      >>> department.employee.name

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

   .. code-block:: jlcon

      >>> employee.department.name

   .. code-block:: jlcon

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

   .. code-block:: jlcon

      >>> employee.position

   .. code-block:: jlcon

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

   .. code-block:: jlcon

      >>> employee

   .. code-block:: jlcon

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

   .. math:: \operatorname{length} : \operatorname{Seq}\{T\} \to \operatorname{Int}

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

   .. code-block:: jlcon

      >>> count(department)

   .. code-block:: jlcon

      35


