from flask import Blueprint, request, jsonify
import uuid  # For generating session IDs
from backend.app.services import youtube_transcript, transcript_extraction
from backend.app.api.cache import Cache

upload_bp = Blueprint('upload', __name__)

@upload_bp.route('/upload', methods=['POST'])
def upload_video():
    data = request.json
    youtube_url = data.get('youtube_url')
    video_file = data.get('video_file')

    if not youtube_url and not video_file:
        return jsonify({"error": "Provide either a YouTube URL or a video file"}), 400

    # Generate session ID
    user = Cache.get_user_cache()
    session_id = user.get_sessionId()  # remove this once teja has fixed session id


    if data.youtube_url:
        transcript_time_stamps, transcript_str = youtube_transcript.get_transcript(data.youtube_url)
    else:
        transcript_time_stamps, transcript_str = transcript_extraction.get_transcript_from_file(data.video_file)

    user.set_transcript(transcript_str)
    user.set_transcript_timestamps(transcript_time_stamps)

    return jsonify({"session_id": session_id, "message": "Video processed and transcript stored."})
