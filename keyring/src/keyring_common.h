#ifndef OMOCHICE_KEYRING_COMMON_H
#define OMOCHICE_KEYRING_COMMON_H

#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Sentinels sit far outside the range of native error codes so that a store's
   own code can be passed through as `Refused` without being mistaken for them. */
#define KEYRING_OK 0
#define KEYRING_NOT_FOUND 1000000001
#define KEYRING_NO_STORE 1000000002

/* Results go through one buffer instead of a returned MoonBit object so the
   plaintext has a single owner that is wiped as soon as it is taken. */
int keyring_result_set(const void *data, size_t len);
void keyring_result_clear(void);

char *keyring_cstr(moonbit_bytes_t b);
void keyring_cstr_free(char *s);

#endif
