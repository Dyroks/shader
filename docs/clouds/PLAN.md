# Nuages volumétriques : plan et état d'avancement

Document de référence du nouveau système de nuages. Il est mis à jour au fil des phases.
Base du pack : SEUS PTGI HRR 2.1 GFME, Iris 1.11.7, Minecraft 26.3, Voxy.

## État

| Phase | Contenu | État |
|---|---|---|
| 0 | Fondations : outils, textures de bruit, squelette Iris, menu, suppression des anciens nuages | ✅ testée en jeu |
| 1 | Forme, météo, raymarching, reconstruction temporelle, composition | ✅ testée en jeu (OK avec Voxy, perte de FPS faible) |
| 2 | Éclairage : phase, diffusion, ambiance, couleur du soleil à l'altitude, crépuscule, nuit + retours du test (formes moins rondes, bruit temporel) | ✅ testée en jeu |
| 3 | Intégration : capture du ciel (GI, lumière ambiante du ciel, réflexions), ombres des nuages (terrain, GI, rayons de lumière) | ✅ testée en jeu (sauf : nuages vus depuis sous l'eau) |
| 4 | Atmosphère Hillaire 2020 (tables précalculées), remplacement du ciel SEUS, option SEUS/Hillaire | ✅ testée en jeu (« beaucoup mieux que SEUS ») |
| 5 | Variété : couches moyennes et hautes (Ac, As, Ci, Cs, Cc), cumulonimbus et enclume, régimes météo, éclairs | ✅ testée en jeu (« très bon », pas de problème) |
| 6 | Accélération (révisée après mesures : saut hiérarchique des zones vides), intérieur et nuages proches | ✅ testée en jeu (meilleures performances, intérieur des nuages bon) |
| 7 | Forme et éclairage des cumulus (retour : trop ronds, adoucis, blancs partout) : forme en chou-fleur, surface trouvée précisément, éclairage calibré sur une référence par path tracing, 2 bugs anciens corrigés | ✅ testée en jeu (« beaucoup mieux », assombrissement brusque sous la couche moyenne corrigé ensuite) |
| 8 | Rayons crépusculaires : nouvelle carte d'ombre des nuages en espace lumière (2 cascades, ±80 km), ombre des nuages dans l'air intégrée avec l'atmosphère physique ; 8b : brume des vallées (milieu participant éclairé et ombré par les nuages) | 🧪 8 testée (rayons trop rares et trop faibles) → 8b testée (perte de FPS) → 8c testée (FPS en partie récupérés, bruit) → 8d à tester en jeu |
| 9 | Audit performance, lot 1 : travail inutile supprimé sans changer l'image, bugs corrigés (voir la section Phase 9) | ✅ testé en jeu (+6 à 7 FPS, aucun bug, rendu stable) ; options de comparaison retirées, code définitif |
| 10 | Audit, lot 2 : remplacements (faisceaux proches dans l'air, cache de GI, bloom, exposition), ombres lointaines et occlusion (voir la section Phase 10) | 🧪 à tester en jeu, chaque partie comparable (écran *Comparaison du lot 2*) |

La bibliothèque de nuages simulés (prévue en phase 7) est écartée : formes figées et répétitives (décision de l'utilisateur).

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
    les nuages sur le ciel lu à l'écran, en lisant l'historique de l'image précédente à la position *reprojetée* de la
    direction (sinon les nuages reflétés traînaient derrière les rotations de caméra, retour du test 3). Hors écran :
    capture du ciel.
  - **Nuages qui restent visibles quelques secondes sur une surface passant devant la caméra** : la composition et la
    reconstruction temporelle testent maintenant, pixel par pixel, si la surface est plus proche que l'entrée de la
    couche de nuages. Dans ce cas, aucun nuage n'est possible, quel que soit l'historique.

- **Test 3** : le fantôme sur les surfaces proches est corrigé. Les reflets au centre de l'écran fonctionnent à
  l'arrêt mais traînaient pendant les rotations : corrigé par la reprojection (à confirmer).

## Phase 10 : audit performance, lot 2

Remplacements à risque moyen et ajouts visuels pour le relief lointain. Comme au lot 1, chaque partie a une option
temporaire `AB_*` (écran *Comparaison du lot 2*), activée par défaut.

| Partie | Option | Contenu | État |
|---|---|---|---|
| 2-A | `AB_AIR_SHAFTS` | R1 : faisceaux proches calculés avec la lumière de l'air | à tester |
| 2-B | `AB_GI_CACHE` | R2 : cache de lumière de la GI retracé par moitié | à tester |
| 2-C | `AB_BLOOM` | R3 : bloom progressif ; R4 écarté | à tester |
| 2-D | `AB_FAR_SHADING` | S7, V6, V7 : ombres et occlusion du relief lointain | à tester |
| 2-E | `AB_GI_FIREFLY` | Anti-lucioles de la GI (retour du test : points lumineux qui clignotent en intérieur) | à tester |

**2-A, faisceaux proches dans l'air** (`AirTerrainShadow.inc`, `Crepuscular.inc`, `composite4_c.csh`) :
- Les anciens godrays (`composite4.fsh`) faisaient 32 pas sur 100 blocs pour chaque pixel interne, ciel compris,
  avec 2 à 3 lectures par pas, et s'ajoutaient par-dessus la brume et la perspective aérienne. Ils ne restent que
  sous l'eau, ou sans atmosphère physique ni nuages volumétriques.
- L'intégration de l'air (`composite4_c`, un pixel sur quatre) commence maintenant par un segment proche de 8 pas
  (répartition quadratique) jusqu'à `shadowDistance`. Dans ce segment, la carte d'ombre du soleil (vitraux
  compris) ombre l'air et la brume des vallées : les vallées à l'ombre d'une crête restent sombres. Une brume
  proche fine (`airMistSigma` × *Intensité des faisceaux proches*, sans extinction, phase HG 0,6 + isotrope,
  estompée vers la fin de la carte d'ombre) diffuse la lumière du soleil. L'air réel est trop clair pour des
  faisceaux visibles sur 100 blocs : la brume représente la poussière et l'humidité locales.
- Calibrage hors jeu (sol plat, entièrement éclairé) : +5 % de lumière à midi, +14 % au coucher du soleil, jusqu'à
  +50 % près du soleil. Les faisceaux naissent du contraste avec les zones à l'ombre du terrain.
- Le segment lointain démarre après le segment proche : le terrain proche (moins de 240 blocs) n'a plus que les
  8 pas proches au lieu de 12 à 24.

**2-B, cache de lumière de la GI** (`deferred2.fsh`, gain estimé 0,5 à 1 ms) : chaque pixel de `colortex5` porte une
cellule du cache (202³ en 4K) en plus des données temporelles du pixel, d'où une taille liée à la résolution.
Réduire la taille (±80 blocs au lieu de ±101) raccourcirait le second rebond alors que le volume de GI fait ±167
blocs : écarté. Une moitié des cellules est retracée par image, par bandes de 8 lignes (warps entiers actifs ou
inactifs), avec un poids double (0,05 au lieu de 0,025 : même temps de réponse) ; l'autre moitié suit seulement
la caméra (copie décalée).

**2-C, bloom progressif** (`composite14_a` à `composite14_i`, `BloomUpsample.glsl`, gain estimé 0,4 à 0,8 ms) :
la passe finale lisait 9 niveaux × 8 échantillons par pixel 4K. Neuf petits dispatchs remontent les niveaux du plus
grossier au plus fin dans `bloomAccum` (même disposition que l'atlas de `colortex7`) : niveau k = poids k × niveau k
flouté + niveau k+1 suréchantillonné avec la même tente. `composite14` ne lit plus que le niveau 1 (8 échantillons).
Simulation numpy contre l'original : écart moyen 1,7 %, maximum 2,7 % (un peu plus doux).
R4 (exposition logarithmique) écarté : la chaîne de mipmaps de `colortex3` ne coûte qu'environ 0,1 ms, et une
moyenne logarithmique changerait la luminosité de toutes les scènes contrastées.

**2-D, ombrage du relief lointain** (`deferred12_a.csh`, `FarShading.inc`, `deferred12.fsh`, coût estimé 0,3 à
0,6 ms) : la carte d'ombre couvre `shadowDistance` et ne contient pas le terrain Voxy, et au-delà du volume de
voxels la GI devient une ambiance plate. Une passe compute au quart de la résolution interne (un pixel par bloc
2×2, différent à chaque image, comme `composite4_c`) écrit `farShade` ; `deferred12` le suréchantillonne avec des
poids selon la distance.
- V7 : marche vers le soleil dans la profondeur de l'écran (24 pas géométriques jusqu'à 4000 blocs, épaisseur
  supposée des obstacles : distance parcourue + 32 blocs). Les pixels proches (moins de 0,75 × `far`) ne comptent
  que le terrain LOD comme obstacle : la carte d'ombre gère le reste. Limite : l'obstacle doit être à l'écran.
- V6 : occlusion ambiante (8 échantillons dans l'hémisphère, rayon 4 % de la distance, 8 à 64 blocs, force 0,8)
  sur la lumière du ciel qui remplace la GI au-delà du volume.
- S7 : `CalculateSunlightVisibility` rend « éclairé » hors de la carte d'ombre au lieu de lire son bord (PCSS de
  85 lectures sauté).
À vérifier en jeu : ombres des sommets sur les vallées lointaines au coucher du soleil, bruit ou faux ombrages
(précision de la profondeur Voxy au loin), force de l'occlusion.

**Retour du test du lot 2** : environ +5 FPS en extérieur, sans dégradation visible. En intérieur, des points
lumineux apparaissent et disparaissent sur les murs (lumière d'une fenêtre, torches). Cause probable : des
« lucioles », rayons de GI qui touchent rarement une petite zone très lumineuse, étalées par le débruiteur. Le cache
retracé par moitié (2-B, poids double : mise à jour environ 1,4 fois plus bruitée) peut les aggraver.

**2-E, anti-lucioles** (`deferred2.fsh`) : un nouvel échantillon, pour le pixel (accumulation temporelle, si
l'historique est valide) comme pour le cache, ne peut pas dépasser `GI_FIREFLY_LIMIT` (6 par défaut) fois la
luminance accumulée + 0,01. Seules les valeurs aberrantes sont biaisées ; une lumière qui apparaît met un peu plus
longtemps à atteindre sa valeur (environ 1 s).

## Phase 9 : audit performance, lot 1

Audit complet : document « SEUS PTGI HRR — Audit performance et rendu » (Claude Docs,
https://claude.ai/code/artifact/0f399351-52ed-4efa-8bd8-885217d65d0b). Le test de l'utilisateur confirme que la
carte graphique limite. Lot 1 : supprimer le travail dont le résultat est jeté, sans changer l'image (sauf bugs).
Chaque partie a une option temporaire `AB_*` (écran *Comparaison du lot 1*), activée par défaut, pour comparer en jeu ;
ces options et l'ancien code seront retirés une fois validés.

| Partie | Option | Contenu | État |
|---|---|---|---|
| 1-A | `AB_GI_VOLUME` | O1, O2, O7, O11, V2 : GI et reflets limités au volume de voxels | ✅ définitif |
| 1-B | `AB_SUN_SHADOW` | O3, O4, V3 : ombres du soleil | ✅ définitif |
| 1-C | `AB_SURFACES` | O5, O6, S3, V4, V9 : surfaces du terrain et de l'eau | ✅ définitif |
| 1-D | `AB_LOD_DISTANCE` | V1 : perspective aérienne du terrain Voxy à sa vraie distance | ✅ définitif |
| 1-E | `AB_POST`, `FINAL_FXAA` | O9, S2, flou de mouvement à l'arrêt ; O8 abandonné | ✅ définitif |
| 1-F | `AB_CLOUD_WEATHER`, `AB_GI_LOOP` | O12 : cartes météo par quarts ; O10 : boucle de GI à deux niveaux | ✅ définitif |

**Résultat du test** : +6 à 7 FPS, aucun bug, rendu stable. Les options `AB_*` de la table (temporaires) et le code
d'origine sont retirés. Les coupures entre tronçons sur l'eau Voxy restent : elles apparaissent aussi sans shaders,
donc elles viennent de Voxy (V9 corrigeait un vrai défaut, mais pas celui-là).

**1-A, GI dans le volume de voxels** (gain estimé 1,5 à 4 ms dans un panorama Voxy) :
- O1 (`deferred.fsh`) : au-delà de `RAY_TRACING_RADIUS` (±167 blocs), `deferred12` remplace la GI par l'ambiance
  du ciel (harmoniques sphériques × lumière du ciel + torches). `deferred` écrit directement cette ambiance au lieu de
  tracer un rayon depuis le bord du volume ; `deferred.vsh` calcule les harmoniques comme `deferred12.vsh`. Le
  débruiteur mélange donc la bande de transition vers la même valeur qu'avant le remplacement : image identique.
- O2 (`deferred.fsh`, `deferred2.fsh`, `composite.fsh`) : un rayon qui sort du volume s'arrête et compte comme
  échappé vers le ciel. Avant, les coordonnées étaient ramenées sur le bord : le rayon relisait les voxels du bord
  jusqu'au 120e pas et pouvait y trouver un faux obstacle.
- O7 (`composite.fsh`) : pas de tracé des reflets dans les voxels pour une surface hors du volume (eau lointaine,
  eau Voxy) : seul le ciel est reflété, le tracé en espace écran reste. Avant, le départ était ramené sur le bord.
- O11 (`PathTraceDenoiser.glsl`, `deferred11.fsh`) : pas de filtrage du ciel ni des pixels hors du volume
  (`deferred11` calcule toujours les caustiques).
- V2 (`PathTraceDenoiser.glsl`) : le centre des pixels Voxy était reconstruit avec la projection vanilla.

À vérifier en jeu : FPS dans la vue de référence ; transition GI / ambiance vers 160-170 blocs ; GI des vallées
profondes près du bord vertical du volume (les rayons qui sortent voient maintenant le ciel).

**1-B, ombres du soleil** (`deferred12.fsh`, gain estimé 0,5 à 2 ms) :
- O3 : même produit, facteurs bon marché d'abord (fuite de lumière en grotte, ombre des nuages, face tournée à
  l'opposé de la lumière sauf feuillage). L'ombre par rayon, l'ombre en espace écran puis les ombres douces (PCSS,
  9 + 75 lectures) ne sont calculées que si le produit n'est pas déjà nul. Image identique.
- O4 : les 25 lectures de couleur des vitraux sont faites dans une seconde boucle, seulement si un échantillon est
  derrière un vitrail. Sans vitrail, `mix()` rendait le résultat inchangé : image identique. (Version exacte : les 25
  tests de profondeur des vitraux restent ; un test préalable de quelques lectures aurait pu manquer un vitrail fin.)
- V3 : `RayTracedShadow` écrasait le décalage de texture (`=` au lieu de `+=`) : seule la face Z lisait le bon texel
  pour décider si un bloc ajouré (feuillage, vitre…) arrête le rayon. Changement visible possible sur ces blocs.

**1-C, surfaces du terrain et de l'eau** (gain estimé 0,3 à 1,5 ms quand beaucoup d'eau est visible ; O5 ne sert
qu'avec Parallaxe activée et un pack de textures avec relief) :
- O5 (`gbuffers_terrain.fsh.glsl`) : la parallaxe écrit `gl_FragDepth`, ce qui coupait l'élimination anticipée des
  pixels cachés. Déclaré `depth_greater` (GL_ARB_conservative_depth) : la parallaxe ne fait qu'éloigner la surface.
  Sans relief, la profondeur d'origine est réécrite telle quelle. Pas de garde `#ifdef GL_ARB_conservative_depth` :
  le préprocesseur d'Iris l'évaluerait comme indéfinie. `compile_check.py` valide ce fichier en GLSL 4.20.
- O6 (`gbuffers_water.fsh.glsl`) : vagues calculées seulement pour l'eau et les autres translucides qui les
  utilisent (pas le verre teinté, le slime, ni sous l'océan de Physics Mod, qui les jetaient).
- S3 : relief des vagues (jusqu'à 60 pas × 6 lectures) estompé puis supprimé là où les vagues sont presque plates :
  décalage × `smoothstep(0.15, 0.3, atténuation des vagues)`, sans coupure. Vanilla : l'atténuation est calculée une
  fois (le `fwidth` dans la boucle était indéfini). Changement visible minime : motif des vagues lointaines décalé.
- V9 (`voxy_water.frag`) : la direction de vue du relief des vagues n'était pas normalisée (position de vue : pas de
  plusieurs dizaines de blocs). Cause probable des coupures entre tronçons sur l'eau Voxy, à confirmer.
- V4 (`voxy_water.frag`) : `matID == 7.0` testé après `+= 0.1` : le verre lointain recevait des vagues.
  Les vagues ne sont plus calculées que pour l'eau Voxy.

Les programmes Voxy ne passent pas par `compile_check.py` : vérifiés avec un en-tête qui simule celui de Voxy
(uniformes de `voxy.json`, structure `VoxyFragmentParameters`).

**1-D, distance du terrain Voxy** (`composite4.fsh`, coût nul) :
- V1 : pour le terrain Voxy solide, la profondeur vanilla vaut 1 : `LandAtmosphericScattering` recevait la distance
  du plan lointain vanilla, donc le même voile pour toutes les montagnes. La position vient maintenant de la
  profondeur Voxy, comme dans `CloudSurfaceDistance`. Changement visible voulu : les montagnes lointaines prennent
  un voile qui grandit avec la distance (*Brume sur le relief lointain* pour le doser). Le brouillard sous l'eau
  utilise aussi la vraie distance.

**1-E, post-traitement** (gain estimé 0,3 à 0,5 ms) :
- S2 : FXAA final désactivé par défaut (`FINAL_FXAA` 0) et `composite15` sauté quand il est désactivé : il ne
  faisait plus qu'une copie 4K. La reconstruction temporelle lisse déjà les bords.
- O9 : `colortex6` (historique de la reconstruction temporelle en 4K, couleur encodée gamma, exposition < 400)
  passe de RGBA32F à RGBA16F : moitié moins de trafic mémoire en lecture et en écriture.
- Flou de mouvement : les deux passes (`composite10`, `composite11`) ne lisent qu'un échantillon quand la caméra est
  immobile (décalage total < 0,01 pixel). La fusion des deux passes est écartée : leur noyau combiné est une boîte
  exacte de 25 échantillons ; une passe unique devrait les lire tous, pour un coût équivalent.
- **O8 abandonné (erreur de l'audit)** : les « copies » des passes plein écran (`deferred`, `composite`,
  `composite1`…) ne sont pas inutiles. Iris alterne deux textures par tampon écrit ; une passe qui ne dessine
  qu'un quadrant laisse dans les autres le contenu de l'autre texture, vieux de deux écritures. Les copies gardent les
  deux textures identiques (exemple : `composite1` recopie le gbuffer complété par l'eau et Voxy, que `composite4`
  relit). `deferred99` fusionne les translucides Voxy dans le gbuffer : nécessaire aussi.

**1-F, cartes météo et boucle de GI** :
- O12 (`begin_a.csh`, `begin_b.csh`, gain estimé ~0,5 ms) : une rangée de groupes de travail sur quatre par image.
  La carte est ancrée sur le texel de la caméra : elle est recalculée entièrement à l'image où ce texel change
  (tous les 48 ou 400 blocs) et aux 4 premières images. Un texel en retard représente donc toujours le bon endroit,
  avec 1 à 3 images de retard sur le vent (une petite fraction de texel). Après un rechargement des shaders ou un
  saut de temps, la carte se complète en 4 images.
- O10 (`deferred.fsh`, gain incertain, à mesurer) : boucle à deux niveaux (Aila et Laine 2009). Une boucle courte
  parcourt les voxels vides ; le test de forme des blocs et les lectures de texture se font en dehors, une fois par
  voxel non vide. Mêmes pas et même résultat ; les fils d'un warp n'attendent plus à chaque pas le test de forme
  d'un voisin. Le nombre de registres ne change pas (il est fixé pour tout le shader) : le gain dépend du GPU.

## Phase 8 : rayons crépusculaires

**Objectif** : rayons « réalistes et spectaculaires » : faisceaux entre les nuages (échelles de Jacob), rayons en
éventail au coucher du soleil, rayons anticrépusculaires, ombres des nuages dans la brume vue d'un sommet ou d'avion.

**Principe physique** : le ciel (table de vue du ciel) et la perspective atmosphérique supposent un air éclairé partout.
L'air à l'ombre d'un nuage ne diffuse pas la lumière directe du soleil : on intègre, le long du rayon de vue, la
diffusion simple (Rayleigh + Mie, vraies fonctions de phase, transmittance vers le soleil) de l'air à l'ombre, et on
la retire de la scène. Les rayons apparaissent par contraste, sans aucun effet en espace écran : ils existent hors
champ du soleil, derrière la caméra (anticrépusculaires), et autour des nuages qui cachent le soleil.

| Élément | Implémentation |
|---|---|
| **Carte d'ombre** (`begin_h`, remplace l'ancienne) | « Beer shadow map » en espace lumière (technique d'Unreal Engine) : texels sur le plan normal à la lumière passant par la caméra, 2 cascades dans une image 768×512 rgba16f (proche 256² sur ±8 km, texels 62,5 m — 512² sur ±16 km avant l'optimisation 8c ; lointaine 512² sur ±80 km, texels 312 m, rafraîchie une ligne sur deux par image). Chaque texel stocke l'entrée des nuages côté lumière, la sortie, leur profondeur optique, et celle des cirrus. Profondeur optique devant un point = linéaire entre l'entrée et la sortie. Marche de 150 km le long de la lumière avec des pas qui grandissent avec la distance (soleil rasant : les nuages lointains projettent les rayons du soir). Corrige aussi l'ancienne carte : ombres justes à toute altitude (sommets dans la couche de nuages), ombres portées jusqu'à l'horizon et jusqu'au coucher du soleil (l'ancienne s'éteignait sous 1,7°). |
| **Intégration** (`lib/atmosphere/Crepuscular.inc`, `composite4`) | 24 pas (option) répartis quadratiquement jusqu'à 100 km (option) ou jusqu'au sommet de la couche de nuages, gigue stratifiée filtrée par le TAA. Lumière retirée devant les nuages, et derrière eux × leur transmittance. La lumière diffusée à travers les nuages fins éclaire encore l'air dessous (isotrope). La nuit : lune. Soustraction bornée sans changer la teinte. |
| **Intensité** (`CREPUSCULAR_STRENGTH`, 150 %) | 100 % = physique (dépend de la brume, *Brume*). Au-delà, les faisceaux d'ombre sont plus sombres, mais jamais plus que de l'air sans lumière directe (pas de trous noirs). |
| **Rayons du pack** | Les rayons proches (ombres du relief, carte d'ombre du pack) sont conservés, mais ajoutés après les nuages (avant, ils étaient atténués par les nuages situés derrière eux) ; leur lecture de l'ombre des nuages passe à une lecture unique par pas. |
| **Brume des vallées** (8b, `HAZE_*`) | Voir plus bas. |
| **Coût** (hors jeu) | Intégration ≈ +13 % du temps de la marche des nuages à résolution égale ; en jeu elle tourne à pleine résolution interne (×4 pixels par rapport à la marche en damier) : ordre de grandeur, la moitié du coût des nuages. Carte d'ombre ≈ 2 × l'ancienne. À mesurer en jeu ; *Qualité des rayons* 16 pour économiser. |

### Phase 8b : brume des vallées (retour du test de la phase 8)

**Retour** : rayons visibles trop rarement et trop faibles, même en *Brume* « Brumeux » et 300 % (vue d'un sommet vers
une vallée, soleil derrière des cumulus). Photo de référence : grands faisceaux en éventail au-dessus de vallées brumeuses.

**Diagnostic** (scène reproduite hors jeu, mesures en linéaire) : l'ombrage de l'air était déjà volumétrique ; c'est
le **milieu** qui manquait. Les aérosols du modèle Hillaire sont planétaires (exp(−h/1,2 km) depuis Y = 63 ; 0,004 /km
× *Brume*) : au-dessus d'une vallée en altitude, l'extinction est d'environ 0,01 à 0,03 /km, alors que des faisceaux
visibles demandent 0,1 à 0,5 /km (visibilité 10 à 40 km). Et quand le milieu est fin, un rayon de vue traverse des
dizaines de faisceaux sur des dizaines de km : leurs contrastes se moyennent et il ne reste qu'un voile uniforme. Une
brume dense limite la profondeur visible à quelques km : le motif des ombres reste lisible.

| Élément | Implémentation |
|---|---|
| **Milieu** (`Crepuscular.inc`) | Couche d'aérosols propre : extinction `0,01 × 2^HAZE_DENSITY` /km (0,02 à 0,64, visibilité 190 à 6 km), constante sous `HAZE_ALTITUDE`, puis décroissance exponentielle (hauteur d'échelle `HAZE_HEIGHT`, × échelle). Ångström 1,3 (le bleu est plus atténué : soleil rasant rougi), albédo 0,92, phase à deux lobes (HG 0,78 vers l'avant + 15 % HG −0,3 vers l'arrière, plus de diffusion latérale que Cornette-Shanks). Pluie : × (1 + 2 × humidité). Éteinte dans les grottes comme la perspective atmosphérique. |
| **Éclairage de la brume** | Soleil (transmittance de l'atmosphère, colonne de brume au-dessus du point / hauteur du soleil, ombre des nuages), lumière diffusée par les nuages fins (isotrope), sol éclairé par le soleil sous la brume (albédo 0,2), diffusion multiple = table de diffusion multiple de Hillaire (champ de lumière du ciel et du sol, comme pour l'air). La nuit : lune ; sans lumière au-dessus de l'horizon : radiance moyenne du ciel. |
| **Entrelacement air / brume** | Avec la brume, la lumière de l'air du segment parcouru est retirée telle que le ciel et la perspective l'ont intégrée (éclairée, sans brume), puis rajoutée ombrée et atténuée par la brume située devant : `(couleur − air0) × T_brume + air1 + brume`. Sans cela, la brume atténuait aussi l'air bleu devant elle (horizon brunâtre, deux fois trop sombre). Nuages : seule la brume devant eux les atténue ; le fond : toute la brume. |
| **Intensité** (`CREPUSCULAR_STRENGTH`) | N'exagère plus que l'ombre des nuages bas et moyens (`CloudShadowOpticalDepthSplit`) : à 300 %, le voile uniforme des cirrus coupait la moitié de la lumière partout. Formulation unique pour l'air et la brume : lumière directe effective = clamp(1 − intensité × (1 − e^−od), 0, 1) × e^−od(cirrus), ce qui remplace l'ancienne borne. |
| **Perspective atmosphérique** | L'air retiré sur le relief suit le même facteur que `LandAtmosphericScattering` (*Perspective atmosphérique* × lumière du ciel à l'œil) : la soustraction était incohérente avec un réglage ≠ 1. |
| **Coût** (hors jeu) | Brume ≈ +10 % du coût des rayons (1 lecture de table de diffusion multiple et quelques exponentielles par pas). Brume seule (rayons désactivés) : moins cher que les rayons. |

*Altitude de la brume* va de −2000 à 2000 (cartes qui descendent sous Y = 0) ; elle est calculée par rapport à la
vraie altitude de la caméra (l'atmosphère, elle, ramène la caméra à son sol, Y = 63).

### Optimisation 8c (retour : 50 → 40 FPS depuis les rayons et la brume)

Mesures hors jeu (rapports seulement), puis trois corrections :

| Cause | Correction |
|---|---|
| Rayons + brume intégrés pour **chaque pixel interne** dans `composite4` (24 pas), soit 4 × les pixels de la marche des nuages | Nouvelle passe `composite4_c` à la résolution de la marche (un pixel de chaque bloc 2×2, un différent à chaque image, comme `CLOUD_RES` 2), 2 images (`airLightA/B`). `composite4` suréchantillonne (4 voisins, poids bilinéaires × similarité de la distance de la surface) et n'intègre lui-même que les pixels sans voisin de profondeur proche (bords fins contre le ciel : < 1 % des pixels). Moins de pas sur les trajets courts (8 sous ~3 km). Coût de l'air ≈ ÷ 3. |
| `CloudShadowLookup` (lumière du soleil sur le relief, **chaque impact de rayon de la GI** dans `deferred2`, réflexions) : la nouvelle carte faisait 4 lectures, 4 exponentielles et un logarithme au lieu d'une lecture filtrée | Sous la couche de nuages (cas du relief et de la GI), une seule lecture filtrée par le matériel (profondeur optique totale du texel), comme avant la phase 8. |
| Carte d'ombre : la cascade proche (512²) traversait 5 à 8 km de champ de cumulus par texel en petits sauts (31 itérations sur 35 hors des nuages : le champ de distance est plafonné à ~0,7 km ; la carte de saut hiérarchique n'aide pas, ses tuiles contiennent presque toutes un nuage) | Cascade proche réduite à 256² (±8 km, même finesse de 62,5 m) ; au-delà, la cascade lointaine (312 m). Coût ≈ ÷ 1,7. |

Second retour : FPS en partie récupérés, mais impact encore sensible, et **bruit sur les rayons** (bords granuleux).

| Problème | Correction (8d) |
|---|---|
| Bruit : la lecture de la carte d'ombre était stochastique (± ½ texel, filtrée par le TAA). À la résolution de la marche, ce bruit devient des grains 2×2 que le TAA ne retire plus ; le bruit bleu était en plus lu un pixel sur deux (spectre perdu) | Lecture filtrée par le matériel (bilinéaire des 4 canaux sMax, sMin, profondeurs optiques : ombres lisses, aucun bruit) pour l'air, les rayons du pack, le relief et la GI ; bruit bleu sur la grille basse résolution ; 12 pas minimum. |
| Carte d'ombre recalculée entièrement à chaque image | **Adressage torique** : un texel garde toujours la même colonne du monde (indice mod taille), donc une ligne non rafraîchie reste juste quand la caméra bouge (vérifié hors jeu : caméra déplacée de 175 m avec les lignes anciennes, écart < 0,01 % des pixels). Cascade proche : une ligne sur deux par image ; lointaine : une sur quatre. Marge de 3 texels au bord de la fenêtre proche (colonnes nouvelles pas encore calculées). |

Réglages conseillés pour une carte de montagne : *Altitude de la brume* = fond des vallées, *Brume des vallées*
Marquée ou Dense, *Épaisseur* 800 à 1000 m (elle monte sur les versants), *Intensité des rayons* 150 à 300 %.

## Phase 7 : forme et éclairage des cumulus

**Retour de test** (capture comparée à une photo de cumulus) : nuages très ronds, très adoucis, blancs partout.
Objectif : forme plus irrégulière mais d'un seul tenant (pas de morceaux détachés), plus de contraste, plus de détail.

**Diagnostic** (outil d'aperçu, coupes verticales de la densité `--slice`, luminances linéaires `DUMP_LINEAR`) :
- **Bug 1 (depuis la phase 1)** : après chaque saut d'espace vide, la marche reprenait à une distance déterministe et
  perdait sa gigue. Les échantillons formaient des « courbes de niveau » sur les dômes et des rideaux verticaux sur les
  flancs, que l'accumulation temporelle ne peut pas effacer. Corrigé : reprise sur une position tirée au hasard.
- **Bug 2 (depuis la phase 2)** : le champ de déformation et de tourelles était lu avec l'origine du bruit de base, qui
  boucle tous les 2 km, sur une texture de période 2,6 km. Les formes sautaient chaque fois que le vent (ou la caméra)
  franchissait une boucle (toutes les ~3 min par 10 m/s). Corrigé : origines bouclées sur un multiple commun des
  périodes (6 km et 9,6 km), déformation de période 2 km.
- **Forme** : les cumulus de beau temps étaient des galettes lisses (ex. 440 × 120 m), de densité uniforme : l'empreinte
  2D extrudée et un profil en dôme définissaient presque tout ; le bruit 3D ne faisait que flouter le bord (rampe de
  densité sur ~45 % du rayon).
- **Flou** : la surface n'était localisée qu'au pas de marche près (~34 m à 2 km, contre ~2 m par pixel en jeu).
- **Éclairage** (référence par path tracing, `tools/cloud_reference.py`) : le modèle était environ **2 × trop lumineux**
  et presque indépendant de l'orientation de la surface par rapport au soleil (zones à l'ombre 3 à 4 × trop claires).
  Le terme de diffusion (85 % de la lumière) était isotrope et ne décroissait presque pas près de la surface. En jeu,
  avec l'exposition réglée sur le ciel, tout le nuage tombait dans l'épaule de la courbe de tons : blanc partout.

| Élément | Implémentation |
|---|---|
| **Forme chou-fleur** (`CLOUD_CUMULUS_MODEL` 1) | Distance signée en blocs à un dôme à base plate (profil x² + h^p, p de 2,6 à 4 selon la convection, 5 pour la colonne d'un cumulonimbus), calculée à partir de l'empreinte et du **rayon du nuage**, désormais stocké dans la carte météo (canal `layer1.y`, à la place du multiplicateur de densité). Creusée par des lobes arrondis (cellules de Worley mises en paraboloïdes) de 500, 250, 125 m et 80-20 m (+ 20-5 m près de la caméra), plus profonds en haut du nuage : on ne creuse que vers l'intérieur, le nuage reste une masse pleine dans son empreinte. Bord de ~10 m près de la caméra (plus large au loin). Les flancs sont déplacés en 3D (pas de murs extrudés). Champ de tourelles lissé (période 6 km) et déformation lue sur des plans inclinés : plus de « tuyaux d'orgue » verticaux. *Lobes des cumulus* règle la profondeur des creux. Les nuages en couches (stratocumulus) gardent l'ancien modèle ; type −1 dans la carte météo. Modèle 0 = forme précédente. |
| **Proportions** | Épaisseur ≥ 0,75 × rayon (les cumulus humilis ne sont plus des galettes), bornée par la profondeur de la couche convective (0,9 km sans convection → 6 km en convection forte) : plus de blocs géants de 3,7 km d'épaisseur en régime de beau temps. |
| **Surface précise** | La forme chou-fleur donne une distance à la surface : hors du nuage, la marche fine avance de cette distance (sphere tracing, pas min. ≈ 1 pixel). La recherche grossière n'évalue que l'enveloppe (moins chère, ne peut pas sauter une partie mince). Bords nets à toute distance, sans bruit supplémentaire. |
| **Éclairage calibré** (`CLOUD_LIGHT_MODEL` 1) | Constantes ajustées (Nelder-Mead) sur 10 images de référence : sphères homogènes de 250 et 600 m, fonction de phase des gouttelettes (pic de diffraction 0,995 pour le transport), 5 configurations vue / soleil (face, côté, contre-jour, vu de dessous ×2). Terme de diffusion : poids 0,85 → 0,48, phase HG(0,27) au lieu d'un mélange presque isotrope ; octaves : atténuation 0,4 → 0,34 ; décroissance 0,22 → 0,26. Erreur moyenne 66 % → 20 %. Le contre-jour était déjà juste ; les faces éclairées de biais et les bases s'assombrissent. Reste : de face, le bord du disque reste trop clair (le modèle ignore l'épaisseur de nuage derrière le point). Modèle 0 = précédent. |
| **Marche vers le soleil** | Premier pas ~20 m au lieu de ~33 m (raison géométrique 3,0 au lieu de 2,6, même longueur totale) : ombrage des petits lobes. |
| **Bruit de détail** | Worley 64³ au lieu de 32³ (texels de 10 m au lieu de 20 m, 1 Mo) : petits lobes nets. |
| **Ombre de la couche moyenne** (retour du test 7) | Les cumulus s'assombrissaient brusquement sous une altitude fixe, la même pour tous : en dessous, l'ombre des altocumulus / altostratus était analytique ; au-dessus, elle venait de la marche vers le soleil, dont les rares pas longs échantillonnent mal une couche mince (ombre trop faible et granuleuse). Désormais, pour les nuages bas, la couche moyenne est toujours traitée de façon analytique, au prorata de la part de la couche (2,1 à 3,1 km × échelle) située au-dessus du point, et exclue de leur marche vers le soleil : transition continue. Les altocumulus gardent leur propre ombrage par la marche. |
| **Coût** | Itérations mesurées : recherche grossière moins chère (enveloppe seule), +1 à 2 évaluations de densité par pixel pour approcher la surface. Temps CPU identique au bruit de mesure près (±15 %). À mesurer en jeu. |

## Phase 6 : accélération et intérieur des nuages

**Mesures avant de coder** (outil d'aperçu, `PROF=1`, rendu CPU : seuls les ordres de grandeur comptent) :
- la marche vers le soleil ne représente que 10 à 20 % du temps : le « volume de lumière » prévu au plan n'aurait
  presque rien fait gagner. **Abandonné.**
- par pixel, l'essentiel des itérations sert à traverser du vide : 40 à 64 sauts (de 0,6 km au plus, la borne du
  champ de distance 2D), contre quelques échantillons dans les nuages. Même par ciel totalement dégagé : 46
  itérations par pixel. Vu de haut, 8 % des rayons atteignaient le plafond d'itérations (nuages lointains coupés).

| Élément | Implémentation |
|---|---|
| **Carte de saut hiérarchique** (`CLOUD_SKIP_MAP`) | `begin_c.csh` : à partir de la carte météo lointaine, 3 niveaux de tuiles (1,6 / 6,4 / 25,6 km × échelle) avec la distance minimale au nuage, le sommet le plus haut et la couche moyenne. Le rayon franchit d'un coup la plus grande tuile où il ne peut rencontrer aucun nuage compte tenu de sa plage d'altitude (planète courbe). Une tuile fine occupée n'est pas re-testée avant d'en sortir. Résultat : ciel dégagé 46 → 4 itérations par pixel, cumulus épars −15 à −35 %, rayons au plafond 7,7 → 4,3 %. Image identique (vérifiée pixel à pixel), sauf des nuages lointains qui ne sont plus coupés. Le gain réel sur GPU est à mesurer en jeu (option activable). La carte d'ombre devient `begin_h`. |
| **Diffusion profonde** (`CLOUD_DEEP_DIFFUSION`, 0,4) | Le terme de diffusion décroissait en exp(−0,22 τ), bien trop vite : dans un milieu qui n'absorbe presque pas, le flux diffus décroît en ~1 / (1 + 0,75 (1 − g) τ). Mélange des deux. L'intérieur d'un cumulus ensoleillé devient un « lait » gris-blanc au lieu d'un brouillard bleu sombre ; faces à l'ombre un peu plus claires. 0 = rendu précédent. |
| **Nuages proches** | Pas de 15 m au lieu de 60 m dans les 250 premiers mètres (bords nets en entrant et en sortant d'un nuage) ; octave d'érosion 4 × plus fine (détails de 20 à 80 m) à moins de ~1,5 km : silhouettes nettes et filaments au lieu d'un bord flou. |
| **Préréglages** | Inchangés : sans mesure GPU, je ne les retouche pas à l'aveugle. À ajuster d'après les FPS en jeu. |

## Phase 4 : atmosphère physique

Option *Atmosphère* (menu *Ciel et atmosphère*) : `ATMOSPHERE_MODEL` 0 = ciel SEUS d'origine, 1 = physique (par défaut).

| Élément | Implémentation |
|---|---|
| **Modèle** | Hillaire 2020 : Rayleigh (hauteur d'échelle 8 km), aérosols de Mie (1,2 km, g = 0,8, Cornette-Shanks), couche d'ozone (profil en tente centré à 25 km ; absorption du rouge prise vers 610 nm, sinon le crépuscule vire au violet). Sol à Y = 63, albédo 0,25. Toute l'atmosphère suit `CLOUD_SCALE` (1 bloc = 1 m × échelle) : même rendu à toute échelle, horizon cohérent avec celui des nuages. |
| **Tables** (compute, chaque image) | `begin_d` transmittance 256×64 (paramétrisation de Bruneton), `begin_e` diffusion multiple 32×32 (64 directions, série géométrique), `begin_f` vue du ciel 192×108 à l'altitude de la caméra, éclairée par le soleil puis par la lune (192×216). La capture du ciel avec nuages devient `begin_g` (elle lit ces tables). |
| **Ciel** | `SkyShading` (`lib/atmosphere/Sky.inc`) aiguille entre SEUS et la table de vue du ciel. Lune : même table éclairée depuis la direction opposée × `nightBrightness`, comme le ciel nocturne SEUS. |
| **Unités** | Luminance calculée pour un éclairement solaire de 1, convertie par 24π × `SUNLIGHT_BRIGHTNESS` : un mur blanc face au soleil vaut 24 × la couleur du soleil dans le pack, donc le rapport ciel / soleil est physique. Le ciel est plus lumineux que celui de SEUS par rapport au soleil (*Luminosité du ciel* pour ajuster). |
| **Couleur du soleil** | `colorSunlight` (shaders.properties) : transmittance analytique (masse d'air de Chapman approchée, Schüler 2012) avec les mêmes coefficients, pour rester un uniform utilisable dans tous les programmes et toutes les dimensions. Les nuages utilisent la table de transmittance exacte au point du nuage (avec l'ombre de la planète). |
| **Perspective atmosphérique** | Marche courte (3 à 10 pas, distribution quadratique) dans les tables de transmittance et de diffusion multiple : terrain (`LandAtmosphericScattering`, y compris réflexions) et nuages (`CloudShade`, 12 pas). Correcte dans toutes les directions, y compris vers le bas depuis la montagne ou en vol (fin de l'astuce de la direction miroir). *Brume sur le relief lointain* multiplie la distance. |
| **Pluie** | Aérosols × 7 (air gris et brumeux). |

Rendus hors-jeu (comparaison à exposition fixe) : midi plus clair et moins saturé, avec une brume réaliste à l'horizon ;
coucher du soleil plus neutre ; crépuscule avec lueur orange côté soleil, ciel bleu-violet et ceinture de Vénus à l'opposé ;
vu de 12 à 30 km, ciel sombre et liseré lumineux à l'horizon.

## Phase 5 : variété des nuages

Ordre choisi par l'utilisateur : phase 5 avant la phase 4.

| Élément | Implémentation |
|---|---|
| **Régimes de ciel** | `CloudGetSkyRegime` (`CloudWeather.inc`) : 8 types de ciel (dégagé, cumulus de beau temps, cumulus + altocumulus, cirrus, cumulus bourgeonnants, stratocumulus, front chaud, mixte). Option *Ciel* : change chaque jour (tirage pondéré par jour, transition de 13 h à minuit), manuel (réglages seuls), ou un type fixé. Chaque régime décale la couverture et la convection, dose les nuages en couche, les couches moyenne et haute, et la probabilité de cumulonimbus. La pluie ajoute un voile d'altostratus / nimbostratus ; l'orage le réduit et ajoute des cumulonimbus. |
| **Apparition progressive** | Les cellules grandissent au lieu d'apparaître d'un coup quand la couverture change (rayon × √(marge d'occupation)). |
| **Couche moyenne** (Ac / As) | Champ 2D signé dans le canal libre `layer1.w` des cartes météo (> 0 dans une plaque, sa partie négative donne une distance pour sauter le vide). Marchée dans la même boucle que les nuages bas : entre 1,8 et 4,4 km (× échelle) au-dessus de `CLOUD_ALTITUDE`, sauts limités à l'entrée de la couche, pas raccourcis dans les parties minces. Altocumulus : cellules de Worley étirées en rangées, aplaties ; altostratus : nappe lisse ondulée. La couche s'amincit en biseau vers le bord d'une plaque (pas de mur vertical). Vent ×1,5. Ombre analytique sur les nuages bas en dessous (`CloudOverheadTransmittance`). |
| **Couche haute** (Ci / Cc / Cs) | Nappe mince analytique à `CLOUD_ALTITUDE` + 8 km (× échelle), une intersection par rayon, visible jusqu'à 2,5 × la distance max. Texture `cirrus.dat` 512² : fibres par convolution intégrale de ligne (LIC) d'un bruit épars le long d'un flot, grains de cirrocumulus, voile. Bandes allongées le long du vent d'altitude (×2,5, tourné de 25°). Phase des cristaux de glace avec halo de 22° dans les cirrostratus. Ombre légère sur les nuages et le terrain. |
| **Cumulonimbus** | Uniquement par orage (ou rarement en régime « cumulus bourgeonnants »), sur les grandes cellules convectives : colonne jusqu'à 8,5 km et enclume (rayon ≈ 2,5 × la colonne) qui s'évase entre 68 et 90 % de la hauteur sous un sommet plat, avec un petit dôme de dépassement. Type > 1 = enclume (rayon de la colonne k = 2 − type). Les paramètres d'un cumulonimbus ne sont jamais moyennés avec ceux des nuages voisins (sinon des colonnes fines apparaissent sur le bord de l'enclume). |
| **Éclairs** | `CloudLightning` (`CloudComposite.inc`), appliqué à la composition (instantané, hors accumulation temporelle) : éclair vanilla via `lightningBoltPosition` (canal lumineux du sol jusque dans le nuage, scintillement) + éclairs aléatoires à l'intérieur des nuages pendant les orages. |

Correctif annexe : la déformation du domaine des empreintes de nuages était proportionnelle au rayon. Les grosses
cellules se repliaient en étoile (bords déchirés, colonnes verticales). Elle est maintenant bornée par la longueur
d'onde de chaque composante.

Coût mesuré hors-jeu (rendu CPU, seuls les rapports comptent) : couche moyenne présente sur ~30 % du ciel ≈ +50 % de
temps de raymarching par rapport aux seuls nuages bas ; couche haute ≈ gratuite ; orage ≈ +5 à 10 %. Les options
*Nuages moyens* et *Nuages hauts* à 0 retirent le code correspondant.

## Architecture (phases 0-3, complétée en phase 5)

Le pack rend la scène à **demi-résolution** dans le quart bas-gauche de l'écran (HRR), puis son TAA (`composite7`)
reconstruit la pleine résolution. Les buffers des nuages suivent cette grille « interne » : en 4K, l'interne fait 1920×1080.

```
begin.csh        carte régime 512²       couverture / convection / altitude de base / regroupement (très basse fréquence)
begin_a.csh      météo proche 2048²×2    cellules de nuages (3 tailles de grilles : 9 / 3,5 / 1,4 km)
begin_b.csh      météo lointaine 1024²×2 + couche stratiforme, distance au nuage le plus proche, sommet max local
begin_c.csh      carte de saut          3 niveaux de tuiles vides / sommet max / couche moyenne (phase 6)
begin_h.csh      carte d'ombre 512²     transmittance des nuages le long de la lumière, sur le plan du bas de la couche (64 m/texel)
begin_d..f.csh   atmosphère             tables de transmittance, diffusion multiple, vue du ciel (phase 4)
begin_g.csh      capture du ciel 512²   ciel + nuages en carte octaédrique, ¼ des texels mis à jour par image, marche basse qualité
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
| `shaders/lib/clouds/CloudSky.inc`, `CloudLookups.inc` | capture du ciel et carte d'ombre en espace lumière (2 cascades) : encodage et lectures pour les passes du pack |
| `shaders/lib/atmosphere/SkySEUS.inc` | fonctions de ciel SEUS, sorties de `Common.inc` pour être utilisables en compute (option *Atmosphère* = SEUS) |
| `shaders/lib/atmosphere/Atmosphere.inc` | atmosphère physique : paramètres, paramétrisations des tables, intégration, ciel, perspective atmosphérique |
| `shaders/lib/atmosphere/Sky.inc` | points d'entrée du pack (`SkyShading`, `SkyTransmittance`), aiguillage SEUS / physique |
| `shaders/lib/atmosphere/AtmosphereSettings.inc` | options de l'atmosphère et des rayons crépusculaires |
| `shaders/lib/atmosphere/Crepuscular.inc` | rayons crépusculaires : diffusion simple de l'air à l'ombre des nuages |
| `shaders/textures/clouds/*.dat` | bruits 3D tuilables (Perlin-Worley 128³, Worley 64³, curl 128²) et texture de cirrus 512², générés par `tools/gen_cloud_noise.py` |

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
- **Cumulus (phase 7)** : dôme en distance signée creusé de lobes (chou-fleur), surface trouvée par sphere tracing ;
  la densité aléatoire par nuage est remplacée par le rayon du nuage dans la carte météo. Voir la section Phase 7.
- **Éclairage** :
  - fonction de phase « gouttelettes » : Henyey-Greenstein + Draine (Jendersie & d'Eon 2023), lobe avant élargi ;
  - diffusion d'ordres bas par octaves ;
  - **terme de diffusion** en exp(−τ·(1−g)), qui rend le côté éclairé lumineux (constantes recalées en phase 7 sur une
    référence par path tracing) ;
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
- Les ombres des nuages sont fines (texels de 62,5 m) jusqu'à ±8 km de la caméra (à l'échelle 1), puis plus douces (312 m) jusqu'à ±80 km.
- Atmosphère SEUS (option 0) : la perspective atmosphérique suppose une caméra au sol ; les rayons vers le bas utilisent
  la direction miroir. Corrigé par l'atmosphère physique.
- Atmosphère physique : `colorSunlight` est une approximation analytique (quelques % d'écart avec les tables) qui ignore
  l'échelle pour l'altitude de la caméra. Les tables suivent l'altitude de la caméra, pas les réflexions vues depuis
  un autre point.
- `lightningBoltPosition` est supposée relative à la caméra (à vérifier en jeu : l'éclairage d'un éclair vanilla
  doit se trouver au-dessus de l'impact).
- Les cumulonimbus apparaissent avec l'orage en quelques secondes (montée de `thunderStrength`), pas en 30 minutes.
- Altostratus : les bords des plaques sont arrondis (aspect d'altocumulus floccus) plutôt qu'effilochés.
- Pas de traînées de pluie (virga) sous les nuages ni de mammatus sous les enclumes.
- Intérieur des nuages : brouillard uniforme (réaliste à l'intérieur d'un cumulus) ; près des bords, les détails
  restent limités par la résolution de la marche vers le soleil (premier pas d'environ 20 m).
- Éclairage calibré : de face (soleil dans le dos), le bord des nuages reste un peu trop clair et le centre un peu trop
  sombre (erreur ~20-30 % sur ce cas) : il faudrait connaître l'épaisseur de nuage derrière chaque point.
- Les grands nuages lointains (> 15 km) gardent parfois des stries verticales sur leurs flancs (empreinte 2D).
- Rayons crépusculaires : après le coucher du soleil, la lumière des ombres passe à la lune (choix d'Iris) : pas de
  rayons du soleil sous l'horizon. Les réflexions et la GI ne voient pas les rayons. Le relief ne projette des rayons
  que dans la portée de la carte d'ombre du pack (rayons proches), pas les montagnes lointaines de Voxy.
- Brume des vallées : le relief ne l'ombre pas au-delà des rayons proches (pas de carte d'ombre des montagnes de Voxy) :
  au soleil rasant, la brume d'une vallée à l'ombre d'une montagne reste éclairée. Elle ne suit pas le relief (altitude
  absolue), n'atténue pas la lumière du soleil sur le terrain, et n'apparaît pas dans les réflexions ni dans la GI.

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
   - S7 (phase 5) : *Ciel* sur chaque type fixé, à midi et au coucher du soleil ; puis *Change chaque jour* avec
     `/time add 24000` plusieurs fois ; `/weather thunder` (cumulonimbus, enclumes, éclairs) ; voler au-dessus des
     altocumulus (environ 4 km d'altitude à l'échelle 1, `CLOUD_ALTITUDE` + 2,7 km × échelle).
   - FPS : comparer *Nuages moyens* 100 % et 0 %, en régime *Cumulus et altocumulus*.
   - S9 (phase 6) : FPS avec *Saut des zones vides* activé / désactivé, par ciel *Dégagé*, *Cumulus de beau temps* et
     vu d'avion (au-dessus de la couche) ; traverser un cumulus en vol (intérieur, entrée, sortie) ; *Diffusion
     profonde* 0 contre 0,4.
   - S10 (phase 7) : `/time set 6000`, ciel *Cumulus de beau temps* puis *Cumulus bourgeonnants* : regarder un cumulus
     d'en dessous (comme la capture), de côté à quelques km, et en vol tout près. Comparer *Forme des cumulus*
     Précédente / Chou-fleur et *Modèle d'éclairage* Précédent / Calibré ; essayer *Lobes des cumulus* 0,5 à 1,5.
     Vérifier : pas de formes qui sautent avec le vent (attendre quelques minutes), pas de bruit nouveau sur les bords.
     FPS avec chaque combinaison.
   - S11 (phase 8) : `/time set 12500` (coucher), ciel *Cumulus bourgeonnants* puis *Cumulus et altocumulus* : regarder
     vers le soleil depuis le sol, puis depuis un sommet ; se retourner (rayons anticrépusculaires) ; `/time set 6000`
     face au soleil sous des nuages épars ; voler au-dessus de la couche. Comparer *Rayons crépusculaires* activés /
     désactivés et *Intensité des rayons* 100 / 150 / 250 %, *Brume* 3 / 4. Vérifier le bruit en mouvement (*Qualité
     des rayons*) et les FPS. Vérifier aussi les ombres des nuages sur le relief au coucher du soleil (elles portent
     maintenant jusqu'au soleil rasant).
   - S12 (phase 8b) : même scène que la capture du retour (sommet, vallée, soleil derrière des cumulus) : *Altitude de
     la brume* au fond de la vallée, *Brume des vallées* Normale / Marquée / Dense, *Épaisseur* 600 / 1000 m,
     *Intensité des rayons* 150 / 300 %. Vérifier : faisceaux dans la vallée, horizon (pas de bande sombre), ciel au
     zénith peu changé, grottes (pas de brume), pluie, nuit (lune), FPS brume Désactivée contre Normale.
   - S8 (phase 4) : comparer *Atmosphère* SEUS / Physique à midi, au coucher du soleil, au crépuscule (`/time set 12800`),
     la nuit, sous la pluie, depuis un sommet (brume sur le relief lointain de Voxy, qui doit se fondre dans le ciel à
     l'horizon) et en vol très haut. FPS SEUS contre Physique.
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
python3 tools/cloud_preview.py out.png --scene noon -O CLOUD_REGIME=4      # un type de ciel fixé
python3 tools/cloud_preview.py out.png --thunder 1 --wetness 0.5 --day 3   # orage, jour du monde
python3 tools/cloud_preview.py out.png --sun -30 --thunder 1 --bolt 1500 -56 -6000   # éclair vanilla
CLOUD_TIMING=1 python3 tools/cloud_preview.py out.png   # temps : carte d'ombre, raymarching, composition + rayons (rapports seulement)
python3 tools/cloud_preview.py out.png --scene sunset --key 0.0011 -O ATMOSPHERE_MODEL=0   # exposition fixe, ciel SEUS
ATMO_DEBUG=dir python3 tools/cloud_preview.py out.png   # enregistre les tables de l'atmosphère (.npy)
CLOUD_DUMP_WEATHER=dir python3 tools/cloud_preview.py out.png   # enregistre les cartes météo (.npy)
PROF=1 python3 tools/cloud_preview.py out.png --frames 1   # itérations par catégorie (vide, grossier, fin, échantillons)
python3 tools/cloud_preview.py out.png --yaw -32 --slice 1000 3500 1300 2300   # coupe verticale de la densité (+ paramètres météo)
DUMP_LINEAR=img.npy python3 tools/cloud_preview.py out.png   # image linéaire + transmittance (.npy) pour mesurer les luminances
python3 tools/cloud_preview.py out.png -D AIR_FULL_RES   # air bas intégré pour chaque pixel (référence du suréchantillonnage) ; -D AIR_DEBUG_FALLBACK : pixels intégrés en pleine résolution en rouge
python3 tools/cloud_preview.py out.png -D AIR_DEBUG=1   # air bas : 1 = transmittance de la brume, 2 = lumière ajoutée, 3 = lumière retirée (avec DUMP_LINEAR : valeurs en unités du ciel)
python3 tools/cloud_preview.py out.png -D CLOUD_LIGHT_RATIO=3.2   # define supplémentaire (constantes internes)
python3 tools/cloud_reference.py render 250 256 ref250.npz   # référence path tracing (sphère de 250 m, 256 spp, ~3 min)
python3 tools/cloud_reference.py fit 250:ref250.npz,600:ref600.npz   # ajuste les constantes de l'éclairage
python3 tools/cloud_reference.py compare 250:ref250.npz cmp.png   # précédent | référence | ajusté
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
