/*
 * phasor_shared_mem.c
 * POSIX shared-memory circular ring buffer for zero-copy synchrophasor stream ingestion.
 */

#include "phasor_c_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

#define PHASOR_SHM_MAGIC 0x50485352 /* "PHSR" */

int phasor_shm_ring_create(const char* shm_name, uint32_t capacity, uint32_t slot_size, void** mapped_addr, size_t* total_size) {
    if (!shm_name || !mapped_addr || !total_size || capacity == 0 || slot_size == 0) {
        return -1;
    }

    /* Unlink any existing segment with this name */
    shm_unlink(shm_name);

    int fd = shm_open(shm_name, O_CREAT | O_RDWR, 0666);
    if (fd < 0) {
        return -2;
    }

    size_t data_size = (size_t)capacity * (size_t)slot_size;
    size_t req_size = sizeof(phasor_shm_ring_header_t) + data_size;

    if (ftruncate(fd, req_size) != 0) {
        close(fd);
        shm_unlink(shm_name);
        return -3;
    }

    void* ptr = mmap(NULL, req_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);

    if (ptr == MAP_FAILED) {
        shm_unlink(shm_name);
        return -4;
    }

    phasor_shm_ring_header_t* hdr = (phasor_shm_ring_header_t*)ptr;
    hdr->magic = PHASOR_SHM_MAGIC;
    hdr->capacity = capacity;
    hdr->slot_size = slot_size;
    hdr->write_idx = 0;
    hdr->read_idx = 0;
    hdr->dropped_frames = 0;

    *mapped_addr = ptr;
    *total_size = req_size;
    return 0;
}

int phasor_shm_ring_open(const char* shm_name, void** mapped_addr, size_t* total_size) {
    if (!shm_name || !mapped_addr || !total_size) {
        return -1;
    }

    int fd = shm_open(shm_name, O_RDWR, 0666);
    if (fd < 0) {
        return -2;
    }

    struct stat sb;
    if (fstat(fd, &sb) != 0) {
        close(fd);
        return -3;
    }

    void* ptr = mmap(NULL, sb.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);

    if (ptr == MAP_FAILED) {
        return -4;
    }

    phasor_shm_ring_header_t* hdr = (phasor_shm_ring_header_t*)ptr;
    if (hdr->magic != PHASOR_SHM_MAGIC) {
        munmap(ptr, sb.st_size);
        return -5;
    }

    *mapped_addr = ptr;
    *total_size = (size_t)sb.st_size;
    return 0;
}

int phasor_shm_ring_write(void* mapped_addr, const void* frame_data, uint32_t frame_len) {
    if (!mapped_addr || !frame_data) return -1;

    phasor_shm_ring_header_t* hdr = (phasor_shm_ring_header_t*)mapped_addr;
    if (hdr->magic != PHASOR_SHM_MAGIC) return -2;
    if (frame_len > hdr->slot_size - sizeof(uint32_t)) return -3;

    uint64_t w_idx = hdr->write_idx;
    uint64_t r_idx = hdr->read_idx;

    if (w_idx - r_idx >= hdr->capacity) {
        /* Buffer is full: advance read pointer to drop oldest frame */
        hdr->read_idx = w_idx - hdr->capacity + 1;
        hdr->dropped_frames++;
    }

    uint32_t slot = (uint32_t)(w_idx % hdr->capacity);
    uint8_t* slot_ptr = (uint8_t*)mapped_addr + sizeof(phasor_shm_ring_header_t) + (slot * hdr->slot_size);

    /* Store payload length followed by data */
    *((uint32_t*)slot_ptr) = frame_len;
    memcpy(slot_ptr + sizeof(uint32_t), frame_data, frame_len);

    __sync_synchronize();
    hdr->write_idx = w_idx + 1;

    return 0;
}

int phasor_shm_ring_read(void* mapped_addr, void* out_data, uint32_t* out_len) {
    if (!mapped_addr || !out_data || !out_len) return -1;

    phasor_shm_ring_header_t* hdr = (phasor_shm_ring_header_t*)mapped_addr;
    if (hdr->magic != PHASOR_SHM_MAGIC) return -2;

    uint64_t r_idx = hdr->read_idx;
    uint64_t w_idx = hdr->write_idx;

    if (r_idx >= w_idx) {
        return 1; /* Buffer empty */
    }

    uint32_t slot = (uint32_t)(r_idx % hdr->capacity);
    const uint8_t* slot_ptr = (const uint8_t*)mapped_addr + sizeof(phasor_shm_ring_header_t) + (slot * hdr->slot_size);

    uint32_t len = *((const uint32_t*)slot_ptr);
    if (len > *out_len) {
        *out_len = len;
        return -3; /* Buffer too small */
    }

    memcpy(out_data, slot_ptr + sizeof(uint32_t), len);
    *out_len = len;

    __sync_synchronize();
    hdr->read_idx = r_idx + 1;

    return 0;
}

int phasor_shm_ring_close(void* mapped_addr, size_t total_size) {
    if (!mapped_addr || total_size == 0) return -1;
    return munmap(mapped_addr, total_size);
}

int phasor_shm_ring_unlink(const char* shm_name) {
    if (!shm_name) return -1;
    return shm_unlink(shm_name);
}
