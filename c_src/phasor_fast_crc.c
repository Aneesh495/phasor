/*
 * phasor_fast_crc.c
 * Table-accelerated CRC-CCITT and CRC-32 for gigabyte-per-second packet validation.
 */

#include "phasor_c_api.h"

static bool crc_tables_initialized = false;
static uint16_t ccitt_table[256];
static uint32_t crc32_table[256];

static void init_crc_tables(void) {
    if (crc_tables_initialized) return;

    /* Initialize CCITT 0x1021 Table */
    for (int i = 0; i < 256; i++) {
        uint16_t curr = (uint16_t)(i << 8);
        for (int j = 0; j < 8; j++) {
            if (curr & 0x8000) {
                curr = (curr << 1) ^ 0x1021;
            } else {
                curr = (curr << 1);
            }
        }
        ccitt_table[i] = curr;
    }

    /* Initialize CRC-32 0xEDB88320 Table */
    for (int i = 0; i < 256; i++) {
        uint32_t curr = (uint32_t)i;
        for (int j = 0; j < 8; j++) {
            if (curr & 1) {
                curr = (curr >> 1) ^ 0xEDB88320U;
            } else {
                curr >>= 1;
            }
        }
        crc32_table[i] = curr;
    }

    crc_tables_initialized = true;
}

uint16_t phasor_fast_crc_ccitt(const uint8_t* buffer, size_t length) {
    if (!crc_tables_initialized) {
        init_crc_tables();
    }

    uint16_t crc = 0xFFFF;
    const uint8_t* p = buffer;
    size_t len = length;

    /* Unrolled 4-byte loop */
    while (len >= 4) {
        crc = (crc << 8) ^ ccitt_table[((crc >> 8) ^ p[0]) & 0xFF];
        crc = (crc << 8) ^ ccitt_table[((crc >> 8) ^ p[1]) & 0xFF];
        crc = (crc << 8) ^ ccitt_table[((crc >> 8) ^ p[2]) & 0xFF];
        crc = (crc << 8) ^ ccitt_table[((crc >> 8) ^ p[3]) & 0xFF];
        p += 4;
        len -= 4;
    }

    while (len > 0) {
        crc = (crc << 8) ^ ccitt_table[((crc >> 8) ^ *p) & 0xFF];
        p++;
        len--;
    }

    return crc;
}

uint32_t phasor_fast_crc32(const uint8_t* buffer, size_t length) {
    if (!crc_tables_initialized) {
        init_crc_tables();
    }

    uint32_t crc = 0xFFFFFFFFU;
    const uint8_t* p = buffer;
    size_t len = length;

    while (len >= 4) {
        crc = (crc >> 8) ^ crc32_table[(crc ^ p[0]) & 0xFF];
        crc = (crc >> 8) ^ crc32_table[(crc ^ p[1]) & 0xFF];
        crc = (crc >> 8) ^ crc32_table[(crc ^ p[2]) & 0xFF];
        crc = (crc >> 8) ^ crc32_table[(crc ^ p[3]) & 0xFF];
        p += 4;
        len -= 4;
    }

    while (len > 0) {
        crc = (crc >> 8) ^ crc32_table[(crc ^ *p) & 0xFF];
        p++;
        len--;
    }

    return crc ^ 0xFFFFFFFFU;
}
