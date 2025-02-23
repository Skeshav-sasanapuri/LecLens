class User:

    def __init__(self, sessionId):
        self.sessionId = sessionId
        self.transcript_timestamps = None
        self.transcript = None
        self.conversations = []

    def get_sessionId(self):
        return self.sessionId

    def set_transcript(self, transcript):
        self.transcript = transcript
    
    def set_transcript_timestamps(self, transcript_timestamps):
        self.transcript_timestamps = transcript_timestamps
    
    def set_conversations(self, conversations):
        self.conversations = conversations
    
    def get_transcript(self):
        return self.transcript

    def get_transcript_timestamps(self):
        return self.transcript_timestamps
    
    def get_conversations(self):
        return self.conversations