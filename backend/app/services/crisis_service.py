import re

CRISIS_KEYWORDS = [
    r"\bsuicid\w*\b", r"\bkill myself\b", r"\bend my life\b",
    r"\bself.harm\b", r"\bself-harm\b", r"\bwant to die\b",
    r"\bno reason to live\b", r"\bhopeless\b",
    r"\bnataka kufa\b", r"\bjiua\b",
]

def compute_crisis_score(text: str) -> float:
    text_lower = text.lower()
    matches = sum(1 for kw in CRISIS_KEYWORDS if re.search(kw, text_lower))
    return min(matches / max(len(CRISIS_KEYWORDS) * 0.3, 1), 1.0)

def get_severity(score: float) -> str:
    if score >= 0.8: return "critical"
    if score >= 0.5: return "high"
    if score >= 0.2: return "medium"
    return "low"

def is_crisis(text: str) -> tuple[bool, float, str]:
    score = compute_crisis_score(text)
    return score >= 0.2, score, get_severity(score)
