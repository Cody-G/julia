# This file is a part of Julia. License is MIT: http://julialang.org/license

# token type on which to dispatch testing methods in order to avoid potential
# name conflicts elsewhere in the base test suite
type TestAbstractArray end

## Tests for the abstract array interfaces with minimally defined array types

# A custom linear fast array type with 24 elements that doesn't rely upon Array storage
type T24Linear{T,N,dims} <: AbstractArray{T,N}
    v1::T;  v2::T;  v3::T;  v4::T;  v5::T;  v6::T;  v7::T;  v8::T
    v9::T;  v10::T; v11::T; v12::T; v13::T; v14::T; v15::T; v16::T
    v17::T; v18::T; v19::T; v20::T; v21::T; v22::T; v23::T; v24::T
    T24Linear() = (prod(dims) == 24 || throw(DimensionMismatch("T24Linear must have 24 elements")); new())
    function T24Linear(v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19,v20,v21,v22,v23,v24)
        prod(dims) == 24 || throw(DimensionMismatch("T24Linear must have 24 elements"))
        new(v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19,v20,v21,v22,v23,v24)
    end
end

T24Linear{T}(::Type{T}, dims::Int...) = T24Linear(T, dims)
T24Linear{T,N}(::Type{T}, dims::NTuple{N,Int}) = T24Linear{T,N,dims}()

Base.convert{T,N  }(::Type{T24Linear     }, X::AbstractArray{T,N}) = convert(T24Linear{T,N}, X)
Base.convert{T,N,_}(::Type{T24Linear{T  }}, X::AbstractArray{_,N}) = convert(T24Linear{T,N}, X)
Base.convert{T,N  }(::Type{T24Linear{T,N}}, X::AbstractArray     ) = T24Linear{T,N,size(X)}(X...)

Base.size{T,N,dims}(::T24Linear{T,N,dims}) = dims
import Base: LinearFast
Base.linearindexing{A<:T24Linear}(::Type{A}) = LinearFast()
Base.getindex(A::T24Linear, i::Int) = getfield(A, i)
Base.setindex!{T}(A::T24Linear{T}, v, i::Int) = setfield!(A, i, convert(T, v))

# A custom linear slow sparse-like array that relies upon Dict for its storage
immutable TSlow{T,N} <: AbstractArray{T,N}
    data::Dict{NTuple{N,Int}, T}
    dims::NTuple{N,Int}
end
TSlow{T}(::Type{T}, dims::Int...) = TSlow(T, dims)
TSlow{T,N}(::Type{T}, dims::NTuple{N,Int}) = TSlow{T,N}(Dict{NTuple{N,Int}, T}(), dims)

Base.convert{T,N  }(::Type{TSlow     }, X::AbstractArray{T,N}) = convert(TSlow{T,N}, X)
Base.convert{T,N,_}(::Type{TSlow{T  }}, X::AbstractArray{_,N}) = convert(TSlow{T,N}, X)
Base.convert{T,N  }(::Type{TSlow{T,N}}, X::AbstractArray     ) = begin
    A = TSlow(T, size(X))
    for I in CartesianRange(size(X))
        A[I.I...] = X[I.I...]
    end
    A
end

Base.size(A::TSlow) = A.dims
Base.similar{T}(A::TSlow, ::Type{T}, dims::Dims) = TSlow(T, dims)
import Base: LinearSlow
Base.linearindexing{A<:TSlow}(::Type{A}) = LinearSlow()
# Until #11242 is merged, we need to define each dimension independently
Base.getindex{T}(A::TSlow{T,0}) = get(A.data, (), zero(T))
Base.getindex{T}(A::TSlow{T,1}, i1::Int) = get(A.data, (i1,), zero(T))
Base.getindex{T}(A::TSlow{T,2}, i1::Int, i2::Int) = get(A.data, (i1,i2), zero(T))
Base.getindex{T}(A::TSlow{T,3}, i1::Int, i2::Int, i3::Int) =
    get(A.data, (i1,i2,i3), zero(T))
Base.getindex{T}(A::TSlow{T,4}, i1::Int, i2::Int, i3::Int, i4::Int) =
    get(A.data, (i1,i2,i3,i4), zero(T))
