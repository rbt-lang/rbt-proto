
push!(LOAD_PATH, "./jl")

using Base.Test
using RBT: Iso, Opt, Seq, Rel, Env, EnvRel, Unit, Zero
using DataFrames

int_here = RBT.HerePipe(Int)
println(repr(int_here))

@test int_here(5) == 5
@test_throws Exception int_here("hi there")

any_here = RBT.HerePipe(Any)
println(repr(any_here))

@test any_here(5) == 5
@test any_here("hi there") == "hi there"

unit_here = RBT.HerePipe(Unit)
println(repr(unit_here))

@test unit_here() == nothing

int_unit = RBT.UnitPipe(Int)
println(repr(int_unit))

@test int_unit(5) == nothing
@test_throws Exception int_unit(nothing)

unit_unit = RBT.UnitPipe(Unit)
println(repr(unit_unit))

@test unit_unit() == nothing
@test_throws Exception unit_unit(5)

zero_unit = RBT.UnitPipe(Zero)
println(repr(zero_unit))

@test_throws Exception zero_unit()

unit_zero = RBT.ZeroPipe(Unit)
println(repr(unit_zero))

@test_throws Exception unit_zero()

const5 = RBT.ConstPipe(5)
println(repr(const5))

@test const5() == 5
@test const5(nothing) == 5
@test_throws Exception const5(5)

null = RBT.NullPipe()
println(repr(null))

@test isequal(null(), Nullable())
@test_throws Exception null(5)

empty = RBT.EmptyPipe()
println(repr(empty))

@test empty() == Union{}[]
@test_throws Exception empty(5)

primes = RBT.SetPipe(:primes, Int[2,3,5,7,11], ismonic=true)
println(repr(primes))

@test primes() == Int[2,3,5,7,11]

sqmap = RBT.IsoMapPipe(:sq, Dict(1=>1,2=>4,3=>9,4=>16,5=>25,6=>36,7=>49,8=>64,9=>81,10=>100,11=>121), true, false)
println(repr(sqmap))

@test sqmap(5) == 25

decmap = RBT.OptMapPipe(:dec, Dict(2=>1,3=>2,4=>3,5=>4,6=>5,7=>6,8=>7,9=>8), true, false)
println(repr(decmap))

@test isequal(decmap(5), Nullable(4))
@test isequal(decmap(1), Nullable{Int}())

divmap = RBT.SeqMapPipe(:div, Dict(4=>[2],6=>[2,3],8=>[2,4],9=>[3],10=>[2,5]), false, false, false)
println(repr(divmap))

@test divmap(6) == Int[2,3]
@test divmap(3) == Int[]

println(repr(primes >> sqmap))
println(repr(primes >> decmap))
println(repr(primes >> divmap))

@test (primes >> sqmap)() == [4,9,25,49,121]
@test (primes >> decmap)() == [1,2,4,6]
@test (primes >> divmap)() == []
@test (divmap >> decmap)(6) == [1,2]
@test isequal((decmap >> decmap >> decmap)(4), Nullable(1))

tuple0 = RBT.TuplePipe()
println(repr(tuple0))

@test tuple0() == ()
@test tuple0(5) == ()

tuple3a = RBT.TuplePipe(sqmap, decmap, divmap)
println(repr(tuple3a))

@test isequal(tuple3a(6), (36, Nullable(5), [2,3]))
@test isequal(tuple3a(11), (121, Nullable{Int}(), Int[]))

tuple3a_items = RBT.TuplePipe(RBT.ItemPipe(tuple3a, 3), RBT.ItemPipe(tuple3a, 2), RBT.ItemPipe(tuple3a, 1))
println(repr(tuple3a_items))

@test isequal((tuple3a >> tuple3a_items)(6), ([2,3], Nullable(5), 36))
@test isequal((tuple3a >> tuple3a_items)(11), (Int[], Nullable{Int}(), 121))

tuple3b = RBT.TuplePipe(int_here, sqmap, decmap >> divmap)
println(repr(tuple3b))

@test tuple3b(7) == (7, 49, [2,3])

vector0 = RBT.VectorPipe()
println(repr(vector0))

@test vector0() == []

vector1a = RBT.VectorPipe(sqmap)
println(repr(vector1a))

@test vector1a(6) == [36]

vector1b = RBT.VectorPipe(decmap)
println(repr(vector1b))

@test vector1b(6) == [5]
@test vector1b(1) == []

vector1c = RBT.VectorPipe(divmap)
println(repr(vector1c))

@test vector1c === divmap
@test vector1c(6) == [2,3]
@test vector1c(1) == []

vector4 = RBT.VectorPipe(int_here, sqmap, decmap, divmap)
println(repr(vector4))

@test vector4(6) == [6,36,5,2,3]
@test vector4(1) == [1,1]

@test (primes >> vector4)() == [2,4,1,3,9,2,5,25,4,7,49,6,11,121]

@test RBT.IsoPipe(sqmap) === sqmap

decmap_as_iso = RBT.IsoPipe(decmap)
println(repr(decmap_as_iso))

@test decmap_as_iso(5) == 4
@test_throws Exception decmap_as_iso(1)

