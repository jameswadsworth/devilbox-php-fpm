# Modern Devilbox PHP-FPM Images (Debian Bookworm)

[![Build and Publish](https://github.com/jameswadsworth/devilbox-php-fpm/actions/workflows/build-and-publish.yml/badge.svg)](https://github.com/jameswadsworth/devilbox-php-fpm/actions)
[![Registry](https://img.shields.io/badge/registry-ghcr.io-blue)](https://github.com/jameswadsworth/devilbox-php-fpm/pkgs/container/php-fpm)

Modern, maintained, drop-in replacement PHP-FPM images for [Devilbox](https://devilbox.org/) and [devilbox-community](https://github.com/devilbox-community). 

Built directly on **Debian 12 (Bookworm)** with multi-architecture support (`linux/amd64` and `linux/arm64`).

---

## Why Use These Images?

1. **Security Patched Upstream:** Legacy Cytopia images have not been rebuilt in years and remain vulnerable to critical engine vulnerabilities—including **CVE-2024-4577** (PHP-CGI argument injection leading to RCE / shell escapes). These builds use active PHP minor releases compiled against modern system libraries.
2. **PHP 8.5 Availability:** Provides bleeding-edge **PHP 8.5** alongside actively supported versions (8.2, 8.3, and 8.4), none of which were fully available or maintained in upstream Devilbox.
3. **Native Apple Silicon & ARM64 Support:** Fully cross-compiled for both `linux/amd64` (Intel/AMD) and `linux/arm64` (Apple Silicon M1–M4 and ARM servers). No emulation penalties or Rosetta overhead.
4. **Debian 12 (Bookworm) Base:** Modern glibc, OpenSSL 3.x, updated database clients (`default-mysql-client`, `postgresql-client-15+`), and current diagnostic tools.
5. **Full Intranet Compatibility:** Retains 100% contract compatibility with Devilbox's intranet dashboard. All background daemons (Supervisor, Postfix, Rsyslog, Socat) and diagnostic probes (`dig`, `nc`, `webpack-cli`, `wp-cli`, etc.) report green.

---

## Image Flavours

Each PHP version is published in two flavours:

* **`work` (Recommended for Local Dev):** Complete developer workstation. Includes Node.js 22 LTS, Yarn, frontend CLI tools (Webpack, Gulp, Grunt, Angular CLI, Vue CLI, Stylelint), and backend tooling (Composer, WP-CLI, PHPUnit 11, Deployer, Symfony CLI, Laravel installer).
* **`prod` (Staging / Intranet):** Minimal, hardened image without Node or build toolchains. Contains only core runtimes, daemons, database clients, and diagnostic tools.

---

## Supported Versions

| PHP Version | Flavours Available | Architectures |
| :--- | :--- | :--- |
| **8.2** | `8.2-work`, `8.2-prod` | `linux/amd64`, `linux/arm64` |
| **8.3** | `8.3-work`, `8.3-prod` | `linux/amd64`, `linux/arm64` |
| **8.4** | `8.4-work`, `8.4-prod` | `linux/amd64`, `linux/arm64` |
| **8.5** | `8.5-work`, `8.5-prod` | `linux/amd64`, `linux/arm64` |

---

## Configuration Guide

Because these images follow the standard Devilbox image tag naming convention, **no changes to `docker-compose.yml` or compose override files are required**.

### 1. Update Your `.env` File

Open the `.env` file in your Devilbox or Devilbox-Community installation directory and update the following variables:

```env
# 1. Point to this GitHub Container Registry namespace
PHP_IMAGE_NS=ghcr.io/jameswadsworth

# 2. Select the PHP version you need (8.2, 8.3, 8.4, or 8.5)
PHP_SERVER=8.4

# 3. Choose the flavour ('work' for local dev, 'prod' for minimal staging)
PHP_IMAGE_TAG=work
