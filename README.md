# Local AI Setup Scripts

Windows setup scripts for running local GGUF models with `llama.cpp` Vulkan.

The default profile installs Qwen3.5 4B with a 100K context window:

```powershell
.\install-local-ai.cmd -Model qwen35-4b-long -Autostart
```

What this repo manages:

- Downloads the pinned, SHA256-verified Windows Vulkan build of `llama.cpp`
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

For a button-based launcher, double-click `launch-local-ai.cmd`. It lets you
select a model, installs it when needed, stops the current server before a
switch, starts the selected model, and provides a button to open the local chat
page. Model downloads show the received size and each operation writes a
timestamped log under `logs/` that is displayed in the launcher. It also
includes copyable Chandra OCR prompts for Markdown, JSON, HTML, and plain-text
output.

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
.\install-local-ai.cmd -Model minicpm-v-4.5
.\install-local-ai.cmd -Model qwen36-27b-64k
.\install-local-ai.cmd -Model chandra-ocr-2
```

## Long-context text: Qwen3.6 27B

The `qwen36-27b-64k` profile installs Qwen3.6 27B Q3_K_S as a text-only,
CPU-friendly profile with a 64K context window and Q8 KV cache. It requires
approximately 12.4 GB for the model file and substantially more RAM while
serving long prompts.

## Vision: MiniCPM-V 4.5

MiniCPM-V 4.5 is an image-capable local model. Its Q4_K_M model is 5.03 GB and
its required vision projector is 1.1 GB; the installer downloads and
SHA256-verifies both files.

```powershell
.\install-local-ai.cmd -Model minicpm-v-4.5
.\scripts\start-local-ai.cmd
.\scripts\test-local-ai.cmd -ImagePath "C:\images\receipt.jpg" -Prompt "Extract all visible text."
```

`-ImageUrl` accepts an HTTPS or `data:` image URL. `-ImagePath` accepts JPG,
PNG, and WEBP files and converts them to a `data:` URL automatically.

The MiniCPM profile uses CPU inference by default on PCs with an integrated GPU,
because the model and vision projector together require more than 6 GB of GPU
memory. Use a dedicated GPU profile only after confirming sufficient VRAM.

## OCR: Chandra OCR 2

The `chandra-ocr-2` profile is specialized for extracting text and preserving
the layout of documents and images. It uses the IQ4_NL GGUF (3.05 GB) and a
required 676 MB vision projector. Both are SHA256-verified during installation.

```powershell
.\install-local-ai.cmd -Model chandra-ocr-2
.\scripts\start-local-ai.cmd
.\scripts\test-local-ai.cmd -ImagePath "C:\images\document.png" -Prompt "Extract all visible text and preserve the layout as Markdown."
```

It is configured for 64K context and CPU inference by default, which is the
safe option for this PC's integrated GPU. The model supports up to 256K, but
64K is the practical balance for this PC's 32 GB of RAM. The prompt may request Markdown,
HTML, JSON, or plain extracted text depending on the intended output.

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
