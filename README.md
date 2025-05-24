# 👻 ghostscan

[![Zig](https://img.shields.io/badge/Built_with-Zig-orange?style=flat-square\&logo=zig)](https://ziglang.org)

A blazing-fast, Zig-native TCP port scanner for terminal ninjas and homelab hackers.

---

## 🚀 Usage

```bash
zig build run -- 192.168.1.1 1 1000
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

## ⚙️ Features

* 🔥 Zero dependencies
* 🧠 Async-ready architecture (planned)
* 📦 Pure Zig, portable, no runtime
* 🛠️ Ideal for integrating with `ghostctl net scan`

---

## 📍 Planned Enhancements

* Parallel scanning using `async` and `await`
* TUI display using `crossterm` or `zig-tui`
* JSON and machine-readable output mode
* IP range scanning support
* Optional banner grab / service fingerprint

---

© 2025 [GhostKellz](https://ghostkellz.sh) / CK Technology — MIT Licensed

