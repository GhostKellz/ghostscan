# 👻 ghostscan

[![Rust](https://img.shields.io/badge/Built_with-Rust-orange?style=flat-square\&logo=rust)](https://www.rust-lang.org)

A blazing-fast, Rust-native TCP port scanner for terminal ninjas, homelabbers, and self-hosting pros.

---

## 🚀 Usage

```bash
cargo run --release -- 192.168.1.1 1 1000
```

Optional arguments:

```
ghostscan <ip> [start-port] [end-port]
```

Example:

```bash
ghostscan 10.0.0.1 20 1024
```

---

## 🏗️ Installation

### Arch Linux (AUR)

```sh
git clone https://github.com/ghostkellz/ghostscan.git
cd ghostscan
makepkg -si
```

### Debian/Ubuntu

```sh
git clone https://github.com/ghostkellz/ghostscan.git
cd ghostscan
cargo build --release
sudo install -Dm755 target/release/ghostscan /usr/local/bin/ghostscan
```

---

## 🖥️ Interactive Mode

Ghostscan will support an interactive CLI/TUI mode for scanning and visualizing results (planned).

---

## 📚 Documentation & Examples

Check out the `examples/` directory for real-world scripts and integration tips. More docs and advanced usage coming soon!

---

## ⚙️ Features

* ⚡ Built with async Rust for speed and reliability
* 🔐 Zero unsafe code
* 📦 Single binary, no dependencies
* 🛠️ Integrates cleanly with `ghostctl net scan`
* 🧪 Output modes: plain text, JSON, CSV
* 🧭 IPv4 support with CIDR/range parsing (coming soon)

---

## 📍 Roadmap

* Parallel scanning with full `tokio` support
* Optional TUI interface via `ratatui`
* Basic service fingerprinting (banners, TLS info)
* Plugin system for custom detection logic
* Integration with `ghostctl` and `phantomlink`

---

© 2025 [GhostKellz](https://ghostkellz.sh) / CK Technology — MIT Licensed
