# System Enforcement Rules

These rules govern the architecture, RAG document boundaries, LLM pipeline, and UX requirements of the Ultimate Frisbee Comparative Rulebook Router App. They must be strictly enforced by all development agents and sub-agents.

---

## 1. RAG ROUTING BOUNDARIES

To prevent hallucination, cross-over rules, and context blending, the backend MUST programmatically isolate document access on every query:

*   **USAU Query Only**: If `selected_leagues` contains `"USAU"`, access ONLY `knowledge/USAU_Rules.pdf`.
*   **UFA Query Only**: If `selected_leagues` contains `"UFA"`, access ONLY `knowledge/UFA_Rules.pdf`.
*   **WFDF Query Only**: If `selected_leagues` contains `"WFDF"`, access ONLY `knowledge/WFDF_Rules.pdf`.
*   **PUL Concurrency**: If `selected_leagues` contains `"PUL"`, access BOTH `knowledge/PUL_Rules.pdf` AND `knowledge/USAU_Rules.pdf` concurrently. Combine their retrieved texts into the PUL context block.

### Dual-League Separation
If `selected_leagues` contains two leagues (e.g. `["USAU", "WFDF"]`):
1.  Isolate the PDF retrieval process for League A and League B.
2.  Extract the respective context blocks **independently**.
3.  Format them into separate, clearly labeled context blocks in the final prompt.
4.  **DO NOT** mix, merge, or average the retrieved context blocks prior to prompt construction.

---

## 2. LLM SYSTEM PERSONA PROMPT

The backend synthesis must invoke this exact persona, adapting dynamically between Single-League and Comparative modes:

> "You are an expert Ultimate Frisbee rules official, head observer, and sports rules historian. Evaluate the user's scenario using ONLY the provided document text retrieved by the backend routing logic.
>
> **IF THE USER SOUGHT A SINGLE LEAGUE:**
> Provide a structured summary response indicating exactly how an official on that specific field would rule. Cite specific numbered rules or unnumbered Appendices/Section Headers accordingly.
>
> **IF THE USER SOUGHT A LEAGUE COMPARISON (2 LEAGUES):**
> Provide a structured three-part response:
> 1. **LEAGUE A RULING**: How League A handles the play, citing specific numbered rules or unnumbered appendix headers.
> 2. **LEAGUE B RULING**: How League B handles the play, citing specific numbered rules or unnumbered appendix headers.
> 3. **OBSERVER ANALYSIS & SUMMARY OF DIFFERENCES**: A rigorous analytical comparison written in the tone of an expert observer. Contrast the physical, structural, tactical, or timing differences between the two rulings (e.g., differences in field dimensions from unnumbered appendices, or differing stall counts/penalties).
>
> **CRITICAL HANDLING FOR RULE STRUCTURES:**
> *   Be explicitly aware that core gameplay rules are numbered, but critical structural segments like Appendices (e.g., USAU Beach, Youth, or Masters adjustments) are UNNUMBERED. Cite these by explicit Appendix name/Section Header and quote the text.
> *   If a retrieved rulebook context is completely silent on the scenario, explicitly state that the respective league's rulebook does not address the matter."

---

## 3. FRONTEND DESIGN AND RESPONSIVENESS

*   **Responsive Layouts**:
    *   **Web/Desktop**: Display a side-by-side comparative split screen for dual-outputs, allowing direct ocular comparison.
    *   **Mobile (iOS/Android)**: Display a clean, stacked or tabbed layout (e.g., Swipeable Tabs or segmented controller) to accommodate small screens without clutter.
*   **Duplicate Selection Prevention**:
    *   In comparison mode, ensure the user cannot select the same league in both dropdowns.
    *   Dynamically filter out or disable the selected League A from League B's options.
*   **Tactile and Glassmorphic Theme**:
    *   Apply HSL-derived colors, rich gradients, and blur backdrops (`BackdropFilter`).
    *   Include subtle micro-animations on hovering pre-defined scenarios, toggling modes, and clicking the Action Button.
