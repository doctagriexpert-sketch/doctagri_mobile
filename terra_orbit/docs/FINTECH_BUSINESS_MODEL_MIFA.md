> Document historique de conception ou de présentation. Les affirmations de certification, paiement, partenariat et résolution ne sont pas attestées. Consulter [l’état actuel](../README.md) avant utilisation.

# TERRA-ORBIT TOGO : Architecture FinTech, Modèle Économique & Dé-risquage Institutionnel

**Dossier d'Ingénierie Financière & Actuarielle - NASA Space Apps Challenge**  
*Auteurs : Équipe TERRA-ORBIT TOGO | Pôle FinTech & Business Architecture*

---

## 1. Contexte & Problématique Macroéconomique au Togo

Au Togo, l'agriculture représente plus de **40 % du PIB** et fait vivre **plus de 60 % de la population active**. Pourtant, ce secteur vital souffre d'un sous-financement chronique :

1. **Taux de rejet des crédits agricoles supérieur à 70 %** : Les institutions de microfinance (SFD) telles que la **FUCEC Togo**, **WAGES**, **COOPEC-AD** et les banques commerciales (**Orabank**, **Ecobank**) refusent l'écrasante majorité des demandes de prêt d'intrants.
2. **Taux d'impayés historique de 22,5 %** : En agriculture pluviale non auditée, l'imprévisibilité climatique (faux départ des pluies, poches de sécheresse en floraison) entraîne des pertes de récoltes massives.
3. **Exigences prudentielles BCEAO punitives** : Selon les règles de la Commission Bancaire de l'UMOA, les institutions financières doivent provisionner **100 % des créances douteuses** (PAR-90). Les défauts agricoles détruisent ainsi directement les fonds propres des microfinances.
4. **Piège de la monoculture dégradante** : Faute de financement dé-risqué, le producteur replante du maïs sur du maïs, achevant d'épuiser les réserves en azote du sol et augmentant sa vulnérabilité aux chocs climatiques.

**TERRA-ORBIT TOGO brise ce cercle vicieux** en transformant les données satellitaires de la NASA en notations de solvabilité bancaire et en contrats d'assurance indicielle automatisés.

---

## 2. Le Mécanisme de Partage de Risque MIFA S.A.

Le **MIFA S.A.** (Mécanisme Incitatif de Financement Agricole fondé sur le partage de risques) a été créé par l'État Togolais avec l'appui de la Banque Africaine de Développement (BAD) et du FIDA pour catalyser les crédits vers les filières stratégiques.

TERRA-ORBIT s'intègre directement dans la matrice d'éligibilité du MIFA :

| Palier d'Agrément | Critères Biophysiques TERRA-ORBIT | Couverture Garantie MIFA | Taux d'Intérêt Bonifié | Décision FinTech |
|---|---|---|---|---|
| **Tier 1 : Crédit Vert Bonifié** | Score de Résilience $\ge 70$, PAW semis $\ge 35\%$, Rotation régénératrice légumineuse (Soja/Niébé) | **75 % garanti par l'État** | **8,5 % à 9,5 %** (au lieu de 16,5 %) | Accord immédiat 100 % du prêt demandé |
| **Tier 2 : Crédit Conditionné** | Score de Résilience $50 - 69$, PAW semis $\ge 25\%$, Rotation moyenne | **50 % garanti par l'État** | **11,5 % à 12,5 %** | Accord partiel (80 %) avec condition d'introduction d'une légumineuse |
| **Tier 3 : Risque Critique** | Score de Résilience $< 50$ ou PAW semis $< 25\%$ (sol trop sec) | **0 % (Non éligible)** | **Taux usuraire non recommandé** | **Refus protecteur** (évite le surendettement paysan) |

---

## 3. L'Algorithme de Notation Multi-Piliers (`ClimateCreditScorer`)

Le moteur `ClimateCreditScorer` calcule un **score composite de solvabilité agro-climatique** sur 100 points, articulé autour de 4 piliers pondérés :

$$Score_{composite} = 0.35 \cdot S_{biophysique} + 0.25 \cdot S_{agroecologique} + 0.25 \cdot S_{economique} + 0.15 \cdot S_{institutionnel}$$

### A. Pilier 1 : Résilience Biophysique & Satellitaire (Poids : 35 %)
* **Couplage SMAP / ECOSTRESS à 30 m** : Mesure de l'Eau Disponible pour la Plante ($PAW\%$) au semis pour éliminer le risque du faux départ des pluies.
* **Résilience dynamique de rotation** : Capacité de la séquence culturale (ex: *Maïs ➔ Soja Bio ➔ Sorgho*) à franchir les déficits pluviométriques régionaux.
* **Facteur topographique SRTM** : Protection contre le ravinement et l'érosion hydrique sur les parcelles en pente (Monts Kabyè, Plateaux).

