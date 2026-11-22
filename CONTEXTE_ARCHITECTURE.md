# PowerTrack — Contexte & Architecture Complète

> Document de référence à fournir au début d'une nouvelle conversation pour reprendre le développement et l'amélioration de **PowerTrack** sans perdre le contexte technique ni l'architecture existante.

---

## 1. Vision & Contraintes du Projet

- **Objectif :** Application iOS native et sur-mesure de suivi de **force athlétique (Powerlifting)** pour usage personnel.
- **Stack technique :**
  - **UI :** SwiftUI (`preferredColorScheme(.dark)`), esthétique **Swiss Editorial / Flighty** centralisée dans `DesignSystem.swift` (`PTTheme`: fond encre profond `#09090B`, surfaces `#111114` / `#18181C`, filets `0.5pt`, texte primaire blanc craie `#F5F5F7`, accent cuivre mat `#DE7A42` utilisé avec parcimonie), pensée pour une utilisation en salle avec téléphone souvent verrouillé.
  - **Persistance locale :** SwiftData (`ModelContainer` sur `MacroBloc.self`) + `UserDefaults` pour l'état de séance en cours (`SeanceProgressTracker`). Fonctionnement **100 % hors-ligne** pendant l'entraînement.
  - **Graphiques :** Swift Charts (`PerformanceDashboardView`).
  - **Arrière-plan & Écran verrouillé :** `ActivityKit`, `WidgetKit`, `AppIntents`, `UserNotifications`, `AVFoundation` / `AudioToolbox` (ducking audio non-intrusif) et `UIKit` haptique.
  - **Réseau (export uniquement) :** `URLSession` (`POST` JSON vers webhook).
- **Contraintes Apple / Sideloading :**
  - Compte Apple gratuit (`DEVELOPMENT_TEAM = A2H9BRHXKX`), limité à **3 App IDs actifs**.
  - Actuellement **3 / 3 App IDs utilisés** : `com.ethanruders.PowerTrack` + `com.ethanruders.PowerTrack.PowerTrackWidgets` + `SideStore`. **Ne pas ajouter de nouvelle App Extension** (sauf suppression d'une autre ou passage sur compte développeur payant).

---

## 2. Structure du Projet & Targets Xcode

Le projet utilise `PBXFileSystemSynchronizedRootGroup` dans `PowerTrack.xcodeproj/project.pbxproj` : tout fichier `.swift` placé dans `PowerTrack/` est automatiquement compilé dans la cible principale, et tout fichier dans `PowerTrackWidgets/` est compilé dans l'extension widget (à l'exception de `PowerTrackWidgets/Info.plist`).

