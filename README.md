# SplitPro — DAppNode Package

[SplitPro](https://splitpro.app) is a free, open-source app for splitting expenses with friends and groups. This package runs SplitPro on your DAppNode with PostgreSQL, pg_cron for recurring transactions, and your choice of authentication provider.

- **Web UI (local network / VPN):** http://split-pro.public.dappnode:3000
- **Web UI (internet):** https://splitpro.\<hash\>.dyndns.dappnode.io (requires [HTTPS package](https://docs.dappnode.io/user/packages/https))

---

## First-time setup

On first launch the package auto-generates `POSTGRES_PASSWORD` and `NEXTAUTH_SECRET` and stores them in the config volume. These are never shown again — back up the config volume if you need to migrate.

The setup wizard runs on install and asks for your authentication provider credentials. At least one provider must be configured for sign-in to work.

---

## Authentication providers

SplitPro uses [NextAuth](https://next-auth.js.org) for authentication. Providers are enabled by setting the relevant environment variables. The setup wizard lets you choose one provider at install time; you can add more later via **Config** in the DAppNode UI.

Username/password login is not supported. All sign-in flows are passwordless (magic link or OAuth).

### Email (SMTP) — magic link

Users receive a one-time sign-in link by email. No password required.

**Required variables:** `FROM_EMAIL`, `EMAIL_SERVER_HOST`, `EMAIL_SERVER_PORT`, `EMAIL_SERVER_USER`, `EMAIL_SERVER_PASSWORD`

**Common SMTP providers:**

| Provider | Host | Port | Notes |
|---|---|---|---|
| Gmail | smtp.gmail.com | 587 | Use an [App Password](https://myaccount.google.com/apppasswords), not your account password. Requires 2-Step Verification. |
| Resend | smtp.resend.com | 465 | Free tier available. API key as password. |
| Mailgun | smtp.mailgun.org | 587 | Requires domain verification. |
| Brevo | smtp-relay.brevo.com | 587 | Free tier available. |
| Postmark | smtp.postmarkapp.com | 587 | Transactional email focused. |

### Google OAuth

Users sign in with their Google account. No email server needed.

**Required variables:** `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`

**How to get credentials:**

1. Go to [Google Cloud Console](https://console.cloud.google.com) → **APIs & Services → Credentials**
2. Create an **OAuth 2.0 Client ID** (type: Web application)
3. Add your SplitPro URL as an **Authorized redirect URI:**
   `https://splitpro.<hash>.dyndns.dappnode.io/api/auth/callback/google`
   (replace with your custom domain if you have one)
4. Copy the **Client ID** and **Client Secret** into the setup wizard

### OIDC (generic)

Connects to any OpenID Connect provider.

**Required variables:** `OIDC_NAME`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_WELL_KNOWN_URL`

Set `OIDC_WELL_KNOWN_URL` to your provider's discovery endpoint, e.g.:
`https://sso.example.com/.well-known/openid-configuration`

Set redirect URI in your provider to:
`<your-splitpro-url>/api/auth/callback/oidc`

### Keycloak

**Required variables:** `KEYCLOAK_ID`, `KEYCLOAK_SECRET`, `KEYCLOAK_ISSUER`

**How to get credentials:**

1. Keycloak Admin Console → your realm → **Clients → Create**
2. Type: OpenID Connect
3. Set redirect URI: `<your-splitpro-url>/api/auth/callback/keycloak`
4. Under **Credentials** tab, copy the client secret
5. `KEYCLOAK_ISSUER` format: `https://keycloak.example.com/realms/your-realm`

### Authentik

**Required variables:** `AUTHENTIK_ID`, `AUTHENTIK_SECRET`, `AUTHENTIK_ISSUER`

**How to get credentials:**

1. Authentik Admin → **Applications → Providers → Create** (type: OAuth2/OpenID)
2. Set redirect URI: `<your-splitpro-url>/api/auth/callback/authentik`
3. `AUTHENTIK_ISSUER` format: `https://authentik.example.com/application/o/splitpro/`

---

## Accessing SplitPro

### Local network / VPN

Access via the DAppNode VPN or local network:

```
http://split-pro.public.dappnode:3000
```

### DynDNS (default for internet access)

Install the [HTTPS package](https://docs.dappnode.io/user/packages/https). SplitPro automatically detects your DynDNS domain from the `_DAPPNODE_GLOBAL_DOMAIN` environment variable and sets `NEXTAUTH_URL` accordingly. No configuration needed.

Your URL will be:
```
https://splitpro.<hash>.dyndns.dappnode.io
```

### Custom domain

Use this if you want a URL like `https://splitpro.yourdomain.com`.

**Why NEXTAUTH_URL matters:** NextAuth embeds the app URL in magic-link emails and session cookies. Accessing SplitPro from a different URL than `NEXTAUTH_URL` causes login failures and can create separate user accounts per URL. Set `NEXTAUTH_URL` in **SplitPro → Config** to match the URL you browse to.

**Why not a simple A record:** DAppNodes run on residential internet with dynamic IPs. The HTTPS package handles DynDNS certificates, but it uses DAppNode's own certificate signing service which only works for `*.dyndns.dappnode.io` — it cannot issue certificates for external domains you own.

The cleanest solution is **Cloudflare as a proxy**. Cloudflare terminates TLS for your custom domain and resolves your CNAME to the DynDNS name, so the dynamic IP is handled automatically.

#### Option A — Cloudflare Worker (recommended)

Cloudflare's proxied CNAME only forwards traffic on [specific ports](https://developers.cloudflare.com/fundamentals/reference/network-ports/). Port 3000 is not in that list. A Worker bypasses this constraint and is simpler than port forwarding.

**1. Create the Worker**

In Cloudflare dashboard → **Workers & Pages → Create**, deploy:

```js
export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = "splitpro.<hash>.dyndns.dappnode.io";
    url.port = "3000";
    url.protocol = "http:";
    return fetch(url, request);
  }
}
```

Replace `splitpro.<hash>.dyndns.dappnode.io` with your actual DynDNS subdomain.

**2. Add a custom domain to the Worker**

In the Worker's **Settings → Domains & Routes**, add:
```
splitpro.yourdomain.com
```

Cloudflare handles TLS automatically. No router port forwarding needed.

**3. Set NEXTAUTH_URL**

In DAppNode UI → **SplitPro → Config**, set **App URL** to:
```
https://splitpro.yourdomain.com
```

No trailing slash. Save and restart the package.

#### Option B — Cloudflare proxied CNAME with port forwarding

Use this if you prefer not to use Workers, and are willing to expose a Cloudflare-supported port.

**1. Forward a supported port on your router**

Cloudflare proxied connections support ports: 80, 443, 2052, 2053, 2082, 2083, 2086, 2087, 2095, 2096, 8080, 8443, 8880.

Forward one of these (e.g. 8080) from your router to your DAppNode's local IP on port 3000.

**2. Create a CNAME record in Cloudflare**

| Type | Name | Target | Proxy |
|---|---|---|---|
| CNAME | `splitpro` | `splitpro.<hash>.dyndns.dappnode.io` | Proxied (orange cloud) |

**3. Set SSL/TLS mode to Full**

Cloudflare → **SSL/TLS → Overview** → **Full** (not Flexible, not Full Strict).

**4. Set NEXTAUTH_URL** same as Option A.

---

## Backup

The package backs up three volumes:

| Volume | Contents |
|---|---|
| `database` | PostgreSQL data (groups, expenses, users) |
| `uploads` | Receipt images |
| `config` | Auto-generated secrets (POSTGRES_PASSWORD, NEXTAUTH_SECRET) |

Use the DAppNode backup feature or snapshot the volumes manually before any migration.

---

## Troubleshooting

**Sign-in emails are not arriving**
Check SMTP credentials in **Config**. Verify the SMTP host and port are reachable. For Gmail, confirm you are using an App Password, not your account password.

**Magic-link emails link to the wrong URL**
`NEXTAUTH_URL` does not match the URL you are browsing to. Check for a trailing slash or wrong protocol.

**I get a redirect loop on the custom domain**
Cloudflare SSL/TLS mode is set to Flexible. Change it to Full.

**Cloudflare Worker returns 522**
The DynDNS hostname in the Worker is wrong, or the HTTPS package is not running. Verify the DynDNS URL works directly in a browser first.

**I signed up via DynDNS and switched to a custom domain — my account seems missing**
Your account exists. The session cookie is scoped to the old origin. Sign in again with the same email on the new URL — you will land in the same account. No data is lost.

**Recurring transactions are not running**
The package uses pg_cron. Verify the postgres service is healthy and the `pg_cron` extension is loaded (`SHOW shared_preload_libraries` should include `pg_cron`).
