# native-compat-fix-for-system5-on-apple-silicon

Un correctif de compatibilité qui permet d'utiliser une **console Avid / Euphonix de la famille System 5** avec **Pro Tools en natif sur les Mac Apple Silicon** — contrôle EUCON complet dans les deux sens, sans Rosetta.

> **Projet indépendant, gratuit et non commercial — non affilié à Avid Technology, Inc., ni approuvé ni soutenu par elle.**
> **Aucun logiciel Avid n'est distribué ici.** Vous téléchargez l'installeur d'Avid depuis votre propre compte Avid ; le script corrige votre propre copie, sur votre propre Mac. Lisez [LEGAL.fr.md](LEGAL.fr.md) avant utilisation.

🇬🇧 [English version](README.md)

---

## Le problème

Sur un Mac récent, une System 5 voit bien le Mac dans sa liste de workstations EUCON, mais **le Link n'aboutit jamais** (le bouton clignote sans fin) et Pro Tools signale des erreurs EUCON.

La cause est le moteur EUCON — le fichier `/usr/local/lib/libEuCon2.dylib` que charge Pro Tools. Les versions récentes d'EUCON installent un moteur qui n'accepte plus les messages envoyés par une System 5. Le dernier moteur qui fonctionne sans modification (2017) ne contient que du code Intel : Pro Tools doit alors tourner sous Rosetta.

## Ce que fait ce correctif

Il part du moteur fourni dans l'installeur **EUCON Workstation 2021.6** d'Avid — la première version contenant du code Apple Silicon — et corrige **deux comportements** qui l'empêchent de fonctionner avec une System 5 :

1. un contrôle de version du protocole qui rejette les messages de la console (alignement de l'identifiant d'interface) ;
2. une étape de validation des pairs qui écarte à tort les changements de contrôle de la console — sans cette correction, Pro Tools ne peut pas déplacer les faders motorisés.

Fonctionnement détaillé : [docs/TECHNICAL.md](docs/TECHNICAL.md). Comment ça a été trouvé : [docs/HISTORY.md](docs/HISTORY.md) (en anglais).

## Configuration testée

| | |
|---|---|
| Console | Avid / Euphonix System 5 (S5 Fusion), contrôleur SC264D, eMix 6.1.0 |
| Mac | Mac Studio M4 Max (Apple Silicon), macOS 15.7 Sequoia |
| Pro Tools | 25.6.1, **en natif** |
| Front-end EUCON | MC_Client 2025.6 (fourni par l'installation EUCON Workstation actuelle) |
| Résultat | la console se lie, la liste des pistes Pro Tools s'affiche, les pistes s'assignent aux faders, **les faders fonctionnent dans les deux sens** (moteurs compris), mute / solo / noms de pistes suivent |

**Pas encore testé :** autres variantes System 5 (S5-MC, MC Pro, Hybrid), autres versions d'eMix, autres versions de Pro Tools, Mac Intel. Les retours sont les bienvenus — voir *Contribuer*.

## Avant de commencer

- **Cela remplace le moteur EUCON utilisé par Pro Tools sur ce Mac.** Tant qu'il est installé, les **surfaces EUCON actuelles** (S1, S3, S4, S6, série Artist, Dock, appli Control) **ne fonctionneront pas** avec Pro Tools sur ce Mac. `restore` annule la modification.
- **Les mises à jour Avid peuvent le remplacer** (EUCON, Pro Tools, Avid Link). Lancez `status` après chaque mise à jour et relancez `install` si nécessaire.
- C'est **non officiel et non supporté**. L'outil sauvegarde votre moteur actuel avant d'installer, et `restore` le remet en place.

## Ce qu'il vous faut

1. Un Mac avec **Pro Tools**. L'outil vérifie que votre version de Pro Tools peut charger un moteur re-signé (Pro Tools 25.6.1 le peut).
2. **EUCON Workstation dans sa version actuelle**, installé depuis votre compte Avid (il fournit **MC_Client**, indispensable à la console).
3. L'installeur **EUCON Workstation 2021.6** pour macOS, téléchargé **depuis votre propre compte Avid** — fichier `EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg` (le portail de téléchargement d'Avid le propose avec les autres versions EUCON / EuControl). **Ne l'installez pas** — l'outil se contente d'en extraire le moteur.