- **Cible `PowerTrack`** (`com.ethanruders.PowerTrack`, `IPHONEOS_DEPLOYMENT_TARGET = 26.5`, Swift 5.0, aucune dépendance SwiftPM externe) :
  - `PowerTrackApp.swift` — Point d'entrée `@main`, configure `.modelContainer(for: MacroBloc.self)`.
  - `DesignSystem.swift` — Palette `PTTheme` (`#09090B` / `#F5F5F7` / `#DE7A42`), primitives éditoriales (`PTHairline`, `PTKicker`, `PTProgressHairline`), boutons capsule (`PTPrimaryPillButtonStyle`, `PTSecondaryPillButtonStyle`), formatage (`PTFormat`) et calculateur de disques (`PTBarbellPlateHelper`).
  - `ContentView.swift` — `TabView` à 2 onglets : **Programmation** (`BlocListView`) et **Performance** (`PerformanceDashboardView`).
  - `models.swift` — Modèles SwiftData (`MacroBloc`, `Semaine`, `Seance`, `Exercice`, `Serie`), énumérations (`CategorieExercice`, `TypeEchauffementExercice`), état local `SeanceProgressTracker`, et moteur de charges RPE (`pourcentagePour`, `calculerCharge`).
  - `BlocListView.swift` — Liste des blocs, menu de création / import JSON coach, accès aux réglages serveur (badge file hors-ligne), suppression par menu contextuel, et bannière flottante `ResumeWorkoutBannerView`.
  - `BlocInitView.swift` — Formulaire entonnoir en 3 étapes (*1. Mouvements → 2. Variantes & Ratios → 3. 1RM & Option Test PR*) appelant `ProgramGenerator`.
  - `ProgramGenerator.swift` — Générateur de cycle de 4 semaines (*Volume RPE 6.5 → Accumulation RPE 7.5 → Intensification RPE 8 → Pic Contrôlé RPE 8.5*) avec option Semaine 5 (*Taper + Test PR en 1 journée*), 7 gabarits (`GabaritProgramme`, dont `fullSBD` en J1 DL / J2 Bench / J3 Squat+Var Bench / J4 SBD), `Bench Tempo` et calcul auto des charges à 2,5 kg près.
  - `ProgramJSONImporter.swift` & `ProgramImportSheet.swift` — Importateur JSON générique (format Coach v2 avec `indications` et séries détaillées, ou format tableau historique) avec prévisualisation et injection dans SwiftData.
  - `SemaineListView.swift` — Liste triée des semaines d'un `MacroBloc` + `ResumeWorkoutBannerView`.
  - `SeanceListView.swift` — Liste triée des séances d'une `Semaine` avec compteur de séries validées.
  - `SeanceDetailView.swift` — Écran principal de séance en salle (`SeanceProgressHeaderView`, `ExerciceSectionHeaderView`, `BackoffAdaptationBannerView`, `SerieCompactRowView`, `CompactStepButton`, accès `SeanceExportSheet`, fin de séance).
  - `EtapeEchauffement.swift` — Calculateur et feuille modale d'échauffement (`genererPaliersEchauffement`, `EchauffementSheetView`).
  - `SeanceSummarySheet.swift` — Modale de bilan en fin de séance (tonnage, meilleur e1RM, séries validées, durée réelle via `SeanceProgressTracker`, Top Sets vs RPE cible, accès direct à l'export & ressentis).
  - `TimerState.swift` — `TimerManager.shared` (`ObservableObject`, `@MainActor`) : calcul des durées min/max selon catégorie & RPE, horodatages absolus (`dateFinMin` / `dateFinMax`), resynchronisation `willEnterForegroundNotification`, notifications locales unifiées et pilotage de la Live Activity.
  - `TimerView.swift` — Bandeau chrono flottant en bas de `SeanceDetailView` affichant le compte à rebours `tempsRestantMax` (blanc → vert au palier min → rouge à `00:00`), statut `Min` / `Prêt` / `Terminé`, `+30s`, `Passer`.
  - `HapticAndSoundManager.swift` — Retours haptiques pré-chauffés (`selection`, `light`, `setValidated`, `PRValidated`) et session `AVAudioSession` `.ambient` avec `[.mixWithOthers, .duckOthers]` pour baisser temporairement Spotify/Apple Music sans la couper.
  - `RestTimerAttributes.swift` — Définition `ActivityAttributes` partagée (cibles `PowerTrack` + `PowerTrackWidgetsExtension`), conforme `Sendable` avec propriété `timerRange`.
  - `RestTimerActivityManager.swift` — Gestionnaire `@MainActor` (`LiveActivityManager` aliasé) pour démarrer, prolonger (`+30s`) et clôturer proprement la Live Activity sans activité orpheline.
  - `RestTimerAppIntents.swift` — `AjouterTempsIntent` et `PasserReposIntent` (`LiveActivityIntent`) partagés entre les deux cibles et routés vers `TimerManager.shared`.
  - `PerformanceDashboardView.swift` — Onglet Performance avec sélecteur multi-blocs (`selectedBlocID`), Total SBD estimé + répartition proportionnelle, graphique `AreaMark`/`LineMark` d'évolution e1RM (calcul via `Serie.calculerE1RM()`), tonnage hebdomadaire empilé par catégorie (`Compétition`, `Variante`, `Accessoire`), et bandeau RPE moyen hebdomadaire.
  - `SeanceExportDTO.swift`, `SeanceExportSheet.swift` & `ExportSettingsView.swift` — Contrat JSON v2 (`SeanceExportDTO` avec cibles vs réel, durée réelle, `seanceId` idempotent, `RessentiSeanceDTO`), configuration webhook `n8n` + auth header, file d'attente hors-ligne, et copie/partage JSON local.

- **Cible `PowerTrackWidgetsExtension`** (`com.ethanruders.PowerTrack.PowerTrackWidgets`, `IPHONEOS_DEPLOYMENT_TARGET = 27.0`, `NSSupportsLiveActivities = YES`) :
  - `PowerTrackWidgetsBundle.swift` — Bundle `@main` enregistrant `RestTimerLiveActivityWidget`.
  - `PowerTrackWidgetsLiveActivity.swift` — UI Écran verrouillé (`RestTimerLiveActivityView`) & Dynamic Island (états expanded, compact, minimal) avec compte à rebours natif `Text(timerInterval: context.state.timerRange)` et boutons interactifs `AjouterTempsIntent` (`+30s`) / `PasserReposIntent` (`Passer`).

---

## 3. Architecture des Données & Règles Métier

### Hiérarchie SwiftData (`models.swift`)
```text
MacroBloc (nom, dateDebut, squat1RM, bench1RM, deadlift1RM)
 └── [cascade] Semaine (numero, nom)
      └── [cascade] Seance (date, titre?)
           └── [cascade] Exercice (nom, categorie: CategorieExercice, indications?, ordre)
                └── [cascade] Serie (repsCibles, rpeCible, chargeSaisie?, rpeSaisi?, estValidee)
```

### Règles métier implémentées
1. **Calcul e1RM (`Serie.calculerE1RM`) :**
   - Formule d'Epley ajustée au RPE : `repsALechec = reps + (10 - rpe)`, `e1RM = charge * (1 + repsALechec / 30)` arrondi au pas de **2,5 kg** (`round(x / 2.5) * 2.5`).
2. **Calcul des charges cibles (`calculerCharge`) :**
   - Table RPE 10 (`1 rep = 100%` jusqu'à `10 reps = 74%`), moins `2,5 %` par point de RPE sous 10 (plancher `40 %`), multiplié par le ratio de variante (`VarianteMouvement.ratioParDefaut` ou ratio personnalisé), arrondi à `2,5 kg`.
3. **Échauffement intelligent (`Exercice.typeEchauffement` & `genererPaliersEchauffement`) :**
   - **Cas C (`aucun`) :** Exercices d'isolation ou poids de corps / sans charge `> 20 kg`.
   - **Cas A (`sbdOuVariante`) :** Mouvements `.competition` ou mots-clés SBD/variantes → 5 paliers max (`20 kg × 10`, `50%`, `70%`, `85%`, `92.5%`, filtrés pour éviter les doublons/paliers `>= Top Set`).
   - **Cas B (`polyarticulaireAccessoire`) :** Accessoires polyarticulaires avec charge `> 20 kg` → 2 paliers (`50% × 8`, `75% × 5`).
4. **Matrice des temps de repos (`TimerManager.calculerDureesAlerte`) :**
   - `isolation` : `90s` fixe (ou `0..30s` si `RPE < 5`).
   - `polyarticulaire` : `180s` fixe.
   - `competition` : `RPE <= 6` → `180–240s` | `RPE <= 7` → `240–300s` | `RPE <= 8` → `300–360s` | `RPE <= 9` → `420–540s` | `RPE > 9` → `420–600s`.
5. **Ergonomie « In-Gym » dans `SeanceDetailView` :**
   - Tiroir d'édition dépliable par série (`+/- 2.5 kg`, `+/- 1 rep`, pilules RPE rapides `6` à `10` par pas de `0.5`).
   - À la validation d'une série : propagation automatique de `chargeSaisie` et `repsCibles` vers la série `N+1` si vide ; détection automatique de PR théorique sur le bloc ; haptique différenciée (PR/Top Set vs série standard) ; démarrage auto du chrono + Live Activity ; auto-scroll vers l'exercice suivant si toutes les séries de l'exercice sont validées.
   - **Adaptation des Back-offs (`BackoffAdaptationBannerView`) :** Si une série de compétition ou Top Set dépasse sa cible d'au moins `+1.0 RPE`, propose d'alléger les séries non validées restantes de `-5 kg` ou `-10 kg` en 1 tap.

---

## 4. CI/CD, Distribution iOS & Infrastructure Homelab

### Build & Déploiement iOS (Sans câble, sans Mac ouvert la nuit)
- **`.github/workflows/build-ipa.yml`** (sur runner `runs-on: xcode-27`) :
  - Déclenché sur `push` vers `main` (hors `README.md`, `.gitignore`) ou `workflow_dispatch`.
  - Compile en `Release` avec `CODE_SIGNING_ALLOWED=NO` et `CURRENT_PROJECT_VERSION="${{ github.run_number }}"`.
  - Génère `PowerTrack.ipa`, crée une GitHub Release (`build-<n>`) et déploie via `.github/scripts/generate_source.py` une source AltStore/SideStore (`source.json`, `icon.png`, `index.html`) sur **GitHub Pages**.
- **Sur l'iPhone :**
  - **SideStore + LocalDevVPN** (installé une fois via `iloader`).
  - Automatisation **Raccourcis iOS à 03:00** : active LocalDevVPN → attend → *Refresh All* dans SideStore → coupe LocalDevVPN (maintient SideStore et PowerTrack signés indéfiniment tous les 7 jours).
  - Pour récupérer une nouvelle version après un `git push` : ouvrir SideStore avec LocalDevVPN actif et appuyer sur **Update**.

### Serveur Homelab (Proxmox & Services Backend)
- Hôte Proxmox `pve` (`192.168.1.200`, accessible via WireGuard `ethanruders.duckdns.org`).
- VM `Serveur-Linux` (`10.0.0.74`) faisant tourner sous Docker : **`n8n`**, **`postgres-force`** (Postgres 15), **`nginx-proxy-manager`**, `gitea`, `grafana`, `prometheus`, `metabase`, `adguard-home`.
- Ce backend est destiné à recevoir les exports JSON de PowerTrack via un workflow **n8n** relié à **PostgreSQL / Metabase / Grafana**.

---

## 5. Dettes Techniques Connues & Pistes d'Amélioration

Ces points ont été observés directement dans le code actuel et constituent d'excellentes prochaines tâches :

1. **Export n8n consolidé (suite) :**
   - L'export JSON v2 par séance (URL `n8n` + auth configurables, ressentis, file d'attente hors-ligne, `seance.semaine?.nom`) et l'import de blocs JSON sont en place dans `SeanceExportDTO.swift`, `SeanceExportSheet.swift`, `ExportSettingsView.swift`, `ProgramJSONImporter.swift` et `ProgramImportSheet.swift`.
   - Reste optionnellement l'export consolidé d'une semaine/bloc complet d'un seul coup si besoin côté `n8n`.
2. **Désynchronisation Live Activity (`+30s` / `Passer`) ↔ `TimerManager` (résolu) :**
   - Résolu : `RestTimerAttributes.swift` et `RestTimerAppIntents.swift` (`LiveActivityIntent`) sont désormais partagés entre `PowerTrack` et `PowerTrackWidgetsExtension` via `PBXFileSystemSynchronizedBuildFileExceptionSet` (`WIDGET_EXTENSION`), et routés sur `TimerManager.shared` (notifications locales + ActivityKit + UI synchronisés).
3. **Multi-blocs dans `PerformanceDashboardView.swift` (résolu) :**
   - Résolu : filtre multi-blocs (`selectedBlocID: PersistentIdentifier?`, tri `@Query` par `dateDebut` décroissant) et déduplication du calcul e1RM via `Serie.calculerE1RM()`.
4. **Cohérence des Deployment Targets :**
   - `PowerTrack` cible iOS `26.5` alors que `PowerTrackWidgetsExtension` cible `27.0` dans `project.pbxproj`. À aligner si besoin.
5. **Tests automatisés :**
   - Aucune cible `XCTest` / `Swift Testing` n'existe encore dans le projet (utile pour tester `ProgramGenerator`, `ProgramJSONImporter`, `calculerE1RM`, `calculerCharge`, `genererPaliersEchauffement`, et `SeanceExportDTO`).
6. **Cockpit Web Coach sur `Serveur-Linux` (piste future, après prise en main quotidienne) :**
   - Éventuelle mini web app Docker (`FastAPI` + front sombre/orange façon PowerTrack derrière `nginx-proxy-manager`) affichant les métriques/alertes depuis `postgres-force` + chat coach relié à une API LLM et aux scripts du repo `powerlifting-coach-skill` (avec historique des messages en BDD et export JSON direct vers `ProgramImportSheet`).

---

## 6. Rappels pour la Prochaine Conversation

- Toujours garder l'app **100 % fonctionnelle hors-ligne** pendant les séances et préserver le style **Swiss Editorial / Flighty (`#09090B` + `#F5F5F7` + `#DE7A42`)** via `DesignSystem.swift`.
- Pour toute modification de `PowerTrack.xcodeproj` ou ajout de fichiers, vérifier la compatibilité avec le build CI sans signature (`CODE_SIGNING_ALLOWED=NO` sur `xcode-27`) et **ne pas ajouter de nouvelle App Extension** (quota de 3 App IDs déjà plein avec `PowerTrack` + `PowerTrackWidgets` + `SideStore`).
- Si un nouveau `.md` de documentation est modifié dans le repo, vérifier `paths-ignore` dans `.github/workflows/build-ipa.yml` pour éviter de déclencher des builds `.ipa` inutiles.
