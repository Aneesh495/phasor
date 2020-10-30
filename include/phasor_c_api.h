/*
 * phasor_c_api.h
 * High-performance C acceleration and shared-memory telemetry bridge for Phasor.
 */

#ifndef PHASOR_C_API_H
#define PHASOR_C_API_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PHASOR_MAX_FRAME_SIZE 1024
#define PHASOR_DEFAULT_RING_CAPACITY 4096

/* IEEE C37.118 Frame Wire Header */
typedef struct {
    uint16_t sync;
    uint16_t frame_size;
    uint16_t id_code;
    uint32_t soc;
    uint32_t frac_sec;
} __attribute__((packed)) phasor_c37_header_t;

/* Shared Memory Ring Header */
typedef struct {
    uint32_t magic;
    uint32_t capacity;
    uint32_t slot_size;
    volatile uint64_t write_idx;
    volatile uint64_t read_idx;
    volatile uint64_t dropped_frames;
} phasor_shm_ring_header_t;

/* Fast CRC-CCITT (0x1021) lookup table calculation */
uint16_t phasor_fast_crc_ccitt(const uint8_t* buffer, size_t length);

/* Standard Ethernet/POSIX CRC-32 (0xEDB88320) calculation */
uint32_t phasor_fast_crc32(const uint8_t* buffer, size_t length);

/* POSIX Shared Memory Operations */
int phasor_shm_ring_create(const char* shm_name, uint32_t capacity, uint32_t slot_size, void** mapped_addr, size_t* total_size);
int phasor_shm_ring_open(const char* shm_name, void** mapped_addr, size_t* total_size);
int phasor_shm_ring_write(void* mapped_addr, const void* frame_data, uint32_t frame_len);
int phasor_shm_ring_read(void* mapped_addr, void* out_data, uint32_t* out_len);
int phasor_shm_ring_close(void* mapped_addr, size_t total_size);
int phasor_shm_ring_unlink(const char* shm_name);

#ifdef __cplusplus
}
#endif

#endif /* PHASOR_C_API_H */
