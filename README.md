# EMQX Production-like Deployment on Kubernetes

Déploiement production-ready d'EMQX sur cluster Kubernetes local (k3d) avec GitOps via ArgoCD.

## Architecture

- **EMQX**: Broker MQTT en cluster haute disponibilité
- **Helm**: Chart de déploiement avec configuration flexible
- **ArgoCD**: Déploiement GitOps avec zero-downtime
- **NGINX Ingress**: Exposition TLS avec cert-manager
- **Stockage persistant**: PVC pour données EMQX

## Prérequis

- Cluster k3d fonctionnel
- ArgoCD installé
- NGINX Ingress Controller installé
- cert-manager installé avec ClusterIssuer `local-amazone`
- MetalLB configuré (si nécessaire)

## Structure du projet

```
├── README.md
├── argocd/
│   └── app.yaml              # Application ArgoCD
├── helm/
│   └── emqx/
│       ├── Chart.yaml
│       ├── values.yaml       # Configuration principale
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── NOTES.txt
├── scripts/
│   └── create-emqx-secret.sh   # Script de création du Secret externe
```

## Déploiement

### 1. Créer le Secret externe (une fois)

Le chart n'inclut plus le Secret pour éviter les rotations via ArgoCD. Crée-le si absent:

```bash
./scripts/create-emqx-secret.sh emqx emqx-auth
```

Variables optionnelles: EMQX_ADMIN_USERNAME, EMQX_ADMIN_PASSWORD, EMQX_ERLANG_COOKIE

### 2. Déploiement via ArgoCD

```bash
kubectl apply -f argocd/app.yaml
```

### 3. Vérification du déploiement

```bash
# Vérifier l'application ArgoCD
kubectl get application -n argocd emqx

# Vérifier les pods EMQX
kubectl get pods -n emqx -l app=emqx

# Vérifier le cluster EMQX
kubectl exec -it emqx-0 -n emqx -- emqx_ctl cluster status
```

### 4. Accès au dashboard

- URL: <https://emqx.amazone.lan/dashboard>
- Credentials: Générés automatiquement (voir secrets)

```bash
# Récupérer les credentials
kubectl get secret emqx-auth -n emqx -o jsonpath='{.data.admin-username}' | base64 -d; echo
kubectl get secret emqx-auth -n emqx -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## Configuration

### Ports exposés

- **1883**: MQTT TCP
- **8883**: MQTT SSL/TLS
- **8083**: MQTT WebSocket
- **8084**: MQTT WebSocket Secure
- **18083**: Dashboard HTTP/API

### Persistance

- Volume persistant de 20Gi par défaut
- Configuré via `values.yaml`

### Clustering

- Autodécouverte Kubernetes activée
- Stratégie: `k8s` avec service discovery
- Réplication automatique des données

## Monitoring et debug

```bash
# Logs des pods
kubectl logs -f emqx-0 -n emqx

# Status du cluster
kubectl exec emqx-0 -n emqx -- emqx_ctl cluster status

# Métriques
curl -s http://emqx.amazone.lan/api/v5/stats
```

## Limitations et avertissements

- ✅ **Secrets externes**: Le Secret est géré hors chart pour éviter toute rotation lors des sync ArgoCD
- ⚠️ **Certificat TLS**: Utilise le ClusterIssuer local, non valide en production Internet
- ⚠️ **Pas de backup automatique**: Configurer la sauvegarde des données persistantes
- ⚠️ **Monitoring basique**: Pas de Prometheus/Grafana intégré

## Troubleshooting

### Cluster ne se forme pas

```bash
# Vérifier les logs de clustering
kubectl logs emqx-0 -n emqx | grep -i cluster

# Forcer la reformation du cluster
kubectl delete pods -l app=emqx -n emqx
```

### Problèmes de connectivité

```bash
# Test MQTT
mosquitto_pub -h emqx.amazone.lan -p 1883 -t test/topic -m "hello"

# Test via ingress
curl -k https://emqx.amazone.lan/api/v5/stats
```

### Certificats TLS

```bash
# Vérifier le certificat
kubectl describe certificate emqx-tls -n emqx

# Renouveler le certificat
kubectl delete certificate emqx-tls -n emqx
```

