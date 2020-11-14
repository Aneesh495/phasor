# Mathematical Formulation and Algorithmic Foundations

This document provides rigorous mathematical derivations and numerical formulations for all computational engines in the Phasor Energy Management System (EMS).

---

## 1. AC Power Flow Formulations

### 1.1 Non-Linear Complex Power Balance Equations

Consider an interconnected transmission network with $N$ buses. Let $V_i = |V_i| e^{j \theta_i}$ denote the complex phasor voltage at bus $i$, and let $Y_{ij} = G_{ij} + j B_{ij}$ represent the $(i, j)$-th entry of the complex nodal admittance matrix $Y_{\text{bus}}$.

The complex net power injection at bus $i$ is defined by:

$$S_i = P_i + j Q_i = V_i I_i^* = V_i \left( \sum_{k=1}^N Y_{ik} V_k \right)^*$$

Expanding into real and imaginary rectangular components yields the fundamental AC power balance equations:

$$P_i(V, \theta) = |V_i| \sum_{k=1}^N |V_k| \left( G_{ik} \cos(\theta_i - \theta_k) + B_{ik} \sin(\theta_i - \theta_k) \right)$$

$$Q_i(V, \theta) = |V_i| \sum_{k=1}^N |V_k| \left( G_{ik} \sin(\theta_i - \theta_k) - B_{ik} \cos(\theta_i - \theta_k) \right)$$

At each bus $i$, scheduled active and reactive powers are defined by generator and load schedules:

$$P_i^{\text{spec}} = P_{G, i} - P_{L, i}$$
$$Q_i^{\text{spec}} = Q_{G, i} - Q_{L, i}$$

The active and reactive power mismatches are:

$$\Delta P_i = P_i^{\text{spec}} - P_i(V, \theta)$$
$$\Delta Q_i = Q_i^{\text{spec}} - Q_i(V, \theta)$$

---

### 1.2 AC Newton-Raphson Solver with Full Jacobian

The Newton-Raphson method linearizes the non-linear power mismatch equations around the operating point via Taylor series expansion:

$$\begin{bmatrix} \Delta P \\ \Delta Q \end{bmatrix} = \begin{bmatrix} J_{11} & J_{12} \\ J_{21} & J_{22} \end{bmatrix} \begin{bmatrix} \Delta \theta \\ \Delta |V| / |V| \end{bmatrix}$$

where the four sub-Jacobian blocks are defined analytically as:

#### Sub-Jacobian $J_{11} = \frac{\partial P}{\partial \theta}$:
- Diagonal elements ($i = k$):
  $$\frac{\partial P_i}{\partial \theta_i} = -Q_i - B_{ii} |V_i|^2$$
- Off-diagonal elements ($i \neq k$):
  $$\frac{\partial P_i}{\partial \theta_k} = |V_i| |V_k| \left( G_{ik} \sin(\theta_i - \theta_k) - B_{ik} \cos(\theta_i - \theta_k) \right)$$

#### Sub-Jacobian $J_{12} = |V_k| \frac{\partial P}{\partial |V_k|}$:
- Diagonal elements ($i = k$):
  $$|V_i| \frac{\partial P_i}{\partial |V_i|} = P_i + G_{ii} |V_i|^2$$
- Off-diagonal elements ($i \neq k$):
  $$|V_k| \frac{\partial P_i}{\partial |V_k|} = |V_i| |V_k| \left( G_{ik} \cos(\theta_i - \theta_k) + B_{ik} \sin(\theta_i - \theta_k) \right)$$

#### Sub-Jacobian $J_{21} = \frac{\partial Q}{\partial \theta}$:
- Diagonal elements ($i = k$):
  $$\frac{\partial Q_i}{\partial \theta_i} = P_i - G_{ii} |V_i|^2$$
- Off-diagonal elements ($i \neq k$):
  $$\frac{\partial Q_i}{\partial \theta_k} = -|V_i| |V_k| \left( G_{ik} \cos(\theta_i - \theta_k) + B_{ik} \sin(\theta_i - \theta_k) \right)$$

#### Sub-Jacobian $J_{22} = |V_k| \frac{\partial Q}{\partial |V_k|}$:
- Diagonal elements ($i = k$):
  $$|V_i| \frac{\partial Q_i}{\partial |V_i|} = Q_i - B_{ii} |V_i|^2$$
