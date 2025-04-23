# MILESTONES

## Plugin Brief
The `vocal.nvim` plugin is a lightweight Neovim plugin designed to provide seamless speech-to-text transcription using the OpenAI Whisper API. It enables users to record audio directly within Neovim, send it to the OpenAI Whisper API for transcription, and insert the transcribed text into the current buffer. The plugin aims to be simple, cross-platform, and user-friendly, leveraging server-based transcription for broad compatibility.

- **Key Features**:
  - Record audio using `sox` with a configurable storage directory.
  - Display a user-friendly popup interface for recording control.
  - Asynchronous operations using `plenary.nvim` to keep Neovim responsive.
  - Pull OpenAI API key from environment variables or configuration.
  - Insert transcribed text at the cursor position or replace selected text.

- **Status**:
  - [x] Phase 1: Configuration and command setup completed.
  - [x] Phase 2: Recording functionality implemented with UX fixes.
  - [x] Phase 3: API integration and text insertion completed.
  - [x] Phase 4: Documentation completed.

## Context of Plugin and Goals
The plugin was inspired by `whisper.lua` from `gp.nvim`, which provides speech-to-text functionality but includes unwanted features, and `murmur.nvim`, which uses a local whisper.cpp server, limiting cross-platform compatibility. The goal is to create a standalone plugin that:
- Uses the OpenAI Whisper API for reliable, server-based transcription.
- Supports cross-platform audio recording with tools like `sox`.
- Provides a simple, intuitive user experience with clear feedback.
- Ensures asynchronous operations to avoid blocking Neovim.
- Maintains a minimal footprint with no unnecessary dependencies beyond `plenary.nvim`.

**Goals**:
- Enable users to transcribe speech directly into Neovim buffers.
- Support normal and visual mode text insertion.
- Provide clear error messages and status indicators.
- Allow configuration for API key, recording directory, and future settings.
- Address compatibility across Linux, macOS, and Windows.

**Context**:
- Development started in April 2025, targeting Neovim 0.11.0+.
- The OpenAI Whisper API supports batch transcription, not real-time streaming, influencing the plugin's design to record audio first and then process it.
- The plugin is developed iteratively, with each phase building on the previous one to ensure a stable foundation.

## Plugin Architecture
The plugin is structured under `lua/vocal/` with a modular design for maintainability and extensibility. It leverages Neovim's Lua API and `plenary.nvim` for asynchronous operations. The architecture is inspired by `whisper.lua` but simplified to focus on OpenAI Whisper API integration.

**Directory Structure**:
- `lua/vocal/`
  - `init.lua`: Main entry point, handles setup and the `:Vocal` command.
  - `config.lua`: Defines default and user-configurable settings.
  - `recording.lua`: Manages audio recording with `sox` and `plenary.job`.
  - `ui.lua`: Provides a popup interface for recording control.
  - `api.lua`: Handles OpenAI Whisper API integration.
  - `buffer.lua`: Manages text insertion into buffers.

**Key Components**:
- **Configuration**: Managed via `config.lua`, allowing users to set `api_key` and `recording_dir`.
- **Recording**: Handled by `recording.lua`, using `sox` with asynchronous job management.
- **UI**: Implemented in `ui.lua`, displaying a popup with status and keybindings.
- **Command**: The `:Vocal` command in `init.lua` orchestrates recording, API calls, and text insertion.

**Dependencies**:
- `plenary.nvim`: For asynchronous job management.
- `sox`: For cross-platform audio recording.

**Future Extensibility**:
- Add support for other recording tools (e.g., `ffmpeg`).
- Allow advanced configuration (e.g., language, model).

## Phase 1 Implementations
**Objective**: Set up the plugin's foundation with configuration and the `:Vocal` command.

**Files**:
- `lua/vocal/init.lua`
- `lua/vocal/config.lua`

**Completed**:
- [x] Defined default configuration in `config.lua` with `api_key` option.
- [x] Implemented `setup` function in `init.lua` to merge user options.
- [x] Created `:Vocal` command that checks for API key.
- [x] Supported pulling `OPENAI_API_KEY` from environment variables.
- [x] Added support for `api_key` as a string or command (table) for flexibility.
- [x] Provided error feedback if API key is missing.

