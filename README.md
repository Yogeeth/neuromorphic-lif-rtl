# Spiking Neural Network (SNN) Hardware Core

> **Hardware-oriented implementation of a Spiking Neural Network, centered around a Leaky Integrate-and-Fire (LIF) neuron**

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Structure](#repository-structure)
3. [Architecture & Modules](#architecture--modules)
4. [Design Philosophy](#design-philosophy)
5. [Architectural Scalability](#architectural-scalability)
6. [Current Limitations & Roadmap](#current-limitations--roadmap)

---

## Project Overview

This repository demonstrates how **temporal neural computation** can be translated from biological intuition and mathematical models into **efficient digital hardware**.

Unlike conventional AI accelerators that rely on heavy Matrix-Multiply (MAC) units and static numbers, this design uses efficient primitives — shifts, additions, and comparisons — to process information encoded in **time**.

| Feature | Description |
|---|---|
| **Arithmetic** | Fixed-point (no floating-point hardware required) |
| **Spike Encoding** | On-chip Poisson Encoding via RNG |
| **Neuron Model** | Leaky Integrate-and-Fire (LIF) dynamics |

This work serves as a foundational building block for **Embedded AI**, **Event-driven computing**, and **Neuromorphic hardware** exploration.

---

## Repository Structure

```text
├── docs/
│   └── Notes/
├── rtl-systollic-array/                  # RTL Source Code
│   ├── design/
│   │   ├── lif_neuron.sv                 # LIF math engine — Leak, Integrate, Fire
│   │   ├── network_top.sv                # 10-Neuron Systolic Array
│   │   ├── snn_core.sv                   # "Brain Cell" (BRAM + LIF Neuron + Pipeline FSM)
│   │   ├── snn_top.sv                    # snn_core + Poisson encoding (pixel inputs)
│   │   ├── synaptic_ram.sv               # Synaptic weight memory
│   │   └── xor_shift_rng.sv              # XOR-shift pseudo-random number generator
│   ├── testbench/                        # Simulation Environments
│   |   ├── tb_network.sv                 # 10-neuron integration test
│   |   ├── tb_snn_core.sv                # Single neuron test — spike inputs
│   |   └── tb_snn_top.sv                 # Single neuron test — pixel inputs
|   └── python scripts for testing
│       └── test.ipynb                    # Log verification for tb_network.sv
│                           
├── lifneuron.ipynb                       # Python prototyping of neuron dynamics
├── snn_analysis.ipynb                    # Accuracy analysis and validation graphs
├── Weights/                              # Network weights and test datasets
│   ├── data.csv
│   └── weights_int8.csv                  # Quantized pre-trained weights
└── README.md
```

---
## Architecture & Modules

### `network_top.sv` — The 10-Neuron Systolic Array

**Role:** System conductor and primary pipeline manager.
This top-level module implements a high-speed **1D Systolic Array**. It uses a single, global Poisson encoder at the front of the pipeline to translate incoming 8-bit image pixels into a 1-bit stochastic spike train. A `generate` block stamps out 10 independent `snn_core` modules, passing spikes down the line via a shift register. By staggering each core's execution by one clock cycle, it prevents physical routing congestion and maximizes the FPGA's overall clock speed.

---

### `snn_top.sv` — The "Retina + Brain Cell" Wrapper

**Role:** Pixel-to-spike translation and routing.
> **Note:** This is a standalone test harness — not part of the final multi-neuron network.
Takes standard 8-bit image pixels as input and houses the `xor_shift_rng` to perform Poisson encoding, converting pixel intensities into a stochastic 1-bit spike train. Those binary spikes are fed directly into a single instantiated `snn_core`. Used to independently verify translation and accumulation math before scaling up to the full array.

---

### `snn_core.sv` — The "Brain Cell"

**Role:** Standalone processing node.
Accepts only 1-bit spikes and wraps the memory (`synaptic_ram`) and math engine (`lif_neuron`) into a single unit. Contains a highly efficient **Finite State Machine (FSM)** that manages the exact timing required to:
1. Fetch a weight from BRAM
2. Accumulate the weight into the running sum if a spike is present
3. Trigger the final neuron membrane update

---

### `lif_neuron.sv` — The Math Engine

**Role:** Implements the Leaky Integrate-and-Fire (LIF) biological model.
A pure combinatorial and sequential math block. Once `snn_core` finishes summing all active weights for a given input, it passes that sum here. This module:
- **Integrates** — adds the weighted sum to the neuron's stored membrane potential $V_m$
- **Leaks** — subtracts a biological decay term using efficient bit-shifting (no division hardware)
- **Fires** — checks if $V_m$ has crossed the threshold $V_{th}$ to emit an output spike

---

### `synaptic_ram.sv` — The Weight Memory

**Role:** High-density parameter storage.
A synchronous memory module inferred as physical **Block RAM (BRAM)** tiles by the Vivado compiler. Each instance stores the 8-bit synaptic weights for its specific neuron, ensuring massive parallel memory bandwidth across the network with zero inter-neuron memory contention.

---

### `xor_shift_rng.sv` — The Random Number Generator

**Role:** Stochastic hardware engine.
A highly optimized, hardware-friendly RNG that uses XOR logic and bit-shifting to generate a new 8-bit pseudo-random number every single clock cycle. Used by `snn_top` for accurate Poisson spike generation.

---
### Resourse Utilization (Basys 3)

| Resource | Estimation | Available | Utilization % |
|----------|-----------|-----------|---------------|
| LUT      | 896       | 20800     | 4.31          |
| FF       | 524       | 41600     | 1.26          |
| BRAM     | 5         | 50        | 10.00         |

two neurons into a single BRAM tile.
$10 \text{ neurons} \div 2 \text{ ports per BRAM} = 5 \text{ BRAM blocks}$.

---

## Design Philosophy

Our SNN architecture is built from the ground up for high-performance, edge-AI applications on FPGA hardware. Rather than retrofitting a software-based neural network onto silicon, the system is designed around two core hardware paradigms: **Compute-Near-Memory** and **Systolic Dataflow Logic**.

### The Von Neumann Problem

Most traditional software systems rely on the **Von Neumann Architecture** — a centralized memory bank paired with a centralized processing unit. This creates the infamous *"Von Neumann Bottleneck"*: the processor must constantly stall to fetch weights across a shared bus.

Our architecture departs from this model across three core principles:

---

### Distributed Compute-Near-Memory

Instead of a single monolithic RAM block, we allocate a dedicated `synaptic_ram` (BRAM) to **every single neuron**. The `lif_neuron` math engine is physically synthesized nanometers away from its parameters.

> This eliminates memory contention entirely. Neuron 0 never has to wait for Neuron 9 to finish reading the memory bus.

---

### 1D Systolic Array (Assembly Line Execution)

Broadcasting an input image to every neuron simultaneously requires massive wire fan-out, which degrades signal voltage and lowers the achievable clock speed. Instead, our network operates as a **bucket brigade**:

```
Pixel Input → [Neuron 0] → [Neuron 1] → [Neuron 2] → ... → [Neuron N]
```

Each neuron processes the spike and passes it to its immediate neighbor — one hop at a time.

---

### Biological Efficiency (1-bit Spikes)

Standard deep learning accelerators pass 32-bit floating-point numbers (FP32) between layers. By contrast, our hardware **Poisson encoder** translates 8-bit pixels into 1-bit stochastic spikes.

| Signal Type | Width | Relative Cost |
|---|---|---|
| FP32 activation | 32 bits | High power, high routing complexity |
| INT8 activation | 8 bits | Moderate |
| SNN spike | **1 bit** | Minimal DSP usage, minimal routing |

---

## Architectural Scalability

A critical metric for any RTL design is how it scales from 10 to 10,000 neurons without degrading routability or clock speed.

### Routing & Clock Frequency ($F_{max}$)

In a broadcast network, every added neuron increases capacitance on the shared input wire — forcing a lower clock target. By using a **Systolic Shift Register**, data wires only ever span one neuron to its immediate neighbor. Whether 10 or 10,000 neurons are instantiated, the **maximum wire length remains constant**, preserving a fast $F_{max}$.

### Throughput

The design is deeply pipelined. Scaling only increases initial latency, not steady-state throughput:

$$\text{Throughput} = \frac{1 \text{ pixel}}{\text{clock cycle}} \quad \forall \; N$$

For a 1,000-neuron array, the pipeline takes 1,000 cycles to prime. Once primed, one result is produced every clock cycle regardless of network depth.

### Resource Parameterization

The network is fully parameterized using SystemVerilog `parameter` and `generate` blocks. Scaling requires **zero RTL code rewrites** — simply adjust the parameter before synthesis:

```systemverilog
parameter NUM_NEURONS = 1000;
```
**NOTE** : BRAM BLOCK Count is Crucial for FPGA imlementaion 
---

## Current Limitations & Roadmap

### Current Limitation — Single-Layer Execution
The `network_top.sv` module currently represents a **single, highly optimized neural layer**. The systolic array handles intra-layer communication flawlessly; however, there is no routing infrastructure to capture `neuron_fire` output spikes and feed them as inputs into a subsequent layer.

### Next Step — Network-on-Chip (NoC)
Evolving this into a **Deep Spiking Neural Network (DSNN)** by hardwiring multiple systolic arrays together is not viable — it would reintroduce the exact routing congestion this architecture was designed to eliminate.

The next major architectural milestone is a **Network-on-Chip (NoC)** to handle efficient, scalable inter-layer communication between systolic array stages.