- Off-diagonal elements ($i \neq k$):
  $$|V_k| \frac{\partial Q_i}{\partial |V_k|} = |V_i| |V_k| \left( G_{ik} \sin(\theta_i - \theta_k) - B_{ik} \cos(\theta_i - \theta_k) \right)$$

#### PV to PQ Bus Type Switching:
During iterations, generator reactive power outputs are calculated:

$$Q_{G, i} = Q_i(V, \theta) + Q_{L, i}$$

If $Q_{G, i} > Q_{i, \max}$, the bus is clamped to $Q_{G, i} = Q_{i, \max}$ and converted to a PQ bus. Conversely, if $Q_{G, i} < Q_{i, \min}$, it is clamped to $Q_{i, \min}$.

---

### 1.3 Fast-Decoupled Power Flow (Stott-Alsac Formulation)

Under typical high-voltage transmission conditions:
1. Conductance is small relative to susceptance: $G_{ik} \ll B_{ik}$.
2. Phase angle differences across lines are small: $\cos(\theta_i - \theta_k) \approx 1$, $\sin(\theta_i - \theta_k) \approx 0$.
3. Reactive power injection is small compared to line short-circuit susceptance: $Q_i \ll B_{ii} |V_i|^2$.

The Jacobian equations decouple into two independent, constant, symmetric positive-definite linear systems:

$$\frac{\Delta P}{|V|} = B' \Delta \theta$$
$$\frac{\Delta Q}{|V|} = B'' \Delta |V|$$

where:
- $B'_{ik} = -1 / X_{ik}$ (omitting line shunt charging and off-nominal transformer taps).
- $B''_{ik} = -B_{ik}$ (including line shunt charging and reactive elements).

Because $B'$ and $B''$ are constant, they are factorized once via Cholesky decomposition ($L L^T$), reducing subsequent iterations to forward and backward substitutions ($O(N)$ operations).

---

### 1.4 Linearized DC Power Flow

Assuming flat voltage profiles ($|V_i| = 1.0$ pu), lossless lines ($R_{ik} = 0$), and small angle differences:

$$P_{ik} = \frac{\theta_i - \theta_k}{X_{ik}}$$

The bus active power injections satisfy the linear matrix system:

$$B_{\text{bus}} \theta = P_{\text{inj}}$$

Removing the slack bus row and column guarantees invertibility, yielding exact linear solutions via single-pass sparse LU factorization.

---

## 2. AC State Estimation and Bad Data Processing

### 2.1 Gauss-Newton Weighted Least Squares (WLS)

Let $z \in \mathbb{R}^M$ denote the vector of SCADA and PMU measurements, related to true state vector $x = [\theta^T, |V|^T]^T \in \mathbb{R}^{2N - 1}$ by:

$$z = h(x) + e$$

where $e \sim \mathcal{N}(0, R)$ represents zero-mean Gaussian measurement noise with diagonal covariance matrix $R = \text{diag}(\sigma_1^2, \sigma_2^2, \dots, \sigma_M^2)$.

The Weighted Least Squares objective minimizes the sum of squared normalized measurement residuals:

$$J(x) = \frac{1}{2} [z - h(x)]^T R^{-1} [z - h(x)]$$

Setting the gradient $\nabla_x J(x) = 0$ yields the non-linear Normal Equations:

$$H^T(x) R^{-1} [z - h(x)] = 0$$

where $H(x) = \frac{\partial h(x)}{\partial x} \in \mathbb{R}^{M \times (2N - 1)}$ is the Measurement Jacobian.

At iteration $k$, the linear Gauss-Newton update step is:

$$G(x^k) \Delta x^k = H^T(x^k) R^{-1} [z - h(x^k)]$$

where $G(x) = H^T(x) R^{-1} H(x)$ is the Gain Matrix, guaranteed to be symmetric positive definite for observable networks.

---

### 2.2 Chi-Square ($\chi^2$) Bad Data Detection

At convergence, the performance index $J(\hat{x})$ follows a Chi-square distribution with $K = M - (2N - 1)$ degrees of freedom:

$$J(\hat{x}) = \sum_{i=1}^M \left( \frac{z_i - h_i(\hat{x})}{\sigma_i} \right)^2 \sim \chi^2(K)$$

For significance level $\alpha = 0.01$ (99% confidence), bad data is flagged if:

$$J(\hat{x}) > \chi^2_{\alpha, K}$$

---

