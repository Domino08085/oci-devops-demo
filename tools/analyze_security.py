#!/usr/bin/env python3
# -*- coding: utf-8 -*-

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
    Static rules defined on scale 1-10 (10=highest):
    """
    t = (item_text or "").lower()
    risk = 3

    # Public endpoint OKE
    if ("endpoint" in t and "public" in t) or ("is_public_ip_enabled" in t and "true" in t):
        risk = max(risk, 8)

    # Kubernetes Dashboard / Tiller (Helm v2)
    if "kubernetes dashboard" in t or "dashboard enabled" in t:
        risk = max(risk, 9)
    if "tiller" in t or "helm v2" in t:
        risk = max(risk, 10)

    # Public internet / IGW / too permissive SL/NSG
    if "internet gateway" in t or "0.0.0.0/0" in t or "allow all" in t or "all traffic" in t:
        risk = max(risk, 9)

    # LoadBalancer public 
    if "loadbalancer" in t and "public" in t:
        risk = max(risk, 7)

    # PSP disabled or lack of PSS
    if "pod security policy" in t and "disabled" in t:
        risk = max(risk, 7)
    if "pod security standards" in t and ("missing" in t or "not enforced" in t):
        risk = max(risk, 7)

    # Public subnets/NSGs
    if "public subnet" in t or ("subnet" in t and "public" in t):
        risk = max(risk, 7)

    return risk

def suggest_remediation(item_text: str) -> list[str]:
    t = (item_text or "").lower()
    fixes = []

    if "kubernetes dashboard" in t or "dashboard enabled" in t:
        fixes += [
            "Set `is_kubernetes_dashboard_enabled = false` in `oci_containerengine_cluster.options.add_ons`.",
            "Limit access to Kubernetes management to external tools (kubectl, Lens) and RBAC."
        ]

    if "tiller" in t or "helm v2" in t:
        fixes += [
            "Set `is_tiller_enabled = false` (Do not use Helm v2).",
            "Use Helm 3 without Tiller and enforce RBAC."
        ]

    if ("endpoint" in t and "public" in t) or ("is_public_ip_enabled" in t and "true" in t):
        fixes += [
            "More safe way is `endpoint_config.is_public_ip_enabled = false` (private endpoint) and access via Bastion/VCN peering.",
            "If endpoint must be public: restrict NSG/Security Lists to trusted CIDR, enable WAF/IPS, enforce TLS and SSO."
        ]

    if "0.0.0.0/0" in t or "allow all" in t or "all traffic" in t or "internet gateway" in t:
        fixes += [
            "Zawęź Security Lists/NSG do konkretnych portów i zaufanych źródeł (zasada najmniejszych uprawnień).",
            "Tighten Security Lists/NSG rules to the specific ports and trusted sources (least privilege principle)",
            "Review route tables and block unnecessary internet-bound traffic."
        ]

    if "loadbalancer" in t and "public" in t:
        fixes += [
            "Add WAF/CDN in front of LB, enforce TLS/mTLS, restrict sources (CIDR allowlist).",
            "Consider private LB + public front (WAF/CDN) as a gateway."
        ]

    if "pod security policy" in t and "disabled" in t:
        fixes += [
            "Enforce Pod Security Standards (baseline/restricted) or use Gatekeeper/OPA with policies.",
            "Use 'runAsNonRoot', 'readOnlyRootFilesystem', 'seccompProfile' settings."
        ]

    if not fixes:
        fixes = ["Implement least privilege principle; reduce exposure and enable access controls."]
    return fixes

def normalize_severity_to_score(sev: str) -> int:
    table = {"CRITICAL": 10, "HIGH": 8, "MEDIUM": 5, "LOW": 3, "INFO": 1}
    return table.get((sev or "").upper(), 4)

# ---------- Loaders of results ----------

def load_trivy():
    """Parse JSON from Trivy (scan-type=config)."""
    if not TRIVY_JSON.exists():
        print(f"Warning: Trivy JSON file {TRIVY_JSON} not found.")
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

def read_json_relaxed(path: pathlib.Path):
    """
    Read JSON file with relaxed parsing
    """
    if not path.exists():
        return {}
    raw = path.read_text(encoding="utf-8", errors="ignore")
    if not raw.strip():
        return {}

    # znajdź pierwszą klamrę lub nawias
    start_obj = raw.find("{")
    start_arr = raw.find("[")
    starts = [i for i in [start_obj, start_arr] if i != -1]
    if not starts:
        return {}
    start = min(starts)

    # heurystyka końca
    end_obj = raw.rfind("}")
    end_arr = raw.rfind("]")
    ends = [i for i in [end_obj, end_arr] if i != -1]
    if not ends:
        return {}
    end = max(ends) + 1

    candidate = raw[start:end]
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        return {}

def load_checkov():
    """Parse JSON from Checkov"""
    data = read_json_relaxed(CHECKOV_JSON)
    if not data:
        print(f"Warning: Checkov JSON file {CHECKOV_JSON} not found or invalid.")
        return []
    print(f"[checkov] file size: {CHECKOV_JSON.stat().st_size} bytes")
    data = read_json_relaxed(CHECKOV_JSON)
    if not data:
        print(f"[checkov] invalid/empty JSON in {CHECKOV_JSON}")
        return []
    results = []
    failed = (data.get("results") or {}).get("failed_checks", []) or []
    for r in failed:
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
    """LLM (chat gpt) summary of top findings"""
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
        OUTPUT_MD.write_text("# Security Report\n\nNo issues detected.\n")
        print("OK: no findings")
        return 0

    # scoring: context OCI/OKE vs. severity
    for f in findings:
        context_score = oci_contextual_risk(f["message"], f["path"])
        sev_score = normalize_severity_to_score(f["severity"])
        f["score"] = max(context_score, sev_score)
        f["remediation"] = suggest_remediation(f["message"])

    # deduplication: (path,id,message) prefer higher score
    uniq = {}
    for f in findings:
        key = (f["path"], f["id"], f["message"])
        if key not in uniq or f["score"] > uniq[key]["score"]:
            uniq[key] = f
    findings = sorted(uniq.values(), key=lambda x: x["score"], reverse=True)

    # gating (fail when threshold_fail)
    fail = any(f["score"] >= threshold_fail for f in findings)

    # Markdown report
    md = []
    md.append("# Security Report (Terraform / OCI / OKE)\n")
    md.append(f"Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
    md.append("## Summary\n")
    md.append(f"- Found issues: **{len(findings)}**")
    md.append(f"- Critical (score≥{threshold_fail}): **{sum(1 for x in findings if x['score']>=threshold_fail)}**")
    md.append(f"- High (score 7–8): **{sum(1 for x in findings if 7<=x['score']<threshold_fail)}**")
    md.append(f"- Medium (score 5–6): **{sum(1 for x in findings if 5<=x['score']<7)}**\n")

    llm = maybe_llm_summarize(findings)
    if llm:
        md.append("## AI – summary and recommendations\n")
        md.append(llm + "\n")

    md.append("## Details\n")
    for f in findings:
        md.append(f"### [{f['severity']}] {f['tool']}:{f['id']} — score {f['score']}/10")
        if f["path"]:
            md.append(f"**File:** `{f['path']}`")
        md.append(f"**Description:** {f['message']}")
        if f["remediation"]:
            md.append("**Recommended changes:**")
            for r in f["remediation"]:
                md.append(f"- {r}")
        md.append("")

    OUTPUT_MD.write_text("\n".join(md))
    print(f"Report written to {OUTPUT_MD}")
    return 1 if fail else 0

if __name__ == "__main__":
    sys.exit(main())