divmap_as_iso = RBT.IsoPipe(divmap)
println(repr(divmap_as_iso))

@test divmap_as_iso(4) == 2
@test_throws Exception divmap_as_iso(1)
@test_throws Exception divmap_as_iso(6)

@test RBT.OptPipe(decmap) === decmap

sqmap_as_opt = RBT.OptPipe(sqmap)
println(repr(sqmap_as_opt))

@test isequal(sqmap_as_opt(5), Nullable(25))

divmap_as_opt = RBT.OptPipe(divmap)
println(repr(divmap_as_opt))

@test isequal(divmap_as_opt(4), Nullable(2))
@test isequal(divmap_as_opt(1), Nullable{Int}())
@test_throws Exception divmap_as_opt(6)

@test RBT.SeqPipe(divmap) === divmap

sqmap_as_seq = RBT.SeqPipe(sqmap)
println(repr(sqmap_as_seq))

@test sqmap_as_seq(5) == [25]

decmap_as_seq = RBT.SeqPipe(decmap)
println(repr(decmap_as_seq))

@test decmap_as_seq(5) == [4]
@test decmap_as_seq(1) == Int[]

id_eq_sq = int_here .== sqmap
println(repr(id_eq_sq))

@test id_eq_sq(1) == true
@test id_eq_sq(5) == false

dec_dec_sq_ne_id = (decmap >> decmap >> sqmap) .!= int_here
println(repr(dec_dec_sq_ne_id))

@test isequal(dec_dec_sq_ne_id(4), Nullable(false))
@test isequal(dec_dec_sq_ne_id(6), Nullable(true))
@test isequal(dec_dec_sq_ne_id(2), Nullable{Bool}())

dec_dec_le_div = (decmap >> decmap) .<= divmap
println(repr(dec_dec_le_div))

@test dec_dec_le_div(4) == [true]
@test dec_dec_le_div(6) == [false, false]
@test dec_dec_le_div(10) == Bool[]

between_3_and_6 = (RBT.ConstPipe(Int, 3) .<= int_here) & (int_here .<= RBT.ConstPipe(Int, 6))
println(repr(between_3_and_6))

@test between_3_and_6(5) == true
@test between_3_and_6(1) == false

not_0_or_1 = ~((int_here .== RBT.ConstPipe(Int, 0)) | (int_here .== RBT.ConstPipe(Int, 1)))
println(repr(not_0_or_1))

@test not_0_or_1(1) == false
@test not_0_or_1(5) == true

any_div_between_3_and_6 = RBT.AnyPipe(divmap >> between_3_and_6)
println(repr(any_div_between_3_and_6))

@test any_div_between_3_and_6(1) == false
@test any_div_between_3_and_6(4) == false
@test any_div_between_3_and_6(6) == true
@test any_div_between_3_and_6(10) == true

all_div_between_3_and_6 = RBT.AllPipe(divmap >> between_3_and_6)
println(repr(all_div_between_3_and_6))

@test all_div_between_3_and_6(1) == true
@test all_div_between_3_and_6(4) == false
@test all_div_between_3_and_6(6) == false
@test all_div_between_3_and_6(9) == true

count_primes = RBT.CountPipe(primes)
println(repr(count_primes))

@test count_primes() == 5

max_prime = RBT.IntMaxPipe(primes)
println(repr(max_prime))

@test isequal(max_prime(), Nullable(11))

max_prime_or_0 = RBT.IntMaxPipe(RBT.VectorPipe(primes, RBT.ConstPipe(0)))
println(repr(max_prime_or_0))

@test max_prime_or_0() == 11

min_prime = RBT.IntMinPipe(primes)
println(repr(min_prime))

@test isequal(min_prime(), Nullable(2))

sum_primes = RBT.IntSumPipe(primes)
println(repr(sum_primes))

@test sum_primes() == 28

mean_prime = RBT.IntMeanPipe(primes)
println(repr(mean_prime))

@test isequal(mean_prime(), Nullable(28/5))

first_prime = RBT.FirstPipe(primes)
println(repr(first_prime))

@test isequal(first_prime(), Nullable(2))

last_prime = RBT.FirstPipe(primes, false)
println(repr(last_prime))

@test isequal(last_prime(), Nullable(11))

mixed = sqmap * decmap * divmap
println(repr(mixed))

@test mixed(6) == [(36,5,2), (36,5,3)]

range1 = RBT.RangePipe(RBT.ConstPipe(1), RBT.ConstPipe(10))
println(repr(range1))

@test range1() == [1,2,3,4,5,6,7,8,9,10]

range2 = RBT.RangePipe(RBT.ConstPipe(1), RBT.ConstPipe(2), RBT.ConstPipe(10))
println(repr(range2))

@test range2() == [1,3,5,7,9]

tagged = RBT.PackPipe(:sq => sqmap, :dec => decmap, :div => divmap)
println(repr(tagged))

@test tagged(6) == Pair{Symbol,Int}[:sq => 36, :dec => 5, :div => 2, :div => 3]

untagged = RBT.CasePipe(
    Int, false, :dec => int_here, :div => decmap)
