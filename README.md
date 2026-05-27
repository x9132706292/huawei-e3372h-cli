# Huawei E3372H-153 SMS & Control CLI

Lightweight, BusyBox-compatible Bash scripts for managing Huawei HiLink modems via HTTP API. Read, send, delete SMS, and reboot the device directly from CLI/SSH.

## ✨ Features
- 📡 **Zero dependencies**: Pure `sh`, `curl`, `sed`, `awk`. Works out-of-the-box on OpenWrt, routers & embedded Linux.
- 📦 **JSON-native**: Structured input/output for easy automation, webhooks & parsing.
- 🔐 **Auto-auth**: Handles Huawei session tokens (`SesInfo`/`TokInfo`) and CSRF headers automatically.
- 🛡️ **BusyBox-safe**: No `grep -P`, `perl`, or `jq` required. Fully compatible with cut-down Unix environments.
- ⚡ **Resilient**: Built-in delay & retry logic to bypass common HiLink API error `100005`.

## 📋 Requirements
- Huawei E3372H-153 (**HiLink firmware**, not Stick/Serial mode)
- `curl` installed on the host system
- Network access to modem IP (default: `192.168.8.1`)

## 🚀 Quick Start
```bash
git clone https://github.com/x9132706292/huawei-e3372h-cli.git
cd huawei-e3372h-cli
chmod +x *.sh
```

## Usage

### 📥 Read SMS (`read_sms.sh`)
Retrieves messages and outputs valid JSON.
```bash
./read_sms.sh [HOST] [FOLDER]
# Folders: inbox (default), sent, draft, all
./read_sms.sh
./read_sms.sh 192.168.8.1 sent
```
JSON Output:
```json
{
  "count": 2,
  "folder": "inbox",
  "messages": [
    {
      "id": 40001,
      "phone": "+79991234567",
      "date": "2026-05-26 12:37:01",
      "status": "read",
      "content": "Hello!"
    }
  ]
}
```

### 📤 Send SMS (`send_sms.sh`)
Sends a text message with automatic XML escaping & number normalization.
```bash
./send_sms.sh [HOST] <PHONE> <MESSAGE>
./send_sms.sh 192.168.8.1 79991234567 "Test message from CLI"
```
*⚠️ Note: Cyrillic messages use UCS-2 encoding. Max safe length: ~70 characters per SMS part.*

### 🗑️ Delete SMS ('delete_sms.sh')
Deletes messages by ID(s). Supports batch deletion with per-ID status reporting.
```bash
./delete_sms.sh [HOST] <ID1> [ID2] [ID3]
./delete_sms.sh 40001 40002
```
JSON Output:
```json
{
  "host": "192.168.8.1",
  "total_requested": 2,
  "deleted": ["40001"],
  "failed": [{"id":"99999","reason":"message_not_found"}]
}
```

### 🔁 Reboot Modem ('reboot_modem.sh')
Safely reboots the modem via HiLink API.
```bash
./reboot_modem.sh [HOST]
./reboot_modem.sh
```
🔧 Automation Examples
(Requires optional `jq` for filtering)

```bash
# Auto-reply to unread messages
./read_sms.sh | jq -r '.messages[] | select(.status=="unread") | .phone' | while read num; do
  ./send_sms.sh "$num" "Auto-reply: Message received."
done

# Delete all read messages
./read_sms.sh | jq -r '.messages[] | select(.status=="read") | .id' | xargs ./delete_sms.sh
```

## ⚙️ Technical Notes
**Session Management**: HiLink tokens expire after ~5 minutes. Each script fetches fresh tokens on startup.
**Error `100005`**: Handled via `sleep 1` delay after token request. If it persists, reboot the modem or wait 2 minutes.
**BusyBox Compatibility**: Uses only POSIX `sh`, standard `grep`, `sed`, and `awk`. Tested on BusyBox v1.37.0.
**Password Protection**: These scripts use the default guest/session flow. If your modem requires a web password, add `/api/user/login` before token requests.
**Encoding**: Save scripts as `UTF-8`. Run `dos2unix *.sh` if edited on Windows.

# 📜 License
MIT License. Feel free to use, modify, and distribute.

## 🤝 Credits
Huawei HiLink API reverse engineering & community documentation
[Stephen Monro's Blog](https://stephenmonro.wordpress.com/2019/02/13/getting-sms-messages-from-the-huawei-e3372-lte-modem/?spm=a2ty_o01.29997173.0.0.278a55fbeQUZrF) for API insights
