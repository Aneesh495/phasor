# IEEE C37.118-2011 and COMTRADE C37.111 Protocol Specification

This document details the bit-level wire format implementation for IEEE C37.118-2011 synchrophasor frames and IEEE C37.111 COMTRADE transient oscillography data structures in Phasor.

---

## 1. IEEE C37.118-2011 Frame Hierarchy

All multi-byte numeric words transmitted across the network wire interface follow big-endian (network byte order).

### 1.1 Common Frame Header (14 Bytes)

| Offset (Bytes) | Field Name | Width (Bytes) | Format | Description |
|---|---|---|---|---|
| 0 to 1 | `SYNC` | 2 | uint16 | Frame synchronization word. Bits 15-8: `0xAA`. Bits 7-4: Frame type. Bits 3-0: Version `0x01`. |
| 2 to 3 | `FRAMESIZE` | 2 | uint16 | Total frame size in bytes including SYNC and CHK. |
| 4 to 5 | `IDCODE` | 2 | uint16 | Unique PMU or Phasor Data Concentrator (PDC) stream identifier. |
| 6 to 9 | `SOC` | 4 | uint32 | Second-of-Century UTC timestamp (seconds since Unix Epoch 1970-01-01 00:00:00). |
| 10 to 13 | `FRACSEC` | 4 | uint32 | Fraction-of-second (bits 0-23) and Time Quality indicators (bits 24-31). |

#### Frame Type Codes (Bits 7-4 of `SYNC`):
- `0x00` (`0xAA01`): Data Frame
- `0x10` (`0xAA11`): Header Frame
- `0x20` (`0xAA21`): Configuration Frame 1
- `0x30` (`0xAA31`): Configuration Frame 2
- `0x40` (`0xAA41`): Configuration Frame 3
- `0x50` (`0xAA51`): Command Frame

---

### 1.2 Data Frame Payload Organization

Following the 14-byte common header, each PMU data block is arranged sequentially:

```
[STAT (2B)] + [PHASORS (numPhasors * 8B)] + [FREQ (4B)] + [DFREQ (4B)] + [ANALOGS (numAnalogs * 4B)] + [DIGITALS (numDigitals * 2B)]
```

#### Status Word (`STAT`) Bitfield Definitions:
- **Bit 15 (`0x8000`)**: Data validity bit. `0` = Good measurement data. `1` = PMU error or invalid data.
- **Bit 14 (`0x4000`)**: PMU error flag. `0` = Normal operation. `1` = Device error.
- **Bit 13 (`0x2000`)**: Time synchronization status. `0` = Clock locked to UTC traceable source (GPS/PTP). `1` = Clock unlocked / degraded.
- **Bit 12 (`0x1000`)**: Data sorting mode. `0` = Sorted by timestamp. `1` = Arrival sequence.
- **Bits 11-6**: Reserved bits (must be zero).
- **Bits 5-4**: Trigger status indicators.
- **Bits 3-0**: Unlocked time quality code (quantifying clock drift duration).

---

### 1.3 Floating-Point Phasor Representation

In IEEE 32-bit floating-point rectangular mode, each phasor occupies 8 bytes:

$$\text{Bytes } 0 \dots 3: \quad \text{Real Component } (X_{\text{re}}) \quad \text{as IEEE 754 single-precision float}$$
$$\text{Bytes } 4 \dots 7: \quad \text{Imaginary Component } (X_{\text{im}}) \quad \text{as IEEE 754 single-precision float}$$

Magnitude and phase angle are recovered using standard complex arithmetic:

$$|X| = \sqrt{X_{\text{re}}^2 + X_{\text{im}}^2}$$
$$\theta = \text{atan2}(X_{\text{im}}, X_{\text{re}}) \times \frac{180^\circ}{\pi}$$

---

### 1.4 Frequency and RoCoF

- **`FREQ` (4 Bytes)**: Transmitted as a 32-bit float representing deviation from nominal base frequency ($f_{\text{nominal}} = 60.0$ or $50.0$ Hz):
  $$f_{\text{actual}} = f_{\text{nominal}} + \text{FREQ}$$
- **`DFREQ` (4 Bytes)**: Transmitted as a 32-bit float representing Rate of Change of Frequency ($df/dt$) in Hz/s.

---

### 1.5 Frame Checksum (`CHK`)

The final 2 bytes of every C37.118 frame contain a 16-bit CRC-CCITT calculated over all preceding bytes (from byte 0 up to byte $\text{FRAMESIZE} - 3$).

- **Polynomial**: $x^{16} + x^{12} + x^5 + 1$ (`0x1021`)
- **Initial Value**: `0xFFFF`
- **Output XOR**: `0x0000`

---

## 2. IEEE C37.111 COMTRADE Transient Oscillography Format

Phasor exports transient stability trajectories to the standard dual-file COMTRADE format:

### 2.1 Configuration File (`.cfg`)
Contains recording station metadata, channel names, phase identities, and sample rates:
1. `station_name,rec_dev_id,1999`
2. `TT,##A,##D` (total, analog, and digital channel counts)
3. For each analog channel:
   `idx,ch_id,ph,ccbm,uu,a,b,skew,min,max,primary,secondary,PS`
4. Nominal line frequency (e.g. `60`)
5. Sample rate blocks: `nrates`, followed by `samp_rate,endsamp`
6. Start timestamp and trigger timestamp: `dd/mm/yyyy,hh:mm:ss.ssssss`
7. Data format: `ASCII` or `BINARY`
8. Time scaling multiplier: `1.0`

### 2.2 Data File (`.dat`)
Contains sample-indexed oscillographic recordings:
```
sample_number,timestamp_microseconds,analog_1,analog_2,...,analog_A,digital_1,...
```
Physical values are reconstructed via linear scaling:

$$Y = a \cdot X + b$$
