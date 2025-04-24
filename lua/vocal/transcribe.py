import sys

import whisper


def main(audio_file, model_name, model_path):
    try:
        # Load the Whisper model
        model = whisper.load_model(model_name, download_root=model_path)
        # Transcribe the audio file
        result = model.transcribe(audio_file)
        print(result["text"])
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(
            "Usage: python transcribe.py <audio_file> <model_name> <model_path>",
            file=sys.stderr,
        )
        sys.exit(1)
    audio_file = sys.argv[1]
    model_name = sys.argv[2]
    model_path = sys.argv[3]
    main(audio_file, model_name, model_path)
