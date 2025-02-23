import redis

# Initialize Redis once and reuse it
redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
