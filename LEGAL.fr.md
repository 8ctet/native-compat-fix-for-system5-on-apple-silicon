# Mentions légales

🇬🇧 [English version](LEGAL.md)

## Avertissement et mention relative aux marques

**Projet indépendant.** native-compat-fix-for-system5-on-apple-silicon est un projet indépendant, gratuit et non commercial. Il n'est ni affilié à Avid Technology, Inc. ou à l'une de ses filiales, ni approuvé, parrainé ou soutenu par elles.

**Marques.** Avid, Pro Tools, EUCON, EuControl, Euphonix et System 5 sont des marques ou des marques déposées d'Avid Technology, Inc. ou de ses filiales aux États-Unis et/ou dans d'autres pays. Elles sont citées ici uniquement pour désigner les produits avec lesquels cet outil est conçu pour fonctionner. Toutes les autres marques appartiennent à leurs titulaires respectifs.

**Aucun logiciel Avid n'est distribué.** Ce dépôt ne contient aucun binaire, installeur, bibliothèque, documentation ou code source d'Avid. Le script ne fonctionne qu'à partir d'une copie de l'installeur EUCON Workstation que vous avez vous-même téléchargée depuis votre propre compte Avid, conformément aux conditions de licence d'Avid. Il vérifie l'empreinte SHA-256 de ce fichier et refuse toute autre version. Il conserve une sauvegarde du composant d'origine et fournit une commande pour le restaurer.

**Finalité.** Cet outil a pour seule finalité de permettre aux licenciés légitimes de rétablir l'interopérabilité entre leur propre console System 5 et les logiciels compatibles EUCON sur les Mac Apple Silicon. Il corrige pour cela, sur leur propre machine et dans leur propre copie, le comportement qui empêche cette interopérabilité. Il ne touche à aucun mécanisme de licence, d'activation, d'autorisation ou iLok, et ne doit pas être utilisé pour en contourner un.

**Votre responsabilité.** Il vous appartient de vérifier que la modification de votre propre copie est autorisée par la loi de votre pays et par les conditions de licence qui vous sont applicables. Dans l'Union européenne, les dispositions pertinentes comprennent les articles 5 et 6 de la directive 2009/24/CE (en France, l'article L.122-6-1 du Code de la propriété intellectuelle). Toute utilisation de cet outil au-delà de ce que la loi permet peut constituer une contrefaçon et exposer à des sanctions civiles ou pénales. La modification d'un composant Avid peut entraîner la perte du support d'Avid pour ce composant.

**Absence de garantie.** Ce logiciel est fourni « en l'état », sans garantie d'aucune sorte, expresse ou implicite. Vous l'utilisez à vos propres risques. Rien dans ce dépôt ne constitue un conseil juridique.

**Titulaires de droits.** Si vous détenez des droits sur un élément mentionné ici et avez une préoccupation, merci d'écrire à **contact@8ctet.fr** avant toute notification formelle. Toute demande de bonne foi sera examinée rapidement.

## Pourquoi cette correction existe

Ces faits sont exposés pour que la finalité de l'outil soit claire.

- Les informations de compatibilité EUCON actuelles d'Avid ne mentionnent plus la famille System 5, et Avid ne propose aucune mise à jour permettant à ces consoles de fonctionner avec les moteurs EUCON qui s'exécutent nativement sur Apple Silicon.
- Le moteur livré avec EUCON Workstation 2021.6 implémente toujours toutes les opérations distantes qu'utilise une System 5 : les 137 premières opérations de son interface de nœud conservent les mêmes noms et le même ordre que dans le moteur de 2016 qui fonctionne avec la console. Il rejette la console uniquement parce qu'un marqueur de version du protocole — une date — ne correspond plus.
- Une étape de validation des pairs, dans ce même moteur, écarte ensuite des changements de contrôle valides venant de la console, ce qui empêche Pro Tools de déplacer les faders motorisés.
- Chaque utilisateur applique la correction à sa propre copie, obtenue auprès d'Avid selon les conditions d'Avid. Rien d'Avid n'est redistribué, et rien de ce qui touche aux licences, à l'activation ou à la protection contre la copie n'est modifié.

## Vocabulaire

Les modifications sont décrites dans tout le projet comme un *correctif de compatibilité* : un *alignement de l'identifiant d'interface du protocole* et une *correction de la validation des pairs*. Elles ne sont pas, et ne doivent pas être présentées comme, un moyen d'obtenir un produit ou une fonction Avid pour lesquels vous n'avez pas de licence.
