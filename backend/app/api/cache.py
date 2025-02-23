import uuid
from backend.app.api.user import User

class Cache:

    info = {}
    session = uuid.uuid4()

    @staticmethod
    def get_user_cache(sessionId = None):
        if sessionId is None:
            sessionId = Cache.generate_session_id()
            Cache.info[sessionId] = User(sessionId)
       
        return Cache.info[sessionId]

    @staticmethod
    def generate_session_id():
        sessionId = str(uuid.uuid4())
        return sessionId
    
def main():
    user = Cache.get_user_cache()
    sessionId = user.get_sessionId()
    user.set_transcript("Hello")
    
    user = Cache.get_user_cache(sessionId)
    print(user.get_transcript())

main()
