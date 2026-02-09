# Supported Instructions

## VSETVLI - Vector Set Vector Length Immediate

#### Description

Sets the vector length (`vl`) and vector length multiplier (`vlmax`) based on the element type (SEW - Standard Element Width) and the LMUL (vector register grouping multiplier). This instruction configures the vector unit's operating parameters without performing any data operations.

### Instruction Format

```asm
vsetvli rd, rs1, vtypei
```

---

### Input Parameters

#### `rd` - Destination Register

- **Type:** Integer register
- Receives the new vector length (`vl`) value
- If `rd = x0`, no update occurs to an integer register

#### `rs1` - Source Register

- **Type:** Integer register or immediate value
- Specifies the requested vector length (in elements)
- The actual `vl` will be `min(rs1, vlmax)` where `vlmax` depends on SEW and LMUL
- If `rs1 = x0`, `vl` is set to `vlmax`

#### `vtypei` - Vector Type Immediate

- **Type:** 14-bit encoded field

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

- **TAIL_POLICY (bit 6):** How to handle elements beyond `vl`
- **MASK_POLICY (bit 7):** How to handle masked elements

---

### Output

| Return | Description                                                     |
| ------ | --------------------------------------------------------------- |
| `vl`   | The new vector length set in `rd` and reflected in the `vl` CSR |

**Calculation:**

```
vl = min(rs1, vlmax)
vlmax = VLEN / (SEW × LMUL)
```

---

### Effect on State

- Updates the `vl` (Vector Length) CSR
- Updates the `vtype` CSR with the new element width and grouping configuration
- Affects all subsequent vector operations until another vset instruction is executed

---

### Notes

> - This is an immediate variant; for register-based length specification, use **VSETVL**
