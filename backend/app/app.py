from flask import Flask
from api.endpoints.notes import notes_bp
from api.endpoints.questions import question_bp
from api.endpoints.quiz import quiz_bp
from api.endpoints.upload import upload_bp
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Register Blueprints
app.register_blueprint(upload_bp)
app.register_blueprint(question_bp)
app.register_blueprint(quiz_bp)
app.register_blueprint(notes_bp)

if __name__ == '__main__':
    app.run(debug=True)