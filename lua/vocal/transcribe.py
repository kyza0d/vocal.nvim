import sys
import threading
import time
from pathlib import Path

# Make sure whisper is installed
try:
    import whisper
except ImportError:
    print("Error: whisper library not found. Please install it.", file=sys.stderr)
    sys.exit(1)


def is_model_downloaded(model_name, model_dir_path):
    """Check if the whisper model .pt file exists in the specified directory."""
    try:
        # Ensure model_dir_path is a Path object and points to the directory
        model_dir = Path(model_dir_path).expanduser().resolve()
        if not model_dir.is_dir():
            # If the user provided a file path inadvertently, use its parent directory
            print(
                f"Warning: Provided model path '{model_dir_path}' is not a directory. Using parent directory '{model_dir.parent}'.",
                file=sys.stderr,
            )
            model_dir = model_dir.parent
            if not model_dir.is_dir():
                print(
                    f"Error: Could not determine a valid model directory from '{model_dir_path}'.",
                    file=sys.stderr,
                )
                return False

        # Whisper model files end with .pt
        model_file = model_dir / (model_name + ".pt")
        # print(f"Debug: Checking for model file at: {model_file}", file=sys.stderr) # Optional debug print
        return model_file.is_file()  # Check if it's specifically a file
    except Exception as e:
        # Log error for debugging, assume not downloaded on error
        print(f"Error checking model existence: {e}", file=sys.stderr)
        return False


def print_status(message, is_download=False):
    """Prints status messages, directing download status to stderr."""
    # Ensure message is a string
    message_str = str(message)
    output_stream = sys.stderr if is_download else sys.stdout
    prefix = "DOWNLOAD_STATUS:" if is_download else ""
    try:
        print(f"{prefix}{message_str}", flush=True, file=output_stream)
    except Exception as e:
        # Fallback if printing fails for some reason
        try:
            sys.stderr.write(f"Error printing status '{prefix}{message_str}': {e}\n")
            sys.stderr.flush()
        except:
            pass  # Ignore further errors during error reporting


def monitor_download(model_name, stop_event, last_update):
    """Monitors download progress by sending periodic updates."""
    while not stop_event.is_set():
        current_time = time.time()
        # Send progress update every 500ms if no other update happened
        if current_time - last_update[0] > 0.5:
            print_status(f"DOWNLOADING_PROGRESS:{model_name}", True)
            last_update[0] = current_time  # Update last update time
        time.sleep(0.1)  # Sleep briefly


def transcribe_audio(audio_file, model_name, model_path_config):
    """Loads model (downloading if necessary) and transcribes audio."""
    download_monitor_thread = None
    stop_event = threading.Event()

    try:
        # Determine the directory where models should be/are stored
        model_dir_path_obj = Path(model_path_config).expanduser().resolve()
        if not model_dir_path_obj.exists():
            print(
                f"Warning: Model directory '{model_path_config}' does not exist. Attempting to create.",
                file=sys.stderr,
            )
            try:
                model_dir_path_obj.mkdir(parents=True, exist_ok=True)
            except Exception as mkdir_e:
                print(
                    f"Error: Failed to create model directory '{model_dir_path_obj}': {mkdir_e}",
                    file=sys.stderr,
                )
                sys.exit(1)
        elif not model_dir_path_obj.is_dir():
            # If the path exists but isn't a directory, use its parent
            parent_dir = model_dir_path_obj.parent
            print(
                f"Warning: Provided model path '{model_path_config}' is not a directory. Using parent directory '{parent_dir}'.",
                file=sys.stderr,
            )
            model_dir_path_obj = parent_dir
            if not model_dir_path_obj.is_dir():
                print(
                    f"Error: Could not determine a valid model directory from '{model_path_config}'. Parent '{parent_dir}' is also not a directory.",
                    file=sys.stderr,
                )
                sys.exit(1)

        model_download_dir = str(
            model_dir_path_obj
        )  # Use this dir for whisper's download_root

        # Check existence using the determined directory
        model_exists = is_model_downloaded(model_name, model_download_dir)

        if model_exists:
            print_status("MODEL_ALREADY_DOWNLOADED", True)
        else:
            print_status(f"DOWNLOADING_MODEL:{model_name}", True)
            # Start download monitoring thread ONLY if download is actually needed
            last_update = [time.time()]  # Use a list to pass by reference
            download_monitor_thread = threading.Thread(
                target=monitor_download,
                args=(model_name, stop_event, last_update),
                daemon=True,
            )
            download_monitor_thread.start()

        # Load the model, telling whisper where to look/download
        # Pass download_root correctly
        model = whisper.load_model(name=model_name, download_root=model_download_dir)

        if not model_exists:
            # Stop the monitoring thread ONLY if it was started
            stop_event.set()
            if download_monitor_thread:
                download_monitor_thread.join(
                    timeout=2.0
                )  # Wait briefly for thread to finish
            print_status("MODEL_DOWNLOAD_COMPLETE", True)

        # Proceed with transcription
        # Ensure audio_file path is valid before passing to whisper
        audio_file_path = Path(audio_file)
        if not audio_file_path.is_file():
            print(f"Error: Audio file not found at '{audio_file}'", file=sys.stderr)
            sys.exit(1)

        # print(f"Debug: Transcribing audio file: {audio_file}", file=sys.stderr) # Optional debug print
        result = model.transcribe(audio_file)
        # print(f"Debug: Transcription result: {result}", file=sys.stderr) # Optional debug print
        print(result["text"])  # Print transcription result to stdout

    except Exception as e:
        print(f"Error during transcription process: {str(e)}", file=sys.stderr)
        # Ensure download monitor thread is stopped in case of error
        if not stop_event.is_set():
            stop_event.set()
            if download_monitor_thread:
                try:
                    download_monitor_thread.join(timeout=1.0)
                except Exception:
                    pass  # Ignore errors during cleanup join
        sys.exit(1)


def main():
    """Parses arguments and calls the transcription function."""
    if len(sys.argv) != 4:
        print(
            "Usage: python transcribe.py <audio_file> <model_name> <model_path>",
            file=sys.stderr,
        )
        sys.exit(1)

    audio_file, model_name, model_path = sys.argv[1:4]
    transcribe_audio(audio_file, model_name, model_path)


if __name__ == "__main__":
    main()
