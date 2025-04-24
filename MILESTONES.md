Vocal.nvim is a lightweight Neovim plugin that enables speech-to-text transcription using the OpenAI Whisper API. It allows users to record audio within Neovim, transcribe it, and insert the text into the current buffer. The plugin is designed for ease of use, asynchronous operation, and integration with Neovim's ecosystem.

Phases:
  - Phase 1: Initial Development
    - [x] Implement core recording functionality using sox
    - [x] Integrate OpenAI Whisper API for transcription
    - [x] Develop buffer manipulation for text insertion
    - [x] Create user interface components (status window, recording popup)
    - [x] Set up configuration system
    - [x] Write initial documentation (README.md, vocal.txt)
    - [x] Initialize MILESTONES.md for project tracking

  - Phase 1.1: UX Improvements
    - [x] Simplify UI by removing window and waiting for Vocal command
    - [ ] Further simplify and refine existing codebase
    - [ ] Add support for custom keymaps

  - Phase 1.2: Windows Testing
    - [ ] Test the plugin on Windows
    - [ ] Fix any Windows-specific issues

  - Phase 2: Stability and Testing
    - [ ] Use health checks over Plugin commands
    - [ ] Determine necessary tests and implement them

  - Phase 3: Feature Expansion
    - [ ] Add support for local model transcription
    - [ ] Implement real-time transcription
