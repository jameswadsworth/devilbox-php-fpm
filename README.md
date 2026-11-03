# Devilbox PHP-FPM (Debian Bookworm)

Modern, maintained, drop-in replacement PHP-FPM images for [Devilbox](https://devilbox.org/). Built on Debian 12 (Bookworm) with multi-architecture support (`linux/amd64` and `linux/arm64`).

## Flavours

- **`prod`**: Hardened, minimal image designed for intranet and staging setups. Includes core background daemons (Supervisor, Postfix, Rsyslog, Socat), database clients (`default-mysql-client`, `postgresql-client`), and Devilbox diagnostic probes (`dig`, `nc`), with zero developer tooling bloat.
- **`work`**: Complete local development workstation. Inherits from `prod` and adds Node.js 22 LTS, Yarn, frontend build tools (Webpack, Gulp, Grunt, Angular CLI, Vue CLI, Stylelint), and backend tools (Composer, WP-CLI, PHPUnit, Deployer, Symfony CLI, Laravel installer).

## Quick Start with Devilbox

Update your `.env` file in your Devilbox installation:

\`\`\`env
# Point to this registry
PHP_IMAGE_NS=ghcr.io/your-username

# Choose version: 8.1, 8.2, 8.3, 8.4
PHP_SERVER=8.2

# Choose flavour: 'work' for local dev, 'prod' for intranet/staging
PHP_IMAGE_TAG=work
\`\`\`

Then pull and start the container:

\`\`\`bash
docker compose pull php
docker compose up -d php
\`\`\`
