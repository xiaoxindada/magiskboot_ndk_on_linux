#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "tinystdio/tinystdio.h"

#define MIN(a,b) ((a)<(b) ? (a) : (b))

// Hand-rolled base FILE operations

typedef struct file_ptr {
    int fd;
    void *cookie;
    int (*read_fn)(void*, char*, int);
    int (*write_fn)(void*, const char*, int);
    int (*close_fn)(void*);
} file_ptr;

typedef struct buf_holder {
    void *begin;
    void *end;
} buf_holder;

static int fp_read_fn(void *p, char *buf, int sz) {
    intptr_t fd = (intptr_t) p;
    return read(fd, buf, sz);
}

static int fp_write_fn(void *p, const char *buf, int sz) {
    intptr_t fd = (intptr_t) p;
    return write(fd, buf, sz);
}

static int fp_close_fn(void *p) {
    intptr_t fd = (intptr_t) p;
    return close(fd);
}

static int buf_read_fn(void *p, char *buf, int sz) {
    buf_holder *h = (buf_holder *) p;
    size_t len;
    if (h->end) {
        len = MIN(h->begin + sz, h->end) - h->begin;
    } else {
        len = sz;
    }
    if (len) {
        memcpy(buf, h->begin, len);
        h->begin += len;
    }
    return sz;
}

static int buf_write_fn(void *p, const char *buf, int sz) {
    buf_holder *h = (buf_holder *) p;
    size_t len;
    if (h->end) {
        len = MIN(h->begin + sz, h->end) - h->begin;
    } else {
        len = sz;
    }
    if (len) {
        memcpy(h->begin, buf, len);
        h->begin += len;
    }
    return sz;
}

static void set_fp_fd(file_ptr *fp, int fd) {
    fp->fd = fd;
    fp->cookie = NULL;
    fp->read_fn = fp_read_fn;
    fp->write_fn = fp_write_fn;
    fp->close_fn = fp_close_fn;
}

static void set_fp_buf(file_ptr *fp, buf_holder *h) {
    fp->fd = -1;
    fp->cookie = h;
    fp->read_fn = buf_read_fn;
    fp->write_fn = buf_write_fn;
    fp->close_fn = NULL;
}

static file_ptr __stdio_fp[3];

FILE* stdin  = (FILE *) &__stdio_fp[0];
FILE* stdout = (FILE *) &__stdio_fp[1];
FILE* stderr = (FILE *) &__stdio_fp[2];

void __init_stdio(void) {
    set_fp_fd((file_ptr *) stdin, 0);
    set_fp_fd((file_ptr *) stdout, 1);
    set_fp_fd((file_ptr *) stderr, 2);
}

FILE *fopen(const char *path, const char *mode) {
    int flag = 0;
    int mode_flg = 0;
    if (*mode == 'r') {
        flag |= O_RDONLY;
    } else if (*mode == 'w') {
        flag |= O_WRONLY | O_CREAT | O_TRUNC;
    } else if (*mode == 'a') {
        flag |= O_WRONLY | O_CREAT | O_APPEND;
    }
    if (strchr(mode, 'e')) flag |= O_CLOEXEC;
    if (strchr(mode, '+')) {
        flag &= ~O_ACCMODE;
        flag |= O_RDWR;
    }
    if (flag & O_CREAT) mode_flg = 0644;

    int fd = open(path, flag, mode_flg);
    if (fd >= 0) {
        return fdopen(fd, mode);
    }
    return NULL;
}

FILE *fdopen(int fd, const char *mode __attribute__((unused))) {
    file_ptr *fp = malloc(sizeof(file_ptr));
    set_fp_fd(fp, fd);
    return (FILE *) fp;
}

FILE *funopen(const void* cookie,
              int (*read_fn)(void*, char*, int),
              int (*write_fn)(void*, const char*, int),
              fpos_t (*seek_fn)(void*, fpos_t, int),
              int (*close_fn)(void*)) {
    file_ptr *fp = malloc(sizeof(file_ptr));
    fp->fd = -1;
    fp->cookie = (void *) cookie;
    fp->read_fn = read_fn;
    fp->write_fn = write_fn;
    fp->close_fn = close_fn;
    return (FILE *) fp;
}

int ferror(FILE *stream) {
    // We don't report any errors
    return 0;
}

#define fn_arg (fp->fd < 0 ? fp->cookie : ((void*)(intptr_t) fp->fd))

int fclose(FILE *stream) {
    file_ptr *fp = (file_ptr *) stream;
    int ret = 0;
    if (fp->close_fn)
        fp->close_fn(fn_arg);
    free(fp);
    return ret;
}

int fileno(FILE *stream) {
    file_ptr *fp = (file_ptr *) stream;
    return fp->fd;
}

int fputc(int ch, FILE *stream) {
    char c = ch;
    file_ptr *fp = (file_ptr *) stream;
    return fp->write_fn(fn_arg, &c, 1) >= 0 ? 0 : EOF;
}

int putchar(int ch) {
    return fputc(ch, stdout);
}

