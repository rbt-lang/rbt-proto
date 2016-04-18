Unfolding a Schema
==================


.. slide:: Querying Non-Hierarchical Databases
   :level: 2

   Our progress so far:

   * We consider hierarchical databases, with data organized in a tree
     structure.

   * Then *a query* maps one tree structure to another.

   * *Combinators* provide a declarative way to compose complex queries.

   * Powerful and easy to use, when it works.

   Example:

   .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls =
            Departments >> Select(
                "name" => Name,
                "N100k" => Count(Employees >> Sieve(Salary > 100000)))


.. slide:: Querying Non-Hierarchical Databases: Idea
   :level: 3

   However, query combinators have major limitations:

   * Input data must be hierarchical.

   * Structure of the query must respect structure of the data.

   Can we generalize query combinators to non-hierarchical databases?

   Wrong question!  Instead, let us ask:

   *Can we make any database hierarchical?*

   Then use combinators to query it.


.. slide:: Categorical Data Model
   :level: 2

   Recall *categorical data model:*

   * Objects: entity types and value types.
   * Arrows: attributes and relationships.

   Example (textbook "employees & departments" schema):

   .. graphviz:: citydb-functional-data-model.dot


.. slide:: Categorical Data Model: Composing Arrows
   :level: 3

   Arrows with compatible input and output can be composed.

   For example, take:

   .. math::

      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   Composing them, we get:

   .. math::

      \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text}

   This is a query that maps an employee entity to the name of their
   department.


.. slide:: Categorical Data Model: Limitations
   :level: 3

   Categorical data model is simple and straightforward.  It is also
   inadequate:

   Not every relationship can be represented as an arrow between entity types.

   Consider:

   * Relationship that associates every department to the set of the respective
     employees.

   * Relationship that associates every employee to their manager.

   * Collection of all departments/all employees.


.. slide:: Plural Relationships
   :level: 3

   Consider a relationship: *Every employee is associated with their
   department.*

   It is represented by arrow:

   .. math::

      \operatorname{department} : \operatorname{Empl}\to\operatorname{Dept}

   But we could also *invert* this relationship:

   *A department is associated with the respective employees.*

   Is there an arrow representing it?  If so, what is its signature?  Perhaps:

   .. math::

      \operatorname{employee} : \operatorname{Dept}\to\operatorname{Empl}\;?

   No, because for a given department, there are multiple employees.

   This is called *a plural relationship*.


.. slide:: Plural Relationships: Schema Diagram
   :level: 3

   Can we extend the schema diagram with a plural relationship?

   *A department is associated with the respective employees.*

   .. graphviz:: citydb-with-plural-link.dot


.. slide:: Partial Relationships
   :level: 3

   Consider a relationship:

   *An employee is associated with their manager.*

   What is the signature if this relationship?

   .. math::

      \operatorname{managed\_by} : \operatorname{Empl}\to\operatorname{Empl}\;?

   But not every employee has a manager! (The CEO doesn't).

   This is called *a partial relationship*.

   Note: there is also an inverse relationship :math:`\operatorname{manages}`,
   which maps employees to their direct subordinates.  It is plural.


.. slide:: Partial Relationships: Schema Diagram
   :level: 3

   Can we extend the schema diagram with a partial relationship?

   *An employee is associated with their manager.*

   .. graphviz:: citydb-with-partial-link.dot


.. slide:: Class Relationships
   :level: 3

   Can we represent the set of all departments?  The set of all employees?

   On the schema graph, they are represented as *nodes:*

   .. math::

      \operatorname{Dept}, \quad
      \operatorname{Empl}

   Can we possibly represent entity sets as *arrows?*

   In other words, is there a relationship that describes all entities of a
   particular class?

   If so, what is its signature?

   .. math::

      &\operatorname{department} & : \;?&\to\operatorname{Dept}\;? \\
      &\operatorname{employee} & : \;?&\to\operatorname{Empl}\;?


.. slide:: Class Relationships: Schema Diagram
   :level: 3

   Can we extend the schema diagram with class relationships?

   *The set of all departments* and *the set of all employees.*

   .. graphviz:: citydb-with-class-links.dot


.. slide:: Expressing Plural and Partial Relationships
   :level: 2

   In the present form, categorical data model cannot express plural and
   partial relationships.

   But it seems easy to mend.  Introduce parametric types:

   * :math:`\operatorname{Seq}\{T\}` is a finite sequence of values of type
     :math:`T`.

   * :math:`\operatorname{Opt}\{T\}` is zero or one value of type :math:`T`.

   Then define:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\}

   Are we good now?


