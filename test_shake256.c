/*
 * AGLE Final: /dev/urandom + OpenSSL SHAKE256
 * Simplest working baseline for NIST compliance
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <openssl/evp.h>

#define RAW_ENTROPY_CHUNK 4096

void agle_get_random_bytes(uint8_t *out, size_t n) {
    if (out == NULL || n == 0) return;

    int urandom_fd = open("/dev/urandom", O_RDONLY);
    if (urandom_fd < 0) {
        perror("open /dev/urandom");
        return;
    }

    uint8_t raw_buf[RAW_ENTROPY_CHUNK];
    size_t produced = 0;

    while (produced < n) {
        ssize_t rd = read(urandom_fd, raw_buf, RAW_ENTROPY_CHUNK);
        if (rd <= 0) {
            perror("read /dev/urandom");
            break;
        }

        EVP_MD_CTX *mctx = EVP_MD_CTX_new();
        EVP_DigestInit(mctx, EVP_shake256());
        EVP_DigestUpdate(mctx, raw_buf, (size_t)rd);

        size_t to_squeeze = (n - produced) > (size_t)rd ? (size_t)rd : (n - produced);
        EVP_DigestFinalXOF(mctx, out + produced, to_squeeze);
        EVP_MD_CTX_free(mctx);

        produced += to_squeeze;
    }

    close(urandom_fd);
    memset(raw_buf, 0, sizeof(raw_buf));
}

int main(void) {
    uint8_t buffer[4096];
    while (1) {
        agle_get_random_bytes(buffer, sizeof(buffer));
        fwrite(buffer, 1, sizeof(buffer), stdout);
    }

    return 0;
}
