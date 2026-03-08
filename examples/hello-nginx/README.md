# hello-nginx (smoke test)

This is an *optional* smoke-test application to validate:

- Gateway API routing (HTTPRoute)
- Envoy Gateway data plane
- MetalLB external IP allocation

It is kept under `examples/` so it does not get deployed by the repo’s root ArgoCD app-of-apps.

## Deploy (via ArgoCD)

This creates a dedicated ArgoCD `Application` that syncs the manifests in this folder.

```sh
kubectl apply -f examples/hello-nginx/argocd-application.yaml
```

## Verify

- Get the Gateway external IP:

```sh
kubectl -n envoy-gateway-system get svc -l app.kubernetes.io/component=proxy -o wide
```

- Test HTTP routing (replace `$IP`):

```sh
curl -H 'Host: hello.cloud.fam-melcher.net' http://$IP/
```

## Remove

```sh
kubectl delete -f examples/hello-nginx/argocd-application.yaml
```
