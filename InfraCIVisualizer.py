# InfraCI Visualizer MVP – with Streamlit UI
# Goal: Upload Terraform plan file, parse changes, visualize affected infra and risk.

import json
import subprocess
from typing import List
from pydantic import BaseModel
import streamlit as st
import tempfile
import altair as alt
import pandas as pd

class ResourceChange(BaseModel):
    action: str
    resource_type: str
    name: str
    depends_on: list = []

# --- Utility Functions ---
def parse_terraform_plan(plan_path: str) -> List[ResourceChange]:
    terraform_dir = "/home/biji/Study/Terraform/EC2"  # update this path to your config location

    # Ensure terraform providers are initialized in the correct directory
    init_cmd = ["terraform", "init", "-input=false", "-no-color"]
    init_result = subprocess.run(init_cmd, capture_output=True, text=True, cwd=terraform_dir)
    if init_result.returncode != 0:
        raise RuntimeError(f"Terraform init error: {init_result.stderr}")

    cmd = ["terraform", "show", "-json", plan_path]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=terraform_dir)
    if result.returncode != 0:
        raise RuntimeError(f"Terraform error: {result.stderr}")
    if not result.stdout.strip():
        raise ValueError("Terraform output is empty. Is this a valid binary plan file?")
    data = json.loads(result.stdout)

    changes = []
    for res in data.get("resource_changes", []):
        action = res["change"]["actions"][0]
        resource_type = res["type"]
        name = res["name"]
        depends_on = res.get("depends_on", [])
        changes.append(ResourceChange(action=action, resource_type=resource_type, name=name, depends_on=depends_on))
    return changes

def calculate_risk_score(changes: List[ResourceChange]) -> str:
    high_risk = any(c.resource_type in ["aws_db_instance", "aws_security_group"] for c in changes)
    return "High" if high_risk else "Medium" if changes else "Low"

def generate_summary(changes: List[ResourceChange]) -> str:
    counts = {}
    for c in changes:
        key = f"{c.action}-{c.resource_type}"
        counts[key] = counts.get(key, 0) + 1
    summary = ", ".join(f"{v} {k}" for k, v in counts.items())
    return f"This plan will perform the following changes: {summary}."

# --- Streamlit App ---
st.set_page_config(page_title="InfraCI Visualizer", layout="centered")
st.title("📊 InfraCI Visualizer")
st.write("Analyze Terraform plan files for infra impact and risk.")

uploaded_file = st.file_uploader("Upload Terraform plan file (binary)", type=None)
if uploaded_file is not None:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".tfplan") as tmp_file:
        tmp_file.write(uploaded_file.read())
        tmp_path = tmp_file.name

    with st.spinner("Analyzing plan..."):
        try:
            changes = parse_terraform_plan(tmp_path)
            risk_score = calculate_risk_score(changes)
            summary = generate_summary(changes)

            st.subheader("Risk Score")
            if risk_score == "Low":
                st.success(risk_score)
            elif risk_score == "Medium":
                st.warning(risk_score)
            else:
                st.error(risk_score)

            st.subheader("Change Summary")
            st.info(summary)

            st.subheader("Affected Resources")
            st.table([{"Action": c.action, "Type": c.resource_type, "Name": c.name} for c in changes])

            # Resource Count Bar Chart with Altair
            data = pd.DataFrame([{
                "Resource Type": c.resource_type,
                "Action": c.action
            } for c in changes])

            chart = alt.Chart(data).mark_bar().encode(
                x='Resource Type:N',
                y='count():Q',
                color='Action:N',
                tooltip=['Resource Type', 'Action']
            ).properties(title="Resource Change Summary")

            st.altair_chart(chart, use_container_width=True)

            # Resource Connections Graph (Graphviz)
            st.subheader("Resource Connections Graph")
            try:
                import graphviz

                dot = graphviz.Digraph()
                # Add nodes for each resource
                for c in changes:
                    dot.node(c.name, f"{c.resource_type}\n{c.name}")

                # Add edges for dependencies
                name_to_resource = {c.name: c for c in changes}
                for c in changes:
                    for dep in c.depends_on:
                        # dep is usually in the format "resource_type.resource_name"
                        dep_name = dep.split('.')[-1]
                        if dep_name in name_to_resource:
                            dot.edge(dep_name, c.name)

                st.graphviz_chart(dot)
            except Exception as e:
                st.info("Graphviz graph could not be rendered. Make sure 'graphviz' is installed and resource dependencies are available.")
        except Exception as e:
            st.error(f"Failed to analyze plan: {str(e)}")
