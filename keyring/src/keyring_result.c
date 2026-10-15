#include "keyring_common.h"

static unsigned char *result = NULL;
static int32_t result_len = 0;

void keyring_result_clear(void) {
  if (result) {
    volatile unsigned char *p = result;
    for (int32_t i = 0; i < result_len; i++) p[i] = 0;
    free(result);
  }
  result = NULL;
  result_len = 0;
}

int keyring_result_set(const void *data, size_t len) {
  keyring_result_clear();
  result = malloc(len ? len : 1);
  if (!result) return 0;
  memcpy(result, data, len);
  result_len = (int32_t)len;
  return 1;
}

char *keyring_cstr(moonbit_bytes_t b) {
  size_t n = Moonbit_array_length(b);
  char *s = malloc(n + 1);
  if (!s) return NULL;
  memcpy(s, b, n);
  s[n] = 0;
  return s;
}

void keyring_cstr_free(char *s) {
  if (!s) return;
  volatile char *p = s;
  for (size_t i = 0; p[i]; i++) p[i] = 0;
  free(s);
}

int32_t omochice_keyring_result_size(void) { return result_len; }

void omochice_keyring_result_take(moonbit_bytes_t dst) {
  memcpy(dst, result, (size_t)result_len);
  keyring_result_clear();
}
