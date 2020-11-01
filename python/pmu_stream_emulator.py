#!/usr/bin/env python3
"""
pmu_stream_emulator.py
High-precision UDP IEEE C37.118-2011 binary synchrophasor stream generator.
Broadcasts realistic multi-bus synchrophasors, frequency deviations, and RoCoF.
"""

import math
import socket
import struct
import sys
import time


def compute_crc_ccitt(data: bytes) -> int:
    """Computes IEEE C37.118 Annex C standard CRC-CCITT (0x1021, init 0xFFFF)."""
    crc = 0xFFFF
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


class PMUStreamEmulator:
    def __init__(self, pmu_id: int = 1, host: str = "127.0.0.1", port: int = 4712, fps: int = 60):
        self.pmu_id = pmu_id
        self.host = host
        self.port = port
        self.fps = fps
        self.dt = 1.0 / fps
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    def generate_frame(self, t: float, fault_active: bool = False) -> bytes:
        """Packs a valid IEEE C37.118 data frame with 2 phasors (V1, I1)."""
        sync = 0xAA01 # Data frame
        pmu_bytes = 2 + 2 * 8 + 4 + 4 # STAT(2) + 2*Phasor(8) + FREQ(4) + DFREQ(4)
        total_size = 14 + pmu_bytes + 2 # Header(14) + PMU + CRC(2)

        now = time.time()
        soc = int(now)
        frac = int((now - soc) * 16777215) # 24-bit fraction

        stat = 0x0000 # Valid data, locked clock

        # Synthesize nominal 60 Hz with subtle dynamic swing
        freq_dev = 0.03 * math.sin(2.0 * math.pi * 0.2 * t) # 0.2 Hz inter-area oscillation
        freq = 60.0 + freq_dev
        rocof = 0.03 * 2.0 * math.pi * 0.2 * math.cos(2.0 * math.pi * 0.2 * t)

        # Voltage phasor: 138 kV nominal, 15 deg phase
        v_mag = 138.0 * (0.40 if fault_active else 1.0)
        v_ang = math.radians(15.0 + 5.0 * math.sin(t))
        v_real = v_mag * math.cos(v_ang)
        v_imag = v_mag * math.sin(v_ang)

        # Current phasor: 450 A nominal, -30 deg phase
        i_mag = 450.0 * (2.8 if fault_active else 1.0)
        i_ang = math.radians(-30.0 + 5.0 * math.sin(t))
        i_real = i_mag * math.cos(i_ang)
        i_imag = i_mag * math.sin(i_ang)

        # Pack body before CRC
        body = struct.pack(
            ">HHHIIHffffff",
            sync,
            total_size,
            self.pmu_id,
            soc,
            frac,
            stat,
            v_real, v_imag,
            i_real, i_imag,
            freq_dev,
            rocof
        )

        crc = compute_crc_ccitt(body)
        return body + struct.pack(">H", crc)

    def run(self, duration_sec: float = 5.0, inject_fault: bool = False):
        """Streams synchrophasors for the requested duration."""
        print(f"Starting PMU Stream Emulator on {self.host}:{self.port} at {self.fps} fps...")
        start_time = time.time()
        sent_frames = 0

        while True:
            elapsed = time.time() - start_time
            if duration_sec > 0 and elapsed >= duration_sec:
                break

            fault = inject_fault and (2.0 <= elapsed <= 2.2) # 200 ms fault at t=2.0s
            packet = self.generate_frame(elapsed, fault_active=fault)
            self.sock.sendto(packet, (self.host, self.port))
            sent_frames += 1

            time.sleep(self.dt)

        print(f"Stream complete: Broadcast {sent_frames} IEEE C37.118 frames ({elapsed:.2f} s).")


if __name__ == "__main__":
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
    emu = PMUStreamEmulator()
    emu.run(duration_sec=dur, inject_fault=True)
