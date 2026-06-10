# DeskClock — Backend

> API REST — Fastify · TypeScript · PostgreSQL

Ce répertoire contient le backend de DeskClock. Il expose les endpoints consommés par l'app iOS et le widget, gère l'authentification via Sign in with Apple, et persiste les sessions de présence en base.

→ [README global du projet](../README.md)

---

## Sommaire

- [Stack](#stack)
- [Structure](#structure)
- [Modèle de données](#modèle-de-données)
- [API — endpoints](#api--endpoints)
- [Flux d'authentification](#flux-dauthentification)
- [Variables d'environnement](#variables-denvironnement)
- [Installation & lancement](#installation--lancement)
- [Tests](#tests)

---

## Stack

| Couche | Technologie | Pourquoi |
|--------|-------------|----------|

todo

---

## Structure

```
todo
```

---

## Modèle de données

```mermaid
erDiagram
    users {
        uuid id PK
        text apple_sub UK "identifiant Apple unique"
        text email "nullable"
        timestamptz created_at
    }

    work_sessions {
        uuid id PK
        uuid user_id FK
        timestamptz started_at "heure d'arrivée (UTC)"
        timestamptz ended_at "heure de départ (UTC) — NULL si en cours"
        timestamptz created_at
    }

    refresh_tokens {
        uuid id PK
        uuid user_id FK
        text token_hash
        timestamptz expires_at
        timestamptz created_at
    }

    users ||--o{ work_sessions : "possède"
    users ||--o{ refresh_tokens : "possède"
```

> **Note :** tout est stocké en UTC (`TIMESTAMPTZ`). L'app iOS applique le fuseau horaire local à l'affichage. On évite ainsi tous les bugs lors des changements d'heure.

---

## API — endpoints

```
Base URL : https://api.your-vps.com/v1
Auth     : Bearer <jwt> dans le header Authorization (sauf /auth/*)
```

| Méthode | Route | Auth | Description |
|---------|-------|------|-------------|
| `POST` | `/auth/apple` | — | Échange un token Apple contre un JWT + refresh token |
| `POST` | `/auth/refresh` | — | Renouvelle le JWT avec un refresh token valide |
| `GET` | `/me` | ✓ | Profil de l'utilisateur connecté |
| `POST` | `/sessions` | ✓ | Clock-in — ouvre une nouvelle session |
| `PATCH` | `/sessions/:id` | ✓ | Clock-out — ferme une session existante |
| `GET` | `/sessions` | ✓ | Liste les sessions (`?from=ISO8601&to=ISO8601`) |
| `DELETE` | `/sessions/:id` | ✓ | Supprime une session (correction d'erreur) |

### Exemple — POST /sessions

```http
POST /v1/sessions
Authorization: Bearer eyJ...
Content-Type: application/json

{
  "started_at": "2025-06-10T08:42:00+02:00"
}
```

```json
{
  "id": "c1f2e3d4-...",
  "user_id": "a0b1c2d3-...",
  "started_at": "2025-06-10T06:42:00Z",
  "ended_at": null,
  "created_at": "2025-06-10T06:42:01Z"
}
```

### Exemple — PATCH /sessions/:id

```http
PATCH /v1/sessions/c1f2e3d4-...
Authorization: Bearer eyJ...
Content-Type: application/json

{
  "ended_at": "2025-06-10T18:15:00+02:00"
}
```

```json
{
  "id": "c1f2e3d4-...",
  "user_id": "a0b1c2d3-...",
  "started_at": "2025-06-10T06:42:00Z",
  "ended_at": "2025-06-10T16:15:00Z",
  "created_at": "2025-06-10T06:42:01Z"
}
```

---

## Flux d'authentification

```mermaid
sequenceDiagram
    participant iPhone
    participant API
    participant Apple

    iPhone->>Apple: Sign in with Apple
    Apple-->>iPhone: identityToken (JWT signé Apple)

    iPhone->>API: POST /auth/apple { identity_token }
    API->>Apple: GET /auth/keys (JWKS)
    Apple-->>API: Clés publiques
    API->>API: Vérifie signature + audience + expiration
    API->>API: Crée ou retrouve l'utilisateur (upsert sur apple_sub)
    API-->>iPhone: { access_token (1h), refresh_token (30j) }

    Note over iPhone,API: Requêtes suivantes
    iPhone->>API: Bearer access_token
    API-->>iPhone: 200 OK

    Note over iPhone,API: access_token expiré
    iPhone->>API: POST /auth/refresh { refresh_token }
    API-->>iPhone: { access_token (nouveau), refresh_token (nouveau) }
```

> Le refresh token est **rotation-based** : à chaque renouvellement, l'ancien est invalidé et un nouveau est émis. En base, on stocke le hash du token (pas la valeur brute).

---

## Variables d'environnement

```bash
# .env.example

# Base de données
DATABASE_URL=postgres://user:password@localhost:5432/deskclock

# JWT
JWT_SECRET=une-chaine-aleatoire-longue-et-secrete
JWT_EXPIRES_IN=1h
REFRESH_TOKEN_EXPIRES_IN=30d

# Sign in with Apple
APPLE_CLIENT_ID=com.ton-nom.deskclock   # Bundle ID de l'app iOS
```

---

## Installation & lancement

### Prérequis

- Node.js ≥ 22
- Docker & Docker Compose

### En local

```bash
# Depuis la racine du monorepo
cp .env.example .env
# → Renseigner les variables

todo
```

### Déploiement VPS

```bash
# Depuis la racine du monorepo, sur le VPS
todo
```

---

## Tests

```bash
cd apps/api
npm run test          # Vitest en mode watch
npm run test:run      # Une seule passe (CI)
```

Les tests d'intégration démarrent une instance Fastify en mémoire et utilisent une base PostgreSQL de test dédiée (`deskclock_test`).