Base.getindex{T}(A::TSlow{T,5}, i1::Int, i2::Int, i3::Int, i4::Int, i5::Int) =
    get(A.data, (i1,i2,i3,i4,i5), zero(T))

Base.setindex!{T}(A::TSlow{T,0}, v) = (A.data[()] = v)
Base.setindex!{T}(A::TSlow{T,1}, v, i1::Int) = (A.data[(i1,)] = v)
Base.setindex!{T}(A::TSlow{T,2}, v, i1::Int, i2::Int) = (A.data[(i1,i2)] = v)
Base.setindex!{T}(A::TSlow{T,3}, v, i1::Int, i2::Int, i3::Int) =
    (A.data[(i1,i2,i3)] = v)
Base.setindex!{T}(A::TSlow{T,4}, v, i1::Int, i2::Int, i3::Int, i4::Int) =
    (A.data[(i1,i2,i3,i4)] = v)
Base.setindex!{T}(A::TSlow{T,5}, v, i1::Int, i2::Int, i3::Int, i4::Int, i5::Int) =
    (A.data[(i1,i2,i3,i4,i5)] = v)

import Base: trailingsize
const can_inline = Base.JLOptions().can_inline != 0
function test_scalar_indexing{T}(::Type{T}, shape, ::Type{TestAbstractArray})
    N = prod(shape)
    A = reshape(1:N, shape)
    B = T(A)
    @test A == B
    # Test indexing up to 5 dimensions
    i=0
    for i5 = 1:trailingsize(B, 5)
        for i4 = 1:size(B, 4)
            for i3 = 1:size(B, 3)
                for i2 = 1:size(B, 2)
                    for i1 = 1:size(B, 1)
                        i += 1
                        @test A[i1,i2,i3,i4,i5] == B[i1,i2,i3,i4,i5] == i
                        @test A[i1,i2,i3,i4,i5] ==
                              Base.unsafe_getindex(B, i1, i2, i3, i4, i5) == i
                    end
                end
            end
        end
    end
    # Test linear indexing and partial linear indexing
    i=0
    for i1 = 1:length(B)
        i += 1
        @test A[i1] == B[i1] == i
    end
    i=0
    for i2 = 1:trailingsize(B, 2)
        for i1 = 1:size(B, 1)
            i += 1
            @test A[i1,i2] == B[i1,i2] == i
        end
    end
    @test A == B
    i=0
    for i3 = 1:trailingsize(B, 3)
        for i2 = 1:size(B, 2)
            for i1 = 1:size(B, 1)
                i += 1
                @test A[i1,i2,i3] == B[i1,i2,i3] == i
            end
        end
    end
    # Test zero-dimensional accesses
    @test A[] == B[] == A[1] == B[1] == 1
    # Test multidimensional scalar indexed assignment
    C = T(Int, shape)
    D1 = T(Int, shape)
    D2 = T(Int, shape)
    D3 = T(Int, shape)
    i=0
    for i5 = 1:trailingsize(B, 5)
        for i4 = 1:size(B, 4)
            for i3 = 1:size(B, 3)
                for i2 = 1:size(B, 2)
                    for i1 = 1:size(B, 1)
                        i += 1
                        C[i1,i2,i3,i4,i5] = i
                        # test general unsafe_setindex!
                        Base.unsafe_setindex!(D1, i, i1,i2,i3,i4,i5)
                        # test for dropping trailing dims
                        Base.unsafe_setindex!(D2, i, i1,i2,i3,i4,i5, 1, 1, 1)
                        # test for expanding index argument to appropriate dims
                        Base.unsafe_setindex!(D3, i, i1,i2,i3,i4)
                    end
                end
            end
        end
    end
    @test D1 == D2 == C == B == A
    @test D3[:, :, :, :, 1] == D2[:, :, :, :, 1]
    # Test linear indexing and partial linear indexing
    C = T(Int, shape)
    fill!(C, 0)
    @test C != B && C != A
    i=0
    for i1 = 1:length(C)
        i += 1
        C[i1] = i
    end
    @test C == B == A
    C = T(Int, shape)
    i=0
    for i2 = 1:trailingsize(C, 2)
        for i1 = 1:size(C, 1)
            i += 1
            C[i1,i2] = i
        end
    end
    @test C == B == A
    C = T(Int, shape)
    i=0
    for i3 = 1:trailingsize(C, 3)
        for i2 = 1:size(C, 2)
            for i1 = 1:size(C, 1)
                i += 1
                C[i1,i2,i3] = i
            end
        end
    end
    @test C == B == A
    # Test zero-dimensional setindex
    A[] = 0; B[] = 0
    @test A[] == B[] == 0
    @test A == B
