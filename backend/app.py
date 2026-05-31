import os
import re
import json
import math
import requests
from pypdf import PdfReader
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Dict, Any

app = FastAPI(title="Ultimate Rules Assistant API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request schema
class QueryRequest(BaseModel):
    selected_leagues: List[str] = Field(..., description="Array of selected leagues (1 or 2 leagues)")
    user_query: str = Field(..., description="The ultimate frisbee scenario query")

# Global PDF page cache
PDF_CACHE: Dict[str, List[Dict[str, Any]]] = {}

# Global Document Frequency Cache (for TF-IDF)
DOC_FREQUENCIES: Dict[str, Dict[str, int]] = {}

# File path routing mapping
LEAGUE_FILE_MAP = {
    "USAU": ["USAU_Rules.pdf"],
    "UFA": ["UFA_Rules.pdf"],
    "WFDF": ["WFDF_Rules.pdf"],
    "PUL": ["PUL_Rules.pdf", "USAU_Rules.pdf"]
}

# Resolve knowledge directory path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNOWLEDGE_DIR = os.path.join(PROJECT_ROOT, "knowledge")

# --- Modern Google Gemini (google.genai) Configuration ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
USING_GEMINI = False

if GEMINI_API_KEY:
    try:
        from google import genai
        client = genai.Client(api_key=GEMINI_API_KEY)
        USING_GEMINI = True
        print("\n==================================================")
        print("   GOOGLE GEMINI PRO API ACTIVATED FOR PRODUCTION")
        print("   (Using modern google.genai SDK)")
        print("==================================================\n")
    except Exception as e:
        print(f"Error configuring Google Gemini: {e}")
else:
    print("\n==================================================")
    print("   LOCAL OLLAMA ACTIVATED (DEVELOPMENT MODE)")
    print("   Set 'GEMINI_API_KEY' env var to enable Gemini Pro")
    print("==================================================\n")

# Domain Synonym Map for Query Expansion (resolving vocabulary mismatch)
SYNONYM_MAP = {
    "duration": ["quarter", "quarters", "minutes", "timing", "regulation", "time", "length"],
    "long": ["quarter", "quarters", "minutes", "timing", "regulation", "time", "length"],
    "last": ["quarter", "quarters", "minutes", "timing", "regulation", "time", "length"],
    "time": ["timing", "regulation", "quarter", "quarters", "minutes"],
    "length": ["timing", "regulation", "quarter", "quarters", "minutes"],
    "double": ["marking", "violation", "marker"],
    "foul": ["contact", "receiving", "collision", "play", "dangerous"],
    "timing": ["quarter", "quarters", "minutes", "regulation"],
    "quarters": ["minutes", "timing", "regulation", "duration"]
}

def clean_text(text: str) -> str:
    """Removes excessive spaces and formats text cleanly."""
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def tokenize(text: str) -> List[str]:
    """Helper to tokenize text for keyword relevance matching."""
    tokens = re.findall(r'\b\w{3,}\b', text.lower()) # words of length >= 3
    stop_words = {
        'the', 'and', 'for', 'with', 'you', 'this', 'that', 'from', 'but', 'are', 'not', 
        'have', 'has', 'their', 'they', 'our', 'who', 'which', 'its', 'any', 'each', 'all',
        'was', 'were', 'been', 'will', 'should', 'would', 'can', 'could', 'may', 'must'
    }
    return [t for t in tokens if t not in stop_words]

def expand_query_tokens(tokens: List[str]) -> List[str]:
    """Expands query tokens using the synonym map to resolve vocabulary mismatch."""
    expanded = list(tokens)
    for t in tokens:
        if t in SYNONYM_MAP:
            expanded.extend(SYNONYM_MAP[t])
    return list(set(expanded))

def load_all_rulebooks():
    """Extracts and caches pages from the PDFs in the background on startup, calculating TF-IDF stats."""
    print("--- PRE-LOADING ULTIMATE FRISBEE RULEBOOKS ---")
    if not os.path.exists(KNOWLEDGE_DIR):
        print(f"WARNING: Knowledge directory {KNOWLEDGE_DIR} not found.")
        return

    for file_name in os.listdir(KNOWLEDGE_DIR):
        if not file_name.endswith(".pdf"):
            continue
        
        file_path = os.path.join(KNOWLEDGE_DIR, file_name)
        league_key = None
        if "USAU" in file_name:
            league_key = "USAU"
        elif "UFA" in file_name:
            league_key = "UFA"
        elif "WFDF" in file_name:
            league_key = "WFDF"
        elif "PUL" in file_name:
            league_key = "PUL"

        if not league_key:
            continue

        try:
            print(f"Caching {file_name} for league '{league_key}'...")
            reader = PdfReader(file_path)
            pages_data = []
            for idx, page in enumerate(reader.pages):
                text = page.extract_text() or ""
                text_clean = clean_text(text)
                if text_clean:
                    pages_data.append({
                        "page_num": idx + 1,
                        "text": text_clean,
                        "tokens": tokenize(text_clean),
                        "source": file_name
                    })
            
            PDF_CACHE[league_key] = pages_data
            
            # Compute Document Frequency (DF) for this league
            df_map = {}
            for p in pages_data:
                unique_tokens = set(p["tokens"])
                for token in unique_tokens:
                    df_map[token] = df_map.get(token, 0) + 1
            DOC_FREQUENCIES[league_key] = df_map
            
            print(f"Successfully cached {len(pages_data)} pages & calculated DF for '{league_key}'.")
        except Exception as e:
            print(f"ERROR caching {file_name}: {e}")

@app.on_event("startup")
def startup_event():
    load_all_rulebooks()

def search_context_for_league(league: str, query: str, top_k: int = 5) -> str:
    """Intelligently retrieves top K relevant pages using TF-IDF and Query Expansion."""
    files_to_query = LEAGUE_FILE_MAP.get(league, [])
    if not files_to_query:
        return f"[System Error]: League '{league}' has no associated rulebook."

    # Programmatic concurrent cache assembly (Crucial Bug Fix for PUL)
    pages = []
    df_map = {}
    
    for file_name in files_to_query:
        target_key = None
        if "USAU" in file_name:
            target_key = "USAU"
        elif "UFA" in file_name:
            target_key = "UFA"
        elif "WFDF" in file_name:
            target_key = "WFDF"
        elif "PUL" in file_name:
            target_key = "PUL"
            
        if target_key and target_key in PDF_CACHE:
            pages.extend(PDF_CACHE[target_key])
            # Merge document frequencies
            for token, count in DOC_FREQUENCIES.get(target_key, {}).items():
                df_map[token] = df_map.get(token, 0) + count

    if not pages:
        return f"[No rulebook content found for {league}]"

    # Tokenize and expand query to resolve vocabulary mismatch
    query_tokens = tokenize(query)
    if not query_tokens:
        query_tokens = query.lower().split()
    
    expanded_tokens = expand_query_tokens(query_tokens)
    N = len(pages)

    # Score pages based on BM25 TF saturation * IDF * WordLength heuristic
    k1 = 1.2
    scored_pages = []
    for p in pages:
        score = 0.0
        text_lower = p["text"].lower()
        for token in expanded_tokens:
            tf = text_lower.count(token)
            if tf > 0:
                df = df_map.get(token, 0)
                # Smooth Inverse Document Frequency
                idf = math.log((N + 1) / (df + 1)) + 1
                # BM25 Term Frequency Saturation
                tf_saturated = (tf * (k1 + 1)) / (tf + k1)
                score += tf_saturated * idf * len(token)
        scored_pages.append((score, p))

    # Sort descending by score
    scored_pages.sort(key=lambda x: x[0], reverse=True)

    # Grab the top K scoring pages
    top_results = [item[1] for item in scored_pages[:top_k] if item[0] > 0]
    
    # Fallback to first few pages if no keyword matched
    if not top_results:
        top_results = pages[:2]

    context_str = ""
    for idx, p in enumerate(top_results):
        source_label = p.get("source", f"{league}_Rules.pdf")
        context_str += f"\n--- EXTRACT FROM {source_label} (Page {p['page_num']}) ---\n"
        context_str += p["text"] + "\n"

    # Inject supplementary metadata/diagram details to overcome RAG PDF extraction limits
    if "USAU_Rules.pdf" in files_to_query:
        context_str += (
            "\n--- DIAGRAM METADATA & OFFICIAL ERRATA FOR USAU ---\n"
            "- Appendix A (Field Diagram Dimensions & Layout):\n"
            "  * Standard Field Dimensions: 110 yards (100 meters) total length, 40 yards (37 meters) width. The central zone is 70 yards (64 meters) long, and each end zone is 20 yards (18.25 meters) deep.\n"
            "  * Standard Brick Mark (Section 4.G & Appendix A): Exactly 20 yards (18.25 meters) from the goal line, centered midway between the sidelines.\n"
            "  * Standard Reverse Brick Line (Appendix A): Located exactly 10 yards (9.1 meters) behind the goal line (inside the defending end zone), centered midway between the sidelines.\n"
            "- Appendix E (Youth Rules Sizing Recommendations - E.2 Recommendation table on Page 53):\n"
            "  * Under-12 (3v3 format): Central zone 25-35 yd, width 15-20 yd, end zone 5-10 yd, brick mark 7-10 yd from the goal line.\n"
            "  * Under-12 (4v4 format): Central zone 35-45 yd, width 20-25 yd, end zone 10-15 yd, brick mark 10-13 yd from the goal line.\n"
            "  * Under-15 (5v5 format): Central zone 45-55 yd, width 25-35 yd, end zone 12-18 yd, brick mark 13-16 yd from the goal line.\n"
            "  * Under-17/20 (6v6 format): Central zone 55-65 yd, width 30-35 yd, end zone 15-20 yd, brick mark 16-18 yd from the goal line.\n"
        )
    if "WFDF_Rules.pdf" in files_to_query:
        context_str += (
            "\n--- DIAGRAM METADATA & OFFICIAL ERRATA FOR WFDF ---\n"
            "- Figure 1 (WFDF Standard Field Dimensions & Layout):\n"
            "  * Standard Field Dimensions: 100 meters total length, 37 meters width. The central zone is 64 meters long, and each end zone is 18 meters deep.\n"
            "  * Standard Brick Mark (Section 2.5 & Figure 1): Located a distance equal to the length of the end zone away from each goal line (which is exactly 18 meters from the goal line), centered midway between the sidelines.\n"
        )

    return context_str.strip()

def query_llm(system_prompt: str, user_prompt: str) -> str:
    """Queries either Google Gemini API (production) or local Ollama (development fallback)."""
    # 1. Primary: Google Gemini API via modern google.genai SDK (Render Production)
    if USING_GEMINI:
        try:
            from google import genai
            from google.genai import types
            print("Querying Google Gemini via modern google.genai SDK (gemini-3.5-flash)...")
            client = genai.Client(api_key=GEMINI_API_KEY)
            response = client.models.generate_content(
                model='gemini-3.5-flash',
                contents=user_prompt,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    temperature=0.15
                )
            )
            if response.text:
                return response.text
        except Exception as e:
            print(f"Error querying Google Gemini Pro API via new SDK: {e}. Falling back to Ollama...")

    # 2. Fallback to local Ollama (Development Mode)
    url = "http://127.0.0.1:11434/api/chat"
    payload = {
        "model": "gpt-oss:120b-cloud",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "stream": False
    }
    
    try:
        response = requests.post(url, json=payload, timeout=90)
        if response.status_code == 200:
            return response.json()["message"]["content"]
    except Exception as e:
        print(f"Error querying gpt-oss:120b-cloud via chat API: {e}")

    try:
        url_gen = "http://127.0.0.1:11434/api/generate"
        payload_gen = {
            "model": "gpt-oss:120b-cloud",
            "prompt": f"System: {system_prompt}\n\nUser: {user_prompt}",
            "stream": False
        }
        response_gen = requests.post(url_gen, json=payload_gen, timeout=90)
        if response_gen.status_code == 200:
            return response_gen.json()["response"]
    except Exception as e:
        print(f"Error querying gpt-oss:120b-cloud via generate API: {e}")

    # Final Local Fallback
    print("Running local model fallback: granite3.3:2b...")
    payload["model"] = "granite3.3:2b"
    try:
        response = requests.post(url, json=payload, timeout=30)
        if response.status_code == 200:
            return response.json()["message"]["content"]
    except Exception as e:
        print(f"Error in granite3.3:2b fallback query: {e}")

    return (
        "### SYSTEM MESSAGE: SYNTHESIS ERROR\n\n"
        "Failed to connect to both Google Gemini API and local Ollama model. "
        "Please ensure 'GEMINI_API_KEY' is configured on Render, or local Ollama is running (`ollama serve`)."
    )

