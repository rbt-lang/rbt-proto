Quotients
=========


.. slide:: Mapping a Query onto the Schema
   :level: 2

   So far, we only considered queries that can be mapped to the schema
   structure.

   .. graphviz:: citydb-unfolded-data-model.dot

   Example: *For each department, show its name and a list of employees.*

   How does it map to the schema?


.. slide:: Mapping a Query onto the Schema: Example
   :level: 3

   *For each department, show its name and a list of employees.*

   .. graphviz:: citydb-unfolded-department-name-employee-name.dot

   We can easily write this query by enumerating nodes in the selected subtree:

   .. math::

      \operatorname{department}
      {:}\operatorname{select}(\operatorname{name},\operatorname{employee}{.}\operatorname{name})


.. slide:: Mapping a Query onto the Schema: Two Queries
   :level: 3

   *For each department, show its name and a list of employees.*

   .. code-block:: julia

      department
      :select(
          name,
          employee.name)


   .. code-block:: julia

      ("WATER MGMNT",["ELVIA A","VICENTE A",…])
      ("POLICE",["JEFFERY A","KARINA A",…])
      ⋮
      ("LICENSE APPL COMM",["MICHELLE G"])

   Is it always that easy?  Consider a different query:

   *For each position, show a list of respective employees.*


.. slide:: Mapping a Query onto the Schema: a Problem
   :level: 3

   *For each position, show a list of respective employees.*

   We will have a hard time trying to map this query to a subtree of the
   schema.

   .. graphviz:: citydb-unfolded-position-employee-name.dot


.. slide:: Mapping a Query onto the Schema: Solution?
   :level: 3

   *For each position, show a list of respective employees.*

   If only we could transform the schema to place
   :math:`\operatorname{position}` on top?

   .. graphviz:: citydb-unfolded-employee-group-position.dot

   In this section, we learn how to adapt the database structure for a given
   query.


.. slide:: Unique Values
   :level: 2

   We start with a simple query:

   *Show a list of all positions.*

   We can get a list of positions of all employees:

   .. code-block:: julia

      employee.position

   .. code-block:: julia

      "WATER RATE TAKER"
      "POLICE OFFICER"
      "POLICE OFFICER"
      "CHIEF CONTRACT EXPEDITER"
      ⋮
      "CHIEF DATA BASE ANALYST"

   The problem is: this list contains duplicate values.

   Can we make a list of all *distinct* employee positions?


.. slide:: The :math:`\operatorname{unique}` Combinator
   :level: 3

   *Show a list of all positions.*

   We start with a list of positions for all employees:

   .. math::

      \operatorname{employee}{.}\operatorname{position}

   To filter out duplicates, we use the :math:`\operatorname{unique}`
   combinator:

   .. math::

      \operatorname{unique}(\operatorname{employee}{.}\operatorname{position})

   This gives us a list of all distinct positions.


.. slide:: The :math:`\operatorname{unique}` Combinator: Output
   :level: 3

   *Show a list of all positions.*

   .. code-block:: julia

      unique(employee.position)

   .. code-block:: julia

      "1ST DEPUTY INSPECTOR GENERAL"
      "A/MGR COM SVC-ELECTIONS"
      "A/MGR OF MIS-ELECTIONS"
      "A/MGR WAREHOUSE-ELECTIONS"
      ⋮
      "ZONING PLAN EXAMINER"


.. slide:: The :math:`\operatorname{unique}` Combinator: Signature
   :level: 3

   *Show a list of all positions.*

   The :math:`\operatorname{unique}` combinator preserves the shape of the
   query:

   .. math::

      & \operatorname{employee}{.}\operatorname{position} &:
      \operatorname{Void} &\to \operatorname{Seq}\{\operatorname{Text}\} \\
      & \operatorname{unique}(\operatorname{employee}{.}\operatorname{position}) &:
      \operatorname{Void} &\to \operatorname{Seq}\{\operatorname{Text}\} \\

   Hence, in general, its signature is:

   .. math::

      \operatorname{unique} : (A\to\operatorname{Seq}\{B\})\to(A\to\operatorname{Seq}\{B\})


.. slide:: The :math:`\operatorname{unique}` Combinator: Example
   :level: 3

   The :math:`\operatorname{unique}` combinator can be a part of a complex
   query.

   *For each department, show the number of employees and the number of positions.*

   .. code-block:: julia

      department
      :select(
          name,
          count(employee),
          count(unique(employee.position)))

   .. code-block:: julia

      ("WATER MGMNT",1848,154)
      ("POLICE",13570,129)
      ⋮
      ("LICENSE APPL COMM",1,1)


