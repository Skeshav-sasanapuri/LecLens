from openai import OpenAI
import os
from dotenv import load_dotenv

load_dotenv()

def audio_to_transcript(openai_key,audio):
    """
    Input:
    openai_key: API key for openai.
    audio: Audion file data in mp3. 
    Output:
    Transcript Object.
    """
    client = OpenAI(api_key=openai_key)
    transcripts = client.audio.transcriptions.create(
                model="whisper-1", 
                file=audio,
                response_format="verbose_json",
                timestamp_granularities=["segment"]
                )
    return transcripts

def format_transcript(transcripts):
    """
    Input:
    transcripts: Transcripts with segment timestamps.
    Output:
    the transcript text and timestamp map.
    """
    stamp_map = {}
    for transcript in transcripts.segments:
        if transcript.text not in stamp_map:
            stamp_map[transcript.text] = [transcript.start]
        else:
             stamp_map[transcript.text].append(transcript.start)
    return stamp_map, transcript.text

def get_audio_data(file_path):
    """
    Input:
    file_path: Path to audio file.
    Output:
    audio data.
    """
    audio = open(file_path,'rb')
    return audio

if __name__ == "__main__":
    fpath = input("Enter audio file path:")
    audio = get_audio_data(fpath)
    key = os.getenv("API_KEY")
    transcripts  = audio_to_transcript(key,audio)
    transcript, stamp_map = format_transcript(transcripts=transcripts)
    print(stamp_map)