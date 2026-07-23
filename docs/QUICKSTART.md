# Quickstart

Run these commands from the repository root.

## Install

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -Autostart
```

This installs:

- SHA256-verified, pinned `llama.cpp` Windows Vulkan build
- Qwen3.5 4B Q4_K_M GGUF
- 100K context local config
- Logon autostart for the local LLM server

## Start

```powershell
.\scripts\start-local-ai.cmd
```

## Vision model

Install MiniCPM-V 4.5 for image input. The installer fetches both the Q4_K_M
model and its required vision projector.

```powershell
.\install-local-ai.cmd -Model minicpm-v-4.5
.\scripts\start-local-ai.cmd
.\scripts\test-local-ai.cmd -ImagePath "C:\images\sample.png" -Prompt "Describe this image in Japanese."
```

## Test

```powershell
.\scripts\status-local-ai.cmd
.\scripts\test-local-ai.cmd
```

## Switch Models

```powershell
.\install-local-ai.cmd -ListModels
.\install-local-ai.cmd -Model qwen35-9b-long
.\scripts\start-local-ai.cmd
```

## Custom GGUF

```powershell
.\install-local-ai.cmd -ModelPath "D:\models\custom.gguf" -Alias custom-local -CtxSize 32768
.\scripts\start-local-ai.cmd
```

## Hermes Optional Autostart

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -Autostart -WithHermes
```

Hermes is not installed by this repository. If it is not found under `%LOCALAPPDATA%\hermes`, the Hermes autostart task logs a warning and exits.
