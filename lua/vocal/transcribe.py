import sys
import threading
import time
from pathlib import Path

try:
    import whisper
except ImportError:
    print("Error: whisper library not found. Please install it.", file=sys.stderr)
    sys.exit(1)


def is_model_downloaded(model_name: str, model_dir_path: str) -> bool:
    """Checks if whisper model .pt file exists in specified directory.

    --- Args:
        model_name: Name of the model to check
        model_dir_path: Directory path to check for model file
    --- Returns:
        bool: True if model file exists, False otherwise
    """
    try:
        model_dir = Path(model_dir_path).expanduser().resolve()
        if not model_dir.is_dir():
            print(
                f"Warning: Path '{model_dir_path}' is not a directory. Using parent '{model_dir.parent}'.",
                file=sys.stderr,
            )
            model_dir = model_dir.parent
            if not model_dir.is_dir():
                print(
                    f"Error: Invalid model directory '{model_dir_path}'.",
                    file=sys.stderr,
                )
                return False
        return (model_dir / f"{model_name}.pt").is_file()
    except Exception as e:
        print(f"Error checking model: {e}", file=sys.stderr)
        return False


def print_status(message: str, is_download: bool = False) -> None:
    """Prints status messages to appropriate stream.

    --- Args:
        message: Message to print
        is_download: If True, prints to stderr with download prefix
    """
    output = sys.stderr if is_download else sys.stdout
    prefix = "DOWNLOAD_STATUS:" if is_download else ""
    try:
        print(f"{prefix}{message}", flush=True, file=output)
    except Exception as e:
        sys.stderr.write(f"Error printing status '{prefix}{message}': {e}\n")
        sys.stderr.flush()


def monitor_download(
    model_name: str, stop_event: threading.Event, last_update: list
) -> None:
    """Monitors download progress with periodic updates.

    --- Args:
        model_name: Name of the model being downloaded
        stop_event: Event to signal thread termination
        last_update: List containing last update timestamp
    """
    while not stop_event.is_set():
        current_time = time.time()
        if current_time - last_update[0] > 0.5:
            print_status(f"DOWNLOADING_PROGRESS:{model_name}", True)
            last_update[0] = current_time
        time.sleep(0.1)


def transcribe_audio(audio_file: str, model_name: str, model_path_config: str) -> None:
    """Loads model and transcribes audio, downloading model if needed.

    --- Args:
        audio_file: Path to audio file
        model_name: Name of whisper model to use
        model_path_config: Directory path for model storage
    """
    download_monitor_thread = None
    stop_event = threading.Event()

    try:
        model_dir = Path(model_path_config).expanduser().resolve()
        if not model_dir.exists():
            print(
                f"Warning: Creating model directory '{model_path_config}'.",
                file=sys.stderr,
            )
            model_dir.mkdir(parents=True, exist_ok=True)
        elif not model_dir.is_dir():
            model_dir = model_dir.parent
            if not model_dir.is_dir():
                print(
                    f"Error: Invalid model directory '{model_path_config}'.",
                    file=sys.stderr,
                )
                sys.exit(1)

        model_download_dir = str(model_dir)
        model_exists = is_model_downloaded(model_name, model_download_dir)

        if model_exists:
            print_status("MODEL_ALREADY_DOWNLOADED", True)
        else:
            print_status(f"DOWNLOADING_MODEL:{model_name}", True)
            last_update = [time.time()]
            download_monitor_thread = threading.Thread(
                target=monitor_download,
                args=(model_name, stop_event, last_update),
                daemon=True,
            )
            download_monitor_thread.start()

        model = whisper.load_model(name=model_name, download_root=model_download_dir)

        if not model_exists:
            stop_event.set()
            if download_monitor_thread:
                download_monitor_thread.join(timeout=2.0)
            print_status("MODEL_DOWNLOAD_COMPLETE", True)

        audio_path = Path(audio_file)
        if not audio_path.is_file():
            print(f"Error: Audio file not found at '{audio_file}'", file=sys.stderr)
            sys.exit(1)

        result = model.transcribe(audio_file)
        print(result["text"])

    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)
        if not stop_event.is_set():
            stop_event.set()
            if download_monitor_thread:
                download_monitor_thread.join(timeout=1.0)
        sys.exit(1)


def main() -> None:
    """Parses command-line arguments and initiates transcription.

    --- Expects:
        sys.argv[1]: Audio file path
        sys.argv[2]: Model name
        sys.argv[3]: Model path
    """
    if len(sys.argv) != 4:
        print(
            "Usage: python transcribe.py <audio_file> <model_name> <model_path>",
            file=sys.stderr,
        )
        sys.exit(1)

    transcribe_audio(sys.argv[1], sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    main()
