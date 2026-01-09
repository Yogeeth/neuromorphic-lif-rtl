# Spiking Neural Networks (SNNs): Intuition & Mathematics

## The Core Philosophy

In traditional Deep Learning, information is **static** (snapshots).  
In **Spiking Neural Networks**, information is **temporal** (movies).

> **Time is not just a dimension — it *is* the data.**

---

## 1. The Paradigm Shift: ANN vs. SNN

To understand SNNs, we must unlearn how we view “numbers” in neural networks.

| Feature | Artificial Neural Networks (ANN) | Spiking Neural Networks (SNN) |
|------|----------------------------------|--------------------------------|
| Data Type | Continuous (float) | Binary (events) |
| Communication | Value magnitude (e.g., 0.95, -0.3) | Spikes (0 or 1) |
| Dimension | Spatial (layers) | Spatio-temporal (layers + time) |
| Analogy | A photograph | Morse code transmission |

### The Golden Rule

In an SNN, a neuron does **not** shout *“0.9!”* or *“0.1!”*  
Instead, it shouts:

> **“NOW!”**

Information is encoded in:
- **Frequency** — how often spikes occur  
- **Latency** — how early spikes occur  
- **Synchronization** — how aligned spikes are across neurons  

---

## 2. The Atomic Unit: The Spike

A spike is mathematically modeled as a **Dirac delta function** \( \delta(t) \),  
but in digital systems it is simply a **binary event**.

- **Amplitude:** irrelevant (all spikes look the same)
- **Duration:** instantaneous (ideal model)
- **Meaning:** an event has occurred

A sequence of spikes over time is called a **spike train**:

\[
S(t) = \sum_i \delta(t - t_i)
\]

where \( t_i \) are the exact moments when the neuron fired.

---

## 3. The Neuron Model: Leaky Integrate-and-Fire (LIF)

The industry-standard neuron model for SNNs is the **Leaky Integrate-and-Fire (LIF)** neuron.

### Intuition: The Leaky Bucket Model

- **Integrate (Fill):** incoming spikes add voltage
- **Leak (Decay):** voltage slowly decays over time
- **Fire (Threshold):** if voltage reaches \( V_{th} \), the neuron spikes
- **Reset:** voltage returns to zero

---

### Why Time Matters: Coincidence Detection

The leak mechanism enables **temporal computation**.

**Case A — Spikes close in time**
- Little leakage
- Voltage accumulates
- Threshold crossed → **FIRE**

**Case B — Spikes far apart**
- Significant leakage
- Voltage never builds up
- Threshold not crossed → **SILENCE**

> **Conclusion:**  
> The LIF neuron fires only when inputs are synchronized in time.  
> It naturally acts as a **coincidence detector**.

---

## 4. The Physics: Continuous-Time Model

The membrane potential \( V(t) \) follows:

\[
\tau \frac{dV(t)}{dt} = -(V(t) - V_{rest}) + R \cdot I(t)
\]

Assuming \( V_{rest} = 0 \) and \( R = 1 \):

\[
\tau \frac{dV(t)}{dt} = -V(t) + \sum_i w_i s_i(t)
\]

Where:
- \( \tau \) — time constant (memory duration)
- \( -V(t) \) — leak (forgetting)
- \( \sum_i w_i s_i(t) \) — spike integration

---

### The Exponential Reality

Solving the equation gives:

\[
V(t) = \sum_k w_k e^{-(t - t_k)/\tau}
\]

Each spike leaves an **exponentially decaying trace**.

> **Coincidence = overlapping exponentials**

---

## 5. From Physics to Code: Discrete-Time Model

Digital systems operate in time steps \( \Delta t \).  
Using **Euler discretization**:

\[
V[t+1] =
\beta V[t] +
\sum w \cdot x[t] -
S_{out}[t] \cdot V_{th}
\]

Where:

\[
\beta = e^{-\frac{\Delta t}{\tau}} \approx 1 - \frac{\Delta t}{\tau},
\quad 0.9 < \beta < 0.99
\]

---

### Interpreting the Equation

- **\( \beta V[t] \)** — Memory of the past  
- **\( \sum w \cdot x[t] \)** — Present input  
- **\( S_{out}[t] \cdot V_{th} \)** — Reset for stability  

This balance enables **stable temporal intelligence**.

---

### Pseudocode (Conceptual)

```python
mem = 0

for t in range(time_steps):
    # 1. Leak (decay)
    mem = mem * beta

    # 2. Integrate input spikes
    mem = mem + input_spikes[t]

    # 3. Threshold check
    if mem >= threshold:
        spike = 1
        mem = 0  # reset
    else:
        spike = 0

    # 4. Record spike
    spike_train_out.append(spike)

**Spiking Neural Networks compute by integrating recent events over time and firing when enough spikes align temporally.**

