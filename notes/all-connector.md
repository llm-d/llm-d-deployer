# All connector notes

What works right now.

Request hits gateway --> routing sidecar --> prefill --> routing sidecar --> decode  (breaks here)

Routing sidecar log:

```log
I0510 20:20:35.765478       1 chat_completions.go:110] "running NIXL protocol" logger="proxy server"
I0510 20:20:35.765575       1 chat_completions.go:172] "sending request to prefiller" logger="proxy server" url="http://10.128.13.233:8000" body="{\"do_remote_decode\":true,\"max_tokens\":500,\"model\":\"Llama-3.2-3B-Instruct\",\"prompt\":\"I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.\",\"stream\":false,\"temperature\":0}"
I0510 20:20:35.787151       1 chat_completions.go:217] "received prefiller response" logger="proxy server" remote_block_ids=[1,2,3,4] remote_engine_id="051f9ab6-20ec-4132-8627-3ec5c9aad4d4" remote_host="10.128.13.233" remote_port=5557
I0510 20:20:35.787214       1 chat_completions.go:252] "sending request to decoder" logger="proxy server" body="{\"do_remote_prefill\":true,\"max_tokens\":500,\"model\":\"Llama-3.2-3B-Instruct\",\"prompt\":\"I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.\",\"remote_block_ids\":[1,2,3,4],\"remote_engine_id\":\"051f9ab6-20ec-4132-8627-3ec5c9aad4d4\",\"remote_host\":\"10.128.13.233\",\"remote_port\":5557,\"temperature\":0}"
2025/05/10 20:20:50 http: proxy error: context canceled
```

Key log: `2025/05/10 20:20:50 http: proxy error: context canceled`

Prefill log (looks fine):

```log
INFO 05-10 20:20:35 [logger.py:39] Received request cmpl-c4b8067d-8aa0-48da-97ac-b014b5ee1e88-0: prompt: 'I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.', params: SamplingParams(n=1, presence_penalty=0.0, frequency_penalty=0.0, repetition_penalty=1.0, temperature=0.0, top_p=1.0, top_k=-1, min_p=0.0, seed=None, stop=[], stop_token_ids=[], bad_words=[], include_stop_str_in_output=False, ignore_eos=False, max_tokens=500, min_tokens=0, logprobs=None, prompt_logprobs=None, skip_special_tokens=True, spaces_between_special_tokens=True, truncate_prompt_tokens=None, guided_decoding=None, extra_args=None), prompt_token_ids: [128000, 40, 1097, 3318, 389, 6975, 311, 1629, 63119, 304, 856, 16264, 48933, 10879, 13, 358, 574, 20910, 422, 499, 1436, 3493, 757, 264, 1160, 315, 1888, 12659, 994, 26984, 17150, 389, 279, 597, 23, 82, 5452, 11, 323, 78637, 11, 904, 507, 7269, 3230, 82278, 430, 527, 8581, 1618, 13, 17830, 4587, 1520, 757, 9429, 264, 3197, 311, 1862, 7649, 17150, 4526, 369, 7649, 323, 3567, 22484, 1778, 439, 1332, 1609, 3845, 477, 3169, 13], lora_request: None, prompt_adapter_request: None.
INFO 05-10 20:20:35 [async_llm.py:255] Added request cmpl-c4b8067d-8aa0-48da-97ac-b014b5ee1e88-0.
DEBUG 05-10 20:20:35 [core.py:431] EngineCore loop active.
[2025-05-10 20:20:35,769] LMCache INFO: Reqid: cmpl-c4b8067d-8aa0-48da-97ac-b014b5ee1e88-0, Total tokens 76, LMCache hit tokens: 75, need to load: 11 (vllm_v1_adapter.py:561:lmcache.integration.vllm.vllm_v1_adapter)
[2025-05-10 20:20:35,785] LMCache WARNING: In connector.start_load_kv, but the attn_metadata is None (vllm_v1_adapter.py:389:lmcache.integration.vllm.vllm_v1_adapter)
DEBUG 05-10 20:20:35 [core.py:425] EngineCore waiting for work.
INFO:     10.131.10.250:33354 - "POST /v1/completions HTTP/1.1" 200 OK
INFO 05-10 20:20:40 [loggers.py:116] Engine 000: Avg prompt throughput: 7.6 tokens/s, Avg generation throughput: 0.1 tokens/s, Running: 0 reqs, Waiting: 0 reqs, GPU KV cache usage: 0.1%, Prefix cache hit rate: 80.0%
```

