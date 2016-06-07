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


