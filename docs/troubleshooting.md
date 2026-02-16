# Troubleshooting Guide

Common issues and solutions when bootstrapping clusters with this repository.

## ArgoCD Issues

### ArgoCD pods not starting

**Symptom:** `kubectl get pods -n argocd` shows pods in Pending or CrashLoopBackOff

**Check resources:**

```bash
kubectl describe pod <pod-name> -n argocd
```

**Common causes:**

1. **No storage available:** StorageClasses not ready yet
   - Solution: Check `bootstrap/storage/` has been applied

2. **Resource limits:** Node doesn't have enough CPU/memory
   - Solution: Check node resources with `kubectl top nodes`

3. **Image pull issues:** Can't pull ArgoCD image
   - Solution: Check image registry access, verify internet connectivity

### ArgoCD not syncing application

**Symptom:** Application shows "OutOfSync" or status is pending

**Check application status:**

```bash
kubectl describe application bootstrap -n argocd

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Check ArgoCD API server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

**Common causes:**

1. **Repository access denied**
   - Check: SSH key or HTTP credentials configured in ArgoCD
   - Solution:

     ```bash
     # For SSH, check repository secret
     kubectl get secret -n argocd | grep repo
     kubectl describe secret <secret-name> -n argocd
     ```

2. **Manifest syntax errors in this repo**
   - Check: Git branch has valid YAML
   - Solution:

     ```bash
     # Run kustomize locally to validate
     kustomize build bootstrap/

     # Fix any YAML errors, commit, and ArgoCD will retry
     ```

3. **CRDs missing for custom resources**
   - Check: All CRDs installed before using them
   - Solution:

     ```bash
     # Verify CRDs exist
     kubectl get crd | grep gateway

     # If missing, ensure bootstrap/crds/ synced first
     ```

4. **Namespace doesn't exist**
   - Check: Resources trying to deploy to non-existent namespace
   - Solution:

     ```bash
     # Ensure namespace creation is in manifests
     # Or set syncPolicy.syncOptions to create namespaces
     ```

### Can't access ArgoCD web UI

**Forward port:**

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

**URL:** `https://localhost:8080`

**Get default password:**

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

## Storage Issues

### StorageClasses not available

**Check available storage:**

```bash
kubectl get storageclass
```

**If empty or missing expected classes:**

1. **Check bootstrap/storage/ manifests:**

   ```bash
   kubectl get pvc,pv

   # Check provisioner is available
   kubectl get pod -A | grep provisioner
   ```

2. **Verify provisioner pods running:**

   ```bash
   # Common provisioners
   kubectl get pod -n kube-system | grep storage
   kubectl get pod -n nfs-provisioner | grep nfs
   ```

3. **Check ArgoCD applied storage manifests:**

   ```bash
   kubectl describe application bootstrap -n argocd | grep -i storage
   ```

### PVC stuck in Pending

**Symptom:** `kubectl get pvc` shows pending PVCs

**Debug steps:**

```bash
# Describe the PVC to see events
kubectl describe pvc <pvc-name>

# Check if storage class exists
kubectl get storageclass <storage-class-name>

# Check provisioner logs
kubectl logs -n <provisioner-namespace> -l app=<provisioner> -f
```

**Common causes:**

1. StorageClass doesn't exist
2. Provisioner pod not running
3. Resource exhaustion on nodes
4. No nodes suitable for local volumes

## Gateway API Issues

### GatewayClass not showing

**Symptom:** No GatewayClass available for creating Gateways

**Check:**

```bash
kubectl get gatewayclass

# List all Gateway API resources
kubectl api-resources | grep gateway
```

**If missing:**

1. **CRDs not installed:**

   ```bash
   kubectl get crd | grep gateway.networking

   # If missing, check if bootstrap/crds/ synced
   ```

2. **Controller not running:**

   ```bash
   kubectl get pod -A | grep gateway

   # Should see gateway controller pod running
   ```

3. **Check ArgoCD synced CRDs:**

   ```bash
   kubectl describe application bootstrap -n argocd
   ```

### Gateway not becoming Ready

**Symptom:** Gateway object exists but status shows not Ready

**Debug:**

```bash
kubectl describe gateway <gateway-name>

# Check associated resources
kubectl get service <gateway-name>
kubectl get pod -l <gateway-selector>
```

