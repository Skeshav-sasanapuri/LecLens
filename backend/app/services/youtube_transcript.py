from collections import defaultdict
import re
from youtube_transcript_api import YouTubeTranscriptApi


def extract_video_id(youtube_url: str) -> str:
    """
    Extract the video ID from a YouTube URL.
    """
    patterns = [
        r"(?:v=|\/)([0-9A-Za-z_-]{11}).*",
        r"youtu\.be\/([0-9A-Za-z_-]{11})"
    ]
    for pattern in patterns:
        match = re.search(pattern, youtube_url)
        if match:
            return match.group(1)
    raise ValueError("Invalid YouTube URL provided.")


def transform_transcript(transcript_list: list) -> tuple:
    """
    Transform the transcript list to a dictionary where:
    - Keys are unique sentences.
    - Values are sets of start times when the sentence appears.
    """
    transcript_dict = defaultdict(set)
    full_transcript = []

    for segment in transcript_list:
        text = segment["text"].replace("\n", " ")
        transcript_dict[segment["text"]].add(segment["start"])
        full_transcript.append(text)
    full_transcript_str = " ".join(full_transcript)
    formatted_transcript_timestamps = {text: sorted(times) for text, times in transcript_dict.items()}

    return formatted_transcript_timestamps, full_transcript_str  # Convert sets to sorted lists for consistency


def get_transcript(youtube_url: str) -> tuple:
    """
    Retrieve and transform the transcript for the given YouTube URL.
    """
    video_id = extract_video_id(youtube_url)
    transcript_list = YouTubeTranscriptApi.get_transcript(video_id, languages=['en'])
    transcript_with_timestamps, full_transcript = transform_transcript(transcript_list)
    return transcript_with_timestamps, full_transcript
