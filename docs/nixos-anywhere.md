## How Does `nixos-anywhere` Work?

Let's walk through what happens **on your local machine** (the one where you run
`nixos-anywhere`) and **on the remote machine (VM or server)** step by step.

- **Your machine** = where you run `nixos-anywhere`.
- **Remote machine (VM)** = the machine you want to install NixOS on.

Let’s assume the remote machine is running **some Linux distro already** (like
Ubuntu or Debian).

✅ **1. You run `nixos-anywhere` on your machine**

📍 **Happens on your machine**

- You run a command like:

  ```bash
  nixos-anywhere --flake .#myhost root@your.remote.ip
  ```

- This tells it to install NixOS remotely on a machine via SSH.

- 📡 **2. `nixos-anywhere` SSHes into the remote machine**

  📍 **Your machine ↔ Remote machine**
  - It connects over SSH to the remote machine.
  - It checks what Linux is running, and that it can proceed.
  - It starts preparing the remote machine to transition into NixOS.

📦 **3. It builds the NixOS system locally**

📍 **Happens on your machine**

- Your machine builds the NixOS system defined in your flake or configuration.
- This includes:
  - The kernel
  - The initrd (initial RAM disk)
  - The installer environment (like a minimal NixOS live system)

🛠️ All of that gets bundled up and prepared to be copied to the remote.

📤 **4. The NixOS kernel and initrd are copied to the remote machine**

📍 **Your machine → Remote machine**

- The built kernel and initrd are uploaded via SSH/SCP.
- These are what the remote system will boot into next.

- 🧠 **5. The remote machine loads the new kernel with `kexec`**

  📍 **Happens on the remote machine**
  - On the remote Linux system:
    - It uses `kexec` to load the NixOS kernel + initrd **into memory**.
    - It doesn’t reboot in the normal way — no BIOS/UEFI — it just _jumps_ into
      the new kernel in RAM.

- 🚀 **6. `kexec` jumps into the NixOS installer environment**

  📍 **Remote machine is now running NixOS in memory**
  - You’re now inside a minimal NixOS live system — not installed to disk yet.
  - This is like booting from a NixOS USB installer, but done all in RAM via
    kexec.

- 🛠️ **7. The installer runs and writes NixOS to disk**

  📍 **Remote machine**
  - It partitions the disk, formats, sets up `/etc/nixos/configuration.nix`, and
    installs NixOS properly.
  - It writes a full NixOS system to the disk.

- 🔁 **8. Remote machine reboots into the freshly installed NixOS**

  📍 **Remote machine**
  - It does a real reboot now (BIOS + bootloader), and this time it boots from
    the installed NixOS on disk.

- ✅ **9. Done! You can SSH into your new NixOS system**

  📍 **Your machine**
  - Once it reboots and comes online, you can SSH in.
  - The remote machine is now fully running NixOS.

### 🧠 In Summary

| Step | Action                      | Where it happens |
| ---- | --------------------------- | ---------------- |
| 1    | Run `nixos-anywhere`        | Your machine     |
| 2    | Connect via SSH             | Your → Remote    |
| 3    | Build NixOS system          | Your machine     |
| 4    | Upload kernel/initrd        | Your → Remote    |
| 5    | Load kernel via `kexec`     | Remote machine   |
| 6    | Boot into NixOS (in RAM)    | Remote machine   |
| 7    | Install NixOS to disk       | Remote machine   |
| 8    | Reboot into installed NixOS | Remote machine   |
| 9    | SSH into final NixOS        | Your machine     |
