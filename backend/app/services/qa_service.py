from transformers import AutoModelForQuestionAnswering, AutoTokenizer 
import torch
import os
import google.generativeai as genai

home_dir = "/home/stu11/s15/ts7244/brickhack_2025/brickhack_2025"
model_name = "bert-large-uncased-whole-word-masking-finetuned-squad"
model_dir = f"{home_dir}/models"
transcript_dir = f"{home_dir}/transcripts"
custom_model_dir = os.path.join(model_dir, model_name)
api_key = "AIzaSyBMxMPW8vHsKPkN2D3nf9djDweGzxTuOjI"

def read_transcript(transcript_name: str) -> str:
    transcript_path = os.path.join(transcript_dir, transcript_name)
    with open(transcript_path, "r") as file:
        transcript = file.read()
    return transcript

def get_context_for_question(question: str, transcript: str) -> str:

    model = None
    if os.path.exists(custom_model_dir):
        print("Loading model")
        tokenizer = AutoTokenizer.from_pretrained(custom_model_dir)
        model = AutoModelForQuestionAnswering.from_pretrained(custom_model_dir)
    else:
        print("Downloading model")
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForQuestionAnswering.from_pretrained(model_name)   
        model.save_pretrained(custom_model_dir)
        tokenizer.save_pretrained(custom_model_dir)
       
    inputs = tokenizer(question, transcript, return_tensors='pt')
    outputs = model(**inputs)
    answer = ""
    with torch.no_grad():
        start = torch.argmax(outputs.start_logits)
        end = torch.argmax(outputs.end_logits)
        answer = tokenizer.convert_tokens_to_string(tokenizer.convert_ids_to_tokens(inputs['input_ids'][0][start:end+1])) 

    return answer


def get_answer(question: str, transcript: str) -> str:
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-pro")
    response = model.generate_content(question)
    print(response.text)


def main():
    question = "What is Artificial Intelligence (AI)?"
    transcript = read_transcript("transcript1.txt")
    # answer = get_context_for_question(question, transcript)
    # print(answer)
    get_answer(question, transcript)

if __name__ == "__main__":
    main()



