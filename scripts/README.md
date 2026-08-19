# TrueNAS Scale Certificate Renewal with smallstep

Simple automated certificate renewal for TrueNAS Scale using your smallstep ACME server.

## What You Need

**Just 2 scripts:**
1. `coredns-dns01-challenge.sh` - DNS challenge script (if using DNS-01 with TrueNAS built-in ACME)
2. `truenas-cert-renewal-stepcli.sh` - Main renewal script using step-cli

**Optional:**
- `truenas-cert-renewal.service` + `.timer` - For automated renewal

## Quick Setup

### Step 1: Install step-cli

```bash
# Visit https://smallstep.com/docs/step-cli/installation/ for your OS
# Or on Debian/Ubuntu:
curl -LO https://github.com/smallstep/cli/releases/latest/download/step-cli_linux_amd64.tar.gz
tar xzf step-cli_linux_amd64.tar.gz
sudo mv step-cli_*/bin/step /usr/local/bin/step-cli
```

### Step 2: Get Your Root CA Certificate

You need the root CA certificate from your smallstep server. If you don't have it:

```bash
# From your smallstep server or LXC container
step ca root root-ca.crt
```

Copy it to the system where you'll run the renewal script.

### Step 3: Create TrueNAS API Key

1. Log into TrueNAS Scale web UI
2. Go to **Credentials > API Keys**
3. Click **Add** to create a new API key
4. Copy the generated API key (you won't see it again!)

### Step 4: Install the Scripts

```bash
# Copy the renewal script
sudo cp truenas-cert-renewal-stepcli.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/truenas-cert-renewal-stepcli.sh

# Copy systemd files (for automation)
sudo cp truenas-cert-renewal.service /etc/systemd/system/
sudo cp truenas-cert-renewal.timer /etc/systemd/system/
```

### Step 5: Configure Environment

Create config file:

```bash
sudo mkdir -p /etc/truenas-cert-renewal
sudo nano /etc/truenas-cert-renewal/env.conf
```

Add:

```ini
DOMAIN=truenas.home.lab
TRUENAS_HOST=192.168.1.100
TRUENAS_API_KEY=your-api-key-here
CA_URL=https://ca.home.lab
ROOT_CA_PATH=/path/to/root-ca.crt
CERT_NAME=truenas-cert
```

**Important:** Secure the config file:
```bash
sudo chmod 600 /etc/truenas-cert-renewal/env.conf
```

### Step 6: Test Manually

```bash
sudo /usr/local/bin/truenas-cert-renewal-stepcli.sh \
    truenas.home.lab \
    192.168.1.100 \
    <your-api-key> \
    https://ca.home.lab \
    /path/to/root-ca.crt \
    truenas-cert
```

### Step 7: Enable Automated Renewal

```bash
sudo systemctl daemon-reload
sudo systemctl enable truenas-cert-renewal.timer
sudo systemctl start truenas-cert-renewal.timer

# Check status
sudo systemctl status truenas-cert-renewal.timer
```

### Step 8: Apply Certificate in TrueNAS

After the certificate is uploaded:

1. Go to **System > General**
2. Under "UI Certificate", select your certificate
3. Save

## Using TrueNAS Built-in ACME with DNS-01 (Optional)

The `coredns-dns01-challenge.sh` script is only needed if you want to use TrueNAS's built-in ACME DNS authenticator.

**Note:** 
- TrueNAS's built-in ACME may only support Let's Encrypt, not custom ACME servers like smallstep
- The main `truenas-cert-renewal-stepcli.sh` script uses step-cli's provisioner authentication (not DNS-01), so it doesn't need the DNS script

If you want to try TrueNAS built-in ACME:

1. Copy `coredns-dns01-challenge.sh` to TrueNAS
2. Edit it to set your zone file path (line 27)
3. In TrueNAS UI: **Credentials > Certificates > ACME DNS-Authenticators**
4. Add as Shell authenticator
5. Create certificate via UI

## Troubleshooting

### step-cli Authentication

`step-cli` uses provisioner tokens for authentication. You may need to:

1. Get a provisioner token from your smallstep server
2. Authenticate: `step ca bootstrap --ca-url https://ca.home.lab --fingerprint <fingerprint>`
3. Or use: `step ca certificate --provisioner <name> --provisioner-password-file <file>`

### Certificate Not Uploading

- Verify TrueNAS API key is correct
- Check that TrueNAS host is reachable
- Ensure API access is enabled in TrueNAS

### View Logs

```bash
sudo journalctl -u truenas-cert-renewal.service -f
```

## Files

- `truenas-cert-renewal-stepcli.sh` - Main renewal script
- `coredns-dns01-challenge.sh` - DNS-01 script (for TrueNAS built-in ACME)
- `truenas-cert-renewal.service` - Systemd service
- `truenas-cert-renewal.timer` - Systemd timer (runs daily)

## Additional Resources

- [step-cli Documentation](https://smallstep.com/docs/step-cli/)
- [TrueNAS API Documentation](https://www.truenas.com/docs/scale/api/)