println(repr(untagged))

@test (tagged >> untagged)(6) == [5,1,2]

primes_filter_select =
    RBT.SelectPipe(
        RBT.FilterPipe(
            primes,
            (int_here .>= RBT.ConstPipe(Int, 5)) & (int_here .<= RBT.ConstPipe(Int, 7))),
        int_here, decmap >> divmap)
println(repr(primes_filter_select))

@test primes_filter_select() == [((5, [2]), 5), ((7, [2,3]), 7)]

rev_primes = RBT.SortPipe(primes, true)
println(repr(rev_primes))

@test rev_primes() == [11,7,5,3,2]

primes_by_count_dec_div = RBT.SortByPipe(primes, RBT.CountPipe(decmap >> divmap))
println(repr(primes_by_count_dec_div))

@test primes_by_count_dec_div() == [2,3,11,5,7]

first_prime_by_count_dec_div = RBT.FirstByPipe(primes, RBT.CountPipe(decmap >> divmap), true)
println(repr(first_prime_by_count_dec_div))

@test isequal(first_prime_by_count_dec_div(), Nullable(7))

first_3_primes = RBT.TakePipe(primes, RBT.ConstPipe(3))
println(repr(first_3_primes))

@test first_3_primes() == [2,3,5]

last_2_primes = RBT.TakePipe(primes, RBT.ConstPipe(3), true)
println(repr(last_2_primes))

@test last_2_primes() == [7,11]

reversed_primes = RBT.ReversePipe(primes)
println(repr(reversed_primes))

@test reversed_primes() == [11,7,5,3,2]

get_prime_5 = RBT.GetPipe(primes, RBT.ConstPipe(5))
println(repr(get_prime_5))

@test isequal(get_prime_5(), Nullable(5))

divs = RBT.ConnectPipe(divmap)
println(repr(divs))

@test divs(8) == [2,4,2]

self_divs = RBT.ConnectPipe(divmap, true)
println(repr(self_divs))

@test self_divs(8) == [8,2,4,2]

depths = range1 >> RBT.DepthPipe(divmap)
@test depths() == [0,0,0,1,0,1,0,2,1,1]

range_sorted_by_div = RBT.SortConnectPipe(range1, divmap)
println(repr(range_sorted_by_div))

@test range_sorted_by_div() == [1,2,4,8,3,6,9,5,10,7]

unique_div = RBT.UniquePipe(range1 >> divmap, true)
println(repr(unique_div))

@test unique_div() == [5,4,3,2]

range1_by_count_div = RBT.GroupPipe(range1, RBT.CountPipe(divmap))
println(repr(range1_by_count_div))

@test range1_by_count_div() == [((0,),[1,2,3,5,7]), ((1,),[4,9]), ((2,),[6,8,10])]

range1_partition_by_count_div =
    RBT.PartitionPipe(
        range1,
        true,
        (RBT.RangePipe(RBT.ConstPipe(-1), RBT.ConstPipe(1)), RBT.CountPipe(divmap), true))
println(repr(range1_partition_by_count_div))

@test isequal(range1_partition_by_count_div(),
    [((Nullable(1),),[4,9]),
     ((Nullable(0),),[1,2,3,5,7]),
     ((Nullable(-1),),[]),
     ((Nullable{Int}(),),[1,2,3,4,5,7,9])])

dict4 = RBT.DictPipe(
    :here => int_here,
    :sq => sqmap,
    :dec => RBT.NullToVoidPipe(decmap),
    :div => divmap)
println(repr(dict4))

@test dict4(6) == Dict{Any,Any}(:here => 6, :sq => 36, :dec => 5, :div => [2,3])
@test dict4(1) == Dict{Any,Any}(:here => 1, :sq => 1, :dec => nothing, :div => [])

df =
    RBT.DataFramePipe(
        RBT.RangePipe(RBT.ConstPipe(1), RBT.ConstPipe(4)),
        :here => int_here, :dec => decmap, :div => divmap)
println(repr(df))

@test isequal(df(), DataFrame(Any[[1,2,3,4], @data([NA,1,2,3]), Vector{Int}[[],[],[],[2]]], [:here,:dec,:div]))

sqr = RBT.FilterPipe(range1, sqmap .== RBT.ParamPipe(Int, :X, Int))
println(repr(sqr))

@test sqr(X=36) == [6]

in_div = RBT.FilterPipe(range1, RBT.InPipe(RBT.ParamPipe(Int, :X, Int), divmap))
println(repr(in_div))

@test in_div(X=2) == [4,6,8,10]

top_div =
    RBT.FilterPipe(
        range1,
        RBT.CountPipe(divmap) .==
            RBT.IntMaxPipe(RBT.RelativePipe(Int, true, true, true) >> RBT.CountPipe(divmap)))
println(repr(top_div))

@test top_div() == [6,8,10]

max_by_div =
    RBT.FilterPipe(
        range1,
        int_here .> RBT.IntMaxPipe(RBT.RelativeByPipe(RBT.CountPipe(divmap), true, false, true)))
println(repr(max_by_div))

@test max_by_div() == [7,9,10]

