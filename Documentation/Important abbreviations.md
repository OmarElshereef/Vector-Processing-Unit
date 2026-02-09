# Important Abbreviations in RVV 1.0

## Vector Length and Configuration

| Abbreviation | Full Name              | Description                                                                                                                                               |
| ------------ | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **VLEN**     | Vector Length          | The maximum number of bits in a vector register (e.g., 128, 256, 512 bits). Implementation-specific and not known at compile time.                        |
| **SEW**      | Standard Element Width | The size of individual vector elements in bits (8, 16, 32, 64). Determines precision and range of operations.                                             |
| **LMUL**     | Length Multiplier      | A multiplier (1/8, 1/4, 1/2, 1, 2, 4, 8) that scales VLEN to determine actual vector length. Allows operating on fractional or multiple vector registers. |
| **VL**       | Vector Length          | The actual number of elements to be processed in the current operation. Can be less than or equal to the maximum supported length.                        |
| **VLMAX**    | Maximum Vector Length  | The maximum number of elements that can fit in a vector register: `VLMAX = (VLEN / SEW) × LMUL`                                                           |

## Instruction Types

| Abbreviation | Full Name               | Description                                                |
| ------------ | ----------------------- | ---------------------------------------------------------- |
| **VV**       | Vector-Vector           | Operations between two vector operands.                    |
| **VX**       | Vector-Scalar (Integer) | Operations between a vector and a scalar integer register. |
| **VI**       | Vector-Immediate        | Operations between a vector and an immediate value.        |

## Memory Operations

| Abbreviation    | Full Name | Description                                                  |
| --------------- | --------- | ------------------------------------------------------------ |
| **Unit Stride** | -         | Load/store where elements are contiguous in memory.          |
| **Strided**     | -         | Load/store with a constant stride between elements.          |
| **Indexed**     | -         | Load/store with addresses computed from a vector of indices. |

## Masking and Control

| Abbreviation         | Full Name   | Description                                                                  |
| -------------------- | ----------- | ---------------------------------------------------------------------------- |
| **VM**               | Vector Mask | A vector register used to selectively enable/disable operations on elements. |
| **Tail Agnostic**    | -           | Behavior of tail elements (beyond VL) is undefined.                          |
| **Tail Undisturbed** | -           | Tail elements retain their previous values.                                  |