### B. Pilier 2 : Régénération Agro-Écologique (Poids : 25 %)
* **Bilan d'Azote Sol ($\Delta N$)** : Valorisation de la fixation symbiotique de l'azote par les légumineuses (+50 kg N/ha pour le soja bio, +40 kg N/ha pour le niébé), remplaçant les engrais chimiques onéreux importés.
* **Efficience d'Utilisation de l'Eau ($WUE$)** : Ratio de valeur économique produite par millimètre d'eau consommé (FCFA / mm).

### C. Pilier 3 : Viabilité Économique & Couverture Dette (Poids : 25 %)
* **Ratio de Couverture du Service de la Dette ($DSCR$)** :
  $$DSCR = \frac{\text{Revenu Brut Agricole Prévisionnel}}{\text{Principal du Prêt} + \text{Intérêts}}$$
  Un ratio $DSCR \ge 1,40$ atteste que le producteur génère un flux de trésorerie suffisant même en cas de baisse de rendement de 30 %.

### D. Pilier 4 : Structuration & Débouché Offtake (Poids : 15 %)
* Présence d'un contrat d'agrégation d'achat ferme avec des exportateurs certifiés (ex: *Bio Togo*, *Label d'Or*, *ESOP*).
* Affiliation à une coopérative agricole reconnue avec caution solidaire.

---

## 4. Modélisation Actuarielle du Défaut & Gain Prudentiel BCEAO

### A. Réduction de la Probabilité de Défaut (PD)
En calibrant la fonction sur les historiques des portefeuilles togolais :
* **Défaut sans audit satellite ($PD_0$)** : **22,5 %**
* **Défaut projeté sous rotation certifiée TERRA-ORBIT ($PD_{TO}$)** : **3,8 % à 5,5 %**
* **Taux d'abattement du risque** : **-76 % à -83 % d'impayés !**

### B. Allègement des Provisions Prudentielles (Règles BCEAO / UMOA)
Pour une institution de microfinance finançant un prêt de **250 000 FCFA** :
* Sans TERRA-ORBIT : Perte attendue brute = $250\,000 \times 22,5\% = 56\,250\text{ FCFA}$ (provision requise à 100 %).
* Avec TERRA-ORBIT & Garantie MIFA 75 % : Exposition nette MFI = $62\,500\text{ FCFA}$. Perte attendue nette = $62\,500 \times 4,5\% = 2\,812\text{ FCFA}$.
* **Économie de fonds propres réglementaires libérés : 53 438 FCFA par hectare financé !**

---

## 5. Assurance Paramétrique à Double Déclencheur (`ParametricInsuranceEngine`)

### A. Le Problème du Risque de Base (Basis Risk) des Assurances Classiques
* Les indices pluviométriques par satellite (CHIRPS, GPM) échouent car une pluie d'orage de 20 mm ruisselle sur une croûte sèche sans s'infiltrer dans les racines.
* Les indices optiques (NDVI Sentinel-2) réagissent avec **15 à 20 jours de retard**, quand la plante est déjà morte (nécrose foliaire irréversible). De plus, la couverture nuageuse en saison des pluies aveugle les capteurs optiques.

### B. La Percée Scientifique : Le Double Déclencheur Biophysique NASA
L'assurance paramétrique TERRA-ORBIT ne verse une indemnité **QUE SI ET SEULEMENT SI** deux conditions biophysiques indépendantes sont simultanément réunies :

$$\text{Trigger} = \left( \Delta SM_{SMAP} \le \text{Seuil}_{sol} \right) \;\land\; \left( \Delta T_{s, ECOSTRESS} \ge \text{Seuil}_{thermique} \right) \;\land\; \left( \text{Durée} \ge \tau \right)$$

1. **NASA SMAP (Micro-ondes Bande L)** : Démontre que la réserve en eau du sol racinaire est épuisée ($\le -25\%$).
2. **NASA ECOSTRESS (Infrarouge thermique ISS)** : Démontre la rupture physiologique de la transpiration de la canopée (+2,5 °C au-dessus de la normale) consécutive à la fermeture stomatique.
3. **Persistance temporelle** : Contrainte maintenue pendant **14 jours consécutifs**.

### C. Grille d'Indemnisation Multi-Paliers (Standards CIMA)

