#!/bin/sh
# PHP snippets intentionally use literal single-quoted strings.
# shellcheck disable=SC2016
set -eu

test "$(cat /usr/local/share/php-security-backport)" = 'sury-7.4.33-37-20261119'
# shellcheck source=/dev/null
. /etc/os-release
test "$VERSION_CODENAME" = bookworm
test "$(wc -l < /usr/local/share/php-security/series)" -eq 149
php -r '
if (PHP_VERSION_ID !== 70433) { fwrite(STDERR, "Expected PHP 7.4.33\n"); exit(1); }
if (phpversion("imagick") !== "3.8.1" || phpversion("memcached") !== "3.4.0") { fwrite(STDERR, "Unexpected PECL versions\n"); exit(1); }
if (OPENSSL_VERSION_NUMBER < 0x30000000) { fwrite(STDERR, "Expected system OpenSSL 3\n"); exit(1); }
foreach (["calendar", "gd", "intl", "json", "mbstring", "Zend OPcache", "pcntl", "pdo_pgsql", "pgsql", "xml", "xsl", "zip", "imagick", "memcached", "sodium", "openssl"] as $extension) {
    if (!extension_loaded($extension)) { fwrite(STDERR, "Missing extension: $extension\n"); exit(1); }
}
if (ini_get("max_multipart_body_parts") === false) { fwrite(STDERR, "Missing multipart limit backport\n"); exit(1); }
if (ini_get("session.upload_progress.enabled")) { fwrite(STDERR, "Session upload progress must be disabled\n"); exit(1); }
$data = "security smoke test";
$key = random_bytes(32);
$iv = random_bytes(12);
$ciphertext = openssl_encrypt($data, "aes-256-gcm", $key, OPENSSL_RAW_DATA, $iv, $tag);
if ($ciphertext === false || openssl_decrypt($ciphertext, "aes-256-gcm", $key, OPENSSL_RAW_DATA, $iv, $tag) !== $data) { exit(1); }
$image = new Imagick();
$image->newImage(2, 2, "white", "png");
if (strlen($image->getImageBlob()) === 0) { exit(1); }
$image->clear();
'
php-fpm -t
composer --version --no-ansi

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