Ni Xcode, ni Homebrew, ni Python : le script n'utilise que des outils fournis avec macOS.

## Installation

1. Téléchargez la dernière [release](../../releases) et décompressez-la.
2. Quittez Pro Tools.
3. Ouvrez le **Terminal**, allez dans le dossier décompressé et vérifiez votre Mac :
   ```bash
   cd ~/Downloads/native-compat-fix-for-system5-on-apple-silicon-1.0.0
   bash patcher.sh status
   ```
4. Installez — une confirmation vous sera demandée, puis le mot de passe de votre Mac :
   ```bash
   bash patcher.sh install ~/Downloads/EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg
   ```
5. Dans le Finder › Applications, sélectionnez **Pro Tools** › *Lire les informations*, et vérifiez que **« Ouvrir avec Rosetta » est décoché**.
6. Lancez Pro Tools, activez EUCON, puis appuyez sur **Link** sur la console.

## Revenir en arrière

```bash
bash patcher.sh restore
```
Remet en place le moteur qui était installé auparavant. Réinstaller EUCON Workstation (version actuelle) depuis Avid restaure aussi le moteur d'origine.

## Vérifier sans installer

```bash
bash patcher.sh build ~/Downloads/EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg ~/Desktop/libEuCon2.dylib.patched
```
Produit le moteur corrigé sans rien modifier sur votre système.

## Sécurité

- L'image de l'installeur et le moteur qu'elle contient sont **vérifiés par SHA-256** ; toute autre version est refusée.
- Après correction, le résultat est comparé à une **empreinte SHA-256 de référence** avant signature ; la signature est ensuite vérifiée.
- Votre moteur actuel est **sauvegardé** dans `/Library/Application Support/native-compat-fix-for-system5-on-apple-silicon/backups/` avant tout remplacement.
- Chaque octet écrit est listé dans [`patch/`](patch/) (position et nouvelle valeur) ; [`tools/make_manifest.py`](tools/make_manifest.py) montre comment cette liste a été produite.
- Le script fait environ 300 lignes de Bash. Lisez-le avant de l'exécuter avec des droits administrateur.

## Dépannage

- **« this is not the EUCON 2021.6.1.7 engine »** — ce n'est pas le bon installeur. Il faut exactement *EUCON Workstation 2021.6* (`…2021_6_1_7.dmg`).
- **« Pro Tools … does not accept a re-signed engine »** — votre version de Pro Tools ne peut pas charger un moteur re-signé ; ce correctif ne peut pas fonctionner avec elle.
- **La console clignote toujours après l'installation** — vérifiez que Pro Tools n'est *pas* en *Ouvrir avec Rosetta* et qu'il est l'application au premier plan, puis lancez `bash patcher.sh status`.
- **Un module de la console ne répond plus** — redémarrez les modules de la console, l'ordinateur de la console et le Mac. (Pendant les essais, la détection tactile d'un module s'est arrêtée après de nombreuses reconnexions ; le moteur Avid non modifié faisait de même, et un redémarrage complet a réglé le problème.)

## Contribuer

Les retours sur d'autres consoles, versions d'eMix, versions de Pro Tools et Mac Intel sont les bienvenus. Ouvrez une *issue* avec : modèle de console et version d'eMix, modèle de Mac, version de macOS, version de Pro Tools, et la sortie de `bash patcher.sh status`.
**N'y joignez jamais de fichiers Avid, d'installeurs, de rapports de plantage ou de captures réseau** — ils peuvent contenir du code Avid ou vos identifiants personnels.

## Mentions légales

Voir **[LEGAL.fr.md](LEGAL.fr.md)** — avertissement, finalité, votre responsabilité et contact pour les titulaires de droits.

*Avid, Pro Tools, EUCON, EuControl, Euphonix et System 5 sont des marques ou des marques déposées d'Avid Technology, Inc. ou de ses filiales, citées uniquement pour désigner les produits avec lesquels cet outil fonctionne.*

## Crédits

Recherche, essais et correction : **8ctet**, avec Claude (Anthropic) comme assistant IA.

## Licence de ce dépôt

MIT — voir [LICENSE](LICENSE). Elle couvre uniquement les fichiers de ce dépôt.
