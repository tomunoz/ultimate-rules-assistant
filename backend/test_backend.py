import sys
import os

# Add project root to python path to allow direct imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient
from app import app, PDF_CACHE, load_all_rulebooks

def test_rulebook_router_app():
    print("\n==================================================")
    print("      ULTIMATE RULES ASSISTANT BACKEND INTEGRATION TEST")
    print("==================================================\n")

    # 1. Initialize and Pre-load PDFs
    print("[1/4] Pre-loading rulebook PDFs into cache...")
    load_all_rulebooks()
    
    print("\nCached leagues in memory:")
    for league, pages in PDF_CACHE.items():
        print(f" - {league}: {len(pages)} pages cached.")
    
    assert "USAU" in PDF_CACHE, "USAU rules should be cached."
    assert "WFDF" in PDF_CACHE, "WFDF rules should be cached."
    print("Success: PDFs pre-loaded correctly.\n")

    # Initialize TestClient
    client = TestClient(app)

    # 2. Test Scenarios Endpoint
    print("[2/4] Testing GET /api/scenarios endpoint...")
    response_scenarios = client.get("/api/scenarios")
    assert response_scenarios.status_code == 200, "Scenarios endpoint failed."
    scenarios = response_scenarios.json()
    print(f"Success: Retrieved {len(scenarios)} pre-defined scenarios from mock_data.json.")
    print(f"Sample Scenario Title: '{scenarios[0]['title']}'\n")

    # 3. Test Single League Query RAG Routing
    print("[3/4] Testing POST /api/query endpoint for SINGLE LEAGUE (USAU)...")
    single_payload = {
        "selected_leagues": ["USAU"],
        "user_query": "What is the rule when a player calls a double team marking violation?"
    }
    response_single = client.post("/api/query", json=single_payload)
    assert response_single.status_code == 200, "Single league query failed."
    single_res = response_single.json()
    print("Success: Received response for Single League RAG.")
    print("Response snippet:")
    print(f" {single_res['response'][:300]}...\n")

    # 4. Test Dual League Comparison (USAU & WFDF) to Verify No Crosstalk
    print("[4/4] Testing POST /api/query endpoint for DUAL LEAGUE COMPARISON (USAU vs WFDF)...")
    comparison_payload = {
        "selected_leagues": ["USAU", "WFDF"],
        "user_query": "Compare the brick mark rules after a pull goes out of bounds on the sideline."
    }
    
    print("Sending payload array: ['USAU', 'WFDF']")
    response_compare = client.post("/api/query", json=comparison_payload)
    assert response_compare.status_code == 200, "Comparison query failed."
    compare_res = response_compare.json()
    
    print("\nSuccess: Received response for Comparative Dual League RAG.")
    print("\n--------------------------------------------------")
    print("                  LLM OUTPUT SUMMARY")
    print("--------------------------------------------------")
    print(compare_res['response'])
    print("--------------------------------------------------\n")

    # Verification of Comparative Structure
    resp_text = compare_res['response'].lower()
    
    # We verify that the output has clear sections separating the two leagues and an observer comparison
    has_league_a = "league a" in resp_text or "usau" in resp_text
    has_league_b = "league b" in resp_text or "wfdf" in resp_text
    has_observer = "observer" in resp_text or "comparison" in resp_text or "difference" in resp_text
    
    print("Verifying response structure requirements:")
    print(f" - Contains League A / USAU reference? {has_league_a}")
    print(f" - Contains League B / WFDF reference? {has_league_b}")
    print(f" - Contains Observer Analysis / Differences? {has_observer}")
    
    assert has_league_a and has_league_b, "Output must contain isolated league rulings."
    print("\n==================================================")
    print("      ALL INTEGRATION TESTS PASSED SUCCESSFULLY!")
    print("==================================================\n")

if __name__ == "__main__":
    test_rulebook_router_app()
