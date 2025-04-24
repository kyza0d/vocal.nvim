# [vocal.nvim](https://github.com/kyza0d/vocal.nvim): 0.2.0

## Plugin Details
- **Repository**: [vocal.nvim](https://github.com/kyza0d/vocal.nvim)
- **Version**: 0.2.0
- **Resources**:
  - [README.md](https://github.com/kyza0d/vocal.nvim/blob/main/README.md)
  - [vocal.txt](https://github.com/kyza0d/vocal.nvim/blob/main/doc/vocal.txt)
## Plugin Description
vocal.nvim is a lightweight Neovim plugin that enables speech-to-text transcription using the OpenAI Whisper API. It allows users to record audio within Neovim, transcribe it, and insert the text into the current buffer. The plugin is designed for ease of use, asynchronous operation, and seamless integration with Neovim's ecosystem.

## Phase 1: Initial Development

### On-going
- [~] Codebase cleanup
    - [~] Optimize code base for: simplicity, reliability

  - [~] Plugin UX/UI
    - [~] Status window

  - [~] Test the plugin across devices
    - [x] Arch Linux 
    - [ ] Windows (not tested)
    - [ ] Mac (not tested)

### Details
  - [x] Implement core recording functionality using sox
    - [x] Integrate OpenAI Whisper API for transcription
       - [ ] Additional testing for API errors
    - [x] Develop buffer manipulation for text insertion
    - [x] Create user interface components (status window, recording popup)
    - [x] Set up configuration system
    - [x] Write initial documentation (README.md, vocal.txt)
    - [x] Initialize MILESTONES.md for project tracking
    - [x] Simplify UI by removing window and waiting for Vocal command
    - [x] Fix not capturing last couple of seconds of audio
    - [x] Download `base` model to specified directory for local transcription
    - [x] Successfully transcribe audio using local model
    - [x] Fix API transcription error to respect local_model configuration
    - [ ] Use whisper.cpp for local transcription
      - [x] Download model automatically
      - [x] Use existing model if one is found
      - [ ] Show feedback while downloading
    - [ ] Add support for custom keymaps
    - [ ] Automate CHANGELOG.md generation and release process
    - [ ] Monitor for inconsistent transcription errors in production

## Phase 2: Stability and Testing

### Details
  - [~] Switch to using `plenary.curl` for API calls
      - [ ] (fix) Error with processing multiple forms
    - [ ] Add in `:checkhealth vocal`
    - [ ] Determine necessary tests and implement them

## Phase 3: Feature Expansion

### Details
  - [ ] Implement real-time transcription
  - [ ] Custom commands which use instructions when transcribing

### Cancelled
- [-] Floating window for recording
