/* Binary OS I/O only, no XPORT/CSV/numeric interpretation. */
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

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
int32_t mx_create(const uint8_t *path) {
  int fd;
  do { fd = open((const char *)path, O_WRONLY|O_CREAT|O_EXCL, 0600); }
  while (fd < 0 && errno == EINTR);
  return fd < 0 ? -errno : fd;
}
int32_t mx_write(int32_t fd, const uint8_t *buffer, int32_t n) {
  int32_t at=0;
  while (at<n) {
    ssize_t wrote=write(fd,buffer+at,(size_t)(n-at));
    if (wrote<0 && errno==EINTR) continue;
    if (wrote<=0) return wrote<0 ? -errno : -EIO;
    at+=(int32_t)wrote;
  }
  return 0;
}
int32_t mx_sync(int32_t fd) { return fsync(fd)<0 ? -errno : 0; }
void mx_exit(int32_t code) { exit(code); }
