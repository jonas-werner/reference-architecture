import ray
import cupy
import cupy.cuda.nccl as nccl
import time
import statistics

# Use same byte sizes as shown in your NCCL example (256MB → 8GB)
TENSOR_SIZES_BYTES = [
    536_870_912,   # 512MB
    1_073_741_824, # 1GB
    2_147_483_648, # 2GB
    4_294_967_296, # 4GB
    8_589_934_592  # 8GB
]

NUM_TRIALS = 5
DTYPE = cupy.float32
DTYPE_STR = "float"
DTYPE_BYTES = 4
REDOP = "sum"
ROOT = -1

ray.init(address="auto")

@ray.remote(num_gpus=1)
class Worker:
    def __init__(self, world_size, rank, uid):
        self.rank = rank
        self.world_size = world_size
        self.device = cupy.cuda.Device(rank % cupy.cuda.runtime.getDeviceCount())
        self.device.use()
        self.stream = cupy.cuda.Stream(non_blocking=True)
        self.handle = nccl.NcclCommunicator(world_size, uid, rank)

    def run_allreduce(self, n_bytes):
        count = n_bytes // DTYPE_BYTES
        x = cupy.ones(count, dtype=DTYPE)
        cupy.cuda.Device().synchronize()

        # Warm-up
        self.stream.use()
        self.handle.allReduce(x.data.ptr, x.data.ptr, count, nccl.NCCL_FLOAT32, nccl.NCCL_SUM, self.stream.ptr)
        self.stream.synchronize()

        # Timed run
        start = time.time()
        self.stream.use()
        self.handle.allReduce(x.data.ptr, x.data.ptr, count, nccl.NCCL_FLOAT32, nccl.NCCL_SUM, self.stream.ptr)
        self.stream.synchronize()
        end = time.time()

        return end - start

def main():
    world_size = int(ray.cluster_resources().get("GPU", 1))
    uid = nccl.get_unique_id()
    workers = [Worker.remote(world_size, rank, uid) for rank in range(world_size)]
    
    print(f"# Number of GPUs : {world_size}")
    print("#                                                              out-of-place")
    print("#       size         count      type   redop    root     time   algbw   busbw #wrong")
    print("#        (B)    (elements)                               (us)  (GB/s)  (GB/s)")

    total_busbw = 0.0
    for size_bytes in TENSOR_SIZES_BYTES:
        count = size_bytes // DTYPE_BYTES
        durations = []

        for _ in range(NUM_TRIALS):
            times = ray.get([w.run_allreduce.remote(size_bytes) for w in workers])
            durations.append(max(times))  # synchronized AllReduce timing

        avg_time_s = statistics.mean(durations)
        avg_time_us = avg_time_s * 1e6
        algbw = (size_bytes * 2) / avg_time_s / 1e9  # GB/s
        busbw = algbw * (world_size - 1) / world_size
        total_busbw += busbw
        wrong=0
        print(f"{size_bytes:12d} {count:12d} {DTYPE_STR:>10} {REDOP:>8} {ROOT:8d} "
              f"{avg_time_us:8.1f} {algbw:7.2f} {busbw:7.2f} {wrong:6d}")

    avg_busbw = total_busbw / len(durations)

    print(f"# Avg bus bandwidth    : {avg_busbw:.3f}")
if __name__ == "__main__":
    main()
