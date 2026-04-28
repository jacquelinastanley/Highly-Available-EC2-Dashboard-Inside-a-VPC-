# 🖥️ EC2 Instance Info Dashboard

> Launch an EC2 instance inside a custom VPC that automatically serves a live metadata dashboard in your browser — no SSH required.

A beginner-friendly AWS project demonstrating how to use **EC2 User Data scripts** to bootstrap a web server inside a custom **VPC with public subnets**. The dashboard displays real-time instance metadata including VPC ID, Subnet ID, CIDR blocks, IP addresses, and more — all fetched at boot time.

---

## 📸 What You'll Build

A dark-themed web dashboard auto-deployed on your EC2 instance, showing:

| Section | Fields |
|---|---|
| **Identity** | Instance ID, Instance Type, AMI ID |
| **Location** | AWS Region, Availability Zone |
| **Networking** | Public IP, Private IP, Public Hostname |
| **VPC & Subnet** | VPC ID, VPC CIDR, Subnet ID, Subnet CIDR |
| **Boot Info** | User Data execution timestamp |

---

## 🏗️ Architecture

```
Internet
    │  (HTTP port 80)
    ▼
Security Group (WebDashboardSG)
    │
    ▼
┌─────────────────────────────────────┐
│  VPC  (10.0.0.0/16)                 │
│  ┌───────────────────────────────┐  │
│  │  Public Subnet (10.0.1.0/24) │  │
│  │  Availability Zone: us-east-1a│  │
│  │                               │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  EC2 t2.micro           │  │  │
│  │  │  Apache + Dashboard     │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
│  Internet Gateway                   │
└─────────────────────────────────────┘
```

---

## 🗂️ Project Structure

```
aws-ec2-dashboard/
├── scripts/
│   └── user-data.sh     # User Data script — paste into EC2 launch wizard
└── README.md
```

---

## ⚡ Quick Start

### Prerequisites
- An AWS account ([free tier](https://aws.amazon.com/free/) works perfectly)
- Basic familiarity with the AWS Console

---

### Part 1 — Set Up the VPC

Before launching EC2, you need a VPC with a public subnet and internet gateway.

#### Option A: Use an Existing VPC
If you already have a VPC with a public subnet and internet gateway (e.g. `LabVpc` from a lab environment), skip to Part 2.

#### Option B: Create a New VPC

1. Go to **VPC Console → Your VPCs → Create VPC**

2. Select **"VPC and more"** (creates everything in one shot):

   | Setting | Value |
   |---|---|
   | Name tag | `my-dashboard-vpc` |
   | IPv4 CIDR | `10.0.0.0/16` |
   | Number of AZs | `1` |
   | Public subnets | `1` |
   | Private subnets | `0` |
   | NAT gateways | `None` |
   | VPC endpoints | `None` |

3. Click **Create VPC** — AWS will automatically create:
   - The VPC
   - A public subnet (`10.0.1.0/24`)
   - An Internet Gateway (attached to the VPC)
   - A route table with `0.0.0.0/0 → igw-xxxx`

> ⚠️ **Auto-assign Public IP**: Go to your new subnet → Actions → **Edit subnet settings** → enable **"Auto-assign public IPv4 address"**. Without this, your EC2 instance won't get a public IP.

---

### Part 2 — Create a Security Group

1. Go to **EC2 Console → Security Groups → Create security group**

2. Configure it:

   | Setting | Value |
   |---|---|
   | Name | `WebDashboardSG` |
   | Description | `Allow HTTP inbound for dashboard` |
   | VPC | Select your VPC from Part 1 |

3. Add **Inbound rules**:

   | Type | Port | Source | Purpose |
   |---|---|---|---|
   | HTTP | 80 | `0.0.0.0/0` | Dashboard access |
   | SSH | 22 | My IP | Optional — for debugging |

4. Click **Create security group**

---

### Part 3 — Launch the EC2 Instance

1. **Fork this repo** and open `scripts/user-data.sh` to review the script

2. Go to **EC2 Console → Launch Instances**

3. Configure the instance:

   | Setting | Value |
   |---|---|
   | Name | `my-info-dashboard` |
   | AMI | Amazon Linux 2 (Free tier eligible) |
   | Instance type | `t2.micro` (Free tier eligible) |
   | Key pair | Proceed without / choose existing |

4. Under **Network settings**:
   - VPC: select your VPC from Part 1
   - Subnet: select your **public** subnet
   - Auto-assign public IP: **Enable**
   - Security group: select `WebDashboardSG`

5. Under **Advanced Details → User Data**, paste the full contents of `scripts/user-data.sh`

6. Click **Launch Instance**

---

### Part 4 — View the Dashboard

1. Wait ~2 minutes for the instance to reach `2/2 status checks passed`

2. Copy the **Public IPv4 address** from the instance details

3. Open your browser and visit:
   ```
   http://<your-public-ip>
   ```

4. You'll see the live dashboard showing all instance and VPC metadata 🎉

---

## 🔍 How It Works

```
EC2 boots inside VPC public subnet
        ↓
Internet Gateway routes public traffic in
        ↓
AWS runs User Data script (once, as root)
        ↓
Script installs Apache
        ↓
Fetches metadata via IMDSv2:
  - Instance identity (ID, type, AMI)
  - Location (region, AZ)
  - Network (public IP, private IP)
  - VPC info (vpc-id, subnet-id, CIDRs) ← via MAC address path
        ↓
Generates HTML dashboard with live values
        ↓
Apache serves it on port 80
        ↓
You visit http://<public-ip>
```

### The VPC Metadata Trick

VPC and subnet details are not available at the top-level metadata path. They are fetched via the instance's **MAC address**, which acts as a key to the network interface metadata:

```bash
MAC=$(curl -s ... http://169.254.169.254/latest/meta-data/mac)

VPC_ID=$(curl -s ... .../network/interfaces/macs/$MAC/vpc-id)
SUBNET_ID=$(curl -s ... .../network/interfaces/macs/$MAC/subnet-id)
VPC_CIDR=$(curl -s ... .../network/interfaces/macs/$MAC/vpc-ipv4-cidr-block)
SUBNET_CIDR=$(curl -s ... .../network/interfaces/macs/$MAC/subnet-ipv4-cidr-block)
```

---

## 💡 Key Concepts Covered

| Concept | What you practice |
|---|---|
| **VPC** | Creating an isolated virtual network with CIDR blocks |
| **Public Subnet** | A subnet with a route to an Internet Gateway |
| **Internet Gateway** | Enabling internet access for your VPC |
| **Security Groups** | Stateful firewall rules controlling port 80 access |
| **EC2 User Data** | Scripts that auto-run on first instance boot |
| **IMDSv2** | Secure token-based access to instance metadata |
| **Apache on Amazon Linux 2** | Installing and enabling a web server via bash |

---

## 🧹 Cleanup

To avoid charges, clean up in this order:

1. **Terminate the EC2 instance**
   - EC2 Console → Instances → Select → Instance State → **Terminate**

2. **Delete the Security Group** (after instance is terminated)
   - EC2 Console → Security Groups → Select `WebDashboardSG` → **Delete**

3. **Delete the VPC** (if you created one for this project)
   - VPC Console → Your VPCs → Select → **Actions → Delete VPC**
   - This also deletes the attached subnets, route tables, and internet gateway

> ⚠️ Always terminate EC2 before deleting the VPC — you cannot delete a VPC that has running instances.

---

## 🪪 License

MIT — fork freely, learn loudly.
