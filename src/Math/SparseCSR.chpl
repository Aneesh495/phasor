/*
 * SparseCSR.chpl
 * High-performance Compressed Sparse Row (CSR) sparse matrix storage and operations.
 */

module SparseCSR {
  use Math;
  use PhasorConstants;
  use PhasorTypes;

  // Real-valued Compressed Sparse Row matrix
  record SparseCSRMatrix {
    var nrows: int;
    var ncols: int;
    var nnz: int;
    var rowPtrDomain: domain(1);
    var rowPtr: [rowPtrDomain] int;
    var colIndDomain: domain(1);
    var colInd: [colIndDomain] int;
    var valDomain: domain(1);
    var values: [valDomain] real;

    proc init(nr: int, nc: int, rPtr: [] int, cInd: [] int, vals: [] real) {
      this.nrows = nr;
      this.ncols = nc;
      this.nnz = vals.size;
      this.rowPtrDomain = 0..nr;
      this.rowPtr = rPtr;
      this.colIndDomain = 0..<nnz;
      this.colInd = cInd;
      this.valDomain = 0..<nnz;
      this.values = vals;
    }

    // Parallel Matrix-Vector Multiplication: y = A * x
    proc matVec(x: [] real, ref y: [] real) {
      forall r in 0..<nrows {
        var sum: real = 0.0;
        const startIdx = rowPtr[r];
        const endIdx = rowPtr[r + 1];
        for k in startIdx..<endIdx {
          sum += values[k] * x[colInd[k]];
        }
        y[r] = sum;
      }
    }

    // Access element (r, c) or return 0.0 if not present
    proc get(r: int, c: int): real {
      if r < 0 || r >= nrows || c < 0 || c >= ncols then return 0.0;
      const startIdx = rowPtr[r];
      const endIdx = rowPtr[r + 1];
      for k in startIdx..<endIdx {
        if colInd[k] == c then return values[k];
      }
      return 0.0;
    }

    // Computes sparse matrix transpose: A^T
    proc transpose(): SparseCSRMatrix {
      var colCounts: [0..<ncols] int = 0;
      for k in 0..<nnz {
        colCounts[colInd[k]] += 1;
      }

      var tRowPtr: [0..ncols] int;
      tRowPtr[0] = 0;
      for c in 0..<ncols {
        tRowPtr[c + 1] = tRowPtr[c] + colCounts[c];
      }

      var currOffset: [0..<ncols] int = tRowPtr[0..<ncols];
      var tColInd: [0..<nnz] int;
      var tValues: [0..<nnz] real;

      for r in 0..<nrows {
        const startIdx = rowPtr[r];
        const endIdx = rowPtr[r + 1];
        for k in startIdx..<endIdx {
          const c = colInd[k];
          const dest = currOffset[c];
          tColInd[dest] = r;
          tValues[dest] = values[k];
          currOffset[c] += 1;
        }
      }

      return new SparseCSRMatrix(ncols, nrows, tRowPtr, tColInd, tValues);
    }

    // Sparsity ratio: 1.0 - (nnz / (nrows * ncols))
    proc sparsity(): real {
      const totalElements = (nrows * ncols): real;
      if totalElements == 0.0 then return 0.0;
      return 1.0 - (nnz: real / totalElements);
    }
  }

  // Complex-valued Compressed Sparse Row matrix for nodal admittances
  record ComplexCSRMatrix {
    var nrows: int;
    var ncols: int;
    var nnz: int;
    var rowPtrDomain: domain(1);
    var rowPtr: [rowPtrDomain] int;
    var colIndDomain: domain(1);
    var colInd: [colIndDomain] int;
    var valDomain: domain(1);
    var values: [valDomain] ComplexPhasor;

    proc init(nr: int, nc: int, rPtr: [] int, cInd: [] int, vals: [] ComplexPhasor) {
      this.nrows = nr;
      this.ncols = nc;
      this.nnz = vals.size;
      this.rowPtrDomain = 0..nr;
      this.rowPtr = rPtr;
      this.colIndDomain = 0..<nnz;
      this.colInd = cInd;
      this.valDomain = 0..<nnz;
      this.values = vals;
    }

    // Parallel complex Matrix-Vector Multiplication: y = A * x
    proc matVec(x: [] ComplexPhasor, ref y: [] ComplexPhasor) {
      forall r in 0..<nrows {
        var sum = new ComplexPhasor(0.0, 0.0);
        const startIdx = rowPtr[r];
        const endIdx = rowPtr[r + 1];
        for k in startIdx..<endIdx {
          sum = sum + (values[k] * x[colInd[k]]);
        }
        y[r] = sum;
      }
    }

    // Access element (r, c)
    proc get(r: int, c: int): ComplexPhasor {
      if r < 0 || r >= nrows || c < 0 || c >= ncols then return new ComplexPhasor(0.0, 0.0);
      const startIdx = rowPtr[r];
      const endIdx = rowPtr[r + 1];
      for k in startIdx..<endIdx {
        if colInd[k] == c then return values[k];
      }
      return new ComplexPhasor(0.0, 0.0);
    }
  }
}
