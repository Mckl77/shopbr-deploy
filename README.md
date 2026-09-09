# ShopBR — Pipeline de déploiement CI/CD (dépôt n°2)

Infrastructure as Code et déploiement continu de la solution ShopBR
sur AWS (ECR + EKS).

> Projet de certification **Architecte en Intelligence Artificielle**.
> Ce dépôt contient le **pipeline de déploiement** (Bloc 4, exigence
> "deux dépôts GitHub distincts"). Le code de la solution vit dans le
> dépôt **shopbr-ia**.

---

## Pourquoi deux dépôts séparés ?

Séparer le code applicatif du code de déploiement est une bonne
pratique (et une exigence de l'énoncé) :

- **Moindre privilège** : seuls les identifiants AWS de CE dépôt
  peuvent toucher la production ; le dépôt de dev n'a aucun secret AWS.
- **Traçabilité** : chaque déploiement référence le SHA exact du
  commit déployé — on sait toujours quelle version tourne.
- **Cycle de vie distinct** : les manifestes Kubernetes évoluent
  moins vite que le code, et sont revus par d'autres personnes (ops).

## Arborescence

```
shopbr-deploy/
├── k8s/
│   ├── deployment.yaml   Deployments API (2 replicas, probes) + dashboard
│   └── service.yaml      Namespace, Services, Ingress (TLS), HPA 2→10 pods
├── scripts/deploy.sh     déploiement manuel (secours / démo)
└── .github/workflows/cd.yml   CD : build+push ECR → deploy EKS → rollback auto
```

## La chaîne complète

```
dépôt shopbr-ia                        dépôt shopbr-deploy (celui-ci)
────────────────                       ──────────────────────────────
push sur main
  └─ CI : lint → tests → build ✓
       └─ repository_dispatch ───────→ CD déclenché automatiquement
                                         ├─ JOB build-and-push
                                         │    checkout shopbr-ia@SHA
                                         │    docker build
                                         │    push ECR (tag = SHA court)
                                         └─ JOB deploy
                                              kubectl apply k8s/
                                              set image (rolling update, 0 coupure)
                                              rollout status (vérification santé)
                                              rollback automatique si échec
```

L'**autoscaling** (HPA 2→10 pods, CPU 70 %) est dimensionné pour les
pics mesurés dans les données : ×7 au Black Friday (1 176 commandes le
24/11/2017 contre 160/jour en moyenne).

## Configuration requise (une seule fois)

Dans **Settings → Secrets and variables → Actions** de ce dépôt :

| Type | Nom | Valeur |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | utilisateur IAM limité à ECR push + EKS deploy |
| Secret | `AWS_ACCOUNT_ID` | compte AWS (12 chiffres) |
| Secret | `DEPLOY_REPO_TOKEN` | PAT si shopbr-ia est privé |
| Variable | `AWS_REGION` | `sa-east-1` (São Paulo — LGPD) |
| Variable | `ECR_REPO` | `shopbr-api` |
| Variable | `EKS_CLUSTER` | `shopbr-cluster` |

Puis remplacer `VOTRE_COMPTE` dans `cd.yml`, et `YOUR_AWS_ACCOUNT`
dans `k8s/deployment.yaml`.

## Déclenchement manuel (démo certification)

Onglet **Actions → CD → Run workflow** : idéal pour la capture vidéo
exigée par le Bloc 4 (on voit le build, le push ECR, le rolling update
et la vérification `rollout status` en direct).

Ou en secours, sans GitHub Actions :

```bash
./scripts/deploy.sh <SHA_ou_main>
```
