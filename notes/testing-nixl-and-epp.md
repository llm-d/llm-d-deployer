# notes

Helper scritps

```bash
export LLM_PROMPT_1="I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind."

export LLM_PROMPT_2="Now that we have implemented benchmarks, I was hoping you could help me understand how I would track these manifests in GitOps. Ideally I would openshift gitops but would also support vanilla argocd for non OCP environments. Do you have any suggestions on the topic?"

export LLM_PROMPT_3="Lets talk about dolphins! What are some unique characteristics of dolphins compared to other acquatic animals?"

export LLM_PROMPT_4="speaking of aquatic animals, what is your favourite aquatic animal and why?"

export LLM_PROMPT_5="How might I gather metrics on how much energy consumption my OCP cluster uses?"

curl llm-d-inference-gateway.apps.summit-gpu.octo-emerging.redhataicoe.com/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.2-3B-Instruct",
    "prompt": "'${LLM_PROMPT_1}'",
    "max_tokens": 500,
    "temperature": 0
  }' | jq

curl llm-d-inference-gateway.apps.summit-gpu.octo-emerging.redhataicoe.com/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.2-3B-Instruct",
    "prompt": "'${LLM_PROMPT_2}'",
    "max_tokens": 500,
    "temperature": 0
  }' | jq

DECODE_POD=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 1 | awk '{print $1}')
PREFILL_POD=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=prefill" | tail -n 1 | awk '{print $1}')
EPP_POD=$(kubectl get pods -l "llm-d.ai/epp" | tail -n 1 | awk '{print $1}')


# grab logs together p/D
stern -n $(oc project -q) "$PREFILL_POD|$DECODE_POD" -c vllm | grep -v "\"GET /metrics HTTP/1.1\" 200 OK\|Avg prompt throughput: 0.0 tokens/s, Avg generation throughput: 0.0 tokens/s, Running: 0 reqs, Waiting: 0 reqs, GPU KV cache usage: 0.0%, Prefix cache hit rate"
```

## Debugging and testing NIXL KV cache

Debugging KV cache through logs:

#### Terminal 1 EPP

Follow EPP logs to see if it can hit Decode routing sidecar

```bash
EPP_POD=$(kubectl get pods -l "llm-d.ai/epp" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${EPP_POD} -f | grep -v "Failed to refreshed metrics\|Refreshed metrics\|gRPC health check serving\|Refreshing Prometheus Metrics"
```

### Terminal 2 Routing sidecar (Decode)

Follow the routing sidecar in the decode pod to see if it can post to prefill if needed

```bash
DECODE_POD=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${DECODE_POD} -c routing-proxy -f | grep -v "http: proxy error: dial tcp \[::1\]:8001: connect: connection refused"
```

### Terminal 3 Decode inference

Follow the decode vllm logs:

```bash
DECODE_POD=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${DECODE_POD} -c vllm -f | grep -v "\"GET /metrics HTTP/1.1\" 200 OK\|Avg prompt throughput: 0.0 tokens/s"
```

### Terminal 4 Prefill

Check to see that prefill logs are getting hit by decode:

```bash
PREFILL_POD=$(kubectl get pods -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=prefill" | tail -n 1 | awk '{print $1}')
kubectl logs pod/${PREFILL_POD} -f |  grep -v "\"GET /metrics HTTP/1.1\" 200 OK\|Avg prompt throughput: 0.0 tokens/s"
```

At this point you should be able to send a request through the gatway and track the relevant logs:

```bash
INGRESS_ADDRESS=$(kubectl get ingress llm-d-inference-gateway | tail -n 1 | awk '{print $3}')
curl ${INGRESS_ADDRESS}/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.2-3B-Instruct",
    "prompt": "'${LLM_PROMPT_1}'",
    "max_tokens": 500,
    "temperature": 0
  }' | jq
```