**Pending**:
- None.

**Notes**:
- Phase 1 established a robust configuration system, ensuring the plugin is ready for recording and API integration.
- The `api_key` resolution logic is inspired by `gp/vault.lua` but simplified for this plugin's needs.

## Phase 2 Implementations
**Objective**: Implement audio recording with a user-friendly interface, allowing users to start, stop, and save recordings.

**Files**:
- `lua/vocal/config.lua` (updated)
- `lua/vocal/init.lua` (updated)
- `lua/vocal/recording.lua` (new)
- `lua/vocal/ui.lua` (new)

**Completed**:
- [x] Added `recording_dir` to `config.lua`, defaulting to `/tmp`.
- [x] Implemented `recording.lua` to start recording with `sox` using `plenary.job`.
- [x] Displayed ` Recording` indicator via `vim.notify` when recording starts.
- [x] Provided error feedback for missing `sox` or recording failures.
- [x] Ensured asynchronous operation with `plenary.nvim`.
- [x] Added `ui.lua` for a popup interface with `<Enter>` to stop and `<Esc>` to cancel.
- [x] Handled subsequent `:Vocal` calls to stop recording and notify `󰠘 Recording saved`.
- [x] Configured `sox` to use the default OS input device (`-d` flag).
- [x] Used `-t wav` to ensure proper WAV format for recordings.

**Pending**:
- None.

## Phase 3 - Completed
**Objective**: Integrate OpenAI Whisper API to transcribe recordings and insert text into the buffer.

**Files**:
- `lua/vocal/init.lua` (updated)
- `lua/vocal/api.lua` (implemented)
- `lua/vocal/buffer.lua` (implemented)

**Completed**:
- [x] Implemented `api.lua` with OpenAI Whisper API integration using `plenary.job` and curl.
- [x] Added comprehensive error handling (API key validation, network errors, empty responses).
- [x] Created `buffer.lua` with text insertion functions for normal and visual modes.
- [x] Added spinner progress indicator during API processing with visual feedback.
- [x] Updated `:Vocal` command to chain recording, API call, and text insertion.
- [x] Implemented debug logging system with commands:
  - `:VocalDebug` - Enable debug mode
  - `:VocalNoDebug` - Disable debug mode
  - `:VocalOpenLog` - Open debug log file
  - `:VocalTestAPI` - Test API connectivity
- [x] Added API key validation with format checking.
- [x] Implemented proper cleanup of text (whitespace trimming, line ending normalization).
- [x] Tested with various audio inputs and edge cases.

**Pending**:
- None.

**Notes**:
- Phase 3 successfully completed the core functionality, enabling end-to-end speech-to-text.
- Comprehensive error handling provides clear feedback for API issues.
- Debug system helps users troubleshoot configuration and connectivity problems.

## Phase 4 - Documentation and Polish
**Objective**: Complete documentation and add finishing touches to the plugin.

**Files**:
- `README.md` (created)
- `doc/vocal.txt` (created)
- `lua/vocal/init.lua` (minor updates)

**Completed**:
- [x] Created comprehensive documentation in `doc/vocal.txt` with:
  - Installation instructions
  - Configuration options
  - Command usage
  - Troubleshooting guide
- [x] Written detailed README.md with:
  - Plugin overview and features
  - Quick start guide
  - Configuration examples
  - Dependencies and requirements

**Pending**:
- [ ] Add health check function for debugging
- [ ] Add support for custom keymappings
- [ ] Consider adding tests using `plenary.test`

**Notes**:
- Documentation provides clear and concise instructions for users
- README offers a quick overview while the help file provides comprehensive details
- Both documents follow Neovim plugin conventions without unnecessary verbosity

**Future Enhancements**:
- [x] Delete recordings automatically (optional)
- [ ] Support for additional recording tools (e.g., `ffmpeg`)
- [ ] Language auto-detection configuration
- [ ] Multiple model support
- [ ] Prompt configuration for Whisper API
- [ ] Cancel recording via `:Vocal` while popup is open
- [ ] Support for longer recordings with chunking
- [ ] Local Whisper model support as Alternative to API