.. slide:: Expressing Plural and Partial Relationships: Composition
   :level: 3

   Unfortunately, we lost the ability to compose arrows.  Consider:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   Or:

   .. math::

      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}

   Inputs and outputs do not agree, so we cannot form compositions:

   .. math::

      \operatorname{employee}{.}\operatorname{name}, \quad
      \operatorname{managed\_by}{.}\operatorname{salary}.

   Can we give a meaning to these expressions?


.. slide:: Monadic Composition
   :level: 3

   How to compose two arrows that do not match perfectly?  *Monads* to the
   rescue!

   Monads extend the notion of composition.  Specifically:

   *If a parametric type* :math:`M\{T\}` *is a monad, then for any mappings:*

   .. math::

      f : A \to M\{B\}, \quad
      g : B \to M\{C\}

   *there is a monadic composition:*

   .. math::

      f{.}g : A \to M\{C\}.

   Both :math:`\operatorname{Opt}\{T\}` and :math:`\operatorname{Seq}\{T\}`
   are monads!


.. slide:: Monadic Composition: :math:`\operatorname{Opt}\{T\}`
   :level: 3

   Given:

   .. math::

      f : A \to \operatorname{Opt}\{B\}, \quad
      g : B \to \operatorname{Opt}\{C\}

   Define:

   .. math::

      f{.}g : A \to \operatorname{Opt}\{C\}

   This is just a composition of partial functions.

   .. math::

      f{.}g : x \longmapsto \begin{cases}
        \operatorname{null} & (\text{when } f(x)=\operatorname{null}) \\
        \operatorname{null} & (\text{when } f(x)\ne\operatorname{null},\, g(f(x))=\operatorname{null}) \\
        g(f(x)) & (\text{otherwise})
      \end{cases}


.. slide:: Monadic Composition: :math:`\operatorname{Seq}\{T\}`
   :level: 3

   Given:

   .. math::

      f : A \to \operatorname{Seq}\{B\}, \quad
      g : B \to \operatorname{Seq}\{C\}

   Define:

   .. math::

      f{.}g : A \to \operatorname{Seq}\{C\}

   Hint: use a function that *flattens* a nested list:

   .. math::

      \operatorname{flat} :
      \operatorname{Seq}\{\operatorname{Seq}\{C\}\} \to
      \operatorname{Seq}\{C\}

.. slide:: Monadic Composition: :math:`\operatorname{Seq}\{T\}`
   :level: 3

   Given :math:`x \in A`, how to evaluate :math:`f{.}g(x) \in \operatorname{Seq}\{C\}`?

   First, evaluate :math:`f` on the input :math:`x`:

   .. math::

      x \overset{f}{\longmapsto} [y_1, y_2, \ldots]

   Then apply :math:`g` to every element of :math:`[y_1,y_2,\ldots]`:

   .. math::

      [y_1, y_2, \ldots]
      \overset{\operatorname{Seq}\{g\}}{\longmapsto}
      [[z_{11}, z_{12}, \ldots], [z_{21}, z_{22}, \ldots], \ldots]

   Finally, erase nested brackets:

   .. math::

      [[z_{11}, z_{12}, \ldots], [z_{21}, z_{22}, \ldots], \ldots]
      \overset{\operatorname{flat}}{\longmapsto}
      [z_{11}, z_{12}, \ldots, z_{21}, z_{22}, \ldots]

   This is the value of :math:`f{.}g(x)`.


.. slide:: Composition: Embedding Rules
   :level: 3

   Monadic composition is not enough:  How to compose arrows of different
   kinds?

   For example:

   .. math::

      f : A \to \operatorname{Opt}\{B\}, \quad
      g : B \to \operatorname{Seq}\{C\}.

   We need one more composition rule.  Consider:

   * :math:`T` contains exactly one value.
   * :math:`\operatorname{Opt}\{T\}` contains zero or one value.
   * :math:`\operatorname{Seq}\{T\}` contains zero, one or more values.

   This gives us *natural embeddings:*

   .. math::

      T \hookrightarrow \operatorname{Opt}\{T\} \hookrightarrow \operatorname{Seq}\{T\}


