# No Sample App Preset

This preset is for when you want to provision the infrastructure around modelservice but not actually create a `modelservice` custom resource.
This can be particularly helpful because of how helm works - it wants to make sure that it owns and deploys all resources in its chart via labels.
The result of this, is that if you create a sample app through the helm charts, and you want to modify or delete your `modelservice` custom resource,
you have to uninstall the whole stack, tweak an sample values override file, or modify the
[base values](https://github.com/llm-d/llm-d-deployer/blob/main/charts/llm-d/values.yaml) file (this is not recommended unless you know what you are doing)
before re-installing through quickstart.

This preset enables you to have more control over that. You can apply the "No Sample App" preset, use `helm template` to template manifests based on
a different preset, extract the resourcess that make up the diff ([see below](./README.md#making-up-the-difference)), and then apply them by hand.
The result should be you can make **some** modifications to your setup without having to use the quickstart `--uninstall` tack in the installer script,
and install everything from the ground up again.

It should be noted that you can only make **some** modifications because
[the baseConfigMap](https://github.com/llm-d/llm-d-deployer/tree/dc90005ef2fc87f1e6dbac282dfc038187efde12/charts/llm-d/templates/modelservice/presets)
presets for `modelservice` are immutable, any desired changes there will require uninstalling and reinstalling via the quickstart install script.

## Deploying

Assuming one is starting from the quickstart directory, a sample deploy might look like:

```bash
HF_TOKEN=$(HFTOKEN) ./llmd-installer.sh --namespace llm-d --values-file examples/no-sample-app/no-sample-app.yaml
```

## Validating the deployment

You should expect to see only see infra related resources that can be plugged into any setup, specifically:

- A gateway, which should spin a gateway deployment / pod.
- A modelservice controller.
- A redis master deployment. This is turned on by default in this example in case the desired modelservice should use the `baseConfigMapRef` of `base-gpu-with-nixl-and-redis-lookup-preset`. If you do not want to use this preset, you can optionally add the following to your `no-sample-app.yaml`:

```yaml
sampleApplication:
  enabled: false
redis
  enabled: false
```

To sumarrize, in a successful deployment of this preset, expect to see:

```log
NAME                                       READY   STATUS    RESTARTS   AGE
llm-d-inference-gateway-654ddbcb74-25vv4   1/1     Running   0          58m
llm-d-modelservice-7844f89454-lcs2r        1/1     Running   0          58m
llm-d-redis-master-8599696799-2wpv5        1/1     Running   0          58m
```

## What This Deployment Lacks

To see all resource templates that get created based on a "Sample App" which we will intentionally miss out on using this example, you can
[look here](https://github.com/llm-d/llm-d-deployer/tree/main/charts/llm-d/templates/sample-application).

These templates will map into the following manifests that you will be missing based on this `no-sample-app` vs another sample app scenario:

1. A `modelservice` custom resource.
    - This is the biggest component of a "Sample App" and will create many other children resources, such as prefill, decode, and `endpoint-picker` deployments, services, serviceAccounts, RBAC, an `inferencepool`, an `inferencemodel`, etc.
2. An `httpRoute` that will be accepted by the gateway, with a backendRef of the `inferencepool` that will get created by the `modelservice` CR.
3. (ISTIO ONLY) A `destinationRule`. We have support for Istio as a gateway control plane implementation but for now we are using kgateway as a default, so I don't believe this has ever been tested.
4. A `ClusterRoleBinding` for the `endpoint-picker` that allow for scraping of `endpoint-picker` (epp) metrics with authentication.
    - This is included in "sample app" because per "sample app" there is an `endpoint-picker` that gets deployed, with a different `serviceAccount`, named based off the `modelName` in the Sample App.

## Making Up the Difference

Lets walkthrough how one might use this "No Sample App" preset to provisoin the base infrastructure, and then create a sample app by hand to re-create one of the other presets.

First lets pick a "Sample App" to re-create - in this case lets start with "no-features". We are going to use `helm template` with two values files, first
the base values file, and then passing the "no features" preset as an override values file, and then dumping that to a temporary yaml file.

```bash
# navigate to the chart directory
cd ../../../charts/llm-d/

# set your namespace in your no-sample-app infra was already deployed
: "${NAMESPACE:=llm-d}"

TEMP=$(mktemp)

helm template llm-d ./ -n ${NAMESPACE} --values ../../quickstart/examples/no-features/no-features.yaml > $TEMP
```

For those unfamiliar with `helm` or `helm template`, this above command will tell helm to spit out what manifests a `helm upgrade -i` or `helm install`
would plan to create based on the merge of the two values files. It will treat the second values file with higher priority in this merge, and overwrite anything
that appears in both with the value of the 2nd values file (in this case, our `no-features` preset we are trying to re-create).

As mentioned above, that `$TEMP` file should include all the manifests from the `no-features` example, but if you remember we already applied our `no-sample-app` preset, so many of these manifests will already exist in our cluster.

We want to grab just the `modelservice` CR, the `httpRoute`, and `clusterRoleBindigng` for EPP metrics. You can do this by hand, but based on the `no-features` preset were re-creating, you can automate it with the following (this yq):

```bash
yq -i eval-all '
  select(
    (.kind == "ModelService")
    or (.kind == "HTTPRoute")
    or (.kind == "ClusterRoleBinding" and .metadata.name == "llm-d-llm-d-modelservice-epp-metrics-scrape")
  )
  | del(.metadata.labels["helm.sh/chart"])
  | del(.metadata.labels["app.kubernetes.io/managed-by"])
' $TEMP

kubectl apply -f $TEMP
```

> [!NOTE]
> The `ClusterRoleBinding` name is based on the `modelservice` controller name, so it can vary.
> It is suggested to copy the manifests by hand, but based on matching up the `CRB` name with the `no-feature` example, this example can be scripted.
> This example also assumes you are using the default `kgateway` control plane and APIs rather than Istio.
> This command depends on the `mikefarah` version of `yq` v4 or greater

In addition to grabbing those resources, the above script will filter out the helm labels that would otherwise get templated into the manifests,
allowing us to create and manage these resources by hand.

Now our pods should reflect that of the `no-feature` example with our new `epp` and single `decode` pods:

```log
NAME                                                       READY   STATUS    RESTARTS   AGE
llm-d-inference-gateway-654ddbcb74-25vv4                   1/1     Running   0          97m
llm-d-modelservice-7844f89454-lcs2r                        1/1     Running   0          97m
llm-d-redis-master-8599696799-2wpv5                        1/1     Running   0          97m
meta-llama-llama-3-2-3b-instruct-decode-7c679bb8b4-kbxc6   2/2     Running   0          42s
meta-llama-llama-3-2-3b-instruct-epp-8d4749d47-dnpf2       1/1     Running   0          42s
```
