## Plugin Details
- **Repository**: [vocal.nvim](https://github.com/kyza0d/vocal.nvim)
- **Version**: 0.2.0
- **Resources**:
  - [README.md](https://github.com/kyza0d/vocal.nvim/blob/main/README.md)
  - [vocal.txt](https://github.com/kyza0d/vocal.nvim/blob/main/doc/vocal.txt)

### On-going

  - [~] Maintain code quality
      - Clean and organized
      - Organized plugin structure
      - Sane set of defaults

  - [~] Plugin UX/UI
    - Status window

  - [~] Cross-platform compatibility
    - [x] Arch Linux 
      - [ ] API functionality isn't reliable
    - [ ] Windows (not working)
      - [ ] Not getting default device
      - [ ] Issues with reading recorded audio 
    - [ ] Mac (not tested)


## Phase 1: Initial Development

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
    - [x] Local Transcription
      - [x] Download model automatically
      - [x] Use existing model if one is found
      - [x] Use local method by default
      - [x] Show feedback while downloading model
    - [ ] UI Improvements
      - [x] Improve upon window design and feedback
      - [ ] Add custom highlights groups
    - [x] Add support for custom keymaps
    - [ ] Automate CHANGELOG.md generation and release process
    - [ ] Monitor for inconsistent transcription errors in with API

## Phase 2: Stability and Testing

  - [~] Switch to using `plenary.curl` for API calls
      - [ ] (fix) Error with processing multiple forms
    - [ ] Determine necessary tests and implement them
    - [ ] Add in `:checkhealth vocal`

## Phase 3: Feature Expansion

  - [ ] Configure plugin appearance with `config.layout`
  - [ ] Custom commands which use instructions when transcribing
  - [ ] Implement real-time transcription

### Cancelled
  - [-] Floating window for recording
