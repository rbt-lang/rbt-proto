Querying with Combinators
=========================


.. slide:: What is Rabbit?
   :level: 2

   Rabbit is *a database query language.*

   Based on:

   * Combinators.
   * Categorical data model.
   * Monadic composition.

   We provide:

   * Formal query model (query combinators).
   * Working prototype (in Julia).

   *There is an increasing need to bring the non-professional user into
   effective communication with a formatted data base.*  Chamberlin, D;
   Boyce, R (1974).

   The challenge: give the specialists direct access to the data.


.. slide:: Table of Contents
   :level: 2

   * :doc:`introduction`
   * :doc:`hierarchical-data`
   * *Infinite Hierarchy and Monadic Structures*
   * *Query Syntax*
   * *Aggregates*
   * *Quotients*
   * *Transitive Closure*
   * *Sorting*
   * *Running Aggregates and Comonads*
   * *Prototype Implementation*


Rabbit is a combinator-based query language for categorical databases. It
proposes a formal query model using query combinators and has a working
prototype implemented in Julia. It shows how complex business inquiries can be
incrementally translated into auditable and succinct federated queries.

SEQUEL was an early attempt to address an "increasing need to bring the
non-professional user into effective communication with a formatted database"
(Chamberlin, D; Boyce, R, 1974).  We think Rabbit is a notable milestone in
this challenge.


.. toctree::
   :maxdepth: 2

   introduction
   hierarchical-data


