import yaml
from jinja2 import Template

import requests
import os

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json"
}

def get_commit_sha_from_tag(repo, tag):
    tag_url = f"https://api.github.com/repos/{repo}/git/ref/tags/{tag}"
    tag_data = requests.get(tag_url, headers=HEADERS).json()
    if tag_data.get("object", {}).get("type") == "tag":
        tag_obj_url = tag_data["object"]["url"]
        tag_obj = requests.get(tag_obj_url, headers=HEADERS).json()
        return tag_obj["object"]["sha"]
    else:
        return tag_data["object"]["sha"]

def get_pr_for_commit(repo, sha):
    pr_url = f"https://api.github.com/repos/{repo}/commits/{sha}/pulls"
    pr_data = requests.get(pr_url, headers={
        **HEADERS,
        "Accept": "application/vnd.github.groot-preview+json"
    }).json()
    return pr_data[0] if pr_data else None

def get_ci_checks_for_commit(repo, sha):
    checks_url = f"https://api.github.com/repos/{repo}/commits/{sha}/check-runs"
    check_data = requests.get(checks_url, headers=HEADERS).json()
    return [
        {
            "name": c["name"],
            "url": c["html_url"],
            "status": c["conclusion"]
        }
        for c in check_data.get("check_runs", [])
    ]

with open("release-llm-d-1.1.0.yaml") as f:
    data = yaml.safe_load(f)

for c in data["components"]:
    if c.get("old_version") == c.get("version"):
        c["has_changes"] = False
        continue

    c["has_changes"] = True
    c["ci_url"] = f"https://github.com/{c['repo']}/actions?query=event:push+tag:{c['version']}"
    if c.get("old_version"):
        c["changelog_url"] = f"https://github.com/{c['repo']}/compare/{c['old_version']}...{c['version']}"

    try:
        sha = get_commit_sha_from_tag(c["repo"], c["version"])
        pr = get_pr_for_commit(c["repo"], sha)
        c["commit_sha"] = sha
        c["pr_number"] = pr["number"] if pr else None
        c["ci_checks"] = get_ci_checks_for_commit(c["repo"], sha)
    except Exception as e:
        print(f"⚠️ Failed to get CI info for {c['name']}: {e}")
        c["ci_checks"] = []


template = Template("""
# 📦 llm-d {{ project_version }} Release Notes

**Release Date:** {{ release_date }}
**Chart Version:** {{ chart_version }}

---

## 🧩 Component Summary

| Component | Version | Previous Version |
|-----------|---------|------------------|
{% for c in components -%}
| {{ c.name }} | `{{ c.version }}` | `{{ c.old_version or "-" }}` |
{% endfor %}

---

{%- for c in components %}
## 🔹 {{ c.name }}

{%- if c.has_changes %}
- **Changelog**: [{{ c.old_version }} → {{ c.version }}]({{ c.changelog_url }})
{%- else %}
_No version change in this release._
{%- endif %}

- **CI Checks:**
{%- if c.ci_checks %}
{%- for check in c.ci_checks %}
  - [{{ check.name }}]({{ check.url }}) [`{{ check.status }}`]
{%- endfor %}
{%- else %}
  - _No CI checks found_
{%- endif %}

---
{%- endfor %}
""")

output = template.render(**data)

filename = f"release-{data['project_version']}.md"

with open(filename, "w") as f:
    f.write(output)

print(f"✅ Release notes written to {filename}")