.. slide:: Composition: Embedding Rules
   :level: 3

   Define :math:`T\hookrightarrow\operatorname{Opt}\{T\}` by:

   .. math::

      x \longmapsto x

   Define :math:`T\hookrightarrow\operatorname{Seq}\{T\}` by:

   .. math::

      x \longmapsto [x]

   Define :math:`\operatorname{Opt}\{T\}\hookrightarrow\operatorname{Seq}\{T\}`
   by:

   .. math::
      x \longmapsto \begin{cases}
      [] & (\text{when }x=\operatorname{null}) \\
      [x] & (\text{when }x\ne\operatorname{null})
      \end{cases}


.. slide:: Composition: Conclusion
   :level: 3

   Monadic composition and embedding rules let us compose any arrows that have
   the same base intermediate type.

   For example, consider:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   First, lift the output of :math:`\operatorname{name}` to
   :math:`\operatorname{Seq}\{\operatorname{Text}\}`:

   .. math::

      \operatorname{Empl}\overset{\operatorname{name}}{\longrightarrow}\operatorname{Text}
      \hookrightarrow\operatorname{Seq}\{\operatorname{Text}\}

   Then, use monadic composition for :math:`\operatorname{Seq}\{T\}`.  We get:

   .. math::

      \operatorname{employee}{.}\operatorname{name} :
      \operatorname{Dept} \to \operatorname{Seq}\{\operatorname{Text}\}


.. slide:: Expressing Class Relationships
   :level: 2

   Database schema represents entity classes as *objects:*

   .. math::

      \operatorname{Dept}, \quad \operatorname{Empl}

   Can we also represent them as *arrows?*

   * What would be the signature of a class arrow?

   * Conveniently, we just defined type :math:`\operatorname{Seq}\{T\}`.

   * We can guess *the output:* a sequence of entities of a particular class.

   * But what is *the input?*

   .. math::

      &\operatorname{department} & : (?)&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : (?)&\to\operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: Class Relationships: Singleton Type
   :level: 3

   Let us introduce *a singleton type* (type with a single value):

   .. math::

      \operatorname{Void} \quad (\operatorname{nothing}\in\operatorname{Void})

   Singleton type serves as input for class arrows:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}

   A class arrow maps value :math:`\operatorname{nothing}` to a sequence of all
   class entities.

   .. math::

      &\operatorname{department} & : \operatorname{nothing}
      &\longmapsto [\textit{all department entities}\ldots] \\
      &\operatorname{employee} & : \operatorname{nothing}
      &\longmapsto [\textit{all employee entities}\ldots]

   * We got each entity class represented as an arrow.

   * Now they can be *composed* with other arrows!


.. slide:: Unfolding a Database Schema
   :level: 2

   The problem: *Can we make any database hierarchical?*  We can now solve it:

   1. Draw the schema graph (omitted some arrows to reduce clutter).

   .. graphviz:: citydb-unfolding-step-1.dot


.. slide:: Unfolding a Database Schema: Step 2
   :level: 3

   The problem: *Can we make any database hierarchical?*

   2. Add all inverse arrows and class arrows.

   .. graphviz:: citydb-unfolding-step-2.dot


.. slide:: Unfolding a Database Schema: Step 3
   :level: 3

   The problem: *Can we make any database hierarchical?*

   3. Start at the :math:`\operatorname{Void}` node.  Convert each outgoing
      arrow to an adjacent node.

   .. graphviz:: citydb-unfolding-step-3.dot


.. slide:: Unfolding a Database Schema: Step 4
   :level: 3

   The problem: *Can we make any database hierarchical?*

   4. Continue converting outgoing arrows to nodes indefinitely.

   .. graphviz:: citydb-unfolding-step-4.dot


.. slide:: Unfolding a Database Schema: Conclusion
   :level: 3

   The problem: *Can we make any database hierarchical?*

   We presented the database schema in a form of an infinite hierarchy:

   .. graphviz:: citydb-unfolded-data-model.dot