Decode logs (request aborts for some unknown reason):

```log
INFO 05-10 20:25:19 [logger.py:39] Received request cmpl-ac0030b3-43e4-41aa-bb43-df9b48feec52-0: prompt: 'I am working on learning to run benchmarks in my openshift cluster. I was wondering if you could provide me a list of best practices when collecting metrics on the k8s platform, and furthermore, any OCP specific optimizations that are applicable here. Finally please help me construct a plan to support testing metrics collection for testing and dev environments such as minikube or kind.', params: SamplingParams(n=1, presence_penalty=0.0, frequency_penalty=0.0, repetition_penalty=1.0, temperature=0.0, top_p=1.0, top_k=-1, min_p=0.0, seed=None, stop=[], stop_token_ids=[], bad_words=[], include_stop_str_in_output=False, ignore_eos=False, max_tokens=500, min_tokens=0, logprobs=None, prompt_logprobs=None, skip_special_tokens=True, spaces_between_special_tokens=True, truncate_prompt_tokens=None, guided_decoding=None, extra_args=None), prompt_token_ids: [128000, 40, 1097, 3318, 389, 6975, 311, 1629, 63119, 304, 856, 16264, 48933, 10879, 13, 358, 574, 20910, 422, 499, 1436, 3493, 757, 264, 1160, 315, 1888, 12659, 994, 26984, 17150, 389, 279, 597, 23, 82, 5452, 11, 323, 78637, 11, 904, 507, 7269, 3230, 82278, 430, 527, 8581, 1618, 13, 17830, 4587, 1520, 757, 9429, 264, 3197, 311, 1862, 7649, 17150, 4526, 369, 7649, 323, 3567, 22484, 1778, 439, 1332, 1609, 3845, 477, 3169, 13], lora_request: None, prompt_adapter_request: None.
INFO 05-10 20:25:19 [async_llm.py:255] Added request cmpl-ac0030b3-43e4-41aa-bb43-df9b48feec52-0.
INFO 05-10 20:25:34 [async_llm.py:414] Aborted request cmpl-ac0030b3-43e4-41aa-bb43-df9b48feec52-0.
INFO 05-10 20:25:34 [async_llm.py:321] Request cmpl-ac0030b3-43e4-41aa-bb43-df9b48feec52-0 aborted.
```

key log: `INFO 05-10 20:25:34 [async_llm.py:414] Aborted request cmpl-ac0030b3-43e4-41aa-bb43-df9b48feec52-0.`

EPP logs all look fine but when it fails again at the end we get this:

```log
{"level":"error","ts":"2025-05-10T20:25:34Z","caller":"handlers/server.go:296","msg":"Error unmarshaling request body","error":"invalid character 'u' looking for beginning of value","stacktrace":"sigs.k8s.io/gateway-api-inference-extension/pkg/epp/handlers.(*StreamingServer).Process\n\t/workspace/pkg/epp/handlers/server.go:296\ngithub.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3._ExternalProcessor_Process_Handler\n\t/go/pkg/mod/github.com/envoyproxy/go-control-plane/envoy@v1.32.4/service/ext_proc/v3/external_processor_grpc.pb.go:106\ngoogle.golang.org/grpc.(*Server).processStreamingRPC\n\t/go/pkg/mod/google.golang.org/grpc@v1.71.1/server.go:1695\ngoogle.golang.org/grpc.(*Server).handleStream\n\t/go/pkg/mod/google.golang.org/grpc@v1.71.1/server.go:1819\ngoogle.golang.org/grpc.(*Server).serveStreams.func2.1\n\t/go/pkg/mod/google.golang.org/grpc@v1.71.1/server.go:1035"}
```

Which if the request fails we expect to get some thing wrong but we seem to get the `invalid character 'u'` a lot and it might make sense to either petition for better logging there, or identify if there is fragility in the code.

Redis doesn't log anythign but also has 0 entries in the keyspace ... wondering if this is a Redis auth issue? Going to try with no auth.

Tried again with no auth on redis and it bails out sameplace, at decode.

