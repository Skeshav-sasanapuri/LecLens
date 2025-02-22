# backend/app/api/endpoints/transcript.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services import youtube_transcript, video_processing

router = APIRouter()

class TranscriptRequest(BaseModel):
    youtube_url: str = None
    video_file_path: str = None  # For local video files

@router.post("/transcript")
def fetch_transcript(request: TranscriptRequest):
    """
    Fetch the transcript (with timestamps) for a given video.
    Provide either a YouTube URL or a local video file path.
    """
    try:
        if request.youtube_url:
            transcript = youtube_transcript.get_transcript(request.youtube_url)
        elif request.video_file_path:
            transcript = video_processing.get_transcript_from_file(request.video_file_path)
        else:
            raise ValueError("Either 'youtube_url' or 'video_file_path' must be provided.")
        return {"transcript": transcript}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
