import json
from sentence_transformers import SentenceTransformer, util

# Load the model once to improve efficiency
MODEL_NAME = "paraphrase-MiniLM-L6-v2"
model = SentenceTransformer(MODEL_NAME)

# Define minimum similarity threshold
SIMILARITY_THRESHOLD = 0.3
TOP_K = 10


def find_relevant_sentences(question, transcript_data):
    """
    Finds the top 10 most relevant sentences in a transcript based on a user question using semantic similarity.

    Args:
        question (str): The user's question.
        transcript_data (dict): Dictionary containing the transcript.
                                Format: { "sentence": [timestamp] }

    Returns:
        list: A list of dictionaries, each containing "sentence", "timestamp", and "relevance_score",
              sorted by relevance_score in descending order.
    """
    if not transcript_data:
        return []

    sentences = list(transcript_data.keys())
    timestamps = [
        transcript_data[sentence][0] if isinstance(transcript_data[sentence], list) and transcript_data[sentence] else
        transcript_data[sentence]
        for sentence in sentences
    ]

    # Encode all sentences and the question
    embeddings = model.encode(sentences + [question], convert_to_tensor=True)
    question_embedding = embeddings[-1]
    transcript_embeddings = embeddings[:-1]

    relevant_sentences = []
    for i in range(len(sentences)):
        cosine_similarity = util.pytorch_cos_sim(question_embedding, transcript_embeddings[i])[0].item()

        # Only consider sentences above the similarity threshold
        if cosine_similarity > SIMILARITY_THRESHOLD:
            relevant_sentences.append({
                "sentence": sentences[i],
                "timestamp": timestamps[i],
                "relevance_score": round(cosine_similarity, 4)  # Format score to 4 decimal places
            })

    # Sort by highest similarity score and return the top K results
    relevant_sentences = sorted(relevant_sentences, key=lambda x: x["relevance_score"], reverse=True)
    return relevant_sentences[:TOP_K]