Epp should filter out Prefill pods, and only target decode first. You should see this between the 2nd and 3rd steps in EPP when it applies the filter plugin:
- Scheduling a request (step 2) has both pods as candidates, ex:
```log
{"level":"info","ts":"2025-05-09T19:26:20Z","caller":"scheduling/scheduler.go:129","msg":"Scheduling a request, Metrics: [{Pod:{NamespacedName:e2e-helm/llama-3-2-3b-instruct-decode-6f9b99b5cd-dlm7g Address:10.131.10.180 Role:1} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:0 KvCacheMaxTokenCapacity:0 UpdateTime:2025-05-09 19:26:20.29171375 +0000 UTC m=+388.303255999}} {Pod:{NamespacedName:e2e-helm/llama-3-2-3b-instruct-prefill-84667878f9-lwb47 Address:10.128.13.52 Role:0} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:0 KvCacheMaxTokenCapacity:0 UpdateTime:2025-05-09 19:26:20.316489317 +0000 UTC m=+388.328031566}}]","pd-schedule":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 388"}
```
- Apply filter plugin (step 3), only has decode as candidate to target sidecar first:
```log
{"level":"Level(-4)","ts":"2025-05-09T19:26:20Z","caller":"scheduling/scheduler.go:160","msg":"Before running filter plugins","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 388","pods":[{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-3-2-3b-instruct-decode-6f9b99b5cd-dlm7g"},"Address":"10.131.10.180","Role":1,"ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-05-09T19:26:20.29171375Z"},{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-3-2-3b-instruct-prefill-84667878f9-lwb47"},"Address":"10.128.13.52","Role":0,"ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-05-09T19:26:20.316489317Z"}]}
{"level":"Level(-4)","ts":"2025-05-09T19:26:20Z","caller":"scheduling/scheduler.go:163","msg":"Running filter plugin","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 388","plugin":"prefill_filter"}
```

Our next stop is the decode proxy sidecar (terminal 2) where you should notice communication being orchistrated between P/D pods, ex:
```log
I0509 19:43:44.077499       1 chat_completions.go:110] "running NIXL protocol" logger="proxy server"
I0509 19:43:44.077593       1 chat_completions.go:172] "sending request to prefiller" logger="proxy server" url="http://10.128.13.52:8000" body="{\"do_remote_decode\":true,\"max_tokens\":500,\"model\":\"Llama-3.2-3B-Instruct\",\"prompt\":\"I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.\",\"stream\":false,\"temperature\":0}"
I0509 19:43:44.099979       1 chat_completions.go:217] "received prefiller response" logger="proxy server" remote_block_ids=[1,2,3,4] remote_engine_id="81eb3201-d5c2-4642-8131-7849f2e955ce" remote_host="10.128.13.52" remote_port=5557
I0509 19:43:44.100082       1 chat_completions.go:252] "sending request to decoder" logger="proxy server" body="{\"do_remote_prefill\":true,\"max_tokens\":500,\"model\":\"Llama-3.2-3B-Instruct\",\"prompt\":\"I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.\",\"remote_block_ids\":[1,2,3,4],\"remote_engine_id\":\"81eb3201-d5c2-4642-8131-7849f2e955ce\",\"remote_host\":\"10.128.13.52\",\"remote_port\":5557,\"temperature\":0}"
```

Finally in the decode inference pod (terminal 3) we should see the logs on KV transfer:

