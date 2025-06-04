# base feature override example

This example will demonstrate how deploy and test the base-feature example. This use-case has PD disabled but multiple decode replicas, and leverages
Prefix aware routing and load aware routing in the `inference-scheduler`. As seen before, since PD is disabled, requests will get routed straight to vllm pods.

## Deploying

Ran from the `quickstart` directory:

```bash
HF_TOKEN=${HF_TOKEN} ./llmd-installer.sh --namespace greg-test --values-file examples/base/prefix-and-load-aware.yaml
```

## Validating the deployment

With this use-case we can expect to see the following pods:

```log
llm-d-inference-gateway-76796b468d-6z687                    1/1     Running   0          67s
llm-d-modelservice-5d7bbc8c57-8bd27                         1/1     Running   0          67s
meta-llama-llama-3-2-3b-instruct-epp-77b789cdd6-4spzt       1/1     Running   0          65s
meta-llama-llama-3-2-3b-instruct-decode-7d4f959d99-4h8bc    2/2     Running   0          65s
meta-llama-llama-3-2-3b-instruct-decode-7d4f959d99-52l4h    2/2     Running   0          65s
```

This should be once gateway instance, the modelservice controller, the `epp` pod (`inference-scheduler`), and 2 decode nodes because we set replicas to 2. Each decode node has 2 containers in the pod, one is the routing sidecar and one is the vllm pod.

## Testing

As with the `no-features` example, I will be using the gateway of service type `NodePort` and ingress to test this, however there are many ways you can hit the "front-door". Those will be discussed in other documentation in this repo.

Also similar to the `no-features` example, we has P/D disabled. From a log trace perspective, this means we care about watching the EPP to understand how the `prefix_aware` and `load_aware` routing is working, as well as the decode vLLM pods themselves.

To that end, lets begin by following the `epp` logs:

```bash
# Terminal 1: EPP
EPP_POD=$(kubectl get pods -l "llm-d.ai/epp" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${EPP_POD} -f | grep -v "Failed to refreshed metrics\|Refreshed metrics\|gRPC health check serving\|Refreshing Prometheus Metrics"
```

The decode pod 1 sidecar:

```bash
# Terminal 2: decode pod 1 container routing-proxy (sidecar)
DECODE_PODS=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 2 | awk '{print $1}')
DECODE_POD_1=$(echo $DECODE_PODS | head -n 1)
kubectl logs pod/${DECODE_POD_1} -c routing-proxy -f | grep -v "http: proxy error: dial tcp \[::1\]:8001: connect: connection refused"
```

The decode pod 1 vllm:

```bash
# Terminal 3: decode pod 1 container vllm
DECODE_PODS=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 2 | awk '{print $1}')
DECODE_POD_1=$(echo $DECODE_PODS | head -n 1)
kubectl logs pod/${DECODE_POD_1} -c vllm -f | grep -v "\"GET /metrics HTTP/1.1\" 200 OK\|Avg prompt throughput: 0.0 tokens/s"
```

The decode pod 2 sidecar:

```bash
# Terminal 4: decode pod 2 container routing-proxy (sidecar)
DECODE_PODS=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 2 | awk '{print $1}')
DECODE_POD_2=$(echo $DECODE_PODS | tail -n 1)
kubectl logs pod/${DECODE_POD_2}  -c routing-proxy -f | grep -v "http: proxy error: dial tcp \[::1\]:8001: connect: connection refused"
```

The decode pod 2 vllm:

```bash
# Terminal 5: decode pod 2 container vllm
DECODE_PODS=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 2 | awk '{print $1}')
DECODE_POD_2=$(echo $DECODE_PODS | tail -n 1)
kubectl logs pod/${DECODE_POD_2}  -c vllm -f | grep -v "\"GET /metrics HTTP/1.1\" 200 OK\|Avg prompt throughput: 0.0 tokens/s"
```

Now we can start with a basic curl request and trace the logs. At the end, we hope to see this at scale and understand how the load-aware scorer functions here.