| Palier d'Aléa | Critère SMAP | Critère ECOSTRESS | Durée Seuil | Taux Indemnisation | Finalité de l'Indemnité |
|---|---|---|---|---|---|
| **Tier 1 : Alerte Défense** | $\Delta SM \le -20\%$ | $\Delta LST \ge +2,0^\circ\text{C}$ | 10 jours | **25 %** (50 000 FCFA) | Achat d'intrants anti-transpirants, replantation précoce de niébé |
| **Tier 2 : Sécheresse Sévère** | $\Delta SM \le -25\%$ | $\Delta LST \ge +2,5^\circ\text{C}$ | 14 jours | **65 % à 90 %** | Remboursement direct du prêt d'intrants à la FUCEC ou WAGES |
| **Tier 3 : Catastrophe Agricole** | $\Delta SM \le -35\%$ | $\Delta LST \ge +3,5^\circ\text{C}$ | 21 jours | **100 %** (200 000 FCFA) | Indemnisation intégrale du capital + filet de sécurité vivrière |

---

## 6. Intégration Mobile Money au Togo (T-Money & Moov Flooz)

Dès confirmation algorithmique du sinistre à la fin d'une décade :
1. **Zéro déclaration physique, zéro expert de sinistre terrain**.
2. **Ordre de virement automatisé (B2W Bulk API)** :
   * Opérateur Togocom T-Money (`*145#`) ou Moov Africa Flooz (`*155#`).
   * Génération d'une référence cryptographique SHA-256 horodatée (ex: `TMONEY_TG-TXN-20261114-819438168FEF`).
3. **Notification SMS instantanée en langues nationales** :
   * **Français** : *« [ASSURANCE PARAMÉTRIQUE TOGO] Alerte sécheresse confirmée par satellites NASA. Virement de 165,600 FCFA effectué sur votre compte T-Money. »*
   * **Éwé (Mina)** : *« [TERRA-ORBIT DZƆGBEVƆVƆ] NASA kple ECOSTRESS gblɔ be kuɖiɖi le anyigba me. Wodo 165,600 FCFA ɖe wò T-Money sika dzi. »*
   * **Kabyè** : *« [TERRA-ORBIT TƆM KƖBAŊ] NASA tɩŋna tɛtʊ wɩlɩʊ yɔɔ nɛ pana wondu kuɖumɩŋ. Pa-ha-ŋ 165,600 FCFA ñɛ-tɛ T-Money yɔɔ. »*

---

## 7. Modèle Actuariel & Simulation à l'Échelle d'un Portefeuille

### A. Tarification Actuarielle selon le Code CIMA (Région Centrale / Savanes)
* **Capital assuré moyen** : 200 000 FCFA / ha
* **Fréquence historique de sinistre** : 9,2 % (Centrale) à 14,5 % (Savanes)
* **Prime Pure de Risque** : 6,6 % à 10,4 % (13 200 à 20 880 FCFA)
* **Prime Commerciale (avec frais de gestion et rétrocession réassurance)** : 10,6 % à 14,4 %
* **Subvention Climat MIFA (50 %)** : Prise en charge publique de 50 % de la prime.
* ➔ **Prime nette payée par le paysan** : **5,3 % à 7,2 %** (soit environ 10 600 à 14 400 FCFA/ha, directement intégrée dans le package de prêt d'intrants).

### B. Impact Macroéconomique sur un Portefeuille de 1 000 Producteurs (FUCEC Togo)
* **Encours total de crédit distribué** : **250 000 000 FCFA**
* **Impayés historiques sans audit satellite (22,5 %)** : 56 250 000 FCFA
* **Impayés sous audit TERRA-ORBIT (adoption 80 %)** : 19 650 000 FCFA
* **Économie de trésorerie nette (pertes évitées)** : **36 600 000 FCFA**
* **Encours sécurisé par la garantie MIFA (75 %)** : **150 000 000 FCFA**
* **Fonds propres réglementaires BCEAO sauvegardés** : **31 110 000 FCFA**

---

## 8. Conclusion Institutionnelle

En unifiant les données spatiales de la NASA (**SMAP**, **ECOSTRESS**, **SRTM**) et les réalités bancaires togolaises (**MIFA**, **FUCEC**, **WAGES**, **BCEAO**), **TERRA-ORBIT TOGO** ne propose pas un simple tableau de bord météo :  
**Il déploie une infrastructure financière de nouvelle génération capable de débloquer des milliards de FCFA de financements agricoles durables pour l'Afrique de l'Ouest.**
