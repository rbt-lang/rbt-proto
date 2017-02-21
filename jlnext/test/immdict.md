Immutable dictionaries
======================

The package contains an implementation of an immutable dictionary based on
bitmap tries.

    using RBT:
        ImmutableDict,
        assoc

We can create a new empty dictionary.

    d0 = ImmutableDict{Symbol,Int}()
    #-> RBT.ImmutableDict{Symbol,Int64}()

We can also provide the initial content of the dictionary.

    d = ImmutableDict(:X=>1, :Y=>2, :Z=>3)
    #-> RBT.ImmutableDict(:X=>1,:Y=>2,:Z=>3)

Since the dictionary object is immutable, adding a value to the dictionary
returns a new dictionary object.

    d1 = assoc(d0, :X, 1)
    #-> RBT.ImmutableDict(:X=>1)

    d0
    #-> RBT.ImmutableDict{Symbol,Int64}()

We can read the value for the given key.

    d1[:X]
    #-> 1

If the key does not exist, an error is raised.

    d0[:X]
    #-> KeyError: key :X not found

It is possible to guard against missing keys.

    get(d1, :X)
    #-> Nullable{Int64}(1)

    get(d0, :X)
    #-> Nullable{Int64}()

Alternatively, we can provide the default value for a missing key.

    get(d1, :X, 0)
    #-> 1

    get(d0, :X, 0)
    #-> 0

We can add more keys or replace the value for an existing key.

    d2 = assoc(d1, :Y, 2)
    #-> RBT.ImmutableDict(:X=>1,:Y=>2)

    d3 = assoc(d2, :Z, 3)
    #-> RBT.ImmutableDict(:X=>1,:Y=>2,:Z=>3)

    d3′ = assoc(d3, :X, 4)
    #-> RBT.ImmutableDict(:X=>4,:Y=>2,:Z=>3)

Currently it is impossible to remove a key from the dictionary.

