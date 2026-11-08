# Modern Devilbox PHP-FPM Images (PHP 5.6 – 8.5)

[![Build and Publish](https://github.com/jameswadsworth/devilbox-php-fpm/actions/workflows/build-and-publish.yml/badge.svg)](https://github.com/jameswadsworth/devilbox-php-fpm/actions)
[![Registry](https://img.shields.io/badge/registry-ghcr.io-blue)](https://github.com/jameswadsworth/devilbox-php-fpm/pkgs/container/php-fpm)

Modern, maintained, drop-in replacement PHP-FPM images for [Devilbox](https://devilbox.org/) and [devilbox-community](https://github.com/devilbox-community). 

Supplies hardened, multi-architecture (`linux/amd64` and `linux/arm64`) runtimes across all major PHP versions from legacy **5.6** through modern **8.5**.

---

## Why Use These Images?

1. **Security Patched EOL Runtimes:** Official upstream Docker images for PHP 5.6, 7.4, and 8.1 are unmaintained and vulnerable. These images feature in-place source backports applied during build time against the high-severity **`php2shell` vulnerabilities (CVE-2026-109618, CVE-2026-109619, and CVE-2026-115560)**, verified with the `php2shell-check` audit suite. Modern releases also avoid legacy CGI injection vectors such as **CVE-2024-4577**.
2. **Complete Version Spectrum (5.6 – 8.5):** Run legacy projects requiring PHP 5.6/7.4 and bleeding-edge applications requiring PHP 8.4/8.5 within the exact same Devilbox ecosystem.
3. **Native Apple Silicon & ARM64:** All versions are cross-compiled natively for both `linux/amd64` and `linux/arm64`. Mac users (M1–M4) and ARM server operators get full native execution speed without QEMU emulation or Rosetta penalties.
4. **Matched Debian Foundations:**
   - **PHP 8.1 – 8.5:** Built on **Debian 12 (Bookworm)** with modern OpenSSL 3.x, updated database clients, and current system toolchains.
   - **PHP 7.4:** Built on **Debian 11 (Bullseye)** with OpenSSL 1.1.1 to preserve engine compatibility.
   - **PHP 5.6:** Built on **Debian 9 (Stretch)** archive mirrors with OpenSSL 1.0.2 to guarantee legacy compatibility.
5. **100% Devilbox Intranet Compatibility:** Retains complete contract compatibility with Devilbox's diagnostic dashboard. All background daemons (Supervisor, Postfix, Rsyslog, Socat) and diagnostic probes (`dig`, `nc`, database clients, and CLI wrappers) pass intranet health checks.

---

## Image Flavours

Each version is compiled into two target flavours:

* **`work` (Recommended for Local Dev):** Complete developer workstation. Includes Node.js, Yarn, frontend CLI tooling (Webpack, Gulp, Grunt, Angular CLI, Vue CLI, Stylelint), and backend developer packages (Composer, WP-CLI, PHPUnit, Codeception, Deployer, Symfony CLI, Laravel installer).
* **`prod` (Staging / Intranet):** Minimal, stripped runtime without Node or compilation toolchains. Ships with core PHP runtimes, daemons, database clients (`default-mysql-client`, `postgresql-client`), and diagnostic probes.

---

## Supported Version Matrix

| PHP Version | Debian Base | Flavours | Architectures | Security Status | Default Toolchains |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **5.6** | Debian 9 (*Stretch*) | `prod`, `work` | `amd64`, `arm64` | **Patched** (`php2shell` CVEs) | Node 16, PHPUnit 5.7, Composer 2.2 LTS |
| **7.4** | Debian 11 (*Bullseye*) | `prod`, `work` | `amd64`, `arm64` | **Patched** (`php2shell` CVEs) | Node 22, PHPUnit 9, Composer latest |
| **8.1** | Debian 12 (*Bookworm*) | `prod`, `work` | `amd64`, `arm64` | **Patched** (`php2shell` CVEs) | Node 22, PHPUnit 10, Composer latest |
| **8.2** | Debian 12 (*Bookworm*) | `prod`, `work` | `amd64`, `arm64` | Active Release | Node 22, PHPUnit 11, Composer latest |
| **8.3** | Debian 12 (*Bookworm*) | `prod`, `work` | `amd64`, `arm64` | Active Release | Node 22, PHPUnit 11, Composer latest |
| **8.4** | Debian 12 (*Bookworm*) | `prod`, `work` | `amd64`, `arm64` | Active Release | Node 22, PHPUnit 11, Composer latest |
| **8.5** | Debian 12 (*Bookworm*) | `prod`, `work` | `amd64`, `arm64` | Active Release | Node 22, PHPUnit 11, Composer latest |

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
```

### 2. Pull and Launch

```bash
docker compose pull php
docker compose up -d php
```

---

## Verifying the Deployment

Run these inside the container to confirm version mapping and toolchain health:

```bash
# Check runtime version and patch integrity
docker compose exec php php -v

# Verify devilbox user mapping (1000:1000)
docker compose exec php id

# Check frontend toolchains (work flavour)
docker compose exec php node -v
docker compose exec php yarn -v
docker compose exec php webpack-cli --version

# Check PHP tooling
docker compose exec php composer --version
docker compose exec php phpunit --version
```

Open `http://localhost/` in your browser to verify that the Devilbox Intranet diagnostic overview displays green checkmarks for all background services and system shims.