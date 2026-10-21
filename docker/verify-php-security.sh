#!/bin/sh
set -eu

test "$(cat /usr/local/share/php-security-backport)" = '712e60f9edfd03f0960fc4fc3c2c375f42b90aa2'
php -r '
if (PHP_VERSION_ID !== 70433) { fwrite(STDERR, "Expected PHP 7.4.33\n"); exit(1); }
foreach (["calendar", "gd", "intl", "json", "mbstring", "Zend OPcache", "pcntl", "pdo_pgsql", "pgsql", "xml", "xsl", "zip", "imagick", "memcached", "sodium", "openssl"] as $extension) {
    if (!extension_loaded($extension)) { fwrite(STDERR, "Missing extension: $extension\n"); exit(1); }
}
'
php-fpm -t

# The EOL backport must terminate immediately on OOM instead of running PHP
# shutdown callbacks against potentially partially initialized request state.
status=0
output="$(php -n -d memory_limit=8M -r 'register_shutdown_function(function () { echo "UNSAFE_SHUTDOWN_CALLBACK\n"; }); str_repeat("x", 32 * 1024 * 1024);' 2>&1)" || status=$?
test "$status" -eq 1
printf '%s\n' "$output" | grep -q 'Allowed memory size'
if printf '%s\n' "$output" | grep -q 'UNSAFE_SHUTDOWN_CALLBACK'; then
    echo 'Security regression: OOM executed a shutdown callback' >&2
    exit 1
fi
echo 'PHP 7.4.33 security backport and runtime checks passed'
