#ifdef __APPLE__

#include "keyring_common.h"
#include <dlfcn.h>

/* The headers are deliberately not included: their prototypes would bind these
   symbols at link time, which is exactly what loading with dlopen avoids. */
typedef const void *CFTypeRef;
typedef int32_t OSStatus;
typedef long CFIndex;

#define errSecItemNotFound (-25300)
#define errSecDuplicateItem (-25299)
#define kCFStringEncodingUTF8 0x08000100u

static CFTypeRef (*CFDictionaryCreateMutable)(CFTypeRef, CFIndex, const void *, const void *);
static void (*CFDictionarySetValue)(CFTypeRef, const void *, const void *);
static const void *(*CFDictionaryGetValue)(CFTypeRef, const void *);
static CFTypeRef (*CFStringCreateWithBytes)(CFTypeRef, const uint8_t *, CFIndex, uint32_t, unsigned char);
static CFIndex (*CFStringGetLength)(CFTypeRef);
static CFIndex (*CFStringGetMaximumSizeForEncoding)(CFIndex, uint32_t);
static unsigned char (*CFStringGetCString)(CFTypeRef, char *, CFIndex, uint32_t);
static CFTypeRef (*CFDataCreate)(CFTypeRef, const uint8_t *, CFIndex);
static const uint8_t *(*CFDataGetBytePtr)(CFTypeRef);
static CFIndex (*CFDataGetLength)(CFTypeRef);
static CFIndex (*CFArrayGetCount)(CFTypeRef);
static const void *(*CFArrayGetValueAtIndex)(CFTypeRef, CFIndex);
static void (*CFRelease)(CFTypeRef);
static OSStatus (*SecItemAdd)(CFTypeRef, CFTypeRef *);
static OSStatus (*SecItemUpdate)(CFTypeRef, CFTypeRef);
static OSStatus (*SecItemDelete)(CFTypeRef);
static OSStatus (*SecItemCopyMatching)(CFTypeRef, CFTypeRef *);

static const void *kDictKeyCallBacks, *kDictValueCallBacks;
static CFTypeRef kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrAccount,
    kSecValueData, kSecReturnData, kSecReturnAttributes, kSecMatchLimit, kSecMatchLimitAll,
    kSecMatchLimitOne, kCFBooleanTrue;

/* Constants are exported variables, so dlsym yields the address of the
   variable and the value is read through it. */
static CFTypeRef load_const(void *h, const char *name) {
  CFTypeRef *p = dlsym(h, name);
  return p ? *p : NULL;
}

static int load_store(void) {
  static int state = 0;
  if (state) return state > 0;
  state = -1;
  void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY);
  void *sec = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY);
  if (!cf || !sec) return 0;

