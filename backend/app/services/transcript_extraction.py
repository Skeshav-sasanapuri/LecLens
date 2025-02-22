from openai import OpenAI

def audio_to_transcript(openai_key,audio):
    """
    Input:
    openai_key: API key for openai
    audio: Audion file data in mp3. 
    Output:
    Transcript with timeframe, list of TranscriptWord object.
    Description:
    TranscriptWord has three parameters, end, start and word.
    start: Start time.
    end: End time.
    word: The word in transcript.
    """
    client = OpenAI(api_key=openai_key)
    transcript = client.audio.transcriptions.create(
                model="whisper-1", 
                file=audio,
                response_format="verbose_json",
                timestamp_granularities=["word"]
                )
    return transcript.words

def get_audio_data(file_path):
    """
    Input:
    file_path: Path to audio file.
    Output:
    audio data.
    """
    audio = open(file_path,'rb')
    return audio