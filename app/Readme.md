# DeskClock — iOS

> SwiftUI · Core Location · WidgetKit (à venir)

Application iOS de DeskClock. Détecte automatiquement les arrivées et départs du bureau via géofencing, et communique avec le backend pour ouvrir/fermer les sessions de présence.

→ [README global du projet](../../README.md)

---

## Sommaire

- [Stack](#stack)
- [Gestion des erreurs](#gestion-des-erreurs)

---

## Stack

| Couche | Technologie |
|--------|-------------|
| UI | SwiftUI |
| Géofencing | Core Location |
| Stockage sécurisé | Keychain |
| Widget | WidgetKit (à venir) |

---

## Gestion des erreurs

### Requêtes API et renouvellement automatique du token

```mermaid
flowchart TD
    A[Requête API] --> B{Code retour}
    B -- 2xx --> C[Succès]
    B -- "401, déjà après refresh" --> D[Déconnexion forcée]
    B -- "401, première fois" --> E[Tentative de refresh]
    B -- Autre erreur HTTP --> F[Erreur propagée]

    E --> G{Résultat du refresh}
    G -- Token local illisible --> H[Requête abandonnée\naucune déconnexion]
    G -- Réseau injoignable --> H
    G -- Rejeté par le serveur --> D
    G -- Succès --> I[Requête rejouée\navec le nouveau token]
```

Un `401` déclenche une tentative de renouvellement avant d'abandonner. Seul un refus explicite du serveur (refresh token invalide ou déjà utilisé) provoque une déconnexion — une impossibilité locale de lire le token, ou un problème réseau, n'entraîne jamais de déconnexion.

### Clock-in / clock-out en arrière-plan

```mermaid
flowchart TD
    A["Transition détectée\n(didEnterRegion / didExitRegion / didDetermineState)"] --> B{État local cohérent ?}
    B -- Non --> Z[Ignoré]
    B -- Oui --> C[Appel API clock-in / clock-out]
    C --> D{Résultat}
    D -- Succès --> E[État local mis à jour]
    D -- "404 sur clock-out" --> F[État local périmé, réinitialisé]
    D -- "Erreur transitoire\n(réseau ou 401)" --> G{Tentatives restantes ?}
    G -- Oui --> H[Attente 5s, nouvelle tentative]
    H --> C
    G -- Non --> I["Abandon pour ce réveil\n(prochaine transition ou lancement réessaiera)"]
    D -- Autre erreur --> J[Échec loggé]
```

Chaque tentative dispose de deux nouvelles tentatives espacées de 5 secondes en cas d'échec transitoire, dans la fenêtre accordée par la background task assertion. Un `404` sur une fermeture de session signale un état local périmé (session déjà fermée ou supprimée côté serveur) : il est réinitialisé plutôt que de bloquer indéfiniment les entrées suivantes.