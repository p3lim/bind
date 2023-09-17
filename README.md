# bind

Containerized [BIND](https://www.isc.org/bind) specifically designed to be used with [ExternalDNS](https://github.com/kubernetes-sigs/external-dns#readme). Can be used standalone, or in conjunction with your primary DNS for the domain.

See [ExternalDNS documentation on RFC2136](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/rfc2136.md).

Configuration is covered by environment variables:

- `BIND_ZONE` - zone domain
- `BIND_KEY` - TSIG secret
- `BIND_KEY_ALG` - TSIG algorithm (defaults to hmac-sha256)

A Kubernetes secret manifest containing a TSIG key can be generated:

```bash
docker run --rm ghcr.io/p3lim/bind:latest tsig my-secret-name my-secret-namespace
# secret name and namespace are optional
```

### Deploying

```yaml
kind: Namespace
apiVersion: v1
metadata:
  name: external-dns
---
$(docker run --rm ghcr.io/p3lim/bind:latest tsig bind-tsig external-dns)
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: bind
  namespace: external-dns
  labels:
    name: external-dns-bind
spec:
  selector:
    matchLabels:
      name: external-dns-bind
  template:
    metadata:
      labels:
        name: external-dns-bind
    spec:
      containers:
        - name: bind
          image: ghcr.io/p3lim/bind:latest # should be pinned
          imagePullPolicy: Always
          ports:
            - containerPort: 53
              name: bind-dns-udp
              protocol: UDP
            - containerPort: 53
              name: bind-dns-tcp
              protocol: TCP
            - containerPort: 8053 # optional, for bind_exporter
              name: bind-stats
              protocol: TCP
          env:
            - name: BIND_ZONE
              value: example.com
            - name: BIND_KEY
              valueFrom:
                secretKeyRef:
                  name: bind-tsig
                  key: rfc2136_tsig_secret
          readinessProbe:
            tcpSocket:
              port: bind-dns-udp
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: bind-dns-tcp
            initialDelaySeconds: 5
            periodSeconds: 10
---
kind: Service
apiVersion: v1
metadata:
  name: bind
  namespace: external-dns
spec:
  selector:
    name: external-dns-bind
  ports:
    - name: dns
      port: 53
      targetPort: bind-dns-udp
      protocol: UDP
    - name: dns-tcp
      port: 53
      targetPort: bind-dns-tcp
      protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: bind-external
  namespace: external-dns
spec:
  type: LoadBalancer # requires a loadbalancer, like MetalLB
  selector:
    name: external-dns-bind
  ports:
    - name: dns-external
      port: 53
      targetPort: bind-dns-udp
      protocol: UDP
```

When using this with [Bitnami's ExternalDNS chart](https://github.com/bitnami/charts/tree/main/bitnami/external-dns#readme) these values are sufficient:

```yaml
provider: rfc2136
policy: sync
rfc2136:
  host: bind.external-dns.svc.cluster.local
  zone: example.com
  secretName: bind-tsig
  tsigKeyname: external-dns
```

	helm install external-dns oci://registry-1.docker.io/bitnamicharts/external-dns -n external-dns -f values.yaml
