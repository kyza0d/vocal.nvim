# vocal.nvim

A lightweight Neovim plugin for speech-to-text transcription using OpenAI Whisper API or local models.

## Overview

`vocal.nvim` enables you to record audio directly within Neovim, transcribe it, and insert the transcribed text into your current buffer. Perfect for drafting documents, taking notes, or composing text without typing.

## Features

- Record audio using the `:Vocal` command
- Transcribe speech with OpenAI Whisper API or local models
- Insert transcriptions at cursor position or replace selected text
- Simple status indicators during recording and processing
- Asynchronous operation to keep Neovim responsive
- Support for local Whisper models (no API key needed)

## Installation

### Requirements

- Neovim 0.11.0+
- `sox` for audio recording
- For API transcription: OpenAI API key
- For local transcription: Python with `whisper` package

### Using lazy.nvim

```lua
{ "kyza0d/vocal.nvim", dependencies = { "nvim-lua/plenary.nvim" }, opts = {} }
```

## Configuration

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

## Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim): Required for asynchronous operations and curl
- `sox`: Command-line audio recording utility (must be installed separately)
- For local transcription: `pip install openai-whisper` 

This plugin was inspired by the following projects:
- [murmur.nvim](https://github.com/mecattaf/murmur.nvim)
- [gp.nvim](https://github.com/Robitx/gp.nvim)

## License

MIT
