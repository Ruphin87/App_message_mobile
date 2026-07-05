# 🔧 Guide détaillé d'utilisation du Pannel Admin

## 📋 Table des matières
1. [Accès au Pannel](#accès-au-pannel)
2. [Authentification](#authentification)
3. [Tableau de Bord](#tableau-de-bord)
4. [Gestion des Messages](#gestion-des-messages)
5. [Gestion des Utilisateurs](#gestion-des-utilisateurs)
6. [Gestion des Signalements](#gestion-des-signalements)
7. [Outils d'Administration](#outils-dadministration)
8. [FAQ](#faq)

---

## Accès au Pannel

### Méthode 1: Via Menu Caché (Recommandé)
1. Allez à l'écran d'accueil
2. Appuyez 5 fois rapidement sur le logo Message_KO
3. L'écran d'authentification admin s'ouvre automatiquement

### Méthode 2: Via Paramètres (Développeurs)
1. Allez à **Paramètres**
2. Allez à **À propos**
3. Appuyez 10 fois sur la version
4. Menu développeur s'active
5. Appuyez sur **Accès Admin**

### Méthode 3: Via URL (Si disponible)
```
app://admin/auth
```

---

## Authentification

### Interface d'authentification

```
┌─────────────────────────────────────┐
│      Administration                 │
├─────────────────────────────────────┤
│                                     │
│           [Admin Icon]              │
│                                     │
│        Panneau Admin                │
│   Accédez au tableau de bord        │
│    d'administration                 │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Mot de passe admin          │   │
│  │ ┌─────────────────────────┐ │   │
│  │ │ •••••••••••••••••••••   │ │   │
│  │ │ [👁️ ̶‌ Eye icon]        │ │   │
│  │ └─────────────────────────┘ │   │
│  └─────────────────────────────┘   │
│                                     │
│   ┌──────────────────────────────┐ │
│   │   Se connecter               │ │
│   └──────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### Saisir le mot de passe

1. **Cliquez sur le champ "Mot de passe admin"**
2. **Entrez**: `twins@2026RP!`
3. **Appuyez sur "Se connecter"** ou pressez Entrée
4. ✅ Vous accédez au dashboard

### Points importants

⚠️ **Le mot de passe est**:
- Case-sensitive (T majuscule)
- Exactement: `twins@2026RP!`
- Contient des caractères spéciaux (@, !)

🔒 **Sécurité**:
- Le mot de passe est hasté SHA-256
- Jamais stocké en clair
- Non visible en debug

---

## Tableau de Bord

### Vue d'ensemble

```
┌──────────────────────────────────────────────────┐
│  ← Tableau de Bord Admin              [Logout]  │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │
│  │👥      │ │💬      │ │🚫      │ │⚠️      │   │
│  │2,345   │ │15,678  │ │234     │ │56      │   │
│  │Users   │ │Messages│ │Blocked │ │Reports │   │
│  └────────┘ └────────┘ └────────┘ └────────┘   │
│                                                  │
├──────────────────────────────────────────────────┤
│  [📧 Messages] [👥 Users] [⚠️ Reports] [⚙️ Tools]│
├──────────────────────────────────────────────────┤
│                                                  │
│  Contenu de l'onglet sélectionné                │
│  ...                                             │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Statistiques en direct

**4 cartes affichées:**

| Icône | Titre | Valeur | Couleur |
|-------|-------|--------|---------|
| 👥 | Utilisateurs | 2,345 | Bleu |
| 💬 | Messages | 15,678 | Vert |
| 🚫 | Bloqués | 234 | Orange |
| ⚠️ | Signalements | 56 | Rouge |

Les statistiques se mettent à jour automatiquement chaque 30 secondes.

---

## Gestion des Messages

### Interface

```
┌──────────────────────────────────────────┐
│ Filtres                          [▼]    │
├──────────────────────────────────────────┤
│  Messages plus anciens que:              │
│  [1 jour] [1 semaine] [1 mois] [3 mois] │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ 🖼️ Appel avec Alice - Il y a 45 jours   │
│    [Supprimer ✕]                        │
│                                          │
│ 🎤 Vocal reçu - Il y a 40 jours          │
│    [Supprimer ✕]                        │
│                                          │
│ 📄 Document PDF - Il y a 35 jours        │
│    [Supprimer ✕]                        │
│                                          │
│ 💬 Message texte - Il y a 31 jours       │
│    [Supprimer ✕]                        │
│                                          │
│ Aucun message trouvé                     │
└──────────────────────────────────────────┘
```

### Opérations

#### 1️⃣ Filtrer les messages

1. Cliquez sur **Filtres** (le chevron ▼)
2. Sélectionnez la durée:
   - **1 jour**: Messages > 24h
   - **1 semaine**: Messages > 7j
   - **1 mois**: Messages > 30j
   - **3 mois**: Messages > 90j
3. La liste se met à jour automatiquement

#### 2️⃣ Supprimer un message

1. Localisez le message dans la liste
2. Cliquez sur **[Supprimer ✕]** à droite
3. ⚠️ **Confirmez** la suppression
4. ✅ Message supprimé
   - Les fichiers sont supprimés du stockage
   - Les métadonnées sont conservées pour l'audit

#### 3️⃣ Supprimer les messages > 30 jours (Batch)

Via l'onglet **Outils**:
1. Allez à **Outils**
2. Trouvez **"Supprimer les messages anciens"**
3. Cliquez sur **[Supprimer les messages > 30 jours]**
4. ⚠️ **Confirmez**: 
   ```
   Êtes-vous sûr de vouloir supprimer tous les 
   messages datant de plus de 30 jours ? 
   Cette action est irréversible.
   ```
5. ✅ Exemple de résultat:
   ```
   ✓ 1,234 messages supprimés avec succès
   ```

### Types de pièces jointes

Les icônes indiquent le type:
- 🖼️ **Image** - Photo, screenshot
- 🎤 **Audio** - Vocal, enregistrement
- 📄 **Fichier** - Document général
- 📕 **PDF** - Document PDF
- 💬 **Texte** - Message texte uniquement

---

## Gestion des Utilisateurs

### Interface

```
┌──────────────────────────────────────────────┐
│ [Avatar] Alice Martin                        │
│ alice@example.com                            │
│ Bloqué depuis 15 jours                       │
│                                [Débloquer]   │
│                                              │
│ [Avatar] Bob Dupont                          │
│ bob@example.com                              │
│ Bloqué depuis 3 jours                        │
│                                [Débloquer]   │
│                                              │
│ Aucun utilisateur bloqué                     │
└──────────────────────────────────────────────┘
```

### Opérations

#### 1️⃣ Voir les utilisateurs bloqués

1. Allez à l'onglet **Utilisateurs**
2. La liste affiche automatiquement les utilisateurs bloqués
3. Informations affichées:
   - Avatar (première lettre du nom)
   - Nom complet
   - Email
   - Nombre de jours depuis le blocage

#### 2️⃣ Débloquer un utilisateur

1. Trouvez l'utilisateur dans la liste
2. Cliquez sur **[Débloquer]**
3. ✅ L'utilisateur est débloqué immédiatement
4. La ligne disparaît de la liste

#### 3️⃣ Bloquer un utilisateur (depuis le signalement)

Voir section "Gestion des Signalements" → Actions possibles

---

## Gestion des Signalements

### Interface

```
┌──────────────────────────────────────────────────────┐
│ 🔴 Signalement #A1B2C3D4                             │
│    Raison: Contenu offensant                         │
│    Signalé il y a 2h                                 │
│                                    [⋮ Menu]          │
│                                                      │
│ ✅ Signalement #E5F6G7H8 (Résolu)                    │
│    Raison: Harcèlement                               │
│    Signalé il y a 5h                                 │
│    [Résolu]            [Supprimer ✕]                │
│                                                      │
│ 🔴 Signalement #I9J0K1L2                             │
│    Raison: Spam                                      │
│    Signalé il y a 12h                                │
│                                    [⋮ Menu]          │
└──────────────────────────────────────────────────────┘
```

### États des signalements

| État | Icône | Couleur | Action |
|------|-------|---------|--------|
| En attente | 🔴 | Rouge | Résoudre, Supprimer |
| Résolu | ✅ | Vert | Supprimer seulement |

### Opérations

#### 1️⃣ Voir les signalements

1. Allez à l'onglet **Signalements**
2. La liste affiche automatiquement tous les signalements
3. Triés par date (plus récent d'abord)

#### 2️⃣ Résoudre un signalement

1. Cliquez sur le menu **[⋮]** du signalement
2. Sélectionnez **Résoudre**
3. ✅ Le signalement passe à "Résolu"
4. L'icône change de 🔴 à ✅

#### 3️⃣ Supprimer un signalement

1. Cliquez sur le menu **[⋮]** du signalement
2. Sélectionnez **Supprimer**
3. ⚠️ **Confirmez** la suppression
4. ✅ Le signalement est supprimé

#### 4️⃣ Actions recommandées

**Pour un signalement de harcèlement:**
1. Marquer comme résolu
2. Aller à l'onglet **Utilisateurs**
3. Chercher l'utilisateur signalé
4. Cliquer **Bloquer** (via menu signalement)

**Pour un signalement de contenu offensant:**
1. Supprimer le message (onglet Messages)
2. Marquer le signalement comme résolu
3. Optionnel: Bloquer l'utilisateur

---

## Outils d'Administration

### Interface

```
┌────────────────────────────────────────┐
│ 🗑️ Supprimer les messages anciens      │
│                                        │
│ Supprimez tous les messages datant    │
│ de plus de 30 jours (fichiers, texte, │
│ audio, etc.)                           │
│                                        │
│ [Supprimer les messages > 30 jours]   │
│                                        │
├────────────────────────────────────────┤
│ ⚠️ Alertes de messages                 │
│                                        │
│ Consultez les messages qui approchent  │
│ de 30 jours d'ancienneté               │
│                                        │
│ [Voir les messages expirant]           │
└────────────────────────────────────────┘
```

### Fonctionnalités

#### 1️⃣ Supprimer les messages > 30 jours

**Étapes:**
1. Cliquez sur **[Supprimer les messages > 30 jours]**
2. **Dialog de confirmation** s'affiche:
   ```
   Confirmer la suppression
   Êtes-vous sûr de vouloir supprimer tous les 
   messages datant de plus de 30 jours ? 
   Cette action est irréversible.
   
   [Annuler]  [Supprimer]
   ```
3. Cliquez **[Supprimer]**
4. ⏳ Traitement en cours (indicateur de progression)
5. ✅ Résultat:
   ```
   ✓ 1,234 messages supprimés avec succès
   ```

**Données supprimées:**
- Texte du message
- Pièces jointes du stockage
- Métadonnées conservées pour audit

#### 2️⃣ Voir les messages expirant

**Étapes:**
1. Cliquez sur **[Voir les messages expirant]**
2. **Dialog** s'ouvre avec la liste:
   ```
   Messages expirant bientôt
   
   42 message(s) plus anciens que 30 jours
   
   🖼️ Photo de vacances
      Il y a 31 jours           [Supprimer]
   
   🎤 Vocal pour toi
      Il y a 32 jours           [Supprimer]
   
   📄 Contrat.pdf
      Il y a 35 jours           [Supprimer]
   
   [Fermer]
   ```
3. **Supprimer individuellement:**
   - Cliquez **[Supprimer]** pour chaque message
4. **Fermer:**
   - Cliquez **[Fermer]** quand terminé

---

## FAQ

### Q1: J'ai oublié le mot de passe admin
**R:** Le mot de passe est: `twins@2026RP!`

Si vous l'avez changé, il faut le réinitialiser via:
- Accès à la base de données Supabase
- Table `admin_settings`
- Exécuter la fonction de réinitialisation

### Q2: Combien de temps avant suppression auto?
**R:** **30 jours** exactement
- Les messages sont supprimés après 30 jours
- Les alertes s'affichent à 28 jours
- Vous pouvez forcer la suppression immédiate via les Outils

### Q3: Peut-on récupérer un message supprimé?
**R:** **Non**, la suppression est irréversible
- Les fichiers sont supprimés du stockage
- Les entrées de base de données sont supprimées
- Des sauvegardes peuvent exister (contacter support)

### Q4: Un utilisateur bloqué peut-il revenir?
**R:** **Oui**
1. Allez à l'onglet **Utilisateurs**
2. Trouvez l'utilisateur
3. Cliquez **[Débloquer]**
4. L'utilisateur peut se reconnecter immédiatement

### Q5: Comment signaler un bug?
**R:** Collectez:
1. Screenshot ou vidéo du bug
2. Les étapes pour le reproduire
3. Votre version d'application
4. Votre version d'OS
5. Contactez le support technique

### Q6: Les logs d'admin sont-ils conservés?
**R:** **Oui**
- Table: `admin_logs`
- Chaque action est enregistrée
- Conservée 1 an par défaut
- Contient: Admin ID, Action, Ressource, Détails, Timestamp

### Q7: Peut-on exporter les statistiques?
**R:** **Pas dans l'interface**
- Utiliser Supabase Dashboard
- Exporter via API
- Utiliser des outils BI (Tableau, Power BI)
- Demander un rapport personnalisé

### Q8: La suppression des messages affecte-t-elle la DB?
**R:** **Non**
- Sauvegardes automatiques: Hourly + Daily
- Replicas de base de données
- Possibilité de restauration (contact support)

### Q9: Peut-on automatiser la suppression?
**R:** **Oui**, via un CRON job Supabase:
```sql
-- À mettre en place
SELECT cron.schedule('cleanup-messages', '0 3 * * *', 
  'SELECT public.cleanup_expired_messages()');
```

### Q10: Comment se déconnecter?
**R:** 
1. Cliquez sur **[Logout]** en haut à droite
2. Vous êtes redirigé vers **AdminAuthScreen**
3. Vous devez re-entrer le mot de passe pour accéder

---

## 🎓 Bonnes pratiques

### ✅ À faire

- ✅ Vérifier régulièrement les signalements
- ✅ Archiver les messages > 1 an
- ✅ Débloquer les utilisateurs après 30j si pas de réitération
- ✅ Documenter les raisons des blocages
- ✅ Effectuer des sauvegardes régulières

### ❌ À ne pas faire

- ❌ Ne pas supprimer les logs d'audit
- ❌ Ne pas partager le mot de passe admin
- ❌ Ne pas bloquer sans raison valide
- ❌ Ne pas utiliser pour modérer les messages personnels
- ❌ Ne pas modifier les données via SQL directement

---

## 📞 Support

**Pour toute question:**
- Lire cette documentation
- Consulter `PHASE8_PHASE9_README.md`
- Contacter l'équipe de support
- Vérifier les logs: `supabase.logs()`

---

Dernière mise à jour: 3 juillet 2026
