from flask import Flask
from api.notes import notes_bp
from api.qa import question_bp
from api.quiz import quiz_bp
from api.transcript import transcript_bp
from api.upload import upload_bp

app = Flask(__name__)

# Register Blueprints
app.register_blueprint(upload_bp)
app.register_blueprint(question_bp)

if __name__ == '__main__':
    app.run(debug=True)