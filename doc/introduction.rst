Introduction
============

.. slide:: Functional Data Model
   :level: 2

    Uses *sets* & set *functions*.

    * **Sets** model classes of entities.

    * **Functions** model entity attributes and relationships.

    Example: departments & employees of the city of Chicago
    (`source`_).

    .. graphviz:: citydb-functional-data-model.dot

Our subjects are logical models of data and syntax and semantics of query
languages.  *A data model* defines terms and concepts for describing business
entities, their attributes and relationships with each other.  In other words,
a data model is a toolset for building *database schemas*.

This work explores *functional data model*, which structures data in terms of
sets and set functions.  Classes of entities are modeled as sets.  Attributes
of entities and relationships between entities are modeled as functions on
sets.

.. admonition:: Example
   :class: note

    Our running example is based on the dataset of employees of the City of
    Chicago (source_).  In functional data model, it can be modeled as follows:

    .. graphviz:: citydb-functional-data-model.dot

    :math:`\operatorname{Dept}` is a set of all departments,
    :math:`\operatorname{Empl}` is a set of all employees.  Function
    :math:`\operatorname{name}:\operatorname{Dept}\to\operatorname{Text}` maps
    department entities to their names,
    :math:`\operatorname{salary}:\operatorname{Empl}\to\operatorname{Int}` sets
    employee's annual salary,
    :math:`\operatorname{department}:\operatorname{Empl}\to\operatorname{Dept}`
    assigns each employee to their department, and so on.

.. _source: https://data.cityofchicago.org/Administration-Finance/Current-Employee-Names-Salaries-and-Position-Title/xzkq-xp2w

The diagram above resembles an entity-relationship diagram and, in fact, any
ERD can be rewritten in terms of sets and functions.  An entity node turns into
a set of homogeneous entities.  An entity attribute becomes a function defined
on an entity set that maps each entity to the attribute value.  A relationship
between two entities can be expressed as a function mapping one type of
entitites to the other.  As long as we can identify classes of entities with a
static set of attributes and relationships, we can use functional data model to
structure the data.

.. slide:: Schema and Instance
   :level: 2

    .. math::

        \begin{matrix}
            \begin{matrix}
                \text{Schema} \\
                \small (\operatorname{Dept}, \operatorname{Empl},\, \ldots)
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Instance} \\
                \small (\langle \texttt{"Rahm Emanuel"}, \texttt{"Mayor"} \rangle,\, \ldots)
            \end{matrix} \\
            & & \\
            \begin{matrix}
                \text{Type} \\
                \small (\operatorname{Int})
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Value} \\
                \small (42\in\operatorname{Int})
            \end{matrix}
        \end{matrix}

    *Database schema* is like a data type.

    *Database instance* is like a value of the data type.

While a database schema establishes how the data is organized, a database
*instance* is the actual data that may be stored in the database at some
particular moment.  Any instance must obey the structure imposed by the schema.

In our example, the schema defines types of entities (*Departments*,
*Employees*), their attributes (*name*, *position*, *salary*) and relationships
(*an employee works in a department*).  A specific instance enumerates concrete
entities (*Police Department*, *Fire Department*, etc) and assigns attribute
values (*position* of *Rahm Emanuel* is *Mayor*).

.. math::

    \begin{matrix}
        \begin{matrix}
            \text{Schema} \\
            \small (\operatorname{Dept}, \operatorname{Empl},\, \ldots)
        \end{matrix} &
        \Rightarrow &
        \begin{matrix}
            \text{Instance} \\
            \small (\langle \texttt{"Rahm Emanuel"}, \texttt{"Mayor"} \rangle,\, \ldots)
        \end{matrix} \\
        & & \\
        \begin{matrix}
            \text{Type} \\
            \small (\operatorname{Int})
        \end{matrix} &
        \Rightarrow &
        \begin{matrix}
            \text{Value} \\
            \small (42\in\operatorname{Int})
        \end{matrix}
    \end{matrix}

The concepts of schema and instance is similar to the notions of a data type
and a value of the type.  Indeed, we can think of a data type as a trivial
database schema.  Then any value of this type becomes a database instance, a
variable becomes a database storage.  One may wonder what becomes a "database
query".

.. slide:: Asking Questions
   :level: 2

    Given a database, we may like to know:

    * *The number of departments in the city of Chicago.*
    * *The number of employees in each department.*
    * *The top salary among all the employees.*
    * *... and for each department.*
    * *The mean salary by position.*
    * *and much more...*

    Raw dataset does not contain immediate answers to these questions.

    Has enough information to infer the answers from the data.

    Need to traverse, transform, filter, summarize the data.

    How to ask questions about the data?

.. slide:: Query Syntax and Semantics
   :level: 2

    .. math::

        \begin{matrix}
            \begin{matrix}
                \text{Schema} \\
                \small (\operatorname{Dept}, \operatorname{Empl},\, \ldots)
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Instance} \\
                \small (\langle \texttt{"Rahm Emanuel"}, \texttt{"Mayor"} \rangle,\, \ldots)
            \end{matrix} \\
            & & \\
            \Downarrow & & \Downarrow \\
            & & \\
            \begin{matrix}
                \text{Query} \\
                \small (\operatorname{count}(\operatorname{employee}))
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Fact} \\
                \small (32181)
            \end{matrix}
        \end{matrix}

    **Query syntax:** How to form a question?

    **Query semantics:** How to interpret a question against some instance?

.. slide:: Query Syntax and Semantics: Trivial Database
   :level: 3

    .. math::

        \begin{matrix}
            \begin{matrix}
                \text{Type} \\
                \small (\operatorname{Int})
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Value} \\
                \small (42\in\operatorname{Int})
            \end{matrix} \\
            & & \\
            \Downarrow & & \Downarrow \\
            & & \\
            \begin{matrix}
                \text{Property} \\
                \small (\operatorname{odd}: \operatorname{Int}\to\operatorname{Bool})
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Property Value} \\
                \small (\operatorname{odd}: 42\mapsto\operatorname{false})
            \end{matrix}
        \end{matrix}

    .. math::

        \operatorname{odd}(x) := x \bmod 2 = 1

    Math notation is the query syntax.  Algebra is the query semantics.

.. slide:: The Objective
   :level: 2

    *Design syntax and semantics of a query language for functional data
    model.*

    For relational model: *SQL* and *relational algebra*.

    * Elementary unit: *tuple set*.
    * Elementary operation: *set product*.

    For functional model: **Rabbit**.

    * Elementary unit: *function*.
    * Elementary operation: *composition of functions*.

    We claim **Rabbit** is:

    * As powerful as SQL.
    * Easier to write and comprehend than SQL.
    * Has no gaps between syntax and semantics (is SQL relational?)