### 2.3 Largest Normalized Residual ($r_N$) Identification

When bad data is detected by the global Chi-square test, the erroneous measurement is localized using normalized residuals.

The residual vector is related to measurement error by:

$$r = z - h(\hat{x}) \approx S e$$

where $S = I - H G^{-1} H^T R^{-1}$ is the residual sensitivity matrix. The residual covariance matrix is:

$$\Omega = \text{Cov}(r) = S R S^T = R - H G^{-1} H^T$$

The normalized residual for measurement $i$ is:

$$r_{N, i} = \frac{|r_i|}{\sqrt{\Omega_{ii}}} = \frac{|z_i - h_i(\hat{x})|}{\sqrt{R_{ii} - [H G^{-1} H^T]_{ii}}}$$

The measurement with the largest normalized residual satisfying $r_{N, \max} > 3.0$ is identified as corrupt, removed from the active measurement set, and the state estimator re-solves.

---

## 3. High-Performance Sensitivity and Contingency Screening

### 3.1 Power Transfer Distribution Factors (PTDF)

The Power Transfer Distribution Factor $\text{PTDF}_{l, i \to j}$ represents the fraction of active power transfer from injection bus $i$ to withdrawal bus $j$ that flows across transmission line $l$:

$$\text{PTDF}_{l, i \to j} = \frac{X_{k i} - X_{k j} - X_{m i} + X_{m j}}{x_l}$$

