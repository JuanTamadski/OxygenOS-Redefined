<div align="center">

# Oxygen OS Redefined

**OnePlus Custom ROM Builder fo Oneplus 12R and Ace 3** — *Automated OEM firmware modification pipeline*

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/badge/version-v1.0-green.svg)](#)
[![Platform](https://img.shields.io/badge/platform-Linux%20x86__64-lightgrey.svg)](#)
[![Telegram](https://img.shields.io/badge/Telegram-Community-2CA5E0?logo=telegram&logoColor=white)](https://t.me/nothingscom)

**Language / Ngôn ngữ:** **English** | [Tiếng Việt](README_VI.MD)

---

*Transform official OnePlus OEM firmware into a fully customized Global ROM — packed with Google Apps, AI fixes, and the KaoriOS Toolbox.*

</div>

##  Features

| Feature | Description |
|---------|-------------|
|  **Google Apps** | Pre-installed GApps for Domestic ROM variants |
|  **AI Fixing** | Intelligent compatibility patches for Domestic ROM |
|  **Droidspaces** | Includes Droidspaces support  |
|  **KaoriOS Toolbox** | Advanced system modification & tuning toolkit |
|  **Automated Pipeline** | End-to-end CI/CD via GitHub Actions |
|  **Cloud Upload** | Auto-upload built ROMs to OneDrive via Rclone |

> More features coming soon — stay tuned!

##  How It Works

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Download   │────▶│    Unpack     │────▶│    Modify     │────▶│    Repack     │
│   Base ROM   │     │  payload.bin  │     │  Partitions   │     │   EXT/EROFS   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────┬───────┘
                                                                      │
                     ┌──────────────┐     ┌──────────────┐            │
                     │   Upload to  │◀────│   Pack ROM   │◀───────────┘
                     │    (Cloud)    │     │    (.zip)     │
                     └──────────────┘     └──────────────┘
```


##  Quick Start

### Prerequisites

use the setup script to install all required tools automatically:

```bash
bash setup.sh
```

### Build From Source

```bash
# Clone the repository
git clone https://github.com/tiencv2006/OxygenOS-Redefined.git
cd OxygenOS-Redefined
```

**Option A** — Build from a firmware URL:

```bash
bash build.sh <URL_OF_FIRMWARE_OTA> y
```

**Option B** — Build from a local firmware file:

```bash
bash build.sh <PATH_TO_FIRMWARE_FILE> y
```
notes: make changes to test.sh first if you are planning to edit build.sh. You can do the same with unpackROM-Fastboot.sh.

##  GitHub Actions (CI/CD)

You can also build ROMs automatically in the cloud using **GitHub Actions**.

####  Required Secrets

| Secret | Description |
|--------|-------------|
| `GH_REPO` | Your GitHub account/repo (`username/repo_name`) |
| `GH_TOKEN` | Your GitHub personal access token |
| `RCLONE_TOKEN_PATH` | Path to your `rclone.conf` file |
| `SSH key pairs` | For Sourceforge Uploads (Default) |

#### 📥 Workflow Inputs

| Input | Description |
|-------|-------------|
| `ROM_URL` | URL of the official OEM firmware OTA |

> [!TIP]
> You can use **Rclone** (OneDrive, Google Drive, MEGA) or upload directly to **GitHub Releases** — customize the upload target in `uploadROM.sh`.

### Configuration

Edit `config.env` to toggle build options:

```env
install_toolbox=true    # Install KaoriOS Toolbox
install_mods=true       # Apply custom modifications
```

##  Changelogs

### Latest Update

> [!NOTE]
> Based on version **v16.0.5** — Fixes & improvements

- **Fixed Gemini Voice Call** — Resolved issue with calling Gemini via voice
- **Fixed CTS & Gemini loss on v16.0.5** — Restored CTS certification and Gemini availability
- **Fixed AI Writing not working** — AI writing feature is now functional
- **Updated Quick View, App Search, Photos, Weather apps** — Fixed widget issues, Google Photos sync failures, and various other bugs
- **Updated to latest KaoriOS Toolbox** — [@kousei_jp](https://t.me/Kousei_jp) *(official release date TBD)*
- **Fixed some banking apps not opening** — Based on Toolbox & notes above
- **Activated Google CTS Scroll & Translate** — Enabled in Google's translation feature section
- **Added Droidspaces and SukiSU Ultra support
---

##  Credits & Sponsors

A huge thank you to everyone who made this project possible:

<a href="https://github.com/tiencv2006">
  <img src="https://github.com/tiencv2006.png" width="60" style="border-radius:50%;" alt="Chau Vinh Tien"/>
</a>

**[Chau Vinh Tien](https://github.com/tiencv2006)** — *Project Lead & Developer* - 


###  Contributors

| Who | Contribution |
|-----|-------------|
| [Kousei](https://t.me/Kousei_jp) | KaoriOS Toolbox |
| [MaiAFK](https://t.me/maiphp) | Website concept & web server code |
| [Mốc](https://t.me/jerryx0x) | Mod & build methods |
| [summert](https://t.me/ntai15) | Coding support & issue resolution |
| [BHLNK](https://t.me/bhlnk) | AI fixing spoof methods |

###  Sponsors

| Who | Support |
|-----|---------|
| [fukiame](https://t.me/fukiame) | Hosting sponsor |
| [Xfu7107](https://t.me/xfu7101) | Hosting, GitHub Actions account & more |
| [AGPHONG](https://t.me/agphong) | Best sponsor  |

###  AI Tools

> Antigravity by Google • Cursor • Codex by OpenAI • Claude

###  Special Thanks

**And everyone who tested the ROM and provided valuable feedback!**

*— The list will be updated as the community grows.*


##  License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ by the NothingsVN community**


</div>
