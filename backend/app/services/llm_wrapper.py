from transformers import AutoModelForQuestionAnswering, AutoTokenizer
import torch
import os
import google.generativeai as genai
import re
import os

home_dir = "C:\Users\tejak\OneDrive\Documents\RIT\projects\brickhack_2025"
model_name = "bert-large-uncased-whole-word-masking-finetuned-squad"
model_dir = f"{home_dir}\\models"
transcript_dir = f"{home_dir}\\transcripts"
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
        answer = tokenizer.convert_tokens_to_string(
            tokenizer.convert_ids_to_tokens(inputs['input_ids'][0][start:end + 1]))

    return answer


def answer_user_query(transcript: str, question: str) -> str:
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-pro")
    prompt = get_prompt(f"{home_dir}//data//prompts//user_query.txt", transcript, question)
    response = model.generate_content(prompt)
    response = extract_text(response)
    return response


def generate_notes(transcript: str) -> str:
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-pro")
    prompt = get_prompt(f"{home_dir}//data//prompts//notes.txt", transcript, "")
    response = model.generate_content(prompt)
    response = extract_text(response)
    return response

def generate_quiz(transcript:str, difficulty_level:str) -> list:
    print("Generating quiz")
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-pro")
    prompt = get_prompt(f"{home_dir}//data//prompts//quiz.txt", transcript, difficulty_level)
    answer_choices = []
    response = None
    while len(answer_choices) != 10:
        response = model.generate_content(prompt)
        response = extract_text(response)
        answer_choices = get_quiz_answers(response)

    questions = create_quizzes(response, answer_choices)

    return questions

def create_quizzes(response:str,answer_choices: list) -> None:
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-pro")
    prompt = get_prompt(f"{home_dir}//data//prompts//format_quiz.txt",response,"")
    response = model.generate_content(prompt)
    response = extract_text(response)
    return response
    # question_pattern = r"\*\*Question (\d+):\*\*(.*?)\s*(A\..*?)\s*(B\..*?)\s*(C\..*?)\s*(D\..*?)\s*\*?\*?Correct answer: ([A-D])\*?\*?"
    # matches = re.findall(question_pattern, response, re.DOTALL)
    # questions = []
    # for match in matches:
    #     question_number = match[0]
    #     question_text = match[1].strip()
    #     options = [match[2].strip(), match[3].strip(), match[4].strip(), match[5].strip()]
    #     correct_answer = match[6]

    #     question_data = {
    #         "question": question_text,
    #         "options": options,
    #         "answer": correct_answer
    #     }
    #     questions.append(question_data)
    # return questions


def get_quiz_answers(response: str) -> list:
    pattern = r"(:\s)([A-Da-d])"
    matches = re.findall(pattern, response)
    answer_choices = [match[1] for match in matches]
    return answer_choices


def extract_text(response: str) -> str:
    response = response.candidates[0].content.parts[0].text
    return response


def get_prompt(file: str, transcript: str, user_parameter: str) -> str:
    transcript_placeholder = "[Insert the lecture transcript here.]"
    user_submitted_placeholder = "[Insert the user submitted parameter here]"
    prompt = None
    with open(file, "r") as file:
        prompt = file.read()
    prompt = prompt.replace(transcript_placeholder, transcript)
    prompt = prompt.replace(user_submitted_placeholder, user_parameter)
    return prompt


def main():
    question = " What is the role of charge interactions in the phenomenon of light refraction?"
    transcript = read_transcript("fcfQkxwz4Oo_transcript.txt")
    # answer = get_context_for_question(question, transcript)
    # print(answer)
    # answer = answer_user_query(transcript, question)
    # answer = generate_notes(transcript)
    answer = generate_quiz(transcript, "Easy")
    # print(answer)


if __name__ == "__main__":
    main()



