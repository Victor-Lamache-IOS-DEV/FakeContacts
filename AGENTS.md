# FakeContacts — règles projet

## 1. Contexte
App iOS 26 imitant l'app Contacts d'Apple + trics cachés :
- **Trick 1** : rotation de profils faux (tél/mail/anniv) sur la fiche détail, séquence armable, avance après N s.
- **Trick 2** : recherche par chiffres → contacts forcés ; n° 10 chiffres `06…` contenant les chiffres tapés.
- **Peek** : bouton volume réaffiche le dernier contact ouvert dans le champ recherche (3 s).
- **My Card** : carte "mienne" fausse (nom/tél/mail/photo) éditable dans Settings.

Stack : SwiftUI + UIKit, dark mode, XcodeGen (`project.yml`), cible iOS 26.0, aucune dépendance externe.
Arbo : `FakeContacts/{App,Core,Trick,Peek,Design,Screens/{Contacts,Detail,Setup,Lists},Resources}`,
`FakeContactsTests/`, `legacy/` = ancien code **non compilé**, à garder en référence.
Entrées clés : `ContactsScreen` (liste), `ContactDetailScreen` (fiche), `TrickEngine` (état + UserDefaults),
`ContactSearch` (filtre), `ContactPresentation` (résolution faux/vrai), `AmbientBackground` + `ContactAvatar` (visuel).

## 2. Commandes
Aucun build local possible (Windows). **Seule validation = GitHub Actions.**
- Lancer : Actions → "Build & Sign FakeContacts" → Run workflow → branche `rebuild`.
- Le workflow fait : `xcodegen generate --spec project.yml` puis
  `xcodebuild -project FakeContacts.xcodeproj -scheme FakeContacts -sdk iphoneos -configuration Release -destination "generic/platform=iOS" -archivePath build/FakeContacts.xcarchive clean archive`
  puis `xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist -exportPath build/output`.
- **La CI ne lance pas les tests** (seulement archive). Les tests ne valident donc rien tant que le workflow n'est pas modifié.
- Déclencheur auto : push sur `main`/`master` uniquement — sur `rebuild`, il faut lancer à la main.

## 3. iOS / Xcode
- Bundle `com.victorlamache.contactdev`, team `A63WD37CXZ`, profil "Victor Lamache Dev Profile", signing manuel.
- Dispo par plateforme : `unifiedMeContactWithKeys` est **macOS uniquement**, ne compile pas sur iOS. Le Me card Apple n'est pas accessible → carte My Card manuelle.
- Ce SDK renvoie des **optionnels** : `AVAudioFormat(standardFormatWithSampleRate:channels:)`, `preparingThumbnail` → déballer (`guard` / `?`).
- `.glassEffect(.prominent)` n'existe pas ici → seul `.regular` compile.
- **`.glassEffect` en dark mode = disque opaque sombre** : inutilisable pour un cercle transparent.
- **`.shadow()` sur un ZStack** s'applique à chaque sous-vue → les ombres s'empilent et noircissent l'intérieur.

## 4. Git / GitHub
- Travailler dans un **worktree** de `rebuild` (`...\Temp\opencode\fc-rebuild`), pas le checkout détaché du dossier principal.
- Commit : 1 ligne courte + corps bref si utile ; **push après chaque lot**.
- `gh` n'est pas installé → le workflow se lance à la main dans l'interface GitHub.
- `legacy/` : on garde, on ne supprime pas, on ne le remet pas dans `FakeContacts/FakeContacts/` (sinon duplicatas de types).
- Ne jamais committer : secrets, certificats `.p12`, `DerivedData`, `.xcuserdata`.

## 5. Erreurs à ne plus refaire
- ❌ API macOS appelée sur iOS → ✅ vérifier la plateforme avant d'écrire la ligne.
- ❌ `.glassEffect` pour un cercle translucide → ✅ couches manuelles (fill blanc faible + reflet + liseré + inner shadow).
- ❌ `shadow()` sur un conteneur → ✅ ring interne : `strokeBorder` noir flouté + `clipShape`.
- ❌ Inventer un dégradé/couleur → ✅ reprendre les valeurs CSS exactes fournies.
- ❌ Réécrire un fichier entier pour 2 lignes → ✅ `edit` ciblé.
- ❌ Conclure "ça compile" sans CI → ✅ dire que seul le build CI le prouve.

## 6. Mise à jour
À la fin de chaque session, proposer d'ajouter ici (projet) et dans `~/.config/opencode/AGENTS.md` (général) les leçons apprises.
