from flask import Blueprint, request, jsonify
from redis_config import redis_client
import uuid  # For generating session IDs

upload_bp = Blueprint('upload', __name__)

@upload_bp.route('/upload', methods=['POST'])
def upload_video():
    data = request.json
    youtube_url = data.get('youtube_url')
    video_file = data.get('video_file')

    if not youtube_url and not video_file:
        return jsonify({"error": "Provide either a YouTube URL or a video file"}), 400

    # Generate session ID
    session_id = str(uuid.uuid4())

    # Simulate transcript generation and store in Redis
    transcript = {
        "I realized recently that I didn't really understand how a prism works, ": [0.0],
        "and I suspect most people out there don't either.": [3.703]
    }
    redis_client.set(session_id, json.dumps(transcript))  # Store transcript in Redis

    return jsonify({"session_id": session_id, "message": "Video processed and transcript stored."})