**Typical causes:**

1. Envoy Gateway controller not ready yet
2. No service loadBalancer IP assigned (MetalLB issue)
3. Gateway references non-existent secret or configmap

## Envoy Gateway Issues

### Envoy Gateway pod not starting

**Check:**

```bash
kubectl get pod -n envoy-gateway-system
kubectl describe pod -n envoy-gateway-system
```

**Common causes:**

1. Gateway API CRDs not installed
2. Insufficient resources
3. RBAC permissions missing

### EnvoyGateway resource not syncing

**Check:**

```bash
kubectl get envoygateway
kubectl describe envoygateway default
```

**Verify:**

1. Syntax is correct
2. All referenced namespaces exist
3. Provisioned settings are valid

## Networking Issues

### MetalLB not assigning IPs

**Symptom:** LoadBalancer services stuck in Pending with no external IP

**Check MetalLB:**

```bash
# Verify MetalLB pods running
kubectl get pod -n metallb-system

# Check MetalLB config
kubectl get configmap -n metallb-system config -o yaml

# View controller logs
kubectl logs -n metallb-system -l app=metallb,component=controller -f

# View speaker logs
kubectl logs -n metallb-system -l app=metallb,component=speaker -f
```

**Common causes:**

1. **MetalLB not deployed yet**
   - Note: This repo assumes MetalLB already installed by Kairos setup
   - Verify: `kubectl get pod -n metallb-system`

2. **MetalLB ConfigMap invalid**
   - Check syntax of IP pools
   - Verify IP range is available and on correct network

3. **No nodes with correct labels**
   - MetalLB speaker pod needs to be on nodes
   - Check: `kubectl get node -L metallb.universe.tf/member`

### Can't reach service via LoadBalancer IP

**Test connectivity:**

```bash
# Get the LoadBalancer IP
kubectl get svc | grep LoadBalancer

# Test from control node
curl <LoadBalancer-IP>:<Port>

# If fails, check:
# 1. Service has endpoints
kubectl get endpoints <service-name>

# 2. Pods are running
kubectl get pod -l <label>

# 3. Firewall allows traffic
# Test from MetalLB speaker node directly
```

## NetworkPolicy Issues

### Pods can't communicate (expected to be blocked)

**Check if NetworkPolicy exists:**

```bash
kubectl get networkpolicy -A

# Describe the policy
kubectl describe networkpolicy <policy-name>
```

**Debug traffic:**

```bash
# Get shell in pod
kubectl exec -it <pod> -- /bin/sh

# Test connectivity to another pod
curl <other-pod-ip>:<port>

# Check logs of target pod
kubectl logs <target-pod>
```

### Pods can't communicate (not expected to be blocked)

**Ensure NetworkPolicy allows traffic:**

```bash
# List all NetworkPolicies that might affect traffic
kubectl get networkpolicy -A

# Check if policy might be blocking
kubectl describe networkpolicy <policy-name>

# Rules to check:
# - podSelector matches source pod labels?
# - namespaceSelector matches source namespace?
# - ports match the traffic?
```

**Add debug NetworkPolicy to allow traffic:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: debug-allow-all
spec:
  podSelector: {}
  ingress:
  - {}
  egress:
  - {}
```

**Note:** This is for debugging only. Replace with proper policies.

## General Troubleshooting Steps

### 1. Check ArgoCD application status

```bash
kubectl get applications -n argocd
kubectl describe application bootstrap -n argocd
```

### 2. Review recent events

```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

### 3. Check component logs

```bash
# CRD installation
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Bootstrap component specific
kubectl logs -n <component-namespace> -l <selector> -f
```

### 4. Verify manifests are valid

```bash
# Run kustomize locally
kustomize build bootstrap/ | kubectl apply --dry-run=client -f -
```

### 5. Check node resources

```bash
kubectl top nodes
kubectl top pods -A
```

## Getting Help

If stuck:

1. **Check GitOps principles:** Is the desired state in Git?
2. **Check ArgoCD:** Is ArgoCD syncing the Git state?
3. **Check cluster:** Does the cluster match Git?
4. **Review logs:** What do the component logs say?

When reporting issues, include:

- ArgoCD application status
- Recent events (`kubectl get events -A`)
- Relevant pod logs
- What you expected vs. what happened
