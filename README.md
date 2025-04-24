# vocal.nvim

A lightweight Neovim plugin for speech-to-text transcription using the OpenAI Whisper API.

## Overview

`vocal.nvim` enables you to record audio directly within Neovim, send it to the OpenAI Whisper API for transcription, and insert the transcribed text into your current buffer. Perfect for drafting documents, taking notes, or composing text without typing.

## Features

- Record audio using the `:Vocal` command
- Transcribe speech with OpenAI Whisper API
- Insert transcriptions at cursor position or replace selected text
- Clear status indicators during recording and processing
- Asynchronous operation to keep Neovim responsive
- Debug tools and API connection testing

## Installation

### Requirements

- Neovim 0.11.0+
- `sox` for audio recording
- OpenAI API key

### Using lazy.nvim

```lua
{ "kyza0d/vocal.nvim", dependencies = { "nvim-lua/plenary.nvim" }, opts = {} }
```

## Configuration

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
  
  -- API configuration
  api = {
    model = "whisper-1",
    language = nil, -- Auto-detect language
    response_format = "json",
    temperature = 0,
    timeout = 60,
  },
})

## Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim): Required for asynchronous operations
- `sox`: Command-line audio recording utility (must be installed separately)

This plugin was inspired by the following projects:

- [murmur.nvim](https://github.com/mecattaf/murmur.nvim)
- [gp.nvim](https://github.com/Robitx/gp.nvim)

## License

MIT
