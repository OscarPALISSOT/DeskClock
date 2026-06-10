# 🕐 DeskClock

> Suivi automatique du temps de présence au bureau — backend REST, app iOS native, widget écran d'accueil.

Un projet perso exploratoire qui couvre plusieurs sujets techniques en un seul endroit : API REST typée, authentification Apple, géofencing iOS, et WidgetKit. Conçu pour une utilisation personnelle sans publication sur l'App Store.

---

## Sommaire

- [Vue d'ensemble](#vue-densemble)
- [Architecture globale](#architecture-globale)
- [Structure du monorepo](#structure-du-monorepo)
- [Stack technique](#stack-technique)
- [Modèle de données](#modèle-de-données)
- [API — endpoints](#api--endpoints)
- [Flux d'authentification](#flux-dauthentification)
- [Détection de présence (géofencing)](#détection-de-présence-géofencing)
- [Installation & lancement](#installation--lancement)
- [Roadmap](#roadmap)

---

## Vue d'ensemble

DeskClock détecte automatiquement quand tu arrives et repars du bureau, sans aucune interaction manuelle. L'iPhone surveille une zone géographique en arrière-plan ; à l'entrée et à la sortie, il ouvre une session ou la clôture via l'API. Un widget sur l'écran d'accueil affiche le récap de la semaine en temps réel.

```
┌─────────────────────────────────────────────────────────┐
│  Tu arrives au bureau                                   │
│  → iPhone détecte la zone géographique                  │
│  → App envoie POST /sessions au backend                 │
│  → Widget se rafraîchit, affiche l'heure d'arrivée      │
│                                                         │
│  Tu repars                                              │
│  → iPhone détecte la sortie de zone                     │
│  → App envoie PATCH /sessions/:id                       │
│  → Widget affiche la durée de la journée                │
└─────────────────────────────────────────────────────────┘
```

---

## Roadmap

- [x] Architecture & schéma de données
- [ ] Backend — auth Apple + CRUD sessions
- [ ] Backend — tests d'intégration (Vitest)
- [ ] App iOS — affichage et clock-in/out manuel
- [ ] App iOS — géofencing Core Location
- [ ] Widget WidgetKit
- [ ] CI GitHub Actions (lint, tests, build Docker)

---

## IA & process

Ce projet est aussi une expérimentation volontaire de **Claude** (Anthropic, version gratuite,
interface chat) comme outil de développement. L'objectif : passer moins de temps sur la
documentation et la recherche pour me concentrer sur l'apprentissage — notamment le dev natif
Apple qui est nouveau pour moi. Toutes les décisions restent relues, comprises et assumées.

---

## Licence

MIT — projet personnel, usage libre.

---

## Architecture globale

```mermaid
graph TB
    subgraph iPhone["📱 iPhone"]
        CL["Core Location\nGéofencing"]
        APP["App SwiftUI\nSessionViewModel"]
        WGT["Widget\nWidgetKit"]
    end

    subgraph VPS["🖥️  VPS"]
        API["Fastify API\nNode.js + TypeScript"]
        DB[("PostgreSQL")]
    end

    subgraph Apple["🍎 Apple"]
        JWKS["Apple JWKS\nValidation token"]
    end

    CL -->|"didEnterRegion\ndidExitRegion"| APP
    APP -->|"POST /sessions\nPATCH /sessions/:id"| API
    WGT -->|"GET /sessions\n(toutes les 30 min)"| API
    API -->|"Vérifie token\n(Sign in with Apple)"| JWKS
    API <-->|"SQL"| DB
```

---

## Structure du monorepo

```
todo
```

---

## Stack technique

| Couche | Technologie | Pourquoi |
|--------|-------------|----------|

todo

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
Auth     : Bearer <jwt> dans le header Authorization (sauf /auth/apple)
```

| Méthode | Route | Description |
|---------|-------|-------------|
| `POST` | `/auth/apple` | Échange un token Apple contre un JWT + refresh token |
| `POST` | `/auth/refresh` | Renouvelle le JWT avec un refresh token valide |
| `GET` | `/me` | Profil de l'utilisateur connecté |
| `POST` | `/sessions` | Clock-in — ouvre une nouvelle session |
| `PATCH` | `/sessions/:id` | Clock-out — ferme une session existante |
| `GET` | `/sessions` | Liste les sessions (`?from=ISO8601&to=ISO8601`) |
| `DELETE` | `/sessions/:id` | Supprime une session (correction d'erreur) |

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
    API-->>iPhone: { access_token, refresh_token }

    Note over iPhone,API: Requêtes suivantes
    iPhone->>API: GET /sessions (Bearer access_token)
    API-->>iPhone: [...sessions]
```

---

## Détection de présence (géofencing)

```mermaid
stateDiagram-v2
    [*] --> Dehors

    Dehors --> ArrivéeDetectée : didEnterRegion\n(iOS, background)
    ArrivéeDetectée --> EnSession : POST /sessions\n(started_at = now)
    EnSession --> DépartDetecté : didExitRegion\n(iOS, background)
    DépartDetecté --> Dehors : PATCH /sessions/:id\n(ended_at = now)

    EnSession --> EnSession : Widget poll\ntoutes les 30 min
```

Core Location surveille une zone circulaire (`CLCircularRegion`) autour du bureau. iOS réveille l'app en background à l'entrée et à la sortie — sans GPS continu, donc sans impact notable sur la batterie. Le rayon recommandé est de **50 à 100 mètres**.

---

## Installation & lancement

### Prérequis

todo

### Backend en local

```bash
# Cloner le repo
git clone https://github.com/<toi>/deskclock.git
cd deskclock

# Variables d'environnement
cp .env.example .env
# → Renseigner DATABASE_URL, JWT_SECRET, APPLE_CLIENT_ID

# Démarrer PostgreSQL
docker compose up -d postgres

# Installer les dépendances et lancer les migrations
cd apps/api
npm install
npm run migrate:up

# Lancer en dev (hot reload)
npm run dev
# → http://localhost:3000
```

### Déploiement VPS

```bash
# Sur le VPS
docker compose -f docker-compose.prod.yml up -d
```

### App iOS

1. Ouvrir `apps/ios/DeskClock.xcodeproj` dans Xcode
2. Sélectionner ton iPhone comme cible
3. Renseigner l'URL de l'API dans `Config.swift`
4. `⌘R` pour compiler et installer

> **Sans Apple Developer Program :** le certificat expire tous les 7 jours. Re-signer en rebranchant l'iPhone et en relançant `⌘R`, ou utiliser [AltStore](https://altstore.io/) pour la re-signature automatique via Wi-Fi.
