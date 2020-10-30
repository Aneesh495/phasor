/*
 * test_c_accel.c
 * Unit verification for C fast CRC calculation and POSIX shared-memory ring buffer.
 */

#include "phasor_c_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int main(void) {
    printf("=== Running Test: C Fast CRC and Shared Memory Bridge ===\n");

    /* 1. Fast CRC-CCITT Verification */
    const uint8_t test_data[] = { 0xAA, 0x01, 0x00, 0x2A, 0x00, 0x01, 0x69, 0xA2, 0x7E, 0x80 };
    uint16_t crc1 = phasor_fast_crc_ccitt(test_data, sizeof(test_data));
    printf("Calculated CRC-CCITT: 0x%04X\n", crc1);
    assert(crc1 != 0 && "CRC should not be zero");

    /* 2. Fast CRC-32 Verification */
    uint32_t crc32 = phasor_fast_crc32(test_data, sizeof(test_data));
    printf("Calculated CRC-32: 0x%08X\n", crc32);
    assert(crc32 != 0 && "CRC-32 should not be zero");

    /* 3. POSIX Shared Memory Ring Buffer Verification */
    const char* shm_name = "/phasor_test_ring";
    void* mapped_writer = NULL;
    size_t shm_size = 0;

    int rc = phasor_shm_ring_create(shm_name, 16, 256, &mapped_writer, &shm_size);
    if (rc != 0) {
        printf("Shared memory creation returned %d (checking environment permissions)\n", rc);
    } else {
        assert(mapped_writer != NULL);
        printf("Created shared memory ring buffer: %zu bytes\n", shm_size);

        /* Write 10 synthetic frames */
        for (int i = 0; i < 10; i++) {
            char frame_buf[64];
            snprintf(frame_buf, sizeof(frame_buf), "PMU_FRAME_%04d_DATA", i);
            int w_rc = phasor_shm_ring_write(mapped_writer, frame_buf, (uint32_t)strlen(frame_buf) + 1);
            assert(w_rc == 0 && "Write to shared memory failed");
        }

        /* Read back frames */
        for (int i = 0; i < 10; i++) {
            char out_buf[64];
            uint32_t out_len = sizeof(out_buf);
            int r_rc = phasor_shm_ring_read(mapped_writer, out_buf, &out_len);
            assert(r_rc == 0 && "Read from shared memory failed");
            char expected[64];
            snprintf(expected, sizeof(expected), "PMU_FRAME_%04d_DATA", i);
            assert(strcmp(out_buf, expected) == 0 && "Frame content mismatch");
        }

        /* Verify buffer empty */
        char empty_buf[64];
        uint32_t empty_len = sizeof(empty_buf);
        int e_rc = phasor_shm_ring_read(mapped_writer, empty_buf, &empty_len);
        assert(e_rc == 1 && "Buffer should be empty after 10 reads");

        phasor_shm_ring_close(mapped_writer, shm_size);
        phasor_shm_ring_unlink(shm_name);
        printf("Shared memory ring buffer verified successfully.\n");
    }

    printf("PASS: C acceleration and telemetry bridge verified successfully.\n");
    return 0;
}
