# Local AI Setup Scripts

Windows setup scripts for running local GGUF models with `llama.cpp` Vulkan.

The default profile installs Qwen3.5 4B with a 100K context window:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -Autostart
```

What this repo manages:

- Downloads a Windows Vulkan build of `llama.cpp`
- Downloads selected GGUF model files from `models.manifest.json`
- Writes `.local-ai-config.json` for the selected model
- Starts an OpenAI-compatible `llama-server`
- Optionally registers Windows logon autostart
- Optionally registers Hermes autostart when Hermes is already installed

What this repo does not commit:

- GGUF model files
- `llama.cpp` binaries
- Logs
- Local config and credentials

## Quick Start

List known models:

```powershell
.\install-local-ai.cmd -ListModels
```

Install the default 100K model:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long
```

Start the server:

```powershell
.\scripts\start-local-ai.cmd
```

Check status:

```powershell
.\scripts\status-local-ai.cmd
```

Test generation:

```powershell
.\scripts\test-local-ai.cmd
```

Stop the server:

```powershell
.\scripts\stop-local-ai.cmd
```

The API endpoint is:

```text
http://127.0.0.1:8080/v1/chat/completions
```

The default API key is `local-qwen` when `LLAMA_API_KEY` is not set.

## Model Selection

Install a model from the manifest:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long
.\install-local-ai.cmd -Model qwen35-9b-long
.\install-local-ai.cmd -Model qwen35-9b-long-fast
.\install-local-ai.cmd -Model glm-flash
```

Override context size:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -CtxSize 65536
```

Use a direct GGUF URL:

```powershell
.\install-local-ai.cmd `
  -ModelUrl "https://huggingface.co/user/repo/resolve/main/model.gguf?download=true" `
  -Alias "my-local-model" `
  -CtxSize 32768
```

Use an existing local GGUF:

```powershell
.\install-local-ai.cmd `
  -ModelPath "D:\models\model.gguf" `
  -Alias "custom-local" `
  -CtxSize 32768
```

## Autostart

Register only the local LLM server:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -Autostart
```

Register local LLM server plus Hermes, if Hermes is already installed:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -Autostart -WithHermes
```

Registered task names:

- `Local AI Server Autostart`
- `Hermes Autostart`

Disable them:

```powershell
Disable-ScheduledTask -TaskName "Local AI Server Autostart"
Disable-ScheduledTask -TaskName "Hermes Autostart"
```

Autostart logs:

```powershell
Get-Content .\logs\autostart-local-llm.log -Tail 50
Get-Content .\logs\autostart-hermes.log -Tail 50
```

## LAN Access

The server binds to `0.0.0.0` by default. To allow inbound connections from other devices on the LAN, run PowerShell as Administrator:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -OpenFirewall
```

Then use:

```text
http://<this-pc-ip>:8080/v1/chat/completions
```

## Repository Layout

```text
install-local-ai.ps1
models.manifest.json
scripts/
  start-local-ai.ps1
  stop-local-ai.ps1
  status-local-ai.ps1
  test-local-ai.ps1
  autostart-local-llm.ps1
  autostart-hermes.ps1
  register-autostart-tasks.ps1
docs/
  QUICKSTART.md
```
