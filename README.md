# 📚 LecLens

LecLens is a GenAI-powered platform that transforms lecture videos into interactive, structured learning materials. With just a YouTube link or video upload, users can generate AI-augmented notes, ask timestamped questions, and take quizzes tailored to the content — making studying smarter, faster, and more personalized.

![LecLens Banner](link-to-banner-if-you-have-one)

---

## ✨ Features

- 🎥 **Video Input**: Upload lecture videos or paste a YouTube link  
- 📄 **Smart Note Generation**: Auto-summarized, PDF-style structured notes  
- 🤖 **AI-Powered Q&A**: Ask questions and get timestamped answers  
- 🧠 **Quiz Generator**: Create MCQs based on the video with difficulty options  
- 🔗 **Timestamps**: Clickable links to exact video moments relevant to your question  

---

## 💡 Inspiration

Imagine turning your lectures into structured study guides within seconds. LecLens makes video learning more interactive and focused by converting passive watching into active understanding — helping students study effectively, anytime, anywhere.

---

## 🧠 What It Does

- Accepts lecture input through YouTube links or file uploads
- Uses Whisper for automatic transcription
- Uses Gemini API for smart note summaries, Q&A, and quiz generation
- Displays timestamped answers and contextual insights
- Provides downloadable study materials

---

## 🛠️ How We Built It

- **Backend**: Python + Flask for API endpoints and video processing logic
- **Frontend**: Flutter for a modern, responsive user interface
- **AI Integration**:  
  - [Gemini API](https://deepmind.google) for natural language understanding  
  - [Whisper](https://openai.com/research/whisper) for speech-to-text transcription

---

## ⚙️ Tech Stack

| Layer        | Tech Used               |
|--------------|--------------------------|
| Frontend     | Flutter                 |
| Backend      | Python, Flask           |
| AI/NLP       | Whisper, Gemini API     |
| Other Tools  | OpenAI APIs, YouTube API |

---

## 🔧 Installation

### 📋 Prerequisites

- Python 3.x
- Flutter SDK
- Gemini API Key
- YouTube Data API Key (if using YouTube transcripts)

### ▶️ Running the Project

**Backend Setup**

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

**Frontend Setup**

```bash
cd frontend/flutter_app
flutter pub get
flutter run -d chrome
```

## 🗂️ Project Structure
LecLens/
│
├── backend/
│   ├── app.py
│   ├── requirements.txt
│   ├── api/
│   │   ├── cache.py
│   │   ├── user.py
│   │   └── endpoints/
│   │       ├── notes.py
│   │       ├── questions.py
│   │       ├── quiz.py
│   │       └── upload.py
│   └── services/
│       ├── llm_wrapper.py
│       ├── transcript_extraction.py
│       ├── relevant_time_stamps.py
│       └── youtube_transcript.py
│
└── frontend/flutter_app/
    ├── main.dart
    ├── components/
    │   ├── button.dart
    │   ├── common_background.dart
    │   └── square_tile.dart
    ├── pages/
    │   └── chat_page.dart
    └── transcripts/
        └── transcript_item.dart

## 🚧 Challenges We Faced

- Handling noisy or accented speech with Whisper for accurate transcription
- Designing a clean and intuitive UX for users across devices
- Linking AI-generated answers precisely with video timestamps
- Generating meaningful, contextual quiz questions automatically

## 🏆 Accomplishments

- Successfully combined transcription + NLP for deep video understanding
- Achieved timestamp-linked answers to improve user navigation
- Created customizable quiz generation to support active learning
- Developed a full-stack solution with seamless front-end/back-end integration

## 📘 What We Learned

- Leveraged Flutter to build fast, cross-platform UI
- Gained experience integrating large language models with APIs
- Learned to work with video pipelines, timestamps, and speech processing
- Strengthened our ability to design and deliver end-to-end GenAI solutions

## 🔮 What’s Next

- Enhance transcription quality with speaker diarization and noise filtering
- Improve quiz logic with Bloom’s taxonomy-style difficulty levels
- Add personalized study recommendations and flashcards
- Support collaborative features like shared notes or quizzes
- Expand support to more languages and video sources

## 🤝 Contributing
Want to improve LecLens or suggest new features? Contributions are welcome! Feel free to fork the repo, submit PRs, or open an issue.

## 📄 License
This project is licensed under the MIT License.

## 🙌 Acknowledgements

- OpenAI Whisper
- Gemini API
- Flutter
- Python Flask

## 🔗 Links
- 🔬 Demo: [link-to-demo]
- 📧 Contact: [your-email@example.com]