end

function test_vector_indexing{T}(::Type{T}, shape, ::Type{TestAbstractArray})
    N = prod(shape)
    A = reshape(1:N, shape)
    B = T(A)
    idxs = rand(1:N, 3, 3, 3)
    @test B[idxs] == A[idxs] == idxs
    @test B[vec(idxs)] == A[vec(idxs)] == vec(idxs)
    @test B[:] == A[:] == collect(1:N)
    @test B[1:end] == A[1:end] == collect(1:N)
    @test B[:,:] == A[:,:] == reshape(1:N, shape[1], prod(shape[2:end]))
    @test B[1:end,1:end] == A[1:end,1:end] == reshape(1:N, shape[1], prod(shape[2:end]))
    # Test with containers that aren't Int[]
    @test B[[]] == A[[]] == []
    @test B[convert(Array{Any}, idxs)] == A[convert(Array{Any}, idxs)] == idxs
end

function test_primitives{T}(::Type{T}, shape, ::Type{TestAbstractArray})
    N = prod(shape)
    A = reshape(1:N, shape)
    B = T(A)

    # last(a)
    @test last(B) == B[length(B)]

    # strides(a::AbstractArray)
    strides_B = strides(B)
    for (i, _stride) in enumerate(collect(strides_B))
        @test _stride == stride(B, i)
    end

    # isassigned(a::AbstractArray, i::Int...)
    j = rand(1:length(B))
    @test isassigned(B, j) == true
    if T == T24Linear
        @test isassigned(B, length(B) + 1) == false
    end

    # reshape(a::AbstractArray, dims::Dims)
    @test_throws ArgumentError reshape(B, (0, 1))

    # copy!(dest::AbstractArray, src::AbstractArray)
    @test_throws BoundsError copy!(Array(Int, 10), [1:11...])

    # convert{T, N}(::Type{Array}, A::AbstractArray{T, N})
    X = [1:10...]
    @test convert(Array, X) == X
end

function test_in_bounds(::Type{TestAbstractArray})
    n = rand(2:5)
    dims = tuple(rand(2:5, n)...)
    len = prod(dims)
    for i in 1:len
        @test checkbounds(Bool, dims, i) == true
    end
    @test checkbounds(Bool, dims, len + 1) == false
end

type UnimplementedFastArray{T, N} <: AbstractArray{T, N} end
Base.linearindexing(::UnimplementedFastArray) = Base.LinearFast()

type UnimplementedSlowArray{T, N} <: AbstractArray{T, N} end
Base.linearindexing(::UnimplementedSlowArray) = Base.LinearSlow()

type UnimplementedArray{T, N} <: AbstractArray{T, N} end

function test_getindex_internals{T}(::Type{T}, shape, ::Type{TestAbstractArray})
    N = prod(shape)
    A = reshape(1:N, shape)
    B = T(A)

    @test getindex(A) == 1
    @test getindex(B) == 1
    @test Base.unsafe_getindex(A) == 1
    @test Base.unsafe_getindex(B) == 1
end

function test_getindex_internals(::Type{TestAbstractArray})
    U = UnimplementedFastArray{Int, 2}()
    V = UnimplementedSlowArray{Int, 2}()
    @test_throws ErrorException getindex(U, 1)
    @test_throws ErrorException Base.unsafe_getindex(U, 1)
    @test_throws ErrorException getindex(V, 1, 1)
    @test_throws ErrorException Base.unsafe_getindex(V, 1, 1)
end

function test_setindex!_internals{T}(::Type{T}, shape, ::Type{TestAbstractArray})
    N = prod(shape)
    A = reshape(1:N, shape)
    B = T(A)

    Base.unsafe_setindex!(B, 1)
    @test B[1] == 1
