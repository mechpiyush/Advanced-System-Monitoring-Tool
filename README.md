# 🚀 LIMO - (Advanced System Monitoring & Auto-Healing) 🔥

## 📝 Overview
**LIMO (Linux Monitor)** is a powerful and interactive Bash-based **system monitoring tool** designed to keep your Linux system running smoothly. It provides real-time monitoring, **auto-healing** for high CPU usage, process management, network bandwidth monitoring, and log tracking—all with an intuitive interface and **Telegram alerts**. 📊💡

## ✨ Features
✅ **Real-time System Monitoring** – Stay informed about CPU and memory usage.

✅ **Auto-Healing** – Automatically detects and terminates high CPU-consuming processes. 🚑

✅ **Process Management** – Search and manually **kill processes** by name or PID. 🛠️

✅ **Network Bandwidth Monitoring** – View real-time **internet speed usage**. 🌐

✅ **Interactive Menu** – User-friendly dashboard using `whiptail`.

✅ **Logging & Alerts** – View system logs and receive **Telegram notifications** for all actions.

✅ **Manual & Auto Controls** – Toggle auto-healing and monitoring features with ease. 🔄

---

## 🔧 Installation & Setup
### 📌 Prerequisites
Ensure your system has the following installed:
- 🐧 **Bash** (default on most Linux distributions)
- 🖥 **whiptail** (for interactive prompts)
- 🔢 **bc** (for floating-point calculations)
- 📊 **ps, top, awk, grep** (standard Linux utilities)
- 📲 **Telegram Bot API** (optional for alerts)

### 📥 Installation Steps
1️⃣ Clone this repository:
   ```bash
   git clone https://github.com/mechpiyush/limo.git
   cd limo
   ```
2️⃣ Make the script executable:
   ```bash
   chmod +x limo.sh
   ```
3️⃣ Configure environment variables in the script:
   - **THRESHOLD_CPU**: Define the CPU usage percentage limit.
   - **HEAL_INTERVAL**: Set the interval between system checks.
   - **TELEGRAM_BOT_TOKEN & CHAT_ID**: (Optional) Configure Telegram alerts.

---

## 🚀 Usage
### ▶️ Start LIMO
Run the script manually:
```bash
./limo.sh
```
An interactive dashboard will appear, offering the following options:

🔄 **Refresh** – Refresh the displayed system stats.

⚡ **Kill a Process** – Search by name or PID and terminate a process.

📶 **Network Bandwidth Monitor** – View current internet speed usage.

🔧 **Toggle Auto-Healing** – Enable or disable **auto-healing** to kill high CPU-consuming processes automatically.

📜 **View Logs** – Display the 50 most recent system logs, including CPU/memory usage and network connections.

🔔 **Telegram Alerts** – Receive real-time alerts for all operations.

### ⏹️ Stop Auto-Healing
If the script is running, executing it again will prompt you to **disable auto-healing**. ❌

---

## 📜 Logging & Alerts
- 📂 Logs of terminated processes are stored in `/tmp/limo.log`.
- 📲 If enabled, alerts will be sent via Telegram.

---

## ⚙️ How It Works
1️⃣ **Monitors CPU & system performance** in real-time.

2️⃣ **Detects and kills** the highest CPU-consuming process when usage exceeds the threshold.

3️⃣ **Sends a Telegram alert** upon any auto-healing or manual intervention.

4️⃣ **Records all actions** in the system logs for transparency.

5️⃣ **Auto-Heals continuously** for **24 hours** before stopping. 🔄

---

## 🎛 Customization
Modify these parameters in `limo.sh`:
```bash
THRESHOLD_CPU=80   # CPU usage threshold (in %)
HEAL_INTERVAL=30   # Interval in seconds
TELEGRAM_BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"
```

---

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing
Pull requests are welcome! Feel free to open an issue for discussions. 🛠️

## 📧 Contact
For any issues, reach out via **GitHub Issues** or **Email**.

---

**Made with ❤️ by [Piyush Sharma](https://github.com/mechpiyush) ✨**

