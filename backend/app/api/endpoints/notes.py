from flask import Blueprint, request, jsonify
from ...services import llm_wrapper
from ..cache import Cache

notes_bp = Blueprint('notes', __name__)

@notes_bp.route('/notes', methods=['POST'])
def get_notes():
    data = request.json
    session_id = data.get('session_id')

    if not session_id:
        return jsonify({"error": "Missing session ID"}), 400

    # Retrieve transcript from cache
    user = Cache.get_user_cache(session_id)
    transcript = user.get_transcript()

    notes = llm_wrapper.generate_notes(transcript)

    return jsonify({"session_id": session_id, "notes": notes})