end

function test_setindex!_internals(::Type{TestAbstractArray})
    U = UnimplementedFastArray{Int, 2}()
    V = UnimplementedSlowArray{Int, 2}()
    @test_throws ErrorException setindex!(U, 1)
    @test_throws ErrorException Base.unsafe_setindex!(U, 1)
    @test_throws ErrorException Base.unsafe_setindex!(U, 1, 1)
end

function test_get(::Type{TestAbstractArray})
    A = T24Linear([1:24...])
    B = TSlow([1:24...])

    @test get(A, (), 0) == Int[]
    @test get(B, (), 0) == TSlow(Int, 0)
end

function test_cat(::Type{TestAbstractArray})
    A = T24Linear([1:24...])
    b_int = reshape([1:27...], 3, 3, 3)
    b_float = reshape(Float64[1:27...], 3, 3, 3)
    b2hcat = Array(Float64, 3, 6, 3)
    b1 = reshape([1:9...], 3, 3)
    b2 = reshape([10:18...], 3, 3)
    b3 = reshape([19:27...], 3, 3)
    b2hcat[:, :, 1] = hcat(b1, b1)
    b2hcat[:, :, 2] = hcat(b2, b2)
    b2hcat[:, :, 3] = hcat(b3, b3)
    b3hcat = Array(Float64, 3, 9, 3)
    b3hcat[:, :, 1] = hcat(b1, b1, b1)
    b3hcat[:, :, 2] = hcat(b2, b2, b2)
    b3hcat[:, :, 3] = hcat(b3, b3, b3)
    B = TSlow(b_int)
    B1 = TSlow([1:24...])
    B2 = TSlow([1:25...])
    C1 = TSlow([1 2; 3 4])
    C2 = TSlow([1 2 3; 4 5 6])
    C3 = TSlow([1 2; 3 4; 5 6])
    D = [1:24...]
    i = rand(1:10)

    @test cat(i) == Any[]
    @test vcat() == Any[]
    @test hcat() == Any[]
    @test hcat(1, 1.0, 3, 3.0) == [1.0 1.0 3.0 3.0]
    @test_throws ArgumentError hcat(B1, B2)
    @test_throws ArgumentError vcat(C1, C2)

    @test vcat(B) == B
    @test hcat(B) == B
    @test Base.typed_hcat(Float64, B) == TSlow(b_float)
    @test Base.typed_hcat(Float64, B, B) == TSlow(b2hcat)
    @test Base.typed_hcat(Float64, B, B, B) == TSlow(b3hcat)

    @test vcat(B1, B2) == TSlow(vcat([1:24...], [1:25...]))
    @test hcat(C1, C2) == TSlow([1 2 1 2 3; 3 4 4 5 6])
    @test hcat(C1, C2, C1) == TSlow([1 2 1 2 3 1 2; 3 4 4 5 6 3 4])

    # hvcat
    for nbc in (1, 2, 3, 4, 5, 6)
        @test hvcat(nbc, 1:120...) ==
              transpose(reshape([1:120...], nbc, round(Int, 120 / nbc)))
    end

    @test_throws ArgumentError hvcat(7, 1:20...)
    @test_throws ArgumentError hvcat((2), C1, C3)
    @test_throws ArgumentError hvcat((1), C1, C2)
    @test_throws ArgumentError hvcat((1), C2, C3)

    tup = tuple(rand(1:10, i)...)
    @test hvcat(tup) == []

    # check for shape mismatch
    @test_throws ArgumentError hvcat((2, 2), 1, 2, 3, 4, 5)
    @test_throws ArgumentError Base.typed_hvcat(Int, (2, 2), 1, 2, 3, 4, 5)
    # check for # of columns mismatch b/w rows
    @test_throws ArgumentError hvcat((3, 2), 1, 2, 3, 4, 5, 6)
    @test_throws ArgumentError Base.typed_hvcat(Int, (3, 2), 1, 2, 3, 4, 5, 6)
end

