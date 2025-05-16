# No feature override example

This example will demonstrate how deploy and test the no-feature example. This example aims to mock the a vanilla instance of vLLM as closely as it can, but still
within the architecture of `llm-d`. This means that PD has been disabled, and thus no KV caching of any kid, or intelligent routing from the epp.
Requests should go right from the EPP to sidecar to decode and get back your inference.

## Deploying

Assuming one is starting from the quickstart repo, a sample deploy might look like:

```bash
HF_TOKEN=${HF_TOKEN} ./llmd-installer.sh --namespace greg-test --values-file examples/no-features/no-features.yaml
```

## Validating the deployment

In this example, you should expect to see the following pods:

```log
NAME                                                       READY   STATUS    RESTARTS   AGE
llm-d-inference-gateway-6d9f46779d-czn2d                   1/1     Running   0          13s
llm-d-modelservice-5d7bbc8c57-gnqmk                        1/1     Running   0          13s
meta-llama-llama-3-2-3b-instruct-decode-7c679bb8b4-8mh6s   2/2     Running   0          11s
meta-llama-llama-3-2-3b-instruct-epp-84987b9b4d-hhggm      1/1     Running   0          11s
```

In this particular example, we disabled PD and set prefill replicas to 0. Therefore while you may see a deployment for prefill, you won't see pdos for it.

## Testing

To test this setup is fairly simple. First acertain what gateway service type you are using. If you are using a `NodePort` service, you can either port-forward
the service for the gateway to localhost, or use the ingress for the service (currently, only available on OCP). If you are uinsg service type `LoadBalancer`
you will be able to curl through the gateway directly. In this example I am using `NodePort` so I will curl through the gateway.

Before that though, let's get our terminals setup to track the logs.

In terminal 1, we want to follow the EPP logs. You can follow these with the following command:

```bash
# Terminal 1: EPP
EPP_POD=$(kubectl get pods -l "llm-d.ai/epp" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${EPP_POD} -f | grep -v "Failed to refreshed metrics\|Refreshed metrics\|gRPC health check serving\|Refreshing Prometheus Metrics"
```

Since we have PD disabled, we will skip the routing sidecar entirely and go straight to only Prefill or Decode pods. In this case, this will be Decode
because we have set prefill replicas to 0 in our sample app.

In terminal 2, we want to follow our Decode vLLM logs. Heres how we do this:

```bash
# Terminal 2: decode vLLM
DECODE_POD=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${DECODE_POD} -c vllm -f | grep -v "\"GET /metrics HTTP/1.1\" 200 OK\|Avg prompt throughput: 0.0 tokens/s"
```

Finally, in terminal 3 we can begin our curl. As mentioned above I will be testing via the ingress that backs the gateway, but there are other options to do this.

```bash
INGRESS_ADDRESS=$(kubectl get ingress llm-d-inference-gateway | tail -n 1 | awk '{print $3}')

export LLM_PROMPT_1="I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind."

curl ${INGRESS_ADDRESS}/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "prompt": "'${LLM_PROMPT_1}'",
    "max_tokens": 500
  }' | jq
```

After a few seconds you should get a response. Now lets breakdown the logs to understand whats happening.

## Tracing the Logs

### EPP

We start with our EPP logs. The logs are rather long here so rather than showng the whole requests, I will focus on the key messages of each step.

1. `LLM request assembled`: Identifying that a request has hit the EPP through the gateway, request headers, targetModel, and a `x-request-id` passed by the gateway
2. `Disagregated prefill/decode disabled - scheduling to decode worker only`: Understanding we have disabled PD, and that EPP should route only to decode pods later in the process (while the system will honor this, it is not considered in steps 3 - 8).
3. `Scheduling a request`: A request gets queued to EPP with all potential candidate nodes in pool, in this case this would be all Decode pods. We happen to have only 1 in this demo so its a bit lackluster.
4. `Before running filter plugins`: Logging on candidates before running the filter plugin
5. `Running filter plugin`: Applying the `plugin:"decode-filter"` to list of candidates
6. `Filter plugin result`: logging step after the filter plugin runs for decode - does not convey any valuable information
7. `Before running scorer plugins`: Listing the pods potentially available based on the request criteria and after filtering for only decode pods
8. (bug) `Running scorer`: Scoring the Pods. Since no scorers were enabled, it is defaulting to `Prefix Aware Scorer` despite being disabled.
9. (bug) `Got pod scores`: Retrieves scores from scoring step.
10. (bug) `No scores found for pods`: This is part of the prefix aware scoring happening but not being honored bug. Scores are not actually computed, and so not factored into the decision process here, but the steps are still running and being logged.
11. (bug) `After running scorer`: Logging step to identify scoring step finished for that scorer (prefix aware routing)
12. (bug) `After running scorer plugins`: Logging to step to identify all scorers have finished
13. (bug) `Before running picker plugin`:  Logging entering selection stage based criteria (in this case filter + score)
14. (bug) `Selecting a pod with the max score from 1 candidates`: selecting the pod to route the request to
15. `After running picker plugin`: Summary of the selection of node to route the request
16. `Running post-schedule plugin`: If any work exists to run after request after a scheduled request, configured via plugin.  In our case, none.
17. `PostResponse called`: The post request to `/v1/completions` has been poseted from the decode node
18. `Request handled`: Request has be successfully handled for the inference coming back from decode
19. `LLM response assembled`: Assembled response back to the gateway
20. (bug) `Prefix aware scorer cleanup`: cleanup after prefix aware routing scorer

> [!NOTE]:Steps 8-14 and 20 are indeed a bug, in that all scorers are disabled and yet it is running the `prefix_aware_scorer`.
> However the values of the scorer are not honored, the bug is just that the `infrenecing-scheduler` does the irrelevant scoring work even though
> they do not drive how requests get routed. [Fix](https://github.com/llm-d/llm-d-inference-scheduler/pull/94) coming for this soon.

### Decode vllm

The vLLM logs here are rather plain but prove our inferencing is working correctly. Your logs should look something like:

```log
INFO 05-16 04:49:00 [logger.py:39] Received request cmpl-bddb7a85-316a-491d-9c6a-cf4c8f2115cf-0: prompt: 'brand new test prompt 15', params: SamplingParams(n=1, presence_penalty=0.0, frequency_penalty=0.0, repetition_penalty=1.0, temperature=0.6, top_p=0.9, top_k=0, min_p=0.0, seed=None, stop=[], stop_token_ids=[], bad_words=[], include_stop_str_in_output=False, ignore_eos=False, max_tokens=300, min_tokens=0, logprobs=None, prompt_logprobs=None, skip_special_tokens=True, spaces_between_special_tokens=True, truncate_prompt_tokens=None, guided_decoding=None, extra_args=None), prompt_token_ids: [128000, 13781, 502, 1296, 10137, 220, 868], lora_request: None, prompt_adapter_request: None.
INFO 05-16 04:49:00 [async_llm.py:256] Added request cmpl-bddb7a85-316a-491d-9c6a-cf4c8f2115cf-0.
INFO 05-16 04:49:00 [loggers.py:116] Engine 000: Avg prompt throughput: 0.7 tokens/s, Avg generation throughput: 6.0 tokens/s, Running: 1 reqs, Waiting: 0 reqs, GPU KV cache usage: 0.0%, Prefix cache hit rate: 0.0%
INFO:     10.129.14.198:0 - "POST /v1/completions HTTP/1.1" 200 OK
```

This is fairly straightforward, a request comes in, gets scheduled, completed by engine in the background, and then posted to `/v1/completions` when done.
