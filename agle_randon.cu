// agle_randon.cu
// GPU-based chaotic pseudo-random generator (AGLE-inspired) with stdout streaming.
// This is a CUDA adaptation of the CPU chaotic feedback algorithm. It does not aim
// to be cryptographically secure; it is a demonstrator for chaos + GPU parallelism.
//
// Build (example):
//   nvcc -O2 -o agle_randon agle_randon.cu
// Run:
//   ./agle_randon > out.bin   # emits 2048 bytes per iteration

#include <cstdio>
#include <cstdint>
#include <cmath>
#include <cstring>

// Minimal CUDA stubs so IntelliSense/host-only parsers do not choke when
// __CUDACC__ is undefined. nvcc will provide the real definitions.
#ifndef __CUDACC__
#define __host__
#define __device__
#define __global__
#define __shared__
#define __align__(n) __attribute__((aligned(n)))
#define __launch_bounds__(t, b)
#define __device_builtin__
#define __cudart_builtin__
#define __noinline__ __attribute__((noinline))
#define __forceinline__ __attribute__((forceinline))
// Fallback for __double_as_longlong when not compiling device code.
static inline long long __double_as_longlong(double x) {
	long long v;
	std::memcpy(&v, &x, sizeof(v));
	return v;
}
#else
#include <cuda_runtime.h>
#endif

// Number of uint32 samples produced per kernel launch (2048 bytes total).
constexpr int BATCH = 512;
// Threads per block; adjust to your GPU SM occupancy needs.
constexpr int THREADS = 256;

// Simple macro to check CUDA calls and bail out on failure.
#define CUDA_CHECK(call)                                           \
    do {                                                           \
        cudaError_t err__ = (call);                                \
        if (err__ != cudaSuccess) {                                \
            fprintf(stderr, "CUDA error %s at %s:%d\n",           \
                    cudaGetErrorString(err__), __FILE__, __LINE__);\
            return 1;                                              \
        }                                                          \
    } while (0)

// Chaotic kernel: each thread generates one uint32 sample.
extern "C" __global__ void agle_kernel(uint32_t* out, double r, double alpha, double lambda,
						   double x_seed, uint64_t seq) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx >= BATCH) return;

	// Per-thread initial state mixes seed, thread id, and sequence counter.
	double x = fmod(x_seed + 1e-6 * idx + 1e-7 * (seq & 0xFFFF), 1.0);
	double epsilon_acc = 0.0;
	uint32_t result = 0;

	// Four inner iterations to amplify chaos and fold error bits.
	for (int iter = 0; iter < 4; iter++) {
		// Lightweight jitter from GPU cycle counter. This is not strong entropy,
		// but perturbs the state slightly to reduce determinism.
		uint64_t t0 = clock64();
		uint64_t t1 = clock64();
		double jitter = (double)((t1 - t0 + (seq << 2) + idx * 13) & 0xFF) / 256.0;

		uint64_t t0b = clock64();
		uint64_t t1b = clock64();
		double physical_jitter = (double)((t1b - t0b + idx * 7) & 0xFFFF) / 65535.0;

		// Chaotic map with singularity exponent and injected jitter.
		double f_real = r * x * (1.0 - x) * pow(x, -alpha);
		f_real += jitter * 1e-7;
		f_real += physical_jitter * 1e-5;

		// Quantization path double -> float -> double to expose rounding error.
		float f32 = (float)f_real;
		double f_quant = (double)f32;
		double epsilon = f_real - f_quant;  // rounding residue

		// Fold error back into the state (mod 1).
		epsilon_acc = fmod(epsilon_acc + epsilon, 1.0);

		double y = f_quant - floor(f_quant);
		x = y + lambda * epsilon + (lambda * 0.3) * epsilon_acc;
		x -= floor(x);

		// Extract bits from x mantissa and epsilon and combine.
		uint64_t raw = __double_as_longlong(x);
		uint32_t mantissa = (uint32_t)((raw >> 12) & 0xFFFFFFFFu);

		uint64_t eps_raw = __double_as_longlong(epsilon);
		uint32_t eps_bits = (uint32_t)(eps_raw & 0xFFFFFFFFu);

		result ^= (mantissa ^ eps_bits);
	}

	out[idx] = result;
}

int main() {
	uint32_t* d_buf = nullptr;
	uint32_t* h_buf = nullptr;

	// Allocate device and host buffers.
	if (cudaMalloc(&d_buf, BATCH * sizeof(uint32_t)) != cudaSuccess) {
		fprintf(stderr, "Failed to allocate device buffer\n");
		return 1;
	}

	h_buf = (uint32_t*)malloc(BATCH * sizeof(uint32_t));
	if (!h_buf) {
		fprintf(stderr, "Failed to allocate host buffer\n");
		cudaFree(d_buf);
		return 1;
	}

	dim3 block(THREADS);
	dim3 grid((BATCH + block.x - 1) / block.x);

	// AGLE parameters (chaotic regime).
	double r = 3.9999;
	double alpha = 1.0;
	double lambda = 3.0;
	double x0 = 0.123456789;

	uint64_t seq = 0;

	// Main loop: launch kernel, copy back, write to stdout.
	while (true) {
		agle_kernel<<<grid, block>>>(d_buf, r, alpha, lambda, x0, seq);
		if (cudaDeviceSynchronize() != cudaSuccess) {
			fprintf(stderr, "Kernel execution failed\n");
			break;
		}

		if (cudaMemcpy(h_buf, d_buf, BATCH * sizeof(uint32_t), cudaMemcpyDeviceToHost) != cudaSuccess) {
			fprintf(stderr, "cudaMemcpy failed\n");
			break;
		}

		size_t written = fwrite(h_buf, sizeof(uint32_t), BATCH, stdout);
		if (written != BATCH) {
			fprintf(stderr, "fwrite incomplete\n");
			break;
		}
		fflush(stdout);
		seq++;
	}

	cudaFree(d_buf);
	free(h_buf);
	return 0;
}
