# vocal.nvim

A lightweight Neovim plugin for speech-to-text transcription using OpenAI Whisper API or local models.

## Overview

`vocal.nvim` enables you to record audio directly within Neovim, transcribe it, and insert the transcribed text into your current buffer. Perfect for drafting documents, taking notes, or composing text without typing.

## Features

- Record audio using the `:Vocal` command or configurable keymap
- Transcribe speech with OpenAI Whisper API or local models
- Insert transcriptions at cursor position or replace selected text
- Simple status indicators during recording and processing
- Asynchronous operation to keep Neovim responsive
- Support for local Whisper models (no API key needed)

## Requirements

- Neovim 0.11.0+
- `sox` for audio recording
- For API transcription: OpenAI API key
- For local transcription: Python with `openai-whisper` package


### Installation

#### Using lazy.nvim

```lua
{
  "kyza0d/vocal.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {}
}
```

#### For Arch Linux

```sh
sudo pacman -S sox python-openai-whisper
```


# Configuration
```lua
require("vocal").setup({
  -- API key (string, table with command, or nil to use OPENAI_API_KEY env var)
  api_key = nil,

  -- Directory to save recordings
  recording_dir = os.getenv("HOME") .. "/recordings",

  -- Delete recordings after transcription
  delete_recordings = true,

  -- Keybinding to trigger :Vocal (set to nil to disable)
  keymap = "<leader>v",

  -- Local model configuration (set this to use local model instead of API)
  local_model = {
    model = "base",       -- Model size: tiny, base, small, medium, large
    path = "~/whisper",   -- Path to download and store models
  },

  -- API configuration (used only when local_model is not set)
  api = {
    model = "whisper-1",
    language = nil,       -- Auto-detect language
    response_format = "json",
    temperature = 0,
    timeout = 60,
  },
})
```

## Usage

1. Start recording with the `:Vocal` command or configured keymap
2. Speak into your microphone
3. Run `:Vocal` again to stop recording and transcribe
4. The transcribed text will be inserted at your cursor position

In visual mode, transcribed text will replace the selected text.

# Installation


## Current Status

- Local model transcription is the default and works on Linux
- API transcription has issues and still needs work
- Windows support is currently not working correctly
- Mac support has not been fully tested

## Troubleshooting

- "sox is not installed": Install sox on your system
  - Ubuntu/Debian: `sudo apt install sox`
  - macOS: `brew install sox`
  - Windows: Install through chocolatey or directly

- "API key not found": Set your OpenAI API key in the configuration or
  as the OPENAI_API_KEY environment variable (only needed for API transcription)

- "Python package not found": Install the openai-whisper package with
  `pip install openai-whisper` (only needed for local transcription)

## License

MIT
