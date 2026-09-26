# ShopBR — Déploiement (dépôt n°2 : CI/CD)

Infrastructure et déploiement continu de la solution ShopBR sur AWS
(ECR pour les images, EKS pour Kubernetes).

> Projet de certification **Architecte en Intelligence Artificielle**
> (Mastère 2, Fonderie de l'Image). Ce dépôt contient le **pipeline de
> déploiement**. Le code de la solution vit dans le dépôt
> **[shopbr-ia](https://github.com/Mckl77/shopbr-ia)**.

---

## Pourquoi deux dépôts séparés

- **Moindre privilège** : seuls les identifiants de ce dépôt donnent
  accès à la production. Un développeur peut modifier le code de la
  solution sans jamais pouvoir toucher aux serveurs.
- **Traçabilité** : chaque déploiement référence le commit exact
  déployé, donc on sait toujours quelle version tourne.
- **Rythmes différents** : le code applicatif change tous les jours,
  l'infrastructure beaucoup plus rarement.

---

## Arborescence

```
shopbr-deploy/
├── k8s/
│   ├── deployment.yaml   Deployments de l'API (2 copies, sondes de santé) et du dashboard
│   └── service.yaml      Namespace, Services, Ingress (TLS) et autoscaling 2 → 10 copies
├── scripts/
│   └── deploy.sh         déploiement manuel, en secours ou pour une démonstration
└── .github/workflows/cd.yml   construction de l'image, publication ECR, déploiement EKS
```

---

## La chaîne complète

```
dépôt shopbr-ia                        dépôt shopbr-deploy (ce dépôt)
push sur main
  └─ CI : lint → 15 tests ✓
       └─ signal automatique ────────→ déploiement déclenché
                                         ├─ récupération du code au commit exact
                                         ├─ construction de l'image Docker
                                         ├─ publication sur Amazon ECR
                                         ├─ déploiement sur Kubernetes (mise à jour progressive)
                                         └─ retour arrière automatique en cas d'échec
```

La construction de l'image est faite ici, pas dans la CI du dépôt de
développement : celle-ci valide le code, celui-ci construit et déploie.

L'**autoscaling** (de 2 à 10 copies, déclenché à 70 % d'utilisation du
processeur) est dimensionné sur les pics mesurés dans les données :
1 176 commandes le jour du Black Friday, contre 160 par jour en
moyenne, soit sept fois la charge habituelle.

---

## Configuration requise

Dans **Settings → Secrets and variables → Actions** de ce dépôt :

| Type | Nom | Valeur |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` | utilisateur IAM limité à la publication ECR et au déploiement EKS |
| Secret | `AWS_ACCOUNT_ID` | numéro de compte AWS |
| Variable | `AWS_REGION` | `sa-east-1` (São Paulo, pour rester conforme à la LGPD) |
| Variable | `ECR_REPO` | `shopbr-api` |
| Variable | `EKS_CLUSTER` | `shopbr-cluster` |

Il reste ensuite à remplacer `YOUR_AWS_ACCOUNT` dans
`k8s/deployment.yaml` par le numéro de compte.

---

## Déclenchement manuel

Onglet **Actions → CD → Run workflow**, utile pour une démonstration :
on voit la construction, la publication et la mise à jour progressive
se dérouler en direct.

En secours, sans GitHub Actions :

```bash
./scripts/deploy.sh <SHA_ou_main>
```

---

## Limite assumée

Aucun cluster Kubernetes n'a été provisionné : le déploiement s'arrête
à l'authentification AWS. C'est un choix cohérent avec l'arbitrage de
coûts du projet, un cluster EKS de démonstration revenant à plusieurs
dizaines de dollars par mois sans rien démontrer de plus. Toute la
chaîne en amont, jusqu'au déclenchement automatique, est fonctionnelle
et vérifiable dans l'onglet Actions.
