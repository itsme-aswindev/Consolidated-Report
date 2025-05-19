# 🔧 Robo-VM Server Health Check Script

A powerful and automated PowerShell script to monitor and verify the health status of all critical infrastructure components across:

- 🖥️ VMware-hosted virtual machines
- 🏠 On-premises servers running on Hyper-V
- ⚙️ Industrial PLC (Programmable Logic Controller) devices

The script generates a detailed consolidated report in a CSV format (`Robo-VM.csv`) and automatically emails the results to configured recipients.

---

## 📌 Features

- ✅ Checks availability and responsiveness of:
  - VMware virtual machines
  - Hyper-V virtual servers
  - PLC devices via ping or protocol-specific checks
- 📊 Consolidated CSV report output
- 📬 Automatic email dispatch to distribution lists and individual recipients
- ⏰ Scheduled execution ready (can be used with Task Scheduler)
- 🔒 Secure credential and connection handling

---

## 📁 Output

The script generates a file named `Robo-VM.csv` with columns such as:

- `DeviceName`
- `IP Address`
- `Platform` (VMware / Hyper-V / PLC)
- `Status` (Online / Offline)
- `Response Time`
- `Timestamp`

---

## ✉️ Email Configuration

Emails are automatically sent using SMTP to recipients defined **within the script**. You can configure:

- SMTP Server details
- Sender Email ID
- To / CC / BCC addresses or distribution lists
- Customizable subject and body message

---

## ⚙️ Prerequisites

- PowerShell 5.1 or later (Windows OS)
- Access to vCenter (for VMware)
- Access to Hyper-V management APIs
- Network reachability to PLC devices
- SMTP server credentials or relay access

---
