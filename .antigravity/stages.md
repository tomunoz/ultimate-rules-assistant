# Stages: Ultimate Frisbee Comparative Rulebook Router App

- [x] Stage 1: Setup & Dependencies
  - [x] Initialize workspace
  - [x] Set up Python virtual environment / Conda packages
  - [x] Install backend dependencies (`fastapi`, `uvicorn`, `pypdf`, `langchain-community`, `langchain-ollama`)
  - [x] Verify Ollama local model availability

- [x] Stage 2: Backend Development (FastAPI RAG Router)
  - [x] Programmatic router implementation in `backend/app.py`
  - [x] Multi-PDF parsing and context extraction logic (isolated for each selected league)
  - [x] Implement dual-league comparison context grouping (no context cross-talk)
  - [x] Set up custom Comparative AI Executive Agent persona prompting
  - [x] Incorporate `backend/mock_data.json` scenario list endpoints

- [x] Stage 3: Frontend Development (Responsive Flutter App)
  - [x] Define `frontend/pubspec.yaml` configuration with required packages
  - [x] Build `frontend/lib/main.dart` with premium custom dark theme and responsive sizing
  - [x] Create `frontend/lib/services/api_service.dart` HTTP client pointing to the FastAPI server
  - [x] Design `frontend/lib/screens/home_screen.dart` with:
    - [x] Responsive glassmorphic layout
    - [x] Mode Switcher (Single Review vs. Compare Leagues)
    - [x] Dynamic Selectors (League A and League B with duplicate prevention)
    - [x] Horizontal scrollable scenario cards utilizing `mock_data.json`
    - [x] Expert Dual-Output View (split-screen columns on Web/Desktop, stacked/tabbed on Mobile)

- [x] Stage 4: Automated Testing & Verification
  - [x] Create python test script `backend/test_backend.py`
  - [x] Inject comparison payload `["USAU", "WFDF"]` and query
  - [x] Assert separated output structure and verify zero crosstalk
  - [x] Create walkthrough documentation