function test_ind2sub(::Type{TestAbstractArray})
    n = rand(2:5)
    dims = tuple(rand(1:5, n)...)
    len = prod(dims)
    A = reshape(1:len, dims...)
    I = ind2sub(dims, [1:len...])
    for i in 1:len
        idx = [ I[j][i] for j in 1:n ]
        @test A[idx...] == A[i]
    end
end

type GenericIterator{N} end
Base.start{N}(::GenericIterator{N}) = 1
Base.next{N}(::GenericIterator{N}, i) = (i, i + 1)
Base.done{N}(::GenericIterator{N}, i) = i > N ? true : false

function test_map(::Type{TestAbstractArray})

    for typ in (Float16, Float32, Float64,
                Int8, Int16, Int32, Int64, Int128,
                UInt8, UInt16, UInt32, UInt64, UInt128
    ),
        arg_typ in (Integer,
                    Signed,
                    Unsigned
    )
        X = typ[1:10...]
        _typ = typeof(arg_typ(one(typ)))
        @test map(arg_typ, X) == _typ[1:10...]
    end

    # generic map
    f(x) = x + 1
    I = GenericIterator{10}()
    @test map(f, I) == Any[2:11...]

    # AbstractArray map for 2 arg case
    f(x, y) = x + y
    A = Array(Int, 10)
    B = Float64[1:10...]
    C = Float64[1:10...]
    @test Base.map_to!(f, 1, A, B, C) == Real[ 2 * i for i in 1:10 ]
    @test map(f, Int[], Float64[]) == Float64[]

    # AbstractArray map for N-arg case
    f(x, y, z) = x + y + z
    D = Float64[1:10...]

    @test map!(f, A, B, C, D) == Int[ 3 * i for i in 1:10 ]
    @test Base.map_to_n!(f, 1, A, (B, C, D)) == Real[ 3 * i for i in 1:10 ]
    @test map(f, B, C, D) == Float64[ 3 * i for i in 1:10 ]
    @test map(f, Int[], Int[], Complex{Int}[]) == Number[]
end

function test_map_promote(::Type{TestAbstractArray})
    A = [1:10...]
    f(x) = iseven(x) ? 1.0 : 1
    @test Base.map_promote(f, A) == fill(1.0, 10)
end

function test_UInt_indexing(::Type{TestAbstractArray})
    A = [1:100...]
    _A = Expr(:quote, A)
    for i in 1:100
        _i8 = convert(UInt8, i)
        _i16 = convert(UInt16, i)
        _i32 = convert(UInt32, i)
        for _i in (_i8, _i16, _i32)
            @eval begin
                @test $_A[$_i] == $i
            end
        end
    end
end

function test_vcat_depwarn(::Type{TestAbstractArray})
    if (Base.JLOptions()).depwarn > 1
        @test_throws ErrorException [1:10]
        @test_throws ErrorException [[1, 2], [3, 4]]
        @test_throws ErrorException [[1, 2], [3, 4], [5, 6]]
    else
        olderr = STDERR
        try
            rd, wr = redirect_stderr()
            @test [1:10] == [1:10...]
            @test [[1, 2], [3, 4]] == [1, 2, 3, 4]
            @test [[1, 2], [3, 4], [5, 6]] == [1, 2, 3, 4, 5, 6]
        finally
            redirect_stderr(olderr)
        end
    end
end

#----- run tests -------------------------------------------------------------#

for T in (T24Linear, TSlow), shape in ((24,), (2, 12), (2,3,4), (1,2,3,4), (4,3,2,1))
    test_scalar_indexing(T, shape, TestAbstractArray)
    test_vector_indexing(T, shape, TestAbstractArray)
    test_primitives(T, shape, TestAbstractArray)
    test_getindex_internals(T, shape, TestAbstractArray)
    test_setindex!_internals(T, shape, TestAbstractArray)
end
test_in_bounds(TestAbstractArray)
test_getindex_internals(TestAbstractArray)
test_setindex!_internals(TestAbstractArray)
test_get(TestAbstractArray)
test_cat(TestAbstractArray)
test_ind2sub(TestAbstractArray)
test_map(TestAbstractArray)
test_map_promote(TestAbstractArray)
test_UInt_indexing(TestAbstractArray)
test_vcat_depwarn(TestAbstractArray)