```bash
INGRESS_ADDRESS=$(kubectl get ingress llm-d-inference-gateway | tail -n 1 | awk '{print $3}')

export LLM_PROMPT_1="I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind"

curl ${INGRESS_ADDRESS}/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "prompt": "'${LLM_PROMPT_1}'",
    "max_tokens": 500
  }' | jq
```

### EPP logs

The EPP logs in particular are log, and contain lots of significant information about how requests are being routed. As such, I have dumped an example of my epp logs from the above `curl` to the two `.jsonl` files in this directory, one formatted and one unformatted. Lets break each step of the epp down.

1. `LLM request assembled`: Identifying that a request has hit the EPP through the gateway, request headers, targetModel, and a `x-request-id` passed by the gateway
2. `Disagregated prefill/decode disabled - scheduling to decode worker only`: Understanding we have disabled PD, and that EPP should route only to decode pods. This means that the typical `filter`, `score` and `picker` plugins that run once for decode and once in prefill when PD disagregation is enabled, will only run for decode.
3. `Scheduling a request`: A request gets queued to EPP with all potential candidate nodes in pool, in this case this would be all Decode pods, this should include both our decode replicas.
4. `Before running filter plugins`: Logging on candidates before running the filter plugin.
5. `Running filter plugin`: Applying the `plugin:"decode-filter"` to list of candidates.
6. `Filter plugin result`: Logging the list of candidates after the `decode-filter` plugin. In this case, we had 2 decode replicas and so both are still available as candidates.
7. `Before running scorer plugins`: Listing the pods potentially available based on the request criteria and after filtering for only decode pods in steps 4-6. This marks the beginning of the scoring phase as a whole - all scorers.
8. `Running scorer`, `"scorer": "session-affinity-scorer"`: Running a scorer, in this case the `session-affinity` scorer.
9. `After running scorer`, `"scorer": "session-affinity-scorer"`: Logging after `session-affinity` scorer has completed.
10. (bug) `Running scorer`, `"scorer": "prefix-aware-scorer"`:
11. (bug) `Got pod scores`, `"logger": "prefix-aware-scorer",`: `null` for pod scores. REVISIT
12. (bug) `No scores found for pods`, `"logger": "prefix-aware-scorer"`: REVISIT
13. (bug) `After running scorer`: Logging step saying `prefix-aware-scorer` has finished.
14. `Running scorer`, `"scorer": "load-aware-scorer"`: Logging beginning of load aware scorer.
15. `After running scorer`, `"scorer": "load-aware-scorer"`: Logging completion of load aware scorer.
16. `After running scorer plugins`, Logging completion of scoring phase as a whole - all scorer plugins
17. `Before running picker plugin`:  Logging entering selection stage based criteria (in this case filter + score)
18. `Selecting a pod with the max score from 2 candidates`: Based on our 2 scorers, `load` and `session` aware, and the various weights attributed to each scorer, a score will be produced. In our case
19. `Selecting a random pod from 2 candidates`: In the event of a tiebreak in scores later on, a random pod is selected. While this seems confusing as there is valid scoring logic in play, this is done at this stage to keep all scoring decisions in one temporal location. It has been verified with valid scorers and scores this value is not honored.
20. `After running picker plugin`: Summary of the selection of node to route the request. In this case the `meta-llama-llama-3-2-3b-instruct-decode-7c679bb8b4-md6hq` pod was selected with a score of `0.5`. This is because I ran this request on a fresh system.
21. `Running post-schedule plugin`: If any work exists to run after request after a scheduled request, configured via plugin.  In our case, none.
22. `PostResponse called`: The post request to `/v1/completions` has been poseted from the decode node
23. `Request handled`: Request has be successfully handled for the inference coming back from decode
24. `LLM response assembled`: Assembled response back to the gateway
25. (bug) `Prefix aware scorer cleanup`: cleanup after prefix aware routing scorer

2nd request into the system, what changes?

Modify our prompt to be similar:

```bash
export LLM_PROMPT_2="I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform. Finally please help me build out a plan to extend this benchmarking to run against workloads on GKE and K8s that runs on CoreWeave to help us integrate into the ecosystems of our wonderful llm-d partners."
```
