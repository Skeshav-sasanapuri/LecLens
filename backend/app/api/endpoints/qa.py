from flask import Blueprint, request, jsonify
from ...services import llm_wrapper

question_bp = Blueprint('question', __name__)

@question_bp.route('/ask', methods=['POST'])
def ask_question():
    data = request.json
    session_id = data.get('session_id')
    question = data.get('question')

    if not session_id or not question:
        return jsonify({"error": "Missing session ID or question"}), 400

    # Retrieve transcript from Redis
    transcript_json = {}

    if not transcript_json:
        return jsonify({"error": "Session ID not found"}), 404

    transcript = json.loads(transcript_json)  # Convert back to dictionary

    # Process the question (placeholder for actual logic)
    response = "Here is a response based on the video."

    return jsonify({"session_id": session_id, "relevant_time_stamps": response, "conversation": transcript})
