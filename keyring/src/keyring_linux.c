#ifdef __linux__

#include "keyring_common.h"
#include <dlfcn.h>

typedef struct { const char *name; int type; } SecretSchemaAttribute;
typedef struct {
  const char *name;
  int flags;
  SecretSchemaAttribute attributes[32];
  int reserved;
  void *reserved1, *reserved2, *reserved3, *reserved4, *reserved5, *reserved6, *reserved7;
} SecretSchema;
typedef struct { uint32_t domain; int code; char *message; } GError;
typedef struct GList { void *data; struct GList *next, *prev; } GList;
typedef struct GHashTable GHashTable;

#define SECRET_SCHEMA_ATTRIBUTE_STRING 0
#define SECRET_SEARCH_ALL (1 << 1)
#define SECRET_SEARCH_UNLOCK (1 << 2)

static int (*secret_password_store_sync)(const SecretSchema *, const char *, const char *,
                                         const char *, void *, GError **, ...);
static char *(*secret_password_lookup_sync)(const SecretSchema *, void *, GError **, ...);
static int (*secret_password_clear_sync)(const SecretSchema *, void *, GError **, ...);
static GList *(*secret_password_search_sync)(const SecretSchema *, int, void *, GError **, ...);
static void (*secret_password_free)(char *);
static GHashTable *(*secret_retrievable_get_attributes)(void *);
static void *(*g_hash_table_lookup)(GHashTable *, const void *);
static void (*g_hash_table_unref)(GHashTable *);
static void (*g_error_free)(GError *);
static void (*g_list_free)(GList *);
static void (*g_object_unref)(void *);

static const SecretSchema schema = {
    "org.omochice.keyring",
    0,
    {{"service", SECRET_SCHEMA_ATTRIBUTE_STRING}, {"account", SECRET_SCHEMA_ATTRIBUTE_STRING}, {NULL, 0}},
    0, NULL, NULL, NULL, NULL, NULL, NULL, NULL};

static int load_store(void) {
  static int state = 0;
  if (state) return state > 0;
  state = -1;
  void *secret = dlopen("libsecret-1.so.0", RTLD_LAZY);
  void *glib = dlopen("libglib-2.0.so.0", RTLD_LAZY);
  void *gobject = dlopen("libgobject-2.0.so.0", RTLD_LAZY);
  if (!secret || !glib || !gobject) return 0;
#define LOAD(h, name) \
  do { *(void **)&name = dlsym(h, #name); if (!name) return 0; } while (0)
  LOAD(secret, secret_password_store_sync);
  LOAD(secret, secret_password_lookup_sync);
  LOAD(secret, secret_password_clear_sync);
  LOAD(secret, secret_password_search_sync);
  LOAD(secret, secret_password_free);
  LOAD(secret, secret_retrievable_get_attributes);
  LOAD(glib, g_hash_table_lookup);
  LOAD(glib, g_hash_table_unref);
  LOAD(glib, g_error_free);
  LOAD(glib, g_list_free);
  LOAD(gobject, g_object_unref);
#undef LOAD
  state = 1;
  return 1;
}

/* Failing to reach the D-Bus service is the user's to fix by installing or
   starting a provider, unlike an error about the item itself. */
static int32_t status_of_error(GError *err) {
  int32_t rc = err->code ? err->code : -1;
  if (err->message && (strstr(err->message, "org.freedesktop.secrets") ||
                       strstr(err->message, "D-Bus") || strstr(err->message, "dbus")))
    rc = KEYRING_NO_STORE;
  g_error_free(err);
  return rc;
}

int32_t omochice_keyring_set(moonbit_bytes_t service, moonbit_bytes_t account, moonbit_bytes_t secret) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account), *pw = keyring_cstr(secret);
  int32_t rc = -1;
  if (svc && acct && pw) {
    GError *err = NULL;
    int ok = secret_password_store_sync(&schema, "default", acct, pw, NULL, &err,
                                        "service", svc, "account", acct, NULL);
    rc = err ? status_of_error(err) : (ok ? KEYRING_OK : -1);
  }
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  keyring_cstr_free(pw);
  return rc;
}

int32_t omochice_keyring_get(moonbit_bytes_t service, moonbit_bytes_t account) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  if (svc && acct) {
    GError *err = NULL;
    char *pw = secret_password_lookup_sync(&schema, NULL, &err, "service", svc, "account", acct, NULL);
    if (err) {
      rc = status_of_error(err);
    } else if (!pw) {
      rc = KEYRING_NOT_FOUND;
    } else {
      rc = keyring_result_set(pw, strlen(pw)) ? KEYRING_OK : -1;
      secret_password_free(pw);
    }
  }
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_delete(moonbit_bytes_t service, moonbit_bytes_t account) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  if (svc && acct) {
    GError *err = NULL;
    secret_password_clear_sync(&schema, NULL, &err, "service", svc, "account", acct, NULL);
    rc = err ? status_of_error(err) : KEYRING_OK;
  }
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_list(moonbit_bytes_t service) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service);
  if (!svc) return -1;
  GError *err = NULL;
  GList *found = secret_password_search_sync(&schema, SECRET_SEARCH_ALL | SECRET_SEARCH_UNLOCK,
                                             NULL, &err, "service", svc, NULL);
  keyring_cstr_free(svc);
  if (err) return status_of_error(err);

  size_t cap = 256, len = 0;
  char *buf = malloc(cap);
  int32_t rc = buf ? KEYRING_OK : -1;
  for (GList *l = found; buf && l; l = l->next) {
    GHashTable *attrs = secret_retrievable_get_attributes(l->data);
    const char *name = attrs ? g_hash_table_lookup(attrs, "account") : NULL;
    if (name) {
      size_t n = strlen(name);
      while (len + n + 1 > cap) {
        char *grown = realloc(buf, cap *= 2);
        if (!grown) { rc = -1; break; }
        buf = grown;
      }
      if (rc != KEYRING_OK) { g_hash_table_unref(attrs); break; }
      memcpy(buf + len, name, n);
      buf[len + n] = '\n';
      len += n + 1;
    }
    if (attrs) g_hash_table_unref(attrs);
  }
  for (GList *l = found; l; l = l->next) g_object_unref(l->data);
  if (found) g_list_free(found);
  if (rc == KEYRING_OK && !keyring_result_set(buf, len)) rc = -1;
  free(buf);
  return rc;
}

#endif
