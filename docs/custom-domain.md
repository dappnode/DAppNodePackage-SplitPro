# Accessing SplitPro with a Custom Domain

SplitPro on DAppNode supports three access methods:

| Method | URL example | Requires |
|---|---|---|
| Local network | `http://split-pro.public.dappnode:3000` | DAppNode VPN or LAN access |
| DynDNS (default) | `https://splitpro.<hash>.dyndns.dappnode.io` | HTTPS package |
| Custom domain | `https://splitpro.yourdomain.com` | Domain + Cloudflare |

---

## Why NEXTAUTH_URL matters

SplitPro uses NextAuth for authentication. NextAuth embeds the app URL into magic-link emails and session cookies. If you access SplitPro from a URL that doesn't match `NEXTAUTH_URL`, logins will fail and you may end up with separate user accounts depending on which URL was used to sign up.

`NEXTAUTH_URL` must match the URL you browse to.

By default, SplitPro auto-detects the DynDNS URL from the `_DAPPNODE_GLOBAL_DOMAIN` environment variable that DAppNode injects into all packages. You only need to configure `NEXTAUTH_URL` manually if you want to use a custom domain.

---

## Option 1: DynDNS (default, no configuration needed)

Install the [HTTPS package](https://docs.dappnode.io/user/packages/https) and SplitPro will automatically be reachable at:

```
https://splitpro.<your-hash>.dyndns.dappnode.io
```

`NEXTAUTH_URL` is set automatically. Nothing else to configure.

---

## Option 2: Custom domain via Cloudflare

Use this if you want a stable, readable URL like `https://splitpro.yourdomain.com`.

### Why Cloudflare

DAppNodes typically run on residential internet connections with dynamic IP addresses. DAppNode's DynDNS service (`<hash>.dyndns.dappnode.io`) tracks the current IP automatically. The HTTPS package can issue TLS certificates for DynDNS subdomains because DAppNode controls that DNS zone — but it cannot issue certificates for external domains you own.

Cloudflare solves both problems: it proxies traffic through its own network (providing TLS for your custom domain), and resolves your CNAME to the DynDNS name so the dynamic IP is not a problem.

### Prerequisites

- A domain managed by [Cloudflare](https://cloudflare.com) (free plan works)
- The HTTPS package installed on your DAppNode (so DynDNS is active)
- Your DynDNS subdomain (visible in the HTTPS package UI, format: `<hash>.dyndns.dappnode.io`)

### Approach A — Cloudflare Worker (recommended)

Cloudflare's proxied CNAME only forwards traffic on [specific ports](https://developers.cloudflare.com/fundamentals/reference/network-ports/). Port 3000 is not in that list. A Cloudflare Worker bypasses this constraint entirely and is simpler to set up than port forwarding.

**1. Create the Worker**

In the Cloudflare dashboard, go to **Workers & Pages → Create** and deploy this script:

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

**2. Add a custom route**

In the Worker's **Triggers** tab, add a custom domain or route:

```
splitpro.yourdomain.com/*
```

Cloudflare will handle TLS for `splitpro.yourdomain.com` automatically. No SSL/TLS mode change needed. No router port forwarding needed.

**3. Set NEXTAUTH_URL**

In the DAppNode UI, go to **SplitPro → Config** and set:

**App URL:** `https://splitpro.yourdomain.com`

Include `https://` and no trailing slash. Save and restart the package.

---

### Approach B — Cloudflare proxied CNAME with port forwarding

Use this if you prefer not to use Workers.

**1. Forward port 3000 on your router**

In your router's port forwarding settings, forward external TCP port 3000 to your DAppNode's local IP address on port 3000.

**2. Create a CNAME record in Cloudflare**

In the Cloudflare DNS dashboard for your domain, add:

| Type | Name | Target | Proxy |
|---|---|---|---|
| CNAME | `splitpro` | `splitpro.<hash>.dyndns.dappnode.io` | Proxied (orange cloud) |

The **Proxied** toggle is essential — it provides TLS for your domain and hides your IP.

**3. Set Cloudflare SSL/TLS mode**

In Cloudflare, go to **SSL/TLS → Overview** and set the mode to **Full**.

- **Flexible** causes redirect loops
- **Full (strict)** requires a valid cert on the origin (DAppNode won't have one for your domain)
- **Full** is correct

Note: Cloudflare proxied connections only reach the origin on [specific ports](https://developers.cloudflare.com/fundamentals/reference/network-ports/). Port 3000 is not supported. You would need to change SplitPro's exposed port to one that Cloudflare supports (e.g. 8080) and update your router forwarding accordingly. This is why Approach A (Worker) is simpler.

**4. Set NEXTAUTH_URL**

Same as Approach A: set **App URL** to `https://splitpro.yourdomain.com` in **SplitPro → Config**, save, and restart.

---

## Troubleshooting

**Magic-link emails link to the wrong URL**
`NEXTAUTH_URL` in Config does not match your actual URL. Check for a trailing slash or wrong protocol.

**I get a redirect loop**
Cloudflare SSL/TLS mode is set to Flexible. Change it to Full (Approach B only).

**Worker returns a 522 or connection error**
The DynDNS hostname in the Worker script is wrong, or the HTTPS package is not running. Verify the DynDNS URL is reachable directly in a browser first.

**Port forwarding doesn't work (Approach B)**
Port 3000 is not in Cloudflare's supported origin port list. Switch to Approach A (Worker), or change SplitPro's exposed port to 8080 in docker-compose.yml and update the router rule.

**I signed up via DynDNS and now use a custom domain — my account seems missing**
Your account exists but the session cookie doesn't carry across origins. Sign in again with the same email on the new URL. Both sessions share the same database — no data is lost.
