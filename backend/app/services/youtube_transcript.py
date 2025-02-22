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


def transform_transcript(transcript_list: list) -> dict:
    """
    Transform the transcript list to a dictionary where:
    - Keys are unique sentences.
    - Values are sets of start times when the sentence appears.
    """
    transcript_dict = defaultdict(set)

    for segment in transcript_list:
        transcript_dict[segment["text"]].add(segment["start"])

    return {text: sorted(times) for text, times in
            transcript_dict.items()}  # Convert sets to sorted lists for consistency


def get_transcript(youtube_url: str) -> dict:
    """
    Retrieve and transform the transcript for the given YouTube URL.
    """
    video_id = extract_video_id(youtube_url)
    transcript_list = YouTubeTranscriptApi.get_transcript(video_id, languages=['en'])
    return transform_transcript(transcript_list)