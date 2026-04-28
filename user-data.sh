#!/bin/bash
# ============================================================
# EC2 Instance Info Dashboard - User Data Script
# Runs automatically on first boot via EC2 User Data
# Displays live instance metadata + VPC/subnet info in browser
# ============================================================

# Update system and install Apache
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# ── Fetch instance metadata using IMDSv2 ────────────────────
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

FETCH() {
  curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/$1"
}

INSTANCE_ID=$(FETCH instance-id)
INSTANCE_TYPE=$(FETCH instance-type)
AZ=$(FETCH placement/availability-zone)
REGION=$(FETCH placement/region)
PUBLIC_IP=$(FETCH public-ipv4)
PRIVATE_IP=$(FETCH local-ipv4)
AMI_ID=$(FETCH ami-id)
HOSTNAME=$(FETCH public-hostname)
MAC=$(FETCH mac)

# ── VPC & Subnet metadata (fetched via MAC address) ─────────
VPC_ID=$(FETCH network/interfaces/macs/$MAC/vpc-id)
SUBNET_ID=$(FETCH network/interfaces/macs/$MAC/subnet-id)
VPC_CIDR=$(FETCH network/interfaces/macs/$MAC/vpc-ipv4-cidr-block)
SUBNET_CIDR=$(FETCH network/interfaces/macs/$MAC/subnet-ipv4-cidr-block)

LAUNCH_TIME=$(date)

# ── Write the HTML dashboard ─────────────────────────────────
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>EC2 Instance Dashboard</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap');

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --bg: #0d1117;
      --surface: #161b22;
      --surface2: #1c2128;
      --border: #30363d;
      --accent: #58a6ff;
      --accent2: #3fb950;
      --accent3: #e3b341;
      --accent4: #bc8cff;
      --text: #c9d1d9;
      --muted: #8b949e;
    }

    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'IBM Plex Sans', sans-serif;
      min-height: 100vh;
      padding: 2rem 1rem;
    }

    .container { max-width: 900px; margin: 0 auto; }

    header {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin-bottom: 2.5rem;
      padding-bottom: 1.5rem;
      border-bottom: 1px solid var(--border);
    }

    .status-dot {
      width: 10px; height: 10px;
      border-radius: 50%;
      background: var(--accent2);
      box-shadow: 0 0 8px var(--accent2);
      flex-shrink: 0;
      animation: pulse 2s ease-in-out infinite;
    }

    @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }

    h1 { font-size: 1.25rem; font-weight: 600; color: #fff; letter-spacing: -0.01em; }
    .subtitle { font-size: 0.8rem; color: var(--muted); font-family: 'IBM Plex Mono', monospace; margin-top: 2px; }

    .badge {
      margin-left: auto;
      background: rgba(88,166,255,0.1);
      border: 1px solid rgba(88,166,255,0.3);
      color: var(--accent);
      font-size: 0.72rem;
      padding: 3px 10px;
      border-radius: 20px;
      font-family: 'IBM Plex Mono', monospace;
    }

    .section-title {
      font-size: 0.72rem;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: var(--muted);
      margin: 2rem 0 0.65rem;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 1px;
      background: var(--border);
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
      margin-bottom: 0.5rem;
    }

    .card {
      background: var(--surface);
      padding: 1.1rem 1.4rem;
      transition: background 0.15s;
    }
    .card:hover { background: var(--surface2); }

    .card-label {
      font-size: 0.7rem;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--muted);
      margin-bottom: 0.45rem;
    }

    .card-value {
      font-family: 'IBM Plex Mono', monospace;
      font-size: 0.9rem;
      color: #fff;
      word-break: break-all;
    }

    .card-value.blue   { color: var(--accent); }
    .card-value.green  { color: var(--accent2); }
    .card-value.yellow { color: var(--accent3); }
    .card-value.purple { color: var(--accent4); }

    /* VPC section gets a subtle purple tint on the container */
    .vpc-section .grid {
      border-color: rgba(188,140,255,0.25);
      background: rgba(188,140,255,0.06);
    }
    .vpc-section .card { background: rgba(188,140,255,0.04); }
    .vpc-section .card:hover { background: rgba(188,140,255,0.09); }

    footer {
      margin-top: 3rem;
      padding-top: 1.5rem;
      border-top: 1px solid var(--border);
      font-size: 0.75rem;
      color: var(--muted);
      display: flex;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 0.5rem;
    }
    footer a { color: var(--accent); text-decoration: none; }
    footer a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="container">

    <header>
      <div class="status-dot"></div>
      <div>
        <h1>EC2 Instance Dashboard</h1>
        <div class="subtitle">Live metadata · Amazon Web Services</div>
      </div>
      <div class="badge">running</div>
    </header>

    <p class="section-title">Identity</p>
    <div class="grid">
      <div class="card">
        <div class="card-label">Instance ID</div>
        <div class="card-value blue">$INSTANCE_ID</div>
      </div>
      <div class="card">
        <div class="card-label">Instance Type</div>
        <div class="card-value">$INSTANCE_TYPE</div>
      </div>
      <div class="card">
        <div class="card-label">AMI ID</div>
        <div class="card-value">$AMI_ID</div>
      </div>
    </div>

    <p class="section-title">Location</p>
    <div class="grid">
      <div class="card">
        <div class="card-label">AWS Region</div>
        <div class="card-value yellow">$REGION</div>
      </div>
      <div class="card">
        <div class="card-label">Availability Zone</div>
        <div class="card-value yellow">$AZ</div>
      </div>
    </div>

    <p class="section-title">Networking — Elastic Network Interface</p>
    <div class="grid">
      <div class="card">
        <div class="card-label">Public IP</div>
        <div class="card-value green">$PUBLIC_IP</div>
      </div>
      <div class="card">
        <div class="card-label">Private IP</div>
        <div class="card-value">$PRIVATE_IP</div>
      </div>
      <div class="card">
        <div class="card-label">Public Hostname</div>
        <div class="card-value">$HOSTNAME</div>
      </div>
    </div>

    <div class="vpc-section">
      <p class="section-title">VPC &amp; Subnet</p>
      <div class="grid">
        <div class="card">
          <div class="card-label">VPC ID</div>
          <div class="card-value purple">$VPC_ID</div>
        </div>
        <div class="card">
          <div class="card-label">VPC CIDR</div>
          <div class="card-value purple">$VPC_CIDR</div>
        </div>
        <div class="card">
          <div class="card-label">Subnet ID</div>
          <div class="card-value purple">$SUBNET_ID</div>
        </div>
        <div class="card">
          <div class="card-label">Subnet CIDR</div>
          <div class="card-value purple">$SUBNET_CIDR</div>
        </div>
      </div>
    </div>

    <p class="section-title">Boot Info</p>
    <div class="grid">
      <div class="card">
        <div class="card-label">User Data Executed At</div>
        <div class="card-value">$LAUNCH_TIME</div>
      </div>
    </div>

    <footer>
      <span>Apache on Amazon Linux 2 &mdash; auto-deployed via EC2 User Data</span>
      <a href="https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html" target="_blank">AWS User Data Docs →</a>
    </footer>

  </div>
</body>
</html>
EOF

echo "Dashboard deployed at $(date)" >> /var/log/user-data-dashboard.log
