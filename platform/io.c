/* Binary OS I/O only, no XPORT/CSV/numeric interpretation. */
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

int32_t mx_open_read(const uint8_t *path) {
  int fd;
  do { fd = open((const char *)path, O_RDONLY); } while (fd < 0 && errno == EINTR);
  return fd < 0 ? -errno : fd;
}
int32_t mx_read(int32_t fd, uint8_t *buffer, int32_t n) {
  ssize_t got;
  do { got = read(fd, buffer, (size_t)n); } while (got < 0 && errno == EINTR);
  return got < 0 ? -errno : (int32_t)got;
}
int32_t mx_close(int32_t fd) { return close(fd) < 0 ? -errno : 0; }