```log
INFO 05-09 19:26:20 [logger.py:39] Received request cmpl-0dec7ca2-42c8-4b79-a753-d355181114f2-0: prompt: 'I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.', params: SamplingParams(n=1, presence_penalty=0.0, frequency_penalty=0.0, repetition_penalty=1.0, temperature=0.0, top_p=1.0, top_k=-1, min_p=0.0, seed=None, stop=[], stop_token_ids=[], bad_words=[], include_stop_str_in_output=False, ignore_eos=False, max_tokens=500, min_tokens=0, logprobs=None, prompt_logprobs=None, skip_special_tokens=True, spaces_between_special_tokens=True, truncate_prompt_tokens=None, guided_decoding=None, extra_args=None), prompt_token_ids: [128000, 40, 1097, 3318, 389, 6975, 311, 1629, 63119, 304, 856, 16264, 48933, 10879, 13, 358, 574, 20910, 422, 499, 1436, 3493, 757, 264, 1160, 315, 1888, 12659, 994, 26984, 17150, 389, 279, 597, 23, 82, 5452, 11, 323, 78637, 11, 904, 507, 7269, 3230, 82278, 430, 527, 8581, 1618, 13, 17830, 4587, 1520, 757, 9429, 264, 3197, 311, 1862, 7649, 17150, 4526, 369, 7649, 323, 3567, 22484, 1778, 439, 1332, 1609, 3845, 477, 3169, 13], lora_request: None, prompt_adapter_request: None.
INFO 05-09 19:26:20 [async_llm.py:255] Added request cmpl-0dec7ca2-42c8-4b79-a753-d355181114f2-0.
DEBUG 05-09 19:26:20 [core.py:431] EngineCore loop active.
DEBUG 05-09 19:26:20 [nixl_connector.py:559] start_load_kv for request cmpl-0dec7ca2-42c8-4b79-a753-d355181114f2-0 from remote engine 81eb3201-d5c2-4642-8131-7849f2e955ce. Num local_block_ids: 4. Num remote_block_ids: 4.
DEBUG 05-09 19:26:20 [nixl_connector.py:313] Querying metadata on path: tcp://10.128.13.52:5557
DEBUG 05-09 19:26:20 [nixl_connector.py:422] Created 1055264 blocks for src engine 6d177cac-6a93-4396-8c06-a5af03e9ace7 and rank 0
DEBUG 05-09 19:26:21 [nixl_connector.py:439] Created 1055264 blocks for dst engine 81eb3201-d5c2-4642-8131-7849f2e955ce and rank 0
DEBUG 05-09 19:26:22 [nixl_connector.py:326] NIXL handshake: get metadata took: 0.0025545399985276163
DEBUG 05-09 19:26:22 [nixl_connector.py:328] NIXL handshake: add agent took: 2.2907175269938307
DEBUG 05-09 19:26:22 [nixl_connector.py:463] Rank 0, get_finished: 0 requests done sending and 1 requests done recving
DEBUG 05-09 19:26:22 [scheduler.py:862] Finished recving KV transfer for request cmpl-0dec7ca2-42c8-4b79-a753-d355181114f2-0
```

If you are debugging networking you can finally observe the prefill pod logs to see how it recieves the request from decode, and sends back the KVs

```log
INFO 05-09 19:43:44 [logger.py:39] Received request cmpl-bb24666d-5d42-46a2-997b-63f352d5bbdb-0: prompt: 'I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.', params: SamplingParams(n=1, presence_penalty=0.0, frequency_penalty=0.0, repetition_penalty=1.0, temperature=0.0, top_p=1.0, top_k=-1, min_p=0.0, seed=None, stop=[], stop_token_ids=[], bad_words=[], include_stop_str_in_output=False, ignore_eos=False, max_tokens=500, min_tokens=0, logprobs=None, prompt_logprobs=None, skip_special_tokens=True, spaces_between_special_tokens=True, truncate_prompt_tokens=None, guided_decoding=None, extra_args=None), prompt_token_ids: [128000, 40, 1097, 3318, 389, 6975, 311, 1629, 63119, 304, 856, 16264, 48933, 10879, 13, 358, 574, 20910, 422, 499, 1436, 3493, 757, 264, 1160, 315, 1888, 12659, 994, 26984, 17150, 389, 279, 597, 23, 82, 5452, 11, 323, 78637, 11, 904, 507, 7269, 3230, 82278, 430, 527, 8581, 1618, 13, 17830, 4587, 1520, 757, 9429, 264, 3197, 311, 1862, 7649, 17150, 4526, 369, 7649, 323, 3567, 22484, 1778, 439, 1332, 1609, 3845, 477, 3169, 13], lora_request: None, prompt_adapter_request: None.
INFO 05-09 19:43:44 [async_llm.py:255] Added request cmpl-bb24666d-5d42-46a2-997b-63f352d5bbdb-0.
DEBUG 05-09 19:43:44 [core.py:431] EngineCore loop active.
DEBUG 05-09 19:43:44 [nixl_connector.py:463] Rank 0, get_finished: 1 requests done sending and 0 requests done recving
DEBUG 05-09 19:43:44 [scheduler.py:865] Finished sending KV transfer for request cmpl-0dec7ca2-42c8-4b79-a753-d355181114f2-0
DEBUG 05-09 19:43:44 [core.py:425] EngineCore waiting for work.
INFO:     10.131.10.180:44514 - "POST /v1/completions HTTP/1.1" 200 OK
```
