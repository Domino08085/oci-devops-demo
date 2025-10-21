#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Agregacja wyników Trivy (IaC) i Checkov dla Terraform,
priorytetyzacja kontekstowa (OCI/OKE), propozycje poprawek
oraz opcjonalne streszczenie i rekomendacje przez OpenAI.

Wyjście:
- results/security_report.md
- exit code != 0, jeśli są krytyczne (score ≥ threshold_fail)
"""

import json
import os
import pathlib
import sys
import time
from collections import defaultdict

RESULTS_DIR = pathlib.Path("results")
RESULTS_DIR.mkdir(exist_ok=True)

TRIVY_JSON = RESULTS_DIR / "trivy.json"
CHECKOV_JSON = RESULTS_DIR / "checkov.json"
OUTPUT_MD = RESULTS_DIR / "security_report.md"

ENABLE_LLM = os.getenv("ENABLE_LLM", "false").lower() == "true"
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# Gating threshold
threshold_fail = 9  # 9/10 => CRITICAL

# ---------- Static rules (OCI/OKE/TF) ----------

def oci_contextual_risk(item_text: str, file_path: str) -> int:
    """
    Prosty scoring ryzyka 1..10 (10=highest) dopasowany do projektu:
    OKE, publiczny endpoint, Dashboard/Tiller, public LB, szerokie SL/NSG, PSP/PSS.
    """
    t = (item_text or "").lower()
    risk = 3

    # Publiczny endpoint API K8s
    if ("endpoint" in t and "public" in t) or ("is_public_ip_enabled" in t and "true" in t):
        risk = max(risk, 8)

    # Kubernetes Dashboard / Tiller (Helm v2)
    if "kubernetes dashboard" in t or "dashboard enabled" in t:
        risk = max(risk, 9)
    if "tiller" in t or "helm v2" in t:
        risk = max(risk, 10)

    # Public internet / IGW / zbyt szerokie reguły
    if "internet gateway" in t or "0.0.0.0/0" in t or "allow all" in t or "all traffic" in t:
        risk = max(risk, 9)

    # LoadBalancer publiczny (zależne od warstwy ochrony)
    if "loadbalancer" in t and "public" in t:
        risk = max(risk, 7)

    # PSP wyłączone lub brak PSS
    if "pod security policy" in t and "disabled" in t:
        risk = max(risk, 7)
    if "pod security standards" in t and ("missing" in t or "not enforced" in t):
        risk = max(risk, 7)

    # Publiczne subnety/NSG
    if "public subnet" in t or ("subnet" in t and "public" in t):
        risk = max(risk, 7)

    return risk

def suggest_remediation(item_text: str) -> list[str]:
    t = (item_text or "").lower()
    fixes = []

    if "kubernetes dashboard" in t or "dashboard enabled" in t:
        fixes += [
            "Ustaw `is_kubernetes_dashboard_enabled = false` w `oci_containerengine_cluster.options.add_ons`.",
            "Ogranicz dostęp do zarządzania K8s do narzędzi zewnętrznych (kubectl, Lens) i RBAC."
        ]

    if "tiller" in t or "helm v2" in t:
        fixes += [
            "Ustaw `is_tiller_enabled = false` (zrezygnuj z Helm v2).",
            "Przejdź na Helm 3 bez Tillera i stosuj RBAC."
        ]

    if ("endpoint" in t and "public" in t) or ("is_public_ip_enabled" in t and "true" in t):
        fixes += [
            "Rozważ `endpoint_config.is_public_ip_enabled = false` (prywatny endpoint) i dostęp przez Bastion/VCN peering.",
            "Jeśli endpoint musi być publiczny: zawęź NSG/Security Lists do zaufanych CIDR, włącz WAF/IPS, wymuś TLS i SSO."
        ]

    if "0.0.0.0/0" in t or "allow all" in t or "all traffic" in t or "internet gateway" in t:
        fixes += [
            "Zawęź Security Lists/NSG do konkretnych portów i zaufanych źródeł (zasada najmniejszych uprawnień).",
            "Zrewiduj trasy (route tables) i zablokuj niepotrzebny ruch do/od internetu."
        ]

    if "loadbalancer" in t and "public" in t:
        fixes += [
            "Dodaj WAF/CDN przed LB, wymuś TLS/mTLS, ogranicz źródła (CIDR allowlist).",
            "Rozważ prywatny LB + publiczny front (WAF/CDN) jako bramkę."
        ]

    if "pod security policy" in t and "disabled" in t:
        fixes += [
            "Wymuś Pod Security Standards (baseline/restricted) lub Gatekeeper/OPA z regułami.",
            "Stosuj `runAsNonRoot`, `readOnlyRootFilesystem`, `seccompProfile`."
        ]

    if not fixes:
        fixes = ["Zastosuj zasadę najmniejszych uprawnień; ogranicz ekspozycję i włącz kontrolę dostępu."]
    return fixes

def normalize_severity_to_score(sev: str) -> int:
    table = {"CRITICAL": 10, "HIGH": 8, "MEDIUM": 5, "LOW": 3, "INFO": 1}
    return table.get((sev or "").upper(), 4)

# ---------- Loadery wyników ----------

def load_trivy():
    """Parsuje JSON z Trivy (scan-type=config)."""
    if not TRIVY_JSON.exists():
        return []
    data = json.loads(TRIVY_JSON.read_text() or "{}")
    results = []
    for r in data.get("Results", []) or []:
        target = r.get("Target", "")
        for mis in r.get("Misconfigurations", []) or []:
            msg = mis.get("Message") or mis.get("Description") or mis.get("Title") or mis.get("ID")
            results.append({
                "tool": "trivy",
                "id": mis.get("ID"),
                "severity": (mis.get("Severity") or "MEDIUM").upper(),
                "message": msg,
                "path": target
            })
    return results

def load_checkov():
    """Parsuje JSON z Checkov."""
    if not CHECKOV_JSON.exists():
        return []
    data = json.loads(CHECKOV_JSON.read_text() or "{}")
    results = []
    for r in (data.get("results") or {}).get("failed_checks", []) or []:
        msg = r.get("description") or r.get("check_name") or r.get("check_id") or "checkov finding"
        results.append({
            "tool": "checkov",
            "id": r.get("check_id"),
            "severity": (r.get("severity") or "MEDIUM").upper(),
            "message": msg,
            "path": r.get("file_path", "")
        })
    return results

# ---------- AI (OpenAI Chat Completions) ----------

def maybe_llm_summarize(findings_top):
    """Zwraca krótkie streszczenie i zalecenia od LLM (jeśli włączone)."""
    if not ENABLE_LLM or not OPENAI_API_KEY:
        return None
    try:
        import json as _json
        import urllib.request
        prompt = "Zreferuj zwięźle najważniejsze ryzyka i zaproponuj konkretne poprawki Terraform/OCI/OKE dla poniższych problemów:\n\n"
        for f in findings_top[:12]:
            prompt += f"- [{f['severity']}/{f['tool']}:{f['id']}] {f['message']} @ {f['path']}\n"
        body = {
            "model": OPENAI_MODEL,
            "messages": [
                {"role": "system", "content": "Jesteś ekspertem DevSecOps dla OCI/OKE/Terraform. Daj krótkie, techniczne zalecenia."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.2
        }
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=_json.dumps(body).encode("utf-8"),
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {OPENAI_API_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=45) as resp:
            out = _json.loads(resp.read().decode("utf-8"))
        return out["choices"][0]["message"]["content"].strip()
    except Exception as e:
        return f"(LLM summary failed: {e})"

# ---------- Main ----------

def main():
    findings = load_trivy() + load_checkov()

    if not findings:
        OUTPUT_MD.write_text("# Security Report\n\nBrak wykrytych problemów.\n")
        print("OK: no findings")
        return 0

    # scoring: kontekst OCI/OKE vs. severity
    for f in findings:
        context_score = oci_contextual_risk(f["message"], f["path"])
        sev_score = normalize_severity_to_score(f["severity"])
        f["score"] = max(context_score, sev_score)
        f["remediation"] = suggest_remediation(f["message"])

    # deduplikacja: (path,id,message) z preferencją wyższego score
    uniq = {}
    for f in findings:
        key = (f["path"], f["id"], f["message"])
        if key not in uniq or f["score"] > uniq[key]["score"]:
            uniq[key] = f
    findings = sorted(uniq.values(), key=lambda x: x["score"], reverse=True)

    # gating (fail, jeśli jest score ≥ threshold_fail)
    fail = any(f["score"] >= threshold_fail for f in findings)

    # raport Markdown
    md = []
    md.append("# Security Report (Terraform / OCI / OKE)\n")
    md.append(f"Data: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
    md.append("## Podsumowanie\n")
    md.append(f"- Znalezione problemy: **{len(findings)}**")
    md.append(f"- Krytyczne (score≥{threshold_fail}): **{sum(1 for x in findings if x['score']>=threshold_fail)}**")
    md.append(f"- Wysokie (score 7–8): **{sum(1 for x in findings if 7<=x['score']<threshold_fail)}**")
    md.append(f"- Średnie (score 5–6): **{sum(1 for x in findings if 5<=x['score']<7)}**\n")

    llm = maybe_llm_summarize(findings)
    if llm:
        md.append("## AI – streszczenie i zalecenia\n")
        md.append(llm + "\n")

    md.append("## Szczegóły\n")
    for f in findings:
        md.append(f"### [{f['severity']}] {f['tool']}:{f['id']} — score {f['score']}/10")
        if f["path"]:
            md.append(f"**Plik:** `{f['path']}`")
        md.append(f"**Opis:** {f['message']}")
        if f["remediation"]:
            md.append("**Zalecane poprawki:**")
            for r in f["remediation"]:
                md.append(f"- {r}")
        md.append("")

    OUTPUT_MD.write_text("\n".join(md))
    print(f"Report written to {OUTPUT_MD}")
    return 1 if fail else 0

if __name__ == "__main__":
    sys.exit(main())
