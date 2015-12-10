#
# Immutable dictionary implemented as a bitmap trie.
#


#
# Trie nodes.
#

abstract ImmDictNode{K,V}

immutable ValueNode{K,V} <: ImmDictNode{K,V}
    key::K
    val::V
    key_hc::UInt
end

immutable CollisionNode{K,V} <: ImmDictNode{K,V}
    keys::Vector{K}
    vals::Vector{V}
    key_hc::UInt
end

immutable BitmapNode{K,V} <: ImmDictNode{K,V}
    branches::Vector{ImmDictNode{K,V}}
    bitmap::UInt32

    BitmapNode(branches, bitmap) = new(branches, bitmap)
    BitmapNode() = new(ImmDictNode{K,V}[], 0x00000000)
end


#
# Lookup in trie nodes.
#

find{K,V}(node::ValueNode{K,V}, key, key_hc, shift) =
    key_hc == node.key_hc && isequal(key, node.key) ?
        Nullable{V}(node.val) : Nullable{V}()

find{K,V}(node::CollisionNode{K,V}, key, key_hc, shift) =
    begin
        if key_hc == node.key_hc
            for j = eachindex(node.keys)
                if isequal(key, node.keys[j])
                    return Nullable{V}(node.vals[j])
                end
            end
        end
        return Nullable{V}()
    end

mask(hc::UInt, shift::Int) = (hc >>> shift) & 0b11111
bitpos(mask::UInt) = 0x00000001 << mask

find{K,V}(node::BitmapNode{K,V}, key, key_hc, shift) =
    begin
        pos = bitpos(mask(key_hc, shift))
        if (node.bitmap & pos) != 0
            j = 1 + count_ones(node.bitmap & (pos-1))
            return find(node.branches[j], key, key_hc, shift+5)::Nullable{V}
        end
        return Nullable{V}()
    end


#
# Iteration.
#

start{K,V}(node::ValueNode{K,V}) = true
next{K,V}(node::ValueNode{K,V}, flag) = (Pair{K,V}(node.key, node.val), false)
done{K,V}(node::ValueNode{K,V}, flag) = !flag

start{K,V}(node::CollisionNode{K,V}) = 1
next{K,V}(node::CollisionNode{K,V}, k) =
    (Pair{K,V}(node.keys[k], node.vals[k]), k+1)
done{K,V}(node::CollisionNode{K,V}, k) = k > length(node.keys)

start{K,V}(node::BitmapNode{K,V}) = 
    begin
        for j = eachindex(node.branches)
            b = node.branches[j]
            bst = start(b)
            if !done(b, bst)
                return (j, bst)
            end
        end
        return ()
    end
next{K,V}(node::BitmapNode{K,V}, state) =
    begin
        j, bst = state
        b = node.branches[j]
        pair, bst = next(b, bst)
        if !done(b, bst)
            return (pair, (j, bst))
        end
        while j < length(node.branches)
            j += 1
            b = node.branches[j]
            bst = start(b)
            if !done(b, bst)
                return (pair, (j, bst))
            end
        end
        return (pair, ())
    end
done{K,V}(node::BitmapNode{K,V}, state) = state == ()


#
# Adding an element.
#

type PutResult{V}
    old::Nullable{V}
    changed::Bool

    PutResult() = new(Nullable{V}(), false)
end

put{K,V}(node::ValueNode{K,V}, key, val, key_hc, shift, result) =
    begin
        if key_hc == node.key_hc
            if isequal(key, node.key)
                if isequal(val, node.val)
                    return node
                else
                    result.old = Nullable{V}(node.val)
                    result.changed = true
                    return ValueNode{K,V}(key, val, key_hc)
                end
            else
                result.changed = true
                return CollisionNode{K,V}(K[node.key, key], [node.val, val], key_hc)
            end
        else
            branches = ImmDictNode{K,V}[node]
            bitmap = bitpos(mask(node.key_hc, shift))
            return put(BitmapNode{K,V}(branches, bitmap), key, val, key_hc, shift, result)
        end
    end

