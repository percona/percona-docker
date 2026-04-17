/*
 * libsystemd-stub.c — no-op libsystemd.so.0 replacement for containers.
 *
 * Percona Server's mysqld is compiled with HAVE_SYSTEMD_NOTIFY and has
 * unconditional sd_notifyf() calls in the startup path. In a container
 * there is no systemd to notify, but libsystemd.so.0 must still be
 * loadable and must provide the sd_* symbols mysqld imports. We ship
 * this stub instead of the real libsystemd0 package file to kill its
 * CVE surface (CVE-2026-29111 et al.). All functions return 0 with
 * empty bodies, matching the behavior the real libsystemd exhibits
 * when NOTIFY_SOCKET is unset (which is always the case in Docker).
 *
 * Build:
 *   gcc -shared -fPIC -Wl,-soname,libsystemd.so.0 \
 *       -o libsystemd.so.0 libsystemd-stub.c
 *
 * Install:
 *   cp libsystemd.so.0 /usr/lib/x86_64-linux-gnu/libsystemd.so.0
 */

#include <stddef.h>

int sd_notify(int unset_env, const char *state) {
    (void)unset_env; (void)state; return 0;
}

int sd_notifyf(int unset_env, const char *format, ...) {
    (void)unset_env; (void)format; return 0;
}

int sd_pid_notify(int pid, int unset_env, const char *state) {
    (void)pid; (void)unset_env; (void)state; return 0;
}

int sd_pid_notifyf(int pid, int unset_env, const char *format, ...) {
    (void)pid; (void)unset_env; (void)format; return 0;
}

int sd_pid_notify_with_fds(int pid, int unset_env, const char *state,
                           const int *fds, unsigned n_fds) {
    (void)pid; (void)unset_env; (void)state; (void)fds; (void)n_fds;
    return 0;
}

int sd_booted(void) {
    return 0;
}

int sd_watchdog_enabled(int unset_env, unsigned long long *usec) {
    (void)unset_env;
    if (usec) *usec = 0;
    return 0;
}

int sd_listen_fds(int unset_env) {
    (void)unset_env; return 0;
}

int sd_listen_fds_with_names(int unset_env, char ***names) {
    (void)unset_env;
    if (names) *names = NULL;
    return 0;
}

int sd_is_socket(int fd, int family, int type, int listening) {
    (void)fd; (void)family; (void)type; (void)listening; return 0;
}

int sd_is_socket_unix(int fd, int type, int listening,
                      const char *path, size_t length) {
    (void)fd; (void)type; (void)listening; (void)path; (void)length;
    return 0;
}

int sd_is_socket_inet(int fd, int family, int type, int listening,
                      unsigned short port) {
    (void)fd; (void)family; (void)type; (void)listening; (void)port;
    return 0;
}

int sd_is_mq(int fd, const char *path) {
    (void)fd; (void)path; return 0;
}

int sd_is_fifo(int fd, const char *path) {
    (void)fd; (void)path; return 0;
}

int sd_is_special(int fd, const char *path) {
    (void)fd; (void)path; return 0;
}
