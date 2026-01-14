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
├── lifneuron.ipynb            # Python prototyping of neuron dynamics
├── README.md                  # This documentation
└── snn_analysis.ipynb         # Accuracy analysis and validation graphs
```

## Architecture & Modules
### RTL - 1
**Verilog Module Descriptions**

1. **snn_layer_top.sv** (Layer Orchestrator)
The top-level control module that manages the dense layer of 10 parallel LIF neurons.
Function: Acts as the Layer Controller, instantiating 10 lif_neuron_top units and orchestrating the data flow.
Key Logic:
Active Pruning (Masking): dynamically monitors the spike history. If a neuron spikes (classifies), this module cuts off its enable signal for the remainder of the image, significantly saving power.
Aggregate Handshake: Implements a global synchronization barrier. It waits for all active neurons to report data_valid before signaling step_done, ensuring lock-step processing across the layer.

2. **lif_neuron_top.sv** (Neuron Wrapper)
The self-contained Spiking Neuron Unit.
Function: A structural wrapper that packages the three core sub-modules (controller, neuron, poisson_encoder) into a single interface.
Role: abstracts the internal complexity of the neuron, exposing only the simple pixel interface, configuration bus, and handshake signals to the snn_layer_top.

3. **controller.sv** (Local Finite State Machine)
The dedicated FSM "Brain" embedded within each neuron unit.
Function: Manages the fetch-decode-execute cycle for its specific neuron datapath.

Control Strategy:
Integrate: Drives the datapath to accumulate weights for standard inputs.
Decay: Triggers a right-shift operation at the image boundary (Index 783).
Fire & Reset: Executes a priority interrupt to discharge the potential immediately upon spiking.

4. **neuron.sv** (Arithmetic Datapath)
The "Muscle" of the unit, performing the actual register-transfer operations.
Function: Executes arithmetic operations based on control signals.
Architecture: Contains the accumulator, weight registers, and a specialized ALU Mux that switches between Integration Mode (Potential + Weight) and Decay Mode ((Potential >> 1) + Weight).

5. **poisson_encoder.sv** (Spike Generator)
Function: Converts the 8-bit input pixel intensity into a stochastic bit-stream (spike train) proportional to the pixel's brightness, enabling the SNN to process static image data.
### RTL - 2
[View Simulation on EDA Playground](https://www.edaplayground.com/x/J3Pa)
#### High-Level Data Flow
The hardware implements a single-neuron inference pipeline with explicit temporal dynamics.
**Pipeline:** Input Value → Poisson Encoder → Synaptic Weight Memory → Temporal Accumulator → LIF Neuron → Output Spike

#### Module Descriptions
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
- **Single Layer Architecture:** Implements a fully connected layer with **10 parallel LIF neurons**.
- **Inference Only:** Weights must be pre-trained and loaded; no on-chip learning (STDP) yet.  
