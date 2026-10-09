# Nuages volumétriques : plan et état d'avancement

Document de référence du nouveau système de nuages. Il est mis à jour au fil des phases.
Base du pack : SEUS PTGI HRR 2.1 GFME, Iris 1.11.7, Minecraft 26.3, Voxy.

## État

| Phase | Contenu | État |
|---|---|---|
| 0 | Fondations : outils, textures de bruit, squelette Iris, menu, suppression des anciens nuages | ✅ testée en jeu |
| 1 | Forme, météo, raymarching, reconstruction temporelle, composition | ✅ testée en jeu (OK avec Voxy, perte de FPS faible) |
| 2 | Éclairage : phase, diffusion, ambiance, couleur du soleil à l'altitude, crépuscule, nuit + retours du test (formes moins rondes, bruit temporel) | ✅ livrée, à tester |
| 3 | Intégration : capture du ciel (GI, lumière ambiante du ciel, réflexions), ombres des nuages (terrain, GI, rayons de lumière) | ✅ livrée, à tester (sauf : nuages vus depuis sous l'eau) |
| 4 | Atmosphère Hillaire 2020 (tables précalculées), remplacement du ciel SEUS, option SEUS/Hillaire | ⏳ |
| 5 | Variété : couches moyennes et hautes (Ac, As, Ci, Cs, Cc), cumulonimbus et enclume, régimes météo, éclairs | ⏳ |
| 6 | Cache voxel + SDF, volume de lumière, intérieur des nuages simplifié, réglage des préréglages | ⏳ |
| 7 | Optionnel : table de diffusion multiple précalculée par path tracing, bibliothèque de nuages simulés | ⏳ |

Configuration de test de l'utilisateur : RTX 4080, 4K, Voxy, carte custom avec des montagnes d'environ 2000 blocs.
Référence : 50-60 FPS à l'arrêt, environ 45 en mouvement, sans nuages.

## Retours de test

- **Test 1 (phases 0-1)** : pas de bug, perte de FPS faible, Voxy OK, la pluie augmente la couverture.
  - Bruit visuel quand la caméra bouge : reconstruction temporelle. Atténué en phase 2 (écrêtage par variance,
    historique plus long). On peut encore le réduire : débruitage spatial, rendu complet (`CLOUD_RES` 1).
  - Formes trop arrondies : en phase 2, ajout de tourelles (sommet local variable), d'une déformation du bruit,
    d'un cisaillement du vent et d'une érosion plus forte. Réglables avec *Érosion* et *Irrégularité*.

### Points d'intégration dans le code du pack (phase 3)

| Fichier | Changement |
|---|---|
| `deferred.fsh`, `deferred2.fsh` | rayons de GI vers le ciel : capture ; lumière du soleil de la GI : × ombre des nuages |
| `deferred12.vsh` (via `GetSkylightData` de `Common.inc`) | harmoniques sphériques du ciel (lumière ambiante lointaine) : capture |
| `deferred12.fsh` | lumière du soleil sur le terrain : × ombre des nuages |
| `composite.fsh` | réflexions : ciel de la capture, disque solaire masqué par les nuages ; soleil réfléchi : × ombre |
| `composite4.fsh` | rayons de lumière : × ombre des nuages ; composition des nuages à l'écran |

- **Test 2 (phases 2-3)** : les ombres défilent bien sur le relief, FPS corrects. Deux bugs, corrigés :
  - **Reflets des nuages visibles seulement sur les bords de l'écran** : les réflexions en espace écran du pack
    reprennent le ciel de `deferred12`, qui n'a pas encore les nuages (ils sont composés dans `composite4`).
    Seuls les rayons sortant de l'écran utilisaient la capture avec nuages. Correctif : `CloudOverScreenSky` repose
    les nuages (historique de l'image précédente) sur le ciel lu à l'écran.
  - **Nuages qui restent visibles quelques secondes sur une surface passant devant la caméra** : la composition et la
    reconstruction temporelle testent maintenant, pixel par pixel, si la surface est plus proche que l'entrée de la
    couche de nuages. Dans ce cas, aucun nuage n'est possible, quel que soit l'historique.

## Architecture (phases 0-3)

Le pack rend la scène à **demi-résolution** dans le quart bas-gauche de l'écran (HRR), puis son TAA (`composite7`)
reconstruit la pleine résolution. Les buffers des nuages suivent cette grille « interne » : en 4K, l'interne fait 1920×1080.

```
begin.csh        carte régime 512²       couverture / convection / altitude de base / regroupement (très basse fréquence)
begin_a.csh      météo proche 2048²×2    cellules de nuages (3 tailles de grilles : 9 / 3,5 / 1,4 km)
begin_b.csh      météo lointaine 1024²×2 + couche stratiforme, distance au nuage le plus proche, sommet max local
begin_c.csh      carte d'ombre 512²     transmittance des nuages le long de la lumière, sur le plan du bas de la couche (64 m/texel)
begin_d.csh      capture du ciel 512²   ciel + nuages en carte octaédrique, ¼ des texels mis à jour par image, marche basse qualité
   ...           (passes du pack)
composite4_a.csh raymarching             ½×½ de l'interne, 1 pixel sur 4 par image en damier (CLOUD_RES 2)
composite4_b.csh reconstruction          historique pleine résolution interne (ping-pong cloudHistA / cloudHistB)
composite4.fsh   composition             couleurs du soleil et du ciel, perspective atmosphérique, avant les rayons de lumière et le TAA
```

### Fichiers

| Fichier | Rôle |
|---|---|
| `shaders/lib/clouds/CloudSettings.inc` | options du menu (incluses depuis `lib/Settings.inc`) |
| `shaders/lib/clouds/CloudCommon.inc` | préréglages, constantes d'échelle, géométrie planétaire, fonctions de phase, temps et vent |
| `shaders/lib/clouds/CloudWeather.inc` | génération et lecture des cartes météo |
| `shaders/lib/clouds/CloudMarch.inc` | densité, marche vers la lumière, raymarching, intégration |
| `shaders/lib/clouds/CloudView.inc` | grille interne, gigue du TAA, profondeur de la scène (Voxy / DH), reprojection |
| `shaders/lib/clouds/CloudUniforms.inc` | uniforms des compute shaders (qui n'incluent pas `Common.inc`) |
| `shaders/lib/clouds/CloudComposite.inc` | composition dans `composite4.fsh`, vues de debug |
| `shaders/lib/clouds/CloudShading.inc` | couleur des nuages à partir du raymarching (partagé par la composition et la capture du ciel) |
| `shaders/lib/clouds/CloudSky.inc`, `CloudLookups.inc` | capture du ciel et carte d'ombre : encodage et lectures pour les passes du pack |
| `shaders/lib/atmosphere/SkySEUS.inc` | fonctions de ciel SEUS, sorties de `Common.inc` pour être utilisables en compute (remplacées en phase 4) |
| `shaders/textures/clouds/*.dat` | bruits 3D tuilables (Perlin-Worley 128³, Worley 32³, curl 128²), générés par `tools/gen_cloud_noise.py` |

### Modèle de nuages

- **Unités** : 1 bloc = 1 m. Toute la géométrie est multipliée par `CLOUD_SCALE` et l'extinction divisée par `CLOUD_SCALE`.
  La profondeur optique, et donc le rendu, ne dépend pas de l'échelle. Le rayon de la planète suit aussi l'échelle,
  pour garder la même courbure perçue.
- **Placement** : chaque nuage est une cellule sur l'une des trois grilles décalées aléatoirement. Il a sa propre taille
  (loi de puissance : beaucoup de petits, peu de gros), son altitude de base, son épaisseur, son type (couche ↔ convectif)
  et sa densité. S'y ajoutent une composante stratiforme et des champs à grande échelle qui évoluent dans le temps
  (couverture, convection, altitude de condensation, regroupement).
- **Forme** : profil vertical par type (base plate, dôme ou tour), empreinte perturbée en 3D, bruit Perlin-Worley
  façon Nubis, puis érosion de détail (effilochée en bas, « chou-fleur » en haut) avec distorsion par curl.
  Les bords sont rendus nets par une rampe de densité raide, avec une extinction réelle d'environ 0,06/m.
- **Accélération** : la carte météo stocke une borne inférieure de la distance horizontale au nuage le plus proche,
  et le sommet maximal local. Le raymarching saute ainsi le vide horizontalement et au-dessus des nuages.
  Les pas sont grossiers dans le vide et fins dans les nuages, avec un retour en arrière à l'entrée.
- **Formes (phase 2)** : tourelles (sommet local de 0,6× à 1,15× l'épaisseur via un champ 2D), déformation du domaine
  du bruit de base, cisaillement du vent avec la hauteur, érosion de détail appliquée avant l'accentuation des bords.
- **Éclairage** :
  - fonction de phase « gouttelettes » : Henyey-Greenstein + Draine (Jendersie & d'Eon 2023), lobe avant élargi ;
  - diffusion d'ordres bas par octaves ;
  - **terme de diffusion** en exp(−τ·(1−g)), qui rend le côté éclairé lumineux ;
  - ciel selon la hauteur dans le nuage, et rebond du sol sous la base ;
  - intégration conservatrice d'énergie (Hillaire 2016) ;
  - (phase 2) couleur du soleil à l'altitude du nuage, avec moins d'atmosphère au-dessus et l'abaissement de l'horizon.
    Les nuages restent éclairés un peu après le coucher du soleil au sol. La nuit, éclairage par la lune.
- **Sortie** : quantités scalaires (lumière du soleil diffusée, lumière du ciel diffusée, transmittance, profondeur).
  Les couleurs du soleil et du ciel sont appliquées à la composition, avec les fonctions d'atmosphère SEUS
  en attendant la phase 4.

### Écarts connus (à traiter dans les phases suivantes)

- **Sous l'eau**, les nuages ne sont pas composés à l'écran (les réflexions et la GI les voient).
- Les réflexions des nuages viennent de la capture 512² : elles sont un peu floues sur une eau très calme.
- Les ombres des nuages couvrent environ ±16 km autour de la caméra (à l'échelle 1) et s'estompent quand le soleil est très bas.
- La perspective atmosphérique SEUS suppose une caméra au sol. Les rayons vers le bas utilisent la direction miroir (phase 4).
- Une seule couche basse/moyenne : pas encore de cirrus ni d'enclumes (phase 5).
- L'intérieur des nuages fonctionne, mais avec des pas grossiers près de la caméra (phase 6).

## Protocole de test en jeu

1. Charger le pack : il doit se charger sans erreur. En cas d'erreur, envoyer le log Iris (`logs/latest.log`).
2. **Référence FPS** : même position et même orientation de caméra, quelques secondes d'attente, relever les FPS (F3) avec
   *Nuages volumétriques* désactivés, puis activés en Basse / Moyenne / Haute / Ultra, et `CLOUD_RES` 1 contre 2.
3. Scènes (`/gamerule doDaylightCycle false` aide pour comparer) :
   - S1 `/time set 6000` `/weather clear` : au sol, regarder vers le haut et vers l'horizon ;
   - S2 `/time set 12300` : coucher de soleil, contre-jour ;
   - S3 `/weather rain` puis `/weather thunder` ;
   - S4 : voler au-dessus de la couche, puis à travers un nuage ;
   - S5 `/time set 18000` : nuit ;
   - S6 : les montagnes qui percent la couche (Voxy) — vérifier que les nuages passent bien **derrière** le relief lointain.
4. Vues de debug utiles pour les retours : *Nuages seuls*, *Coût* (rouge = coûteux), *Carte météo*.

Points d'attention particuliers pour la première version :
- **Voxy** : si des nuages s'affichent **devant** le relief lointain alors qu'ils devraient être derrière, c'est que les
  textures de profondeur de Voxy ne sont pas accessibles aux compute shaders. Il faudra alors déplacer la lecture de
  profondeur dans une passe fragment.
- **Traînées** derrière les bords du relief en mouvement : attendues en partie (reconstruction temporelle).

## Outils (`tools/`)

```bash
python3 tools/gen_cloud_noise.py                      # régénère les textures de bruit (déterministe)
python3 tools/compile_check.py                        # compile tous les programmes (glslangValidator)
python3 tools/compile_check.py -D VOXY -O CLOUD_RES=1 # avec Voxy et une option forcée
python3 tools/cloud_preview.py out.png --scene sunset # rendu hors-jeu des nuages (Mesa llvmpipe)
```

Dépendances : `glslang-tools`, `libegl1`, `libegl-mesa0` (apt) ; `numpy`, `pillow`, `moderngl` (pip).
Le rendu hors-jeu exécute les vrais programmes de nuages, mais avec un sol plat et une exposition simplifiée.
Il sert à vérifier formes et éclairage, pas les performances.

## Références

- Schneider 2015, *The Real-time Volumetric Cloudscapes of Horizon Zero Dawn* ; 2017 *Nubis* ; 2022 *Nubis Evolved* ; 2023 *Nubis³*
- Hillaire 2016, *Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite* ; 2020, *A Scalable and Production Ready Sky and Atmosphere Rendering Technique*
- Wrenninge et al. 2013, *Oz: The Great and Volumetric* (diffusion multiple par octaves)
- Jendersie & d'Eon 2023, *An Approximate Mie Scattering Function for Fog and Cloud Rendering*
- Bauer 2019, *Creating the Atmospheric World of Red Dead Redemption 2*
