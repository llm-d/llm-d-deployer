# Monitoring llm-d in OpenShift with Grafana

## Prerequisites

Before you begin, ensure you have:

1. An OpenShift cluster with administrative access
2. User Workload Monitoring enabled in your cluster
   - Follow the [official OpenShift documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/monitoring/configuring-user-workload-monitoring#enabling-monitoring-for-user-defined-projects_preparing-to-configure-the-monitoring-stack-uwm) to enable this feature
3. ServiceMonitors for scraping metrics from llm-d prefill, decode, and endpoint-picker pods. These are created with the llm-d-deployer quickstart
   installer. Check from the OpenShift console `Observe -> Metrics` that the `vllm*` and `inference*` metrics are being scraped. See the [llm-d metrics overview](./metrics-overview.md) for a list of llm-d metrics.

## Install Grafana Resources

1. Install Grafana Operator from OperatorHub:
   - Go to the OpenShift Console
   - Navigate to Operators -> OperatorHub
   - Search for "Grafana Operator"
   - Click "Install"

2. Create the llm-d-observability namespace:

   ```bash
   oc create ns llm-d-observability
   ```

3. Deploy Grafana with Prometheus datasource, llm-d dashboard, and inference-gateway dashboard:

   ```bash
   oc apply -n llm-d-observability --kustomize grafana
   ```

   This will:
   - Deploy a Grafana instance
   - Configure the Prometheus datasource to use OpenShift's user workload monitoring
   - Set up basic authentication (username: `admin`, password: `admin`)
   - Create a ConfigMap from the [llm-d dashboard JSON](./dashboards/llm-d-dashboard.json)
   - Deploy the GrafanaDashboard llm-d dashboard that references the ConfigMap
   - Deploy the GrafanaDashboard inference-gateway dashboard that references the upstream
   [k8s-sigs/gateway-api-inference-extension dashboard JSON](https://github.com/kubernetes-sigs/gateway-api-inference-extension/blob/main/tools/dashboards/inference_gateway.json)

4. Access Grafana:
   - Go to the OpenShift Console
   - Navigate to Networking -> Routes
   - Find the Grafana route (it will be in the llm-d-observability namespace)
   - Click on the route URL to access Grafana
   - Log in with:
     - Username: `admin`
     - Password: `admin`
     (choose `skip` to keep the default password)

5. The llm-d and inference-gateway dashboards will be automatically imported and available in your Grafana instance. You can access the dashboard by
clicking on "Dashboards" in the left sidebar and selecting the llm-d dashboard. You can also explore metrics directly using Grafana's Explore page, which is pre-configured to use
OpenShift's user workload monitoring Prometheus instance.

## Additional Resources

- [OpenShift Monitoring Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/monitoring/index)
- [Grafana Operator Documentation](https://github.com/grafana-operator/grafana-operator)
