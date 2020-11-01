#!/usr/bin/env python3
"""
dashboard.py
Real-time curses dashboard for synchrophasor stream visualization and frequency monitoring.
Listens to UDP IEEE C37.118 binary streams and renders live meters.
"""

import curses
import socket
import struct
import sys
import time


def decode_c37_frame(payload: bytes):
    """Unpacks essential fields from an IEEE C37.118 data frame."""
    if len(payload) < 38:
        return None

    # Header: sync(2), size(2), id(2), soc(4), frac(4), stat(2)
    sync, total_size, pmu_id, soc, frac, stat = struct.unpack_from(">HHHIIH", payload, 0)
    if sync != 0xAA01:
        return None

    # Phasor 0 (V1): real(4), imag(4)
    v_re, v_im = struct.unpack_from(">ff", payload, 16)
    v_mag = (v_re * v_re + v_im * v_im) ** 0.5

    # Phasor 1 (I1): real(4), imag(4)
    i_re, i_im = struct.unpack_from(">ff", payload, 24)
    i_mag = (i_re * i_re + i_im * i_im) ** 0.5

    # FREQ(4), DFREQ(4)
    f_dev, rocof = struct.unpack_from(">ff", payload, 32)
    freq = 60.0 + f_dev

    return {
        "pmu_id": pmu_id,
        "soc": soc,
        "stat": stat,
        "v_mag": v_mag,
        "i_mag": i_mag,
        "freq": freq,
        "rocof": rocof,
    }


def run_dashboard(stdscr, port: int = 4712, max_frames: int = 0):
    curses.curs_set(0)
    stdscr.nodelay(True)
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_YELLOW, curses.COLOR_BLACK)
    curses.init_pair(3, curses.COLOR_RED, curses.COLOR_BLACK)
    curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", port))
    sock.setblocking(False)

    frame_count = 0
    start_time = time.time()

    while True:
        try:
            data, _addr = sock.recvfrom(2048)
            frame = decode_c37_frame(data)
            if frame:
                frame_count += 1
                stdscr.erase()

                # Header
                stdscr.addstr(1, 2, "=== PHASOR LIVE WIDE AREA MONITORING SYSTEM (WAMS) ===", curses.color_pair(4) | curses.A_BOLD)
                stdscr.addstr(2, 2, f"PMU Station ID: {frame['pmu_id']} | UDP Port: {port} | Frames: {frame_count}")
                stdscr.addstr(3, 2, "-------------------------------------------------------------")

                # Frequency Meter
                f = frame['freq']
                color = curses.color_pair(1)
                if abs(f - 60.0) > 0.05:
                    color = curses.color_pair(3)
                elif abs(f - 60.0) > 0.02:
                    color = curses.color_pair(2)

                stdscr.addstr(5, 2, f"System Frequency:  {f:.3f} Hz ", color | curses.A_BOLD)
                # Gauge bar
                bar_len = int((f - 59.8) / 0.4 * 30)
                bar_len = max(0, min(30, bar_len))
                gauge = "[" + "=" * bar_len + " " * (30 - bar_len) + "]"
                stdscr.addstr(5, 32, gauge, color)

                # RoCoF Meter
                rocof = frame['rocof']
                stdscr.addstr(7, 2, f"RoCoF (df/dt):     {rocof:+.3f} Hz/s")

                # Voltage & Current Phasors
                stdscr.addstr(9, 2, f"Voltage Phasor V1: {frame['v_mag']:.1f} kV (Nominal: 138.0 kV)")
                stdscr.addstr(10, 2, f"Current Phasor I1: {frame['i_mag']:.1f} A  (Nominal: 450.0 A)")

                # Status
                stat_str = "HEALTHY" if frame['stat'] == 0 else "WARNING"
                stdscr.addstr(12, 2, f"PMU Health Status: {stat_str}", curses.color_pair(1 if frame['stat'] == 0 else 3))

                stdscr.addstr(14, 2, "Press 'q' to exit live monitor.")
                stdscr.refresh()

                if max_frames > 0 and frame_count >= max_frames:
                    break

        except BlockingIOError:
            pass

        key = stdscr.getch()
        if key == ord('q'):
            break

        time.sleep(0.01)

    sock.close()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4712
    curses.wrapper(lambda scr: run_dashboard(scr, port=port))


if __name__ == "__main__":
    main()
