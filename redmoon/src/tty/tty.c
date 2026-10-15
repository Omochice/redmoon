#include <moonbit.h>
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <termios.h>
#include <unistd.h>
#endif

#define TTY_READ_FAILED (-1)
#define TTY_LINE_TOO_LONG (-2)

int32_t omochice_tty_is_terminal(void) {
#ifdef _WIN32
  DWORD mode;
  return GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), &mode) ? 1 : 0;
#else
  return isatty(STDIN_FILENO) ? 1 : 0;
#endif
}

#ifdef _WIN32

int32_t omochice_tty_read_secret(moonbit_bytes_t buf) {
  HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
  DWORD saved;
  if (!GetConsoleMode(in, &saved)) return TTY_READ_FAILED;
  if (!SetConsoleMode(in, saved & ~ENABLE_ECHO_INPUT)) return TTY_READ_FAILED;
  int32_t cap = Moonbit_array_length(buf);
  int32_t len = 0;
  int32_t status = 0;
  for (;;) {
    char c;
    DWORD got;
    if (!ReadFile(in, &c, 1, &got, NULL)) { status = TTY_READ_FAILED; break; }
    if (got == 0 || c == '\n') break;
    if (len == cap) { status = TTY_LINE_TOO_LONG; break; }
    buf[len++] = (uint8_t)c;
  }
  SetConsoleMode(in, saved);
  return status < 0 ? status : len;
}

#else

int32_t omochice_tty_read_secret(moonbit_bytes_t buf) {
  struct termios saved;
  if (tcgetattr(STDIN_FILENO, &saved) != 0) return TTY_READ_FAILED;
  struct termios silent = saved;
  silent.c_lflag &= ~(tcflag_t)ECHO;
  if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &silent) != 0) return TTY_READ_FAILED;
  int32_t cap = Moonbit_array_length(buf);
  int32_t len = 0;
  int32_t status = 0;
  for (;;) {
    char c;
    ssize_t got = read(STDIN_FILENO, &c, 1);
    if (got < 0) { status = TTY_READ_FAILED; break; }
    if (got == 0 || c == '\n') break;
    if (len == cap) { status = TTY_LINE_TOO_LONG; break; }
    buf[len++] = (uint8_t)c;
  }
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved);
  return status < 0 ? status : len;
}

#endif
