#ifdef _WIN32

#include "keyring_common.h"
#include <stdio.h>
#include <windows.h>
#include <wincred.h>

#pragma comment(lib, "advapi32.lib")

/* Target name is "<service>:<account>" so that a service can be enumerated with
   the filter "<service>:*". */
static wchar_t *widen(const char *s, int len) {
  int n = MultiByteToWideChar(CP_UTF8, 0, s, len, NULL, 0);
  if (n <= 0 && len != 0) return NULL;
  wchar_t *w = calloc((size_t)n + 1, sizeof(wchar_t));
  if (w) MultiByteToWideChar(CP_UTF8, 0, s, len, w, n);
  return w;
}

static wchar_t *target_name(const char *service, const char *account) {
  size_t n = strlen(service) + strlen(account) + 2;
  char *joined = malloc(n);
  if (!joined) return NULL;
  snprintf(joined, n, "%s:%s", service, account);
  wchar_t *w = widen(joined, -1);
  free(joined);
  return w;
}

static int32_t status_of(DWORD e) {
  if (e == ERROR_NOT_FOUND) return KEYRING_NOT_FOUND;
  if (e == ERROR_NO_SUCH_LOGON_SESSION) return KEYRING_NO_STORE;
  return (int32_t)e;
}

int32_t omochice_keyring_set(moonbit_bytes_t service, moonbit_bytes_t account, moonbit_bytes_t secret) {
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  wchar_t *target = (svc && acct) ? target_name(svc, acct) : NULL;
  wchar_t *user = acct ? widen(acct, -1) : NULL;
  if (target && user) {
    CREDENTIALW cred = {0};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = target;
    cred.UserName = user;
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
    cred.CredentialBlobSize = (DWORD)Moonbit_array_length(secret);
    cred.CredentialBlob = (LPBYTE)secret;
    rc = CredWriteW(&cred, 0) ? KEYRING_OK : status_of(GetLastError());
  }
  free(target);
  free(user);
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_get(moonbit_bytes_t service, moonbit_bytes_t account) {
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  wchar_t *target = (svc && acct) ? target_name(svc, acct) : NULL;
  if (target) {
    PCREDENTIALW cred = NULL;
    if (CredReadW(target, CRED_TYPE_GENERIC, 0, &cred)) {
      rc = keyring_result_set(cred->CredentialBlob, cred->CredentialBlobSize) ? KEYRING_OK : -1;
      SecureZeroMemory(cred->CredentialBlob, cred->CredentialBlobSize);
      CredFree(cred);
    } else {
      rc = status_of(GetLastError());
    }
  }
  free(target);
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_delete(moonbit_bytes_t service, moonbit_bytes_t account) {
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  wchar_t *target = (svc && acct) ? target_name(svc, acct) : NULL;
  if (target) {
    rc = CredDeleteW(target, CRED_TYPE_GENERIC, 0) ? KEYRING_OK : status_of(GetLastError());
  }
  free(target);
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_list(moonbit_bytes_t service) {
  char *svc = keyring_cstr(service);
  if (!svc) return -1;
  size_t n = strlen(svc) + 3;
  char *pattern = malloc(n);
  if (!pattern) { keyring_cstr_free(svc); return -1; }
  snprintf(pattern, n, "%s:*", svc);
  wchar_t *filter = widen(pattern, -1);
  free(pattern);
  keyring_cstr_free(svc);
  if (!filter) return -1;

  DWORD count = 0;
  PCREDENTIALW *creds = NULL;
  int32_t rc;
  if (!CredEnumerateW(filter, 0, &count, &creds)) {
    DWORD e = GetLastError();
    rc = e == ERROR_NOT_FOUND ? (keyring_result_set("", 0) ? KEYRING_OK : -1) : status_of(e);
    free(filter);
    return rc;
  }
  free(filter);

  size_t cap = 256, len = 0;
  char *buf = malloc(cap);
  rc = buf ? KEYRING_OK : -1;
  for (DWORD i = 0; buf && i < count; i++) {
    if (!creds[i]->UserName) continue;
    int need = WideCharToMultiByte(CP_UTF8, 0, creds[i]->UserName, -1, NULL, 0, NULL, NULL);
    if (need <= 0) continue;
    while (len + (size_t)need + 1 > cap) {
      char *grown = realloc(buf, cap *= 2);
      if (!grown) { rc = -1; break; }
      buf = grown;
    }
    if (rc != KEYRING_OK) break;
    WideCharToMultiByte(CP_UTF8, 0, creds[i]->UserName, -1, buf + len, need, NULL, NULL);
    len += (size_t)need - 1;
    buf[len++] = '\n';
  }
  CredFree(creds);
  if (rc == KEYRING_OK && !keyring_result_set(buf, len)) rc = -1;
  free(buf);
  return rc;
}

#endif
