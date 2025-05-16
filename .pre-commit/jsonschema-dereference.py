import json
from typing import List, Any
from pathlib import Path

import jsonref

JSONSCHEMA_TEMPLATE_NAME = "values.schema.tmpl.json"
JSONSCHEMA_NAME = "values.schema.json"
CHART_LOCK = "Chart.lock"

def load(chart_dir: Path):
    """Load JSONSCHEMA_TEMPLATE_NAME file from the chart into Python."""
    with open(chart_dir / JSONSCHEMA_TEMPLATE_NAME, "r", encoding="utf-8") as f:
        return json.load(f)


def save(chart_dir: Path, my_schema: Any):
    """Take schema containing $refs and dereference them."""
    with open(chart_dir / JSONSCHEMA_NAME, "w", encoding="utf-8") as f:
        json.dump(my_schema, f, indent=4, sort_keys=True)

if __name__ == '__main__':
    charts = [p.parent for p in Path(".").rglob(CHART_LOCK)]

    errors: List[BaseException] = []
    for chart in charts:
        try:
            schema_template = load(chart)
            schema = jsonref.replace_refs(schema_template)
            save(chart, schema)

        except BaseException as e:
            print(f"Could not process schema for '{chart}': {e}")
            errors.append(e)
    if errors:
        exit(1)
