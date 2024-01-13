using MPI
using Random
using Base.Threads

# Function to perform threaded partitioning using a ping-pong buffer
function threaded_partition!(local_A, v, result_buffer)
    local_n = length(local_A)
    local_p, local_q = 1, 1

    if local_n == 1
        return local_p, local_q, local_A
    end

    # Use a ping-pong buffer to perform partitioning in parallel
    ping_buffer = Vector{Int}(undef, local_n)
    pong_buffer = Vector{Int}(undef, local_n)

    @threads for i in 1:local_n
        if local_A[i] < v
            ping_buffer[local_p] = local_A[i]
            local_p += 1
        elseif local_A[i] == v
            pong_buffer[local_q] = local_A[i]
            local_q += 1
        end
    end

    # Copy results back to the result buffer
    resize!(result_buffer, local_p + local_q - 1)
    copyto!(result_buffer[1:local_p-1], ping_buffer[1:local_p-1])

    if local_q > 1
        copyto!(result_buffer[local_p:local_p+local_q-2], pong_buffer[1:local_q-1])
    end

    return local_p, local_q, result_buffer
end

# Function to perform parallel kselect within each MPI process
function parallel_kselect(local_A, k, comm)
    while true
        local_n = length(local_A)

        if local_n == 0
            println("(Rank $(MPI.Comm_rank(comm))) local_A is empty")
            break
        end

        pivot = local_A[1]

        println("(Rank $(MPI.Comm_rank(comm))) To partition: $local_A with pivot $pivot")

        # Use a result buffer for parallel partitioning
        result_buffer = Vector{Int}(undef, local_n)
        local_p, local_q, _ = threaded_partition!(local_A, pivot, result_buffer)

        println("(Rank $(MPI.Comm_rank(comm))) After partition: $local_A with pivot $pivot")
        @show local_p local_q

        # Exchange only local_p and local_q information
        all_local_p = MPI.Allreduce(local_p, MPI.SUM, comm)
        all_local_q = MPI.Allreduce(local_q, MPI.SUM, comm)
        println("(Rank $(MPI.Comm_rank(comm))) All local p / q: $all_local_p , $all_local_q")

        global_p = [0]
        global_q = [0]

        if MPI.Comm_rank(comm) == 0
            global_p[1] = all_local_p
            global_q[1] = all_local_q
        end

        MPI.Bcast!(global_p, 0, comm)
        MPI.Bcast!(global_q, 0, comm)

        global_p = global_p[1]
        global_q = global_q[1]

        @show global_p, global_q

        if k <= global_p
            return local_A[k]
        elseif k <= global_p + local_q
            # Return the k-th smallest element in the local partition
            return local_A[k - global_p]
        else
            k -= global_p + local_q
            local_A = local_A[local_q + 1:end]
        end

        if k <= 0 || global_p <= 1 || isempty(local_A)
            break
        end
    end
end

function main()
    if length(ARGS) != 1
	println("Usage: julia kselect_script.jl <filename> <k>")
        return
    end
    MPI.Init()
    comm = MPI.COMM_WORLD
    nprocs = MPI.Comm_size(comm)
    rank = MPI.Comm_rank(comm)

    if rank == 0
	N = 10000
	A = rand(1:N, N)
        println("Original A: $A")
    else
        A = Int[]
    end

    # Broadcast the length of the array to all processes
    n = MPI.Bcast(length(A), 0, comm)

    # Preallocate space for the local array based on the expected size
    local_size = div(n , nprocs)
    local_A = Vector{Int}(undef, local_size)

    # Scatter A to all processes
    MPI.Scatter!(A, local_A, 0, comm)

    k = parse(Int, ARGS[1])

    println("(Rank $rank) received array: $local_A")

    result = parallel_kselect(local_A, k, comm)
    println("(Rank: $rank) Result: $result")

    MPI.Finalize()
end

@time main()
