/* Binary OS I/O only, no XPORT/CSV/numeric interpretation. */
#define _XOPEN_SOURCE 700
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

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
int64_t mx_tell(int32_t fd) {
  off_t position = lseek(fd, 0, SEEK_CUR);
  return position < 0 ? -(int64_t)errno : (int64_t)position;
}
int32_t mx_seek(int32_t fd, int64_t offset) {
  if (offset < 0 || (int64_t)(off_t)offset != offset) return -EOVERFLOW;
  return lseek(fd, (off_t)offset, SEEK_SET) < 0 ? -errno : 0;
}
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

int32_t mx_temp(uint8_t *path) {
  int fd=mkstemp((char *)path);
  return fd<0 ? -errno : fd;
}
int32_t mx_exists(const uint8_t *path) {
  struct stat st;
  if (lstat((const char *)path,&st)==0) return S_ISDIR(st.st_mode) ? -EISDIR : 1;
  return errno==ENOENT ? 0 : -errno;
}
int32_t mx_rename(const uint8_t *a,const uint8_t *b) {
  return rename((const char *)a,(const char *)b)<0 ? -errno : 0;
}
int32_t mx_link(const uint8_t *a,const uint8_t *b) {
  return link((const char *)a,(const char *)b)<0 ? -errno : 0;
}
int32_t mx_remove(const uint8_t *path) {
  return unlink((const char *)path)<0 && errno!=ENOENT ? -errno : 0;
}
static char *mx_canonical(const char *path) {
  char *resolved=realpath(path,NULL);
  if (resolved || errno!=ENOENT) return resolved;
  char *copy=strdup(path);
  if (!copy) return NULL;
  char *slash=strrchr(copy,'/');
  const char *base=slash ? slash+1 : copy;
  char *name=strdup(base);
  if (!name) { free(copy); return NULL; }
  if (slash) *slash='\0';
  const char *parent=slash ? (slash==copy ? "/" : copy) : ".";
  char *dir=realpath(parent,NULL);
  if (dir) {
    size_t n=strlen(dir)+strlen(name)+2;
    resolved=malloc(n);
    if (resolved) snprintf(resolved,n,"%s/%s",dir,name);
  }
  int saved=errno;
  free(dir);free(name);free(copy);errno=saved;
  return resolved;
}
int32_t mx_same(const uint8_t *a,const uint8_t *b) {
  struct stat sa,sb;
  if (stat((const char *)a,&sa)==0 && stat((const char *)b,&sb)==0 && sa.st_dev==sb.st_dev && sa.st_ino==sb.st_ino) return 1;
  char *aa=mx_canonical((const char *)a);
  if (!aa) return -errno;
  char *bb=mx_canonical((const char *)b);
  if (!bb) { int e=errno;free(aa);return -e; }
  int result=strcmp(aa,bb)==0;
  free(aa);free(bb);return result;
}
int32_t mx_remove_same(const uint8_t *path,const uint8_t *owned) {
  struct stat a,b;
  if (lstat((const char *)path,&a)<0) return errno==ENOENT ? 0 : -errno;
  if (lstat((const char *)owned,&b)<0) return -errno;
  if (a.st_dev!=b.st_dev || a.st_ino!=b.st_ino) return -EEXIST;
  return mx_remove(path);
}