put{K,V}(node::CollisionNode{K,V}, key, val, key_hc, shift, result) =
    begin
        if key_hc == node.key_hc
            N = length(node.keys)
            for j = 1:N
                if isequal(key, node.keys[j])
                    if isequal(val, node.vals[j])
                        return node
                    else
                        result.old = Nullable{V}(node.vals[j])
                        result.changed = true
                        vals = copy(node.vals)
                        vals[j] = val
                        return CollisionNode{K,V}(node.keys, vals, node.key_hc)
                    end
                end
            end
            result.changed = true
            keys = Vector{K}(N+1)
            vals = Vector{K}(N+1)
            for j = 1:N
                keys[j] = node.keys[j]
                vals[j] = node.vals[j]
            end
            keys[N+1] = key
            vals[N+1] = val
            return CollisionNode{K,V}(keys, vals, node.key_hc)
        else
            nodes = ImmDictNode{K,V}[node]
            bitmap = bitpos(mask(node.key_hc, shift))
            return put(BitmapNode{K,V}(branches, bitmap), key, val, key_hc, shift, result)
        end
    end

put{K,V}(node::BitmapNode{K,V}, key, val, key_hc, shift, result) =
    begin
        pos = bitpos(mask(key_hc, shift))
        j = 1 + count_ones(node.bitmap & (pos-1))
        if (node.bitmap & pos) != 0
            j = 1 + count_ones(node.bitmap & (pos-1))
            branch = put(node.branches[j], key, val, key_hc, shift+5, result)
            if result.changed
                branches = copy(node.branches)
                branches[j] = branch
                return BitmapNode{K,V}(branches, node.bitmap)
            else
                return node
            end
        end
        result.changed = true
        branch = ValueNode{K,V}(key, val, key_hc)
        N = length(node.branches)
        branches = Vector{ImmDictNode{K,V}}(N+1)
        for k = 1:j-1
            branches[k] = node.branches[k]
        end
        branches[j] = branch
        for k = j:N
            branches[k+1] = node.branches[k]
        end
        bitmap = node.bitmap | pos
        return BitmapNode{K,V}(branches, bitmap)
    end


#
# Immutable dictionary.
#

immutable ImmutableDict{K,V} <: Associative{K,V}
    root::ImmDictNode{K,V}
    sz::Int
    hc::UInt

    ImmutableDict() = new(BitmapNode{K,V}(), 0, 0)
    ImmutableDict(root::ImmDictNode{K,V}, sz::Int, hc::UInt) = new(root, sz, hc)
end

length(idict::ImmutableDict) = idict.sz
isempty(idict::ImmutableDict) = idict.sz == 0

start(idict::ImmutableDict) = start(idict.root)
next(idict::ImmutableDict, state) = next(idict.root, state)
done(idict::ImmutableDict, state) = done(idict.root, state)

get{K,V}(idict::ImmutableDict{K,V}, key) =
    find(idict.root, key, hash(key), 0)::Nullable{V}

get{K,V}(idict::ImmutableDict{K,V}, key, default) =
    let maybe_val = get(idict, val)
        isnull(maybe_val) ? default : get(maybe_val)
    end

getindex{K,V}(idict::ImmutableDict{K,V}, key) =
    let maybe_val = get(idict, key)
        isnull(maybe_val) ? throw(KeyError(key)) : get(maybe_val)
    end

assoc{K,V}(idict::ImmutableDict{K,V}, key, val) =
    begin
        result = PutResult{V}()
        new_root = put(idict.root, key, val, hash(key), 0, result)
        if result.changed
            entry_hc = hash(key, hash(val))
            if !isnull(result.old)
                old_entry_hc = hash(key, hash(get(result.old)))
                hc = idict.hc $ entry_hc $ old_entry_hc
                return ImmutableDict{K,V}(new_root, idict.sz, hc)
            else
                sz = idict.sz + 1
                hc = idict.hc $ entry_hc
                return ImmutableDict{K,V}(new_root, sz, hc)
            end
        end
        return idict
    end

