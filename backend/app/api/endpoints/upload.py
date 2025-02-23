from flask import Blueprint, request, jsonify
import uuid  # For generating session IDs
from app.services import youtube_transcript, transcript_extraction

upload_bp = Blueprint('upload', __name__)

@upload_bp.route('/upload', methods=['POST'])
def upload_video():
    data = request.json
    youtube_url = data.get('youtube_url')
    video_file = data.get('video_file')

    if not youtube_url and not video_file:
        return jsonify({"error": "Provide either a YouTube URL or a video file"}), 400

    # Generate session ID
    session_id = str(uuid.uuid4())  # remove this once teja has fixed session id


    if data.youtube_url:
        transcript_time_stamp, transcript_str = youtube_transcript.get_transcript(data.youtube_url)
    elif data.video_file:
        transcript_time_stamp, transcript_str = transcript_extraction.get_transcript_from_file(data.video_file)

    return jsonify({"session_id": session_id, "message": "Video processed and transcript stored."})
