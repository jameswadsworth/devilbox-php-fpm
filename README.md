# Modern Devilbox PHP-FPM Images (PHP 5.6 – 8.5)

[![Build and Publish](https://github.com/jameswadsworth/devilbox-php-fpm/actions/workflows/build-and-publish.yml/badge.svg)](https://github.com/jameswadsworth/devilbox-php-fpm/actions)
[![Registry](https://img.shields.io/badge/registry-ghcr.io-blue)](https://github.com/jameswadsworth/devilbox-php-fpm/pkgs/container/php-fpm)

Modern, maintained, drop-in replacement PHP-FPM images for [Devilbox](https://devilbox.org/) and [devilbox-community](https://github.com/devilbox-community). 

Supplies hardened, multi-architecture (`linux/amd64` and `linux/arm64`) runtimes across all major PHP versions from legacy **5.6** through modern **8.5**.

---

## Why Use These Images?

1. **Security Patched EOL Runtimes:** Official upstream Docker images for PHP 5.6, 7.4, and 8.1 are unmaintained and vulnerable. These images feature in-place source backports applied during build time[cite: 1] against the high-severity **`php2shell` vulnerabilities (CVE-2026-109618, CVE-2026-109619, and CVE-2026-115560)**[cite: 1], verified with the `php2shell-check` audit suite. Modern releases also avoid legacy CGI injection vectors such as **CVE-2024-4577**.
2. **Complete Version Spectrum (5.6 – 8.5):** Run legacy projects requiring PHP 5.6/7.4 and bleeding-edge applications requiring PHP 8.4/8.5 within the exact same Devilbox ecosystem.
3. **Native Apple Silicon & ARM64:** All versions are cross-compiled natively for both `linux/amd64` and `linux/arm64`. Mac users (M1–M4) and ARM server operators get full native execution speed without QEMU emulation or Rosetta penalties.
4. **Matched Debian Foundations:**
   - **PHP 8.1 – 8.5:** Built on **Debian 12 (Bookworm)** with modern OpenSSL 3.x, updated database clients, and current system toolchains[cite: 1].
   - **PHP 7.4:** Built on **Debian 11 (Bullseye)**[cite: 1] with OpenSSL 1.1.1 to preserve engine compatibility.
   - **PHP 5.6:** Built on **Debian 9 (Stretch)** archive mirrors[cite: 1] with OpenSSL 1.0.2[cite: 1] to guarantee legacy compatibility.
5. **100% Devilbox Intranet Compatibility:** Retains complete contract compatibility with Devilbox's diagnostic dashboard. All background daemons (Supervisor, Postfix, Rsyslog, Socat)[cite: 1] and diagnostic probes (`dig`, `nc`, database clients, and CLI wrappers)[cite: 1] pass intranet health checks.

---

## Image Flavours

Each version is compiled into two target flavours:

* **`work` (Recommended for Local Dev):** Complete developer workstation. Includes Node.js[cite: 1], Yarn[cite: 1], frontend CLI tooling (Webpack, Gulp, Grunt, Angular CLI, Vue CLI, Stylelint)[cite: 1], and backend developer packages (Composer[cite: 1], WP-CLI[cite: 1], PHPUnit[cite: 1], Codeception[cite: 1], Deployer[cite: 1], Symfony CLI[cite: 1], Laravel installer[cite: 1]).
* **`prod` (Staging / Intranet):** Minimal, stripped runtime without Node or compilation toolchains[cite: 1]. Ships with core PHP runtimes, daemons, database clients (`default-mysql-client`, `postgresql-client`), and diagnostic probes[cite: 1].

---

## Supported Version Matrix

| PHP Version | Debian Base | Flavours | Architectures | Security Status | Default Toolchains |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **5.6**[cite: 1] | Debian 9 (*Stretch*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | **Patched** (`php2shell` CVEs)[cite: 1] | Node 16[cite: 1], PHPUnit 5.7[cite: 1], Composer 2.2 LTS[cite: 1] |
| **7.4**[cite: 1] | Debian 11 (*Bullseye*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | **Patched** (`php2shell` CVEs)[cite: 1] | Node 22[cite: 1], PHPUnit 9[cite: 1], Composer latest[cite: 1] |
| **8.1**[cite: 1] | Debian 12 (*Bookworm*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | **Patched** (`php2shell` CVEs)[cite: 1] | Node 22[cite: 1], PHPUnit 10[cite: 1], Composer latest[cite: 1] |
| **8.2**[cite: 1] | Debian 12 (*Bookworm*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | Active Release | Node 22[cite: 1], PHPUnit 11[cite: 1], Composer latest[cite: 1] |
| **8.3**[cite: 1] | Debian 12 (*Bookworm*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | Active Release | Node 22[cite: 1], PHPUnit 11[cite: 1], Composer latest[cite: 1] |
| **8.4**[cite: 1] | Debian 12 (*Bookworm*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | Active Release | Node 22[cite: 1], PHPUnit 11[cite: 1], Composer latest[cite: 1] |
| **8.5**[cite: 1] | Debian 12 (*Bookworm*)[cite: 1] | `prod`, `work`[cite: 1] | `amd64`, `arm64` | Active Release | Node 22[cite: 1], PHPUnit 11[cite: 1], Composer latest[cite: 1] |

---

## Configuration in Devilbox

These images use Devilbox's standard tag schema, requiring no changes to `docker-compose.yml` or compose override files.

### 1. Update `.env`

In your Devilbox or Devilbox-Community installation directory, update `.env`:

```env
# 1. Point to this registry
PHP_IMAGE_NS=ghcr.io/jameswadsworth

# 2. Select any version: 5.6, 7.4, 8.1, 8.2, 8.3, 8.4, 8.5
PHP_SERVER=7.4

# 3. Choose flavour: 'work' for local dev, 'prod' for minimal intranet/staging
PHP_IMAGE_TAG=work
