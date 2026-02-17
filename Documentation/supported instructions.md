# Supported Instructions

## 1-VSETVLI - Vector Set Vector Length Immediate

### Description

Sets the vector length (`vl`) and vector length multiplier (`vlmax`) based on the element type (SEW - Standard Element Width) and the LMUL (vector register grouping multiplier). This instruction configures the vector unit's operating parameters without performing any data operations.

### Instruction Format

```asm
vsetvli rd, rs1, vtypei
```

### Input Parameters

#### `rd` - Destination Register

- **Type:** Integer register
- Receives the new vector length (`vl`) value
- If `rd = x0`, no update occurs to an integer register

#### `rs1` - Source Register

- **Type:** Integer register
- Specifies the requested vector length (in elements)
- The actual `vl` will be `min(rs1, vlmax)` where `vlmax` depends on SEW and LMUL
- If `rs1 = x0`, `vl` is set to `vlmax`

#### `vtypei` - Vector Type Immediate (14-bit encoded field)

**SEW (bits 2:0) - Standard Element Width:**

| Value | Element Width |
| ----- | ------------- |
| `000` | 8-bit         |
| `001` | 16-bit        |
| `010` | 32-bit        |
| `011` | 64-bit        |
| `100` | 128-bit       |
| `101` | 256-bit       |
| `110` | 512-bit       |
| `111` | 1024-bit      |

**LMUL (bits 5:3) - Vector Register Group Multiplier:**

| Value | Multiplier       |
| ----- | ---------------- |
| `000` | 1/8 (fractional) |
| `001` | 1/4 (fractional) |
| `010` | 1/2 (fractional) |
| `011` | 1 (standard)     |
| `100` | 2                |
| `101` | 4                |
| `110` | 8                |
| `111` | reserved         |

**Additional Fields:**

- **TAIL_POLICY (bit 6):** Handling of elements beyond `vl`
- **MASK_POLICY (bit 7):** Handling of masked elements

### Output

| Return | Description                                        |
| ------ | -------------------------------------------------- |
| `vl`   | The new vector length set in `rd` and the `vl` CSR |

**Calculation:**

```python
vl = min(rs1, vlmax)
vlmax = VLEN / (SEW × LMUL)
```

### State Changes

- Updates the `vl` (Vector Length) CSR
- Updates the `vtype` CSR with element width and grouping configuration
- Affects all subsequent vector operations until another vset instruction executes

---

## 2-VSETIVLI - Vector Set Vector Length Immediate (Immediate Source)

### Description

Sets the vector length (`vl`) and vector length multiplier (`vlmax`) based on SEW and LMUL, with the requested length provided as an immediate value rather than from a register.

### Instruction Format

```asm
vsetivli rd, uimm, vtypei
```

### Input Parameters

#### `rd` - Destination Register

- **Type:** Integer register
- Receives the new vector length (`vl`) value
- If `rd = x0`, no update occurs

#### `uimm` - Unsigned Immediate Value

- **Type:** 5-bit unsigned immediate
- Specifies the requested vector length (in elements)
- The actual `vl` will be `min(uimm, vlmax)`
- Range: 0 to 31

#### `vtypei` - Vector Type Immediate

- **Type:** 14-bit encoded field (same format as VSETVLI)

### Output

| Return | Description                                        |
| ------ | -------------------------------------------------- |
| `vl`   | The new vector length set in `rd` and the `vl` CSR |

**Calculation:**

```python
vl = min(uimm, vlmax)
vlmax = VLEN / (SEW × LMUL)
```

### State Changes

- Updates the `vl` (Vector Length) CSR
- Updates the `vtype` CSR with element width and grouping configuration
- Affects all subsequent vector operations until another vset instruction executes

---

## 3-VADD.VV - Vector Add Vector-Vector

### Description

Adds two vector operands element-wise, storing the result in the destination vector register. Performs standard addition without saturation.

### Instruction Format