where $k$ and $m$ are the terminal buses of line $l$, $x_l$ is the series reactance of line $l$, and $X$ is the inverse bus reactance matrix $X = (B')^{-1}$.

---

### 3.2 Line Outage Distribution Factors (LODF)

The Line Outage Distribution Factor $\text{LODF}_{k, l}$ quantifies the change in power flow on line $k$ following the outage of line $l$:

$$\text{LODF}_{k, l} = \frac{\text{PTDF}_{k, i \to j}}{1 - \text{PTDF}_{l, i \to j}}$$

where $i$ and $j$ are the terminal buses of tripped line $l$. Post-contingency flow on line $k$ is evaluated directly without re-solving power flow:

$$P_k^{\text{post}} = P_k^{\text{pre}} + \text{LODF}_{k, l} \cdot P_l^{\text{pre}}$$

---

### 3.3 Sherman-Morrison Rank-1 Re-solve

Tripping branch $l = (i, j)$ corresponds to a rank-1 modification to the admittance matrix:

$$Y_{\text{post}} = Y_{\text{pre}} - y_l \cdot u \cdot u^T$$

where $u = e_i - e_j$ is the incidence vector. By the Sherman-Morrison theorem:

$$Y_{\text{post}}^{-1} = Y_{\text{pre}}^{-1} + \frac{Y_{\text{pre}}^{-1} u u^T Y_{\text{pre}}^{-1}}{y_l^{-1} - u^T Y_{\text{pre}}^{-1} u}$$

This allows $O(N)$ contingency re-solves using the pre-factored base matrix without re-factoring.

---

### 3.4 Performance Indices ($PI_P$ and $PI_V$)

To rank contingency severity across thousands of candidate outages, composite performance indices are evaluated:

#### Active Power Overload Performance Index ($PI_P$):
$$PI_P = \sum_{k=1}^{N_{\text{br}}} \left( \frac{P_k}{P_k^{\max}} \right)^{2m}$$

where $m = 1$ is the penalty exponent.

#### Voltage Security Performance Index ($PI_V$):
$$PI_V = \sum_{i=1}^{N_{\text{bus}}} \left( \frac{2 |V_i| - (V_i^{\max} + V_i^{\min})}{V_i^{\max} - V_i^{\min}} \right)^{2n}$$

where $n = 1$ penalizes boundary excursions.

---

### 3.5 Voltage Collapse Proximity (Kessel-Glavitsch $L$-Index)

The $L$-index quantifies local proximity to voltage collapse:

$$L_j = \left| 1 - \sum_{i \in \alpha_G} F_{ji} \frac{V_i}{V_j} \right|$$

where $F = -Y_{LL}^{-1} Y_{LG}$ is obtained by partitioning the admittance matrix into load ($L$) and generator ($G$) sub-blocks:

$$\begin{bmatrix} I_L \\ I_G \end{bmatrix} = \begin{bmatrix} Y_{LL} & Y_{LG} \\ Y_{GL} & Y_{GG} \end{bmatrix} \begin{bmatrix} V_L \\ V_G \end{bmatrix}$$

$L_j = 0$ indicates zero load, while $L_j \to 1.0$ indicates immediate voltage collapse.

---

## 4. Multi-Machine Electromechanical Transient Dynamics

### 4.1 Second-Order Non-Linear Swing Equation

For machine $i$ with inertia constant $H_i$ (seconds) and damping coefficient $D_i$:

$$\frac{d\delta_i}{dt} = \omega_i - \omega_s$$

$$\frac{2 H_i}{\omega_s} \frac{d\omega_i}{dt} = P_{m, i} - P_{e, i} - D_i (\omega_i - \omega_s)$$

where:
- $\delta_i$ is the rotor electrical angle (radians).
- $\omega_i$ is the rotor electrical speed (rad/s).
- $\omega_s = 2 \pi f_0$ is synchronous speed.
- $P_{m, i}$ is mechanical shaft power input.
- $P_{e, i}$ is air-gap electrical power output:

$$P_{e, i} = E_i^2 G_{ii} + \sum_{j \neq i} E_i E_j \left( G_{ij} \cos(\delta_i - \delta_j) + B_{ij} \sin(\delta_i - \delta_j) \right)$$

---

### 4.2 Numerical Integration (Explicit 4th-Order Runge-Kutta)

Given state vector $y = [\delta^T, \omega^T]^T$ governed by $\frac{dy}{dt} = f(t, y)$:

$$k_1 = f(t_n, y_n)$$
$$k_2 = f\left( t_n + \frac{\Delta t}{2}, y_n + \frac{\Delta t}{2} k_1 \right)$$
$$k_3 = f\left( t_n + \frac{\Delta t}{2}, y_n + \frac{\Delta t}{2} k_2 \right)$$
$$k_4 = f(t_n + \Delta t, y_n + \Delta t k_3)$$
$$y_{n+1} = y_n + \frac{\Delta t}{6} (k_1 + 2 k_2 + 2 k_3 + k_4)$$

with standard step size $\Delta t = 0.001$ s (1 ms).

---

### 4.3 Center of Inertia (COI) and RoCoF Formulation

The Center of Inertia rotor angle and frequency represent the aggregate system inertial motion:

$$\delta_{\text{COI}}(t) = \frac{\sum_{i=1}^{N_G} H_i \delta_i(t)}{\sum_{i=1}^{N_G} H_i}$$

$$f_{\text{COI}}(t) = \frac{\sum_{i=1}^{N_G} H_i f_i(t)}{\sum_{i=1}^{N_G} H_i}$$

The Rate of Change of Frequency (RoCoF) is:

$$\text{RoCoF}(t) = \frac{d f_{\text{COI}}}{dt} = \frac{f_0}{2 \sum H_i} \left( \sum_{i=1}^{N_G} P_{m, i} - \sum_{i=1}^{N_G} P_{e, i} \right)$$

---

## 5. Economic Generation Dispatch and SCED

### 5.1 Lambda-Iteration Optimal Dispatch

Given quadratic generator production costs:

$$C_i(P_i) = a_i P_i^2 + b_i P_i + c_i$$

the economic dispatch problem minimizes total generation cost subject to meeting total demand $P_D$:

$$\min \sum_{i=1}^{N_G} C_i(P_i) \quad \text{s.t.} \quad \sum_{i=1}^{N_G} P_i = P_D, \quad P_i^{\min} \le P_i \le P_i^{\max}$$

Using the method of Lagrange multipliers:

$$\mathcal{L}(P, \lambda) = \sum_{i=1}^{N_G} C_i(P_i) - \lambda \left( \sum_{i=1}^{N_G} P_i - P_D \right)$$

Setting $\frac{\partial \mathcal{L}}{\partial P_i} = 0$ yields the equal incremental cost criterion:

$$\frac{dC_i}{dP_i} = 2 a_i P_i + b_i = \lambda \implies P_i(\lambda) = \frac{\lambda - b_i}{2 a_i}$$

Clamping each generator to its capability limits:

$$P_i^*(\lambda) = \max\left( P_i^{\min}, \min\left( P_i^{\max}, \frac{\lambda - b_i}{2 a_i} \right) \right)$$

The clearing price $\lambda$ is solved via bisection or secant iteration until power balance $|\sum P_i^*(\lambda) - P_D| < \epsilon$.
