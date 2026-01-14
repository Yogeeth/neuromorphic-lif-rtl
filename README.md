# Spiking Neural Network (SNN) Hardware Core

> **A cycle-accurate, hardware-oriented implementation of a Spiking Neural Network, centered around a Leaky Integrate-and-Fire (LIF) neuron, written in SystemVerilog.**

---

## Table of Contents
1. Project Overview
2. Repository Structure
3. Architecture & Modules
4. Design Philosophy

---

## Project Overview

This repository demonstrates how **temporal neural computation** can be translated from biological intuition and mathematical models into **efficient digital hardware**.

Unlike conventional AI accelerators that rely on heavy Matrix-Multiply (MAC) units and static numbers, this design uses efficient primitives—shifts, additions, and comparisons—to process information encoded in **time**.

**Key Features:**
* **Cycle-accurate RTL** design in SystemVerilog.
* **Fixed-point arithmetic** (no floating point hardware required).
* **On-chip Poisson Encoding** (RNG-based spike generation).
* **Leaky Integrate-and-Fire (LIF)** neuron dynamics.

This work serves as a foundational building block for Embedded AI, Event-driven computing, and Neuromorphic hardware exploration.

---

## Repository Structure

```text
.
├── Notes/
├── rtl-1/
├── rtl-2/
│   ├── design/
│   │   ├── lif_neuron.sv      # Leaky Integrate-and-Fire neuron (fixed-point)
│   │   ├── snn_core.sv        # Top-level SNN core (FSM + Encoder + Neuron)
│   │   ├── synaptic_ram.sv    # Synaptic weight memory (parameterized)
│   │   └── xor_shift_rng.sv   # 32-bit XOR-shift RNG for Poisson encoding
│   ├── testbench/
│   │   └── tb_snn.sv          # Simulation testbench
│   └── weights/
│       ├── data.csv
│       └── weights_int8.csv
├── lifneuron.ipynb
├── README.md                  # This documentation
└── SNNExploration.ipynb
```

## Architecture & Modules
# RTL - 1

# RTL - 2
[Link text]https://www.edaplayground.com/x/J3Pa
### High-Level Data Flow
The hardware implements a single-neuron inference pipeline with explicit temporal dynamics.
**Pipeline:** Input Value → Poisson Encoder → Synaptic Weight Memory → Temporal Accumulator → LIF Neuron → Output Spike

### Module Descriptions
1. **lif_neuron.sv (The Brain)**  
   Implements the Leaky Integrate-and-Fire model using signed fixed-point arithmetic.  
   **Logic:** Uses arithmetic right shifts to simulate exponential decay (leak) without expensive multipliers.  
   **Mechanism:** Accumulates input weights, subtracts leakage, and checks against a threshold.  
   **Reset:** Voltage hard-resets to 0 upon firing.

2. **synaptic_ram.sv (The Memory)**  
   Storage for synaptic weights.  
   **Features:** Parameterized depth, synchronous write (programming), asynchronous read (inference).  
   **Hardware Mapping:** Designed to map to Block RAM (BRAM) on FPGAs.

3. **xor_shift_rng.sv (The Encoder)**  
   A 32-bit XOR-shift Pseudo-Random Number Generator.  
   **Purpose:** Converts static input integers into probabilistic spike trains (Poisson Encoding).  
   **Mechanism:** If Input_Value > Random_Value, a spike is generated for that cycle.

4. **snn_core.sv (The Controller)**  
   The top-level module containing the Finite State Machine (FSM).  
   **States:** IDLE (Wait), PROCESS (Accumulate Synapses), UPDATE (Leak & Fire).

## Design Philosophy
- **Time is the Signal:** Logic is designed around temporal accumulation.  
- **Simplicity:** Uses basic primitives (ADD, SUB, SHIFT) instead of complex DSPs.  
- **Clarity:** Code is structured to be readable and educational.

## Current Limitations
- **Single Neuron:** Currently implements one physical neuron.  
- **Inference Only:** Weights must be pre-trained and loaded; no on-chip learning (STDP) yet.  
- **Sequential Processing:** Synapses are processed one by one, trading speed for area efficiency.