#define LOAD(h, name) \
  do { *(void **)&name = dlsym(h, #name); if (!name) return 0; } while (0)
  LOAD(cf, CFDictionaryCreateMutable);
  LOAD(cf, CFDictionarySetValue);
  LOAD(cf, CFDictionaryGetValue);
  LOAD(cf, CFStringCreateWithBytes);
  LOAD(cf, CFStringGetLength);
  LOAD(cf, CFStringGetMaximumSizeForEncoding);
  LOAD(cf, CFStringGetCString);
  LOAD(cf, CFDataCreate);
  LOAD(cf, CFDataGetBytePtr);
  LOAD(cf, CFDataGetLength);
  LOAD(cf, CFArrayGetCount);
  LOAD(cf, CFArrayGetValueAtIndex);
  LOAD(cf, CFRelease);
  LOAD(sec, SecItemAdd);
  LOAD(sec, SecItemUpdate);
  LOAD(sec, SecItemDelete);
  LOAD(sec, SecItemCopyMatching);
#undef LOAD

  kDictKeyCallBacks = dlsym(cf, "kCFTypeDictionaryKeyCallBacks");
  kDictValueCallBacks = dlsym(cf, "kCFTypeDictionaryValueCallBacks");
  kCFBooleanTrue = load_const(cf, "kCFBooleanTrue");
  kSecClass = load_const(sec, "kSecClass");
  kSecClassGenericPassword = load_const(sec, "kSecClassGenericPassword");
  kSecAttrService = load_const(sec, "kSecAttrService");
  kSecAttrAccount = load_const(sec, "kSecAttrAccount");
  kSecValueData = load_const(sec, "kSecValueData");
  kSecReturnData = load_const(sec, "kSecReturnData");
  kSecReturnAttributes = load_const(sec, "kSecReturnAttributes");
  kSecMatchLimit = load_const(sec, "kSecMatchLimit");
  kSecMatchLimitAll = load_const(sec, "kSecMatchLimitAll");
  kSecMatchLimitOne = load_const(sec, "kSecMatchLimitOne");
  if (!kDictKeyCallBacks || !kDictValueCallBacks || !kCFBooleanTrue || !kSecClass ||
      !kSecClassGenericPassword || !kSecAttrService || !kSecAttrAccount || !kSecValueData ||
      !kSecReturnData || !kSecReturnAttributes || !kSecMatchLimit || !kSecMatchLimitAll ||
      !kSecMatchLimitOne)
    return 0;
  state = 1;
  return 1;
}

static CFTypeRef cfstr(const char *s) {
  return CFStringCreateWithBytes(NULL, (const uint8_t *)s, (CFIndex)strlen(s), kCFStringEncodingUTF8, 0);
}

/* A query for one generic password; `account` is NULL when matching a whole service. */
static CFTypeRef make_query(const char *service, const char *account) {
  CFTypeRef q = CFDictionaryCreateMutable(NULL, 0, kDictKeyCallBacks, kDictValueCallBacks);
  CFTypeRef svc = cfstr(service);
  CFTypeRef acct = account ? cfstr(account) : NULL;
  if (!q || !svc || (account && !acct)) {
    if (q) CFRelease(q);
    if (svc) CFRelease(svc);
    if (acct) CFRelease(acct);
    return NULL;
  }
  CFDictionarySetValue(q, kSecClass, kSecClassGenericPassword);
  CFDictionarySetValue(q, kSecAttrService, svc);
  if (acct) CFDictionarySetValue(q, kSecAttrAccount, acct);
  CFRelease(svc);
  if (acct) CFRelease(acct);
  return q;
}

static int32_t status_of(OSStatus s) {
  if (s == 0) return KEYRING_OK;
  if (s == errSecItemNotFound) return KEYRING_NOT_FOUND;
  return s;
}

int32_t omochice_keyring_set(moonbit_bytes_t service, moonbit_bytes_t account, moonbit_bytes_t secret) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  CFTypeRef q = (svc && acct) ? make_query(svc, acct) : NULL;
  CFTypeRef data = CFDataCreate(NULL, (const uint8_t *)secret, (CFIndex)Moonbit_array_length(secret));
  if (q && data) {
    CFTypeRef add = CFDictionaryCreateMutable(NULL, 0, kDictKeyCallBacks, kDictValueCallBacks);
    if (add) {
      CFDictionarySetValue(add, kSecClass, kSecClassGenericPassword);
      CFDictionarySetValue(add, kSecAttrService, CFDictionaryGetValue(q, kSecAttrService));
      CFDictionarySetValue(add, kSecAttrAccount, CFDictionaryGetValue(q, kSecAttrAccount));
      CFDictionarySetValue(add, kSecValueData, data);
      OSStatus s = SecItemAdd(add, NULL);
      if (s == errSecDuplicateItem) {
        CFTypeRef upd = CFDictionaryCreateMutable(NULL, 0, kDictKeyCallBacks, kDictValueCallBacks);
        if (upd) {
          CFDictionarySetValue(upd, kSecValueData, data);
          s = SecItemUpdate(q, upd);
          CFRelease(upd);
        }
      }
      rc = status_of(s);
      CFRelease(add);
    }
  }
  if (data) CFRelease(data);
  if (q) CFRelease(q);
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_get(moonbit_bytes_t service, moonbit_bytes_t account) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  CFTypeRef q = (svc && acct) ? make_query(svc, acct) : NULL;
  if (q) {
    CFDictionarySetValue(q, kSecReturnData, kCFBooleanTrue);
    CFDictionarySetValue(q, kSecMatchLimit, kSecMatchLimitOne);
    CFTypeRef out = NULL;
    OSStatus s = SecItemCopyMatching(q, &out);
    rc = status_of(s);
    if (s == 0 && out) {
      if (!keyring_result_set(CFDataGetBytePtr(out), (size_t)CFDataGetLength(out))) rc = -1;
      CFRelease(out);
    }
    CFRelease(q);
  }
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_delete(moonbit_bytes_t service, moonbit_bytes_t account) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service), *acct = keyring_cstr(account);
  int32_t rc = -1;
  CFTypeRef q = (svc && acct) ? make_query(svc, acct) : NULL;
  if (q) {
    rc = status_of(SecItemDelete(q));
    if (rc == KEYRING_NOT_FOUND) rc = KEYRING_OK;
    CFRelease(q);
  }
  keyring_cstr_free(svc);
  keyring_cstr_free(acct);
  return rc;
}

int32_t omochice_keyring_list(moonbit_bytes_t service) {
  if (!load_store()) return KEYRING_NO_STORE;
  char *svc = keyring_cstr(service);
  int32_t rc = -1;
  CFTypeRef q = svc ? make_query(svc, NULL) : NULL;
  if (q) {
    CFDictionarySetValue(q, kSecReturnAttributes, kCFBooleanTrue);
    CFDictionarySetValue(q, kSecMatchLimit, kSecMatchLimitAll);
    CFTypeRef out = NULL;
    OSStatus s = SecItemCopyMatching(q, &out);
    if (s == errSecItemNotFound) {
      rc = keyring_result_set("", 0) ? KEYRING_OK : -1;
    } else if (s != 0) {
      rc = s;
    } else if (out) {
      size_t cap = 256, len = 0;
      char *buf = malloc(cap);
      rc = buf ? KEYRING_OK : -1;
      for (CFIndex i = 0; buf && i < CFArrayGetCount(out); i++) {
        CFTypeRef name = CFDictionaryGetValue(CFArrayGetValueAtIndex(out, i), kSecAttrAccount);
        if (!name) continue;
        CFIndex max = CFStringGetMaximumSizeForEncoding(CFStringGetLength(name), kCFStringEncodingUTF8) + 2;
        char *tmp = malloc((size_t)max);
        if (!tmp) { rc = -1; break; }
        if (CFStringGetCString(name, tmp, max, kCFStringEncodingUTF8)) {
          size_t n = strlen(tmp);
          while (len + n + 1 > cap) {
            cap *= 2;
            char *grown = realloc(buf, cap);
            if (!grown) { rc = -1; break; }
            buf = grown;
          }
          if (rc == KEYRING_OK) {
            memcpy(buf + len, tmp, n);
            buf[len + n] = '\n';
            len += n + 1;
          }
        }
        free(tmp);
        if (rc != KEYRING_OK) break;
      }
      if (rc == KEYRING_OK && !keyring_result_set(buf, len)) rc = -1;
      free(buf);
      CFRelease(out);
    }
    CFRelease(q);
  }
  keyring_cstr_free(svc);
  return rc;
}

#endif