@app.post("/api/query")
def process_rules_query(payload: QueryRequest):
    leagues = payload.selected_leagues
    query = payload.user_query

    if not leagues or len(leagues) > 2:
        raise HTTPException(status_code=400, detail="Must select either 1 or 2 leagues.")

    system_prompt = (
        "You are an expert Ultimate Frisbee rules official, head observer, and sports rules historian. "
        "Evaluate the user's scenario using ONLY the provided document text retrieved by the backend routing logic.\n\n"
    )

    if len(leagues) == 1:
        league_a = leagues[0]
        context_a = search_context_for_league(league_a, query)

        system_prompt += (
            "IF THE USER SOUGHT A SINGLE LEAGUE:\n"
            "Provide a structured summary response indicating exactly how an official on that specific field would rule. "
            "Cite specific numbered rules or unnumbered Appendices/Section Headers accordingly.\n\n"
            "CRITICAL HANDLING FOR RULE STRUCTURES:\n"
            "- Be explicitly aware that core gameplay rules are numbered, but critical structural segments like Appendices "
            "(e.g., USAU Beach, Youth, or Masters adjustments) are UNNUMBERED. Cite these by explicit Appendix name/Section Header "
            "and quote the text.\n"
            "- If a retrieved rulebook context is completely silent on the scenario, explicitly state that the respective league's "
            "rulebook does not address the matter."
        )

        user_prompt = (
            f"USER SCENARIO QUERY: {query}\n\n"
            f"=== ROUTED RULEBOOK CONTEXT FOR LEAGUE: {league_a} ===\n"
            f"{context_a}\n\n"
            "Rule on the scenario using ONLY the text above. Cite exactly."
        )

    else:
        league_a = leagues[0]
        league_b = leagues[1]

        context_a = search_context_for_league(league_a, query)
        context_b = search_context_for_league(league_b, query)

        system_prompt += (
            "IF THE USER SOUGHT A LEAGUE COMPARISON (2 LEAGUES):\n"
            "Provide a structured three-part response:\n"
            "1. LEAGUE A RULING: How League A handles the play, citing specific numbered rules or unnumbered appendix headers.\n"
            "2. LEAGUE B RULING: How League B handles the play, citing specific numbered rules or unnumbered appendix headers.\n"
            "3. OBSERVER ANALYSIS & SUMMARY OF DIFFERENCES: A rigorous analytical comparison written in the tone of an expert observer. "
            "Contrast the physical, structural, tactical, or timing differences between the two rulings (e.g., differences in field dimensions "
            "from unnumbered appendices, or differing stall counts/penalties).\n\n"
            "CRITICAL HANDLING FOR RULE STRUCTURES:\n"
            "- Be explicitly aware that core gameplay rules are numbered, but critical structural segments like Appendices "
            "(e.g., USAU Beach, Youth, or Masters adjustments) are UNNUMBERED. Cite these by explicit Appendix name/Section Header "
            "and quote the text.\n"
            "- If a retrieved rulebook context is completely silent on the scenario, explicitly state that the respective league's "
            "rulebook does not address the matter.\n\n"
            "DO NOT let rule crossover or context blending occur. Base the ruling for League A ONLY on League A's Context, "
            "and League B ONLY on League B's Context."
        )

        user_prompt = (
            f"USER SCENARIO QUERY: {query}\n\n"
            f"=== ROUTED RULEBOOK CONTEXT FOR LEAGUE A: {league_a} ===\n"
            f"{context_a}\n\n"
            f"=== ROUTED RULEBOOK CONTEXT FOR LEAGUE B: {league_b} ===\n"
            f"{context_b}\n\n"
            f"Rule on the scenario and contrast the two leagues. Make sure part 1 uses ONLY Context A, and part 2 uses ONLY Context B."
        )

    response_text = query_llm(system_prompt, user_prompt)
    return {
        "selected_leagues": leagues,
        "query": query,
        "response": response_text
    }

@app.get("/api/scenarios")
def get_scenarios():
    """Fetches the 10 pre-defined scenarios for the frontend switcher."""
    mock_data_path = os.path.join(PROJECT_ROOT, "backend", "mock_data.json")
    if os.path.exists(mock_data_path):
        try:
            with open(mock_data_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error reading mock data: {e}")
    raise HTTPException(status_code=404, detail="mock_data.json not found")
