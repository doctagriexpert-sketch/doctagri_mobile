#!/usr/bin/env python3
"""
05_benchmark_device.py
Benchmark model latency on reference devices.
Target: < 50ms per inference
"""

import os
import time
import numpy as np


def benchmark_device(
    model_path: str,
    num_runs: int = 100,
    warmup_runs: int = 10,
) -> dict:
    print(f"[5/6] Benchmarking device...")
    print(f"  Model   : {model_path}")
    print(f"  Runs    : {num_runs} (+ {warmup_runs} warmup)")
    print(f"  Target  : < 50ms")

    import tensorflow as tf

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    dummy_input = np.random.rand(1, 224, 224, 3).astype(np.float32)
    for _ in range(warmup_runs):
        interpreter.set_tensor(input_details[0]["index"], dummy_input)
        interpreter.invoke()

    latencies = []
    for _ in range(num_runs):
        start = time.perf_counter()
        interpreter.set_tensor(input_details[0]["index"], dummy_input)
        interpreter.invoke()
        end = time.perf_counter()
        latencies.append((end - start) * 1000)

    latencies = np.array(latencies)
    p50 = np.percentile(latencies, 50)
    p95 = np.percentile(latencies, 95)
    p99 = np.percentile(latencies, 99)
    mean = np.mean(latencies)
    std = np.std(latencies)

    print(f"  Latency p50: {p50:.2f}ms")
    print(f"  Latency p95: {p95:.2f}ms")
    print(f"  Latency p99: {p99:.2f}ms")
    print(f"  Latency mean: {mean:.2f}ms ± {std:.2f}ms")
    print(f"  PASS" if p50 < 50 else f"  FAIL (target: < 50ms)")

    return {
        "p50_ms": p50,
        "p95_ms": p95,
        "p99_ms": p99,
        "mean_ms": mean,
        "std_ms": std,
        "passed": p50 < 50,
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--num_runs", type=int, default=100)
    parser.add_argument("--warmup_runs", type=int, default=10)
    args = parser.parse_args()
    result = benchmark_device(args.model_path, args.num_runs, args.warmup_runs)
    print(result)
