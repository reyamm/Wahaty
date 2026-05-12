# Wahaty

Wahaty is a child-safe Arabic AI assistant system designed for children, parents, and researchers. The system provides safe, age-appropriate Arabic interaction through a controlled AI pipeline that combines safety filtering, parental supervision, intent classification, retrieval-based grounding, response generation, and output moderation.

The project is built as a mobile application using Flutter and a backend service using FastAPI. The AI pipeline uses Gemini for response generation and a fine-tuned AraBERT-based classifier for Arabic intent detection and routing.

## Project Purpose

General-purpose AI assistants are not always suitable for young users. They may produce inaccurate, unsafe, or age-inappropriate answers, and they often lack parent-facing supervision tools. Wahaty addresses this gap by providing a safer Arabic-first AI assistant experience for children.

Wahaty focuses on:

- Safe and age-appropriate Arabic responses.
- Parent-supervised interaction.
- Input and output safety checks.
- Arabic intent classification.
- Retrieval-Augmented Generation (RAG) and Multi-RAG routing.
- Child-friendly text and voice interaction.
- Activity logging and parent controls.

## Main Features

### Kid Mode

Kid Mode allows children to interact with the assistant through text and voice. The child can ask questions, request stories, receive explanations, or ask for emotional support. Before a response reaches the child, it passes through the safety and moderation pipeline.

### Parent Mode

Parent Mode gives parents control over the child's experience. Parents can manage blocked words, review activity logs, adjust restrictions, and supervise how the child uses the system.

### Safety Layers

Wahaty uses a layered safety design instead of relying only on the language model. The safety pipeline includes:

- Input filtering for unsafe or restricted prompts.
- Parent-defined blocked words and topics.
- Intent classification for routing.
- Safe handling of soft-unsafe and hard-unsafe requests.
- Output moderation before showing the final answer.
- Safe fallback responses when needed.

### Intent Classification and Routing

The system classifies each Arabic query into a suitable intent before deciding how it should be handled. Example intents include:

- General questions.
- Curriculum questions.
- Story requests.
- Religious questions.
- Emotional-support prompts.
- Soft-unsafe prompts.
- Hard-unsafe prompts.

The routing step helps the system send each query to the correct response path instead of treating all child questions the same.

### RAG and Multi-RAG

Wahaty uses retrieval-based grounding to improve answer reliability. Instead of depending only on the modelâs internal knowledge, the system retrieves relevant information from prepared knowledge sources.

The Multi-RAG version separates knowledge into different branches, allowing the system to retrieve from the most relevant source based on the detected intent.

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile application | Flutter |
| Backend | FastAPI |
| Main language | Arabic |
| Response generation | Gemini |
| Intent classification | AraBERT |
| Retrieval approach | RAG and Multi-RAG |
| Safety design | Input guard, parent policy, output guard |
| Supported platforms | Android, iOS, Web, macOS, Windows, Linux |




## Backend Overview

The backend handles the AI pipeline and connects the application to the system logic. It is responsible for processing child queries, applying safety checks, selecting the correct route, retrieving relevant context, generating responses, and returning the final moderated answer.

Main backend files shown in the project include:

- `main.py`: Backend entry point.
- `rag_utils.py`: Utility functions for retrieval and RAG handling.
- `wahaty_v6.py`: Main Wahaty pipeline implementation.
- `LATEST_MULTIRAG_INDEX.json`: Current Multi-RAG index metadata.
- `safety/`: Safety rules and moderation logic.
- `rag_store/`: Stored retrieval data.
- `child_memories/`: Child-specific memory data.

## Running the Flutter App

From the project root, install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

To choose a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

## Running the Backend

Go to the backend folder:

```bash
cd backend
```

Create and activate a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

Install backend dependencies:

```bash
pip install -r requirements.txt
```

Run the FastAPI backend:

```bash
uvicorn main:app --reload
```

If the backend is structured as a package, run it using the correct module path used in your local project.

## Environment Variables

The backend may require API keys and configuration values. Keep them in a local `.env` file and do not upload them to GitHub.

Example:

```env
GEMINI_API_KEY=your_api_key_here
```

Before pushing the project, make sure `.env` is listed inside `.gitignore`.

## Evaluation Summary

Wahaty was evaluated using safety and quality tests, including red-team prompts. The final Multi-RAG version showed strong safety and response-quality behavior, including:

| Metric | Result |
|---|---:|
| Safety | 100.0% |
| Child appropriateness | 100.0% |
| Correct retrieval behavior | 100.0% |
| Unsafe-detail leakage | 0.0% |
| Correct behavior | 98.5% |
| Helpfulness | 98.5% |

These results show that combining safety layers, parental controls, Arabic intent classification, and Multi-RAG retrieval can improve the safety and reliability of Arabic AI interaction for children.

## Notes for Developers

- Do not commit API keys or `.env` files.
- Keep parent-control logic separate from model-only behavior.
- Test unsafe, borderline, and safe prompts after any pipeline change.
- Keep Arabic normalization consistent between training, routing, and retrieval.
- Update the Multi-RAG index whenever the knowledge sources change.
- Make sure the output guard runs before any response is shown to the child.

## Team

Wahaty was developed as a Bachelor of Science in Computer Science graduation project at Imam Mohammad Ibn Saud Islamic University.

Team members:

- Reyam Saleh Albalihi
- Rana Alzelfawi
- Deema Alsaud

Supervisor:

- Dr. Dhouha Ahmed Ben Noureddine

## License

This project is intended for academic and research purposes. 