size_t fwrite(const void* buf, size_t size, size_t count, FILE* stream) {
    file_ptr *fp = (file_ptr *) stream;
    int len = size * count;
    int ret = fp->write_fn(fn_arg, buf, len);
    return ret == len ? count : 0;
}

int fputs(const char* s, FILE* stream) {
    file_ptr *fp = (file_ptr *) stream;
    size_t length = strlen(s);
    return fp->write_fn(fn_arg, s, length) == length ? 0 : EOF;
}

int fgetc(FILE *stream) {
    char ch;
    file_ptr *fp = (file_ptr *) stream;
    if (fp->read_fn(fn_arg, &ch, 1) == 1) {
        return ch;
    }
    return -1;
}

size_t fread(void *buf, size_t size, size_t count, FILE* stream) {
    file_ptr *fp = (file_ptr *) stream;
    int len = size * count;
    int ret = fp->read_fn(fn_arg, buf, len);
    return ret == len ? count : 0;
}

void setbuf(FILE* fp, char* buf) {}

// tfp_vfprintf implementation

struct file_putp {
    FILE *fp;
    int len;
};

static void file_putc(void *data, char ch) {
    struct file_putp *putp = data;
    if (fputc(ch, putp->fp) >= 0) {
        ++putp->len;
    }
}

int tfp_vfprintf(FILE *stream, const char *format, va_list arg) {
    struct file_putp data;
    data.fp = stream;
    data.len = 0;
    tfp_format(&data, &file_putc, format, arg);
    return data.len;
}

// {s,f}printf and sscanf family wrappers

int vasprintf(char **strp, const char *fmt, va_list ap) {
    int size = vsnprintf(NULL, 0, fmt, ap);
    if (size >= 0) {
        *strp = malloc(size + 1);
        vsnprintf(*strp, size, fmt, ap);
    }
    return size;
}

int vsprintf(char *str, const char *fmt, va_list ap) {
    file_ptr file;
    buf_holder h;
    h.begin = str;
    h.end = NULL;
    set_fp_buf(&file, &h);

    int retval = vfprintf((FILE *) &file, fmt, ap);
    if (retval > 0) {
        str[retval] = '\0';
    }
    return retval;
}

int sprintf(char *str, const char *format, ...) {
    va_list ap;
    int retval;

    va_start(ap, format);
    retval = vsprintf(str, format, ap);
    va_end(ap);
    return retval;
}

int vsnprintf(char *str, size_t size, const char *fmt, va_list ap) {
    file_ptr file;
    buf_holder h;
    h.begin = str;
    h.end = str + size;
    set_fp_buf(&file, &h);

    int retval = vfprintf((FILE *) &file, fmt, ap);
    if (retval > 0) {
        str[MIN(size - 1, retval)] = '\0';
    }
    return retval;
}

int snprintf(char *str, size_t size, const char *format, ...) {
    va_list ap;
    int retval;

    va_start(ap, format);
    retval = vsnprintf(str, size, format, ap);
    va_end(ap);
    return retval;
}

int vprintf(const char *fmt, va_list args) {
    return vfprintf(stdout, fmt, args);
}

int fprintf(FILE *stream, const char *fmt, ...) {
    va_list args;
    int ret;

    va_start(args, fmt);
    ret = vfprintf(stream, fmt, args);
    va_end(args);
    return ret;
}

int printf(const char *fmt, ...) {
    va_list args;
    int ret;

    va_start(args, fmt);
    ret = vfprintf(stdout, fmt, args);
    va_end(args);
    return ret;
}

int sscanf(const char *str, const char *format, ...) {
    va_list ap;
    int retval;

    va_start(ap, format);
    retval = vsscanf(str, format, ap);
    va_end(ap);
    return retval;
}

// Original source: https://github.com/freebsd/freebsd/blob/master/contrib/file/src/getline.c
// License: BSD, full copyright notice please check original source
ssize_t getdelim(char **buf, size_t *bufsiz, int delimiter, FILE *fp) {
    char *ptr, *eptr;

    if (*buf == NULL || *bufsiz == 0) {
        *bufsiz = BUFSIZ;
        if ((*buf = (char *) malloc(*bufsiz)) == NULL)
            return -1;
    }

    for (ptr = *buf, eptr = *buf + *bufsiz;;) {
        int c = fgetc(fp);
        if (c == -1) {
            return ptr == *buf ? -1 : ptr - *buf;
        }
        *ptr++ = c;
        if (c == delimiter) {
            *ptr = '\0';
            return ptr - *buf;
        }
        if (ptr + 2 >= eptr) {
            char *nbuf;
            size_t nbufsiz = *bufsiz * 2;
            ssize_t d = ptr - *buf;
            if ((nbuf = (char *) realloc(*buf, nbufsiz)) == NULL)
                return -1;
            *buf = nbuf;
            *bufsiz = nbufsiz;
            eptr = nbuf + nbufsiz;
            ptr = nbuf + d;
        }
    }
}

ssize_t getline(char **buf, size_t *bufsiz, FILE *fp) {
    return getdelim(buf, bufsiz, '\n', fp);
}
