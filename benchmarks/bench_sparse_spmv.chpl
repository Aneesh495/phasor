/*
 * bench_sparse_spmv.chpl
 * Microbenchmark for parallel Compressed Sparse Row (CSR) matrix-vector multiplication.
 */

use Time;
use Math;
use SparseCSR;

proc runSpMVBenchmark(dim: int, nonzerosPerRow: int, trials: int = 1000) {
  const nnz = dim * nonzerosPerRow;
  var rowPtr: [0..dim] int;
  var colInd: [0..<nnz] int;
  var values: [0..<nnz] real;

  var idx = 0;
  for r in 0..<dim {
    rowPtr[r] = idx;
    for c in 0..<nonzerosPerRow {
      colInd[idx] = (r + c) % dim;
      values[idx] = 1.0 + (c: real) * 0.1;
      idx += 1;
    }
  }
  rowPtr[dim] = nnz;

  var mat = new SparseCSRMatrix(dim, dim, rowPtr, colInd, values);

  var x: [0..<dim] real = 1.0;
  var y: [0..<dim] real = 0.0;

  // Warmup
  for w in 1..10 do mat.matVec(x, y);

  var timer: stopwatch;
  timer.start();

  for t in 1..trials {
    mat.matVec(x, y);
  }

  timer.stop();
  const totalSec = timer.elapsed();
  const avgUs = (totalSec / trials) * 1.0e6;
  const flopsPerMultiply = 2.0 * nnz;
  const gflops = (flopsPerMultiply * trials) / (totalSec * 1.0e9);
  const bytesPerMultiply = (nnz * 8) + (nnz * 8) + (dim * 8) + (dim * 8); // vals + colInd + x + y
  const gbytesPerSec = (bytesPerMultiply * trials) / (totalSec * 1.0e9);

  writeln("Dim: ", dim, "\t| NNZ: ", nnz, "\t| Latency: ", avgUs, " us\t| Throughput: ", gflops, " GFLOP/s\t| Bandwidth: ", gbytesPerSec, " GB/s");
}

proc main() {
  writeln("=== Benchmarking Parallel Sparse CSR SpMV ===");
  runSpMVBenchmark(dim=1000, nonzerosPerRow=5, trials=5000);
  runSpMVBenchmark(dim=5000, nonzerosPerRow=6, trials=2000);
  runSpMVBenchmark(dim=10000, nonzerosPerRow=8, trials=1000);
  writeln("SpMV benchmark completed successfully.");
}