```asm
vadd.vv vd, vs2, vs1, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the result of the addition operation

#### `vs2` - Source Vector Register 2

- **Type:** Vector register
- First operand for addition

#### `vs1` - Source Vector Register 1

- **Type:** Vector register
- Second operand for addition

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated
- If `vm = 0`, all elements are updated; otherwise, masked elements are skipped based on `vtype.ma` policy

### Output

| Return | Description                                 |
| ------ | ------------------------------------------- |
| `vd`   | Vector register containing element-wise sum |

**Operation:**

```python
vd[i] = vs2[i] + vs1[i] (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

---

## 4-VADD.VX - Vector Add Vector-Scalar

### Description

Adds a vector operand and a scalar operand element-wise, storing the result in the destination vector register. The scalar value is broadcast to all elements.

### Instruction Format

```asm
vadd.vx vd, vs2, rs1, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the result of the addition operation

#### `vs2` - Source Vector Register

- **Type:** Vector register
- Vector operand for addition

#### `rs1` - Source Scalar Register

- **Type:** Integer register
- Scalar operand broadcast to all elements
- Comes from the scalar processor after the alu to ensure proper data hazard handling

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                                 |
| ------ | ------------------------------------------- |
| `vd`   | Vector register containing element-wise sum |

**Operation:**

```python
vd[i] = vs2[i] + rs1 (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

## 5-VWMACC.VV - Signed Widening Multiply-Accumulate Vector-Vector

### Description

Performs signed element-wise multiplication of two vector operands, widens the result, and accumulates (adds) it to a wider destination vector register. This instruction is essential for matrix multiplication and dot-product operations, supporting the 8×8+32→32 operation for efficient GEMM (General Matrix Multiply) workloads.

### Instruction Format

```asm
vwmacc.vv vd, vs1, vs2, vm
```

### Input Parameters

#### `vd` - Destination Vector Register (Accumulator)

- **Type:** Wide vector register
- Stores the accumulated result
- Must be a register that can hold values wider than the source operands
- For 8×8+32→32 operations, this holds 32-bit values

#### `vs1` - Source Vector Register 1 (Multiplicand)

- **Type:** Vector register
- First operand for multiplication
- For 8×8+32→32, this contains 8-bit signed elements

#### `vs2` - Source Vector Register 2 (Multiplier)

- **Type:** Vector register
- Second operand for multiplication
- For 8×8+32→32, this contains 8-bit signed elements

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated
- If `vm = 0`, all elements are updated; otherwise, masked elements are skipped based on `vtype.ma` policy

### Output

| Return | Description                                                  |
| ------ | ------------------------------------------------------------ |
| `vd`   | Wide vector register containing accumulated multiply results |

**Operation:**

```python
vd[i] = vd[i] + (vs1[i] × vs2[i]) (for all active elements)
```

For 8×8+32→32:

```python
vd[i] (32-bit) = vd[i] (32-bit) + (vs1[i] (8-bit) × vs2[i] (8-bit))
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Data Width Promotion:** The multiplication of two 8-bit values produces a 16-bit intermediate result, which is then added to the 32-bit accumulator
- **Sign Extension:** Both input operands are treated as signed values
- **Accumulation:** The key distinction from multiply-only operations; result accumulates into existing `vd` value
- **GEMM Acceleration:** Ideal for innermost loops of matrix multiplication where partial products accumulate

## 6-VWMACCU.VV - Unsigned Widening Multiply-Accumulate Vector-Vector

### Description

Performs unsigned element-wise multiplication of two vector operands, widens the result, and accumulates (adds) it to a wider destination vector register. This instruction is essential for matrix multiplication with unsigned operands, supporting the 8×8+32→32 operation for efficient GEMM workloads with unsigned activations.

### Instruction Format

```asm
vwmaccu.vv vd, vs1, vs2, vm
```

### Input Parameters

#### `vd` - Destination Vector Register (Accumulator)

- **Type:** Wide vector register
- Stores the accumulated result
- Must be a register that can hold values wider than the source operands
- For 8×8+32→32 operations, this holds 32-bit values

#### `vs1` - Source Vector Register 1 (Multiplicand)

- **Type:** Vector register
- First operand for multiplication
- For 8×8+32→32, this contains 8-bit unsigned elements

#### `vs2` - Source Vector Register 2 (Multiplier)

- **Type:** Vector register
- Second operand for multiplication
- For 8×8+32→32, this contains 8-bit unsigned elements

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated
- If `vm = 0`, all elements are updated; otherwise, masked elements are skipped based on `vtype.ma` policy

### Output

| Return | Description                                                  |
| ------ | ------------------------------------------------------------ |
| `vd`   | Wide vector register containing accumulated multiply results |

**Operation:**

```python
vd[i] = vd[i] + (vs1[i] × vs2[i]) (for all active elements, unsigned)
```

For 8×8+32→32:

```python
vd[i] (32-bit) = vd[i] (32-bit) + (vs1[i] (8-bit unsigned) × vs2[i] (8-bit unsigned))
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

---

## 7-VWMACCSU.VV - Signed-Unsigned Widening Multiply-Accumulate Vector-Vector

### Description

Performs signed-unsigned element-wise multiplication of two vector operands, widens the result, and accumulates (adds) it to a wider destination vector register. This instruction is critical for neural network operations where weights are typically signed but activations (after ReLU) are unsigned.

### Instruction Format

```asm
vwmaccsu.vv vd, vs1, vs2, vm
```

### Input Parameters

#### `vd` - Destination Vector Register (Accumulator)

- **Type:** Wide vector register
- Stores the accumulated result
- Must be a register that can hold values wider than the source operands
- For 8×8+32→32 operations, this holds 32-bit values

#### `vs1` - Source Vector Register 1 (Multiplicand - Signed)

- **Type:** Vector register
- First operand for multiplication
- For 8×8+32→32, this contains 8-bit signed elements (weights)

#### `vs2` - Source Vector Register 2 (Multiplier - Unsigned)

- **Type:** Vector register
- Second operand for multiplication
- For 8×8+32→32, this contains 8-bit unsigned elements (activations)

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated
- If `vm = 0`, all elements are updated; otherwise, masked elements are skipped based on `vtype.ma` policy

### Output

| Return | Description                                                  |
| ------ | ------------------------------------------------------------ |
| `vd`   | Wide vector register containing accumulated multiply results |

**Operation:**

```python
vd[i] = vd[i] + (vs1[i] × vs2[i]) (for all active elements, signed × unsigned)
```

For 8×8+32→32:

```python
vd[i] (32-bit) = vd[i] (32-bit) + (vs1[i] (8-bit signed) × vs2[i] (8-bit unsigned))
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Mixed Signedness:** vs1 is treated as signed; vs2 is treated as unsigned
- **Neural Networks:** Essential for efficient inference with signed weight kernels and unsigned ReLU activations

## 8-VSSRA.VI - Saturating Rounding Arithmetic Right Shift Immediate

### Description

Performs an arithmetic right shift on vector elements by an immediate amount, with rounding and saturation to prevent overflow. This instruction is essential for scaling operations in quantized neural networks, removing lower bits while maintaining numerical accuracy.

### Instruction Format

```asm
vssra.vi vd, vs2, uimm, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the shifted and saturated result

#### `vs2` - Source Vector Register

- **Type:** Vector register
- Vector operand to be shifted

#### `uimm` - Unsigned Immediate Shift Amount

- **Type:** 5-bit unsigned immediate
- Specifies the number of bit positions to right shift
- Range: 0 to 31

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                                               |
| ------ | --------------------------------------------------------- |
| `vd`   | Vector register containing saturated right-shifted values |

**Operation:**

```python
vd[i] = saturate(round(vs2[i] >> uimm)) (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Rounding:** Rounding is applied to least significant discarded bits
- **Saturation:** Results are clamped to the valid range for the element width to prevent overflow

---

## 9-VSSRA.VX - Saturating Rounding Arithmetic Right Shift Register

### Description

Performs an arithmetic right shift on vector elements by an amount specified in a scalar register, with rounding and saturation to prevent overflow.

### Instruction Format

```asm
vssra.vx vd, vs2, rs1, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the shifted and saturated result

#### `vs2` - Source Vector Register

- **Type:** Vector register
- Vector operand to be shifted

#### `rs1` - Source Scalar Register

- **Type:** Integer register
- Specifies the shift amount (in bits)

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                                               |
| ------ | --------------------------------------------------------- |
| `vd`   | Vector register containing saturated right-shifted values |

**Operation:**

```python
vd[i] = saturate(round(vs2[i] >> rs1)) (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

---

## 10-VNCLIP.WI - Narrowing Clip Immediate

### Description

Narrows vector elements by clipping (saturating) values into a smaller bit width specified by an immediate, converting wider values into narrower elements with built-in saturation bounds.

### Instruction Format

```asm
vnclip.wi vd, vs2, uimm, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the narrowed and clipped result

#### `vs2` - Source Vector Register

- **Type:** Wide vector register
- Vector operand to be narrowed (e.g., 32-bit values)

#### `uimm` - Unsigned Immediate Clip Bound

- **Type:** 5-bit unsigned immediate
- Specifies the narrowing target width
- Controls saturation limits (e.g., 8-bit narrows to range [−128, 127])

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                                        |
| ------ | -------------------------------------------------- |
| `vd`   | Vector register containing clipped narrowed values |

**Operation:**

```python
vd[i] = clip(vs2[i], min_val, max_val) (for all active elements)
```

For 32→8 bit narrowing:

```python
vd[i] (8-bit) = clip(vs2[i] (32-bit), -128, 127)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Saturation:** Values exceeding bounds are clamped to min/max values
- **Quantization:** Essential for converting intermediate results back to lower precision formats in neural networks

---

## 11-VNCLIP.WX - Narrowing Clip Register

### Description

Narrows vector elements by clipping (saturating) values into a smaller bit width specified by a scalar register, with built-in saturation bounds.

### Instruction Format

```asm
vnclip.wx vd, vs2, rs1, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the narrowed and clipped result

#### `vs2` - Source Vector Register

- **Type:** Wide vector register
- Vector operand to be narrowed

#### `rs1` - Source Scalar Register

- **Type:** Integer register
- Specifies the clip bound

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                                        |
| ------ | -------------------------------------------------- |
| `vd`   | Vector register containing clipped narrowed values |

**Operation:**

```python
vd[i] = clip(vs2[i], min_val, max_val) (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs


## 12-VLE8.V - Vector Load 8-bit Elements

### Description

Loads 8-bit elements from memory into a vector register. Elements are loaded sequentially from the address specified by the base register.

### Instruction Format

```asm
vle8.v vd, (rs1), vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the loaded 8-bit elements

#### `rs1` - Base Address Register

- **Type:** Integer register
- Points to the starting memory address for the load

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are loaded

### Output

| Return | Description                      |
| ------ | -------------------------------- |
| `vd`   | Vector register with loaded data |

**Operation:**

```python
vd[i] = memory[rs1 + i] (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

---

## 13-VSE8.V - Vector Store 8-bit Elements

### Description

Stores 8-bit elements from a vector register into memory. Elements are stored sequentially to the address specified by the base register.

### Instruction Format

```asm
vse8.v vs3, (rs1), vm
```

### Input Parameters

#### `vs3` - Source Vector Register

- **Type:** Vector register
- Contains the 8-bit elements to be stored

#### `rs1` - Base Address Register

- **Type:** Integer register
- Points to the starting memory address for the store

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are stored

### State Changes

- Updates memory at the specified address
- No changes to CSRs or vector registers

---

## 14-VLE32.V - Vector Load 32-bit Elements

### Description

Loads 32-bit elements from memory into a vector register. Essential for loading and saving intermediate high-precision sums during accumulation operations.

### Instruction Format

```asm
vle32.v vd, (rs1), vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the loaded 32-bit elements

#### `rs1` - Base Address Register

- **Type:** Integer register
- Points to the starting memory address for the load

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are loaded

### Output

| Return | Description                      |
| ------ | -------------------------------- |
| `vd`   | Vector register with loaded data |

**Operation:**

```python
vd[i] = memory[rs1 + i*4] (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

---

## 15-VSE32.V - Vector Store 32-bit Elements

### Description

Stores 32-bit elements from a vector register into memory. Essential for saving intermediate high-precision accumulation results.

### Instruction Format

```asm
vse32.v vs3, (rs1), vm
```

### Input Parameters

#### `vs3` - Source Vector Register

- **Type:** Vector register
- Contains the 32-bit elements to be stored

#### `rs1` - Base Address Register

- **Type:** Integer register
- Points to the starting memory address for the store

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are stored

### State Changes

- Updates memory at the specified address
- No changes to CSRs or vector registers

---

## 16-VLSE8.V - Vector Load Strided 8-bit Elements

### Description

Loads 8-bit elements from memory with a constant stride between elements. This instruction is essential for convolutions, allowing efficient loading of matrix columns or filter windows without memory rearrangement.

### Instruction Format

```asm
vlse8.v vd, (rs1), rs2, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the loaded 8-bit elements

#### `rs1` - Base Address Register

- **Type:** Integer register
- Points to the starting memory address for the load

#### `rs2` - Stride Register

- **Type:** Integer register
- Specifies the byte stride between consecutive elements
- Allows non-contiguous memory access patterns

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are loaded

### Output

| Return | Description                      |
| ------ | -------------------------------- |
| `vd`   | Vector register with loaded data |

**Operation:**

```python
vd[i] = memory[rs1 + i*rs2] (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Convolution Optimization:** Enables efficient column-wise loading of input feature maps
- **Memory Flexibility:** Supports arbitrary strides for accessing non-linear memory patterns
- **No Rearrangement:** Eliminates need for data reorganization before vector operations

---

## 17-VSLIDEUP.VI - Vector Slide Up Immediate

### Description

Moves vector elements upward by an immediate number of positions, shifting elements into higher-indexed positions. Lower positions are filled with zeros or masked elements. Essential for sliding-window operations in 1D and 2D convolutions.

### Instruction Format

```asm
vslideup.vi vd, vs2, uimm, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the slid-up result

#### `vs2` - Source Vector Register

- **Type:** Vector register
- Vector operand to be slid upward

#### `uimm` - Unsigned Immediate Slide Amount

- **Type:** 5-bit unsigned immediate
- Specifies the number of positions to slide up
- Range: 0 to 31

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                       |
| ------ | --------------------------------- |
| `vd`   | Vector register with slid elements |

**Operation:**

```python
vd[i] = vs2[i - uimm] for i >= uimm, else 0 (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Convolution Windows:** Enables efficient sliding-window computations by shifting input elements
- **Order Preservation:** Maintains element order while shifting positions

---

## 18-VSLIDEDOWN.VI - Vector Slide Down Immediate

### Description

Moves vector elements downward by an immediate number of positions, shifting elements into lower-indexed positions. Upper positions are filled with zeros or masked elements. Essential for sliding-window operations in 1D and 2D convolutions.

### Instruction Format

```asm
vslidedown.vi vd, vs2, uimm, vm
```

### Input Parameters

#### `vd` - Destination Vector Register

- **Type:** Vector register
- Stores the slid-down result

#### `vs2` - Source Vector Register

- **Type:** Vector register
- Vector operand to be slid downward

#### `uimm` - Unsigned Immediate Slide Amount

- **Type:** 5-bit unsigned immediate
- Specifies the number of positions to slide down
- Range: 0 to 31

#### `vm` - Vector Mask Register (optional)

- **Type:** Vector mask register (v0)
- Controls which elements are updated

### Output

| Return | Description                       |
| ------ | --------------------------------- |
| `vd`   | Vector register with slid elements |

**Operation:**

```python
vd[i] = vs2[i + uimm] for i + uimm <= vl, else 0 (for all active elements)
```

### State Changes

- Updates the destination vector register `vd`
- No changes to CSRs

### Usage Notes

- **Convolution Windows:** Enables efficient sliding-window computations by shifting input elements
- **Data Reuse:** Supports efficient tiling patterns in 1D/2D filter operations