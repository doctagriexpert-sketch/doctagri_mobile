> Document historique de conception ou de présentation. Les affirmations de certification, paiement, partenariat et résolution ne sont pas attestées. Consulter [l’état actuel](../README.md) avant utilisation.

# OFFICIAL SUBMISSION DOSSIER - NASA SPACE APPS CHALLENGE

## Project Details
* **Project Title:** TERRA-ORBIT TOGO
* **Challenge:** Field Shift: Adapting Farms with NASA Data
* **Location:** Lomé, Togo (Global South Division)
* **Tagline:** Turning NASA Earth Observations into a Field-Level Crop Rotation Engine & Financial De-Risking Platform for West African Smallholders.
* **Lead Target Beneficiaries:** 500,000+ smallholder farmers across Togo & the Sahel, Agricultural Microfinance Institutions (FUCEC, WAGES), and the National Agricultural Financing Mechanism (MIFA).

---

## 1. Project Overview & Executive Summary

Across West Africa and specifically in Togo, smallholder agriculture accounts for over 40% of GDP and employs over 60% of the rural workforce. However, climate change has severely disrupted the onset and distribution of the rainy season. Farmers routinely fall into the **"false start of rains" trap**: sowing their seeds after an initial isolated downpour, only to watch their seeds incinerate when a dry spell hits two weeks later. 

Because rainfall and soil moisture variability create extreme uncertainty, regional financial institutions (banks and microfinance organizations) reject **more than 70% of agricultural credit applications**. Deprived of credit, farmers cannot afford certified seeds or organic fertilizers and default to repetitive, soil-depleting monocultures (continuous maize or cotton), causing severe organic degradation, soil erosion, and chronic poverty.

**TERRA-ORBIT TOGO** is the first dual-purpose agricultural intelligence platform that:
1. **Solves the Spatial Resolution Mismatch:** It develops a physical and machine-learning downscaling engine that couples **NASA SMAP L-Band microwave soil moisture** (9–36 km) with **NASA ECOSTRESS land surface temperature** (70 m) and **SRTM digital elevation** (30 m) to determine root-zone plant-available water at parcel scale (30 m).
2. **Simulates Resilient Crop Rotation Scenarios (What-If Engine):** It models multi-season rotations (e.g., *Maize ➔ Nitrogen-fixing Bio Soybean ➔ Drought-tolerant Sorghum*) to optimize water use efficiency (WUE), restore soil nitrogen, and mitigate erosion.
3. **Connects Agronomic Science to Real-World Capital (B2B2C):** It translates satellite-certified crop rotation plans into an institutional **Climate Credit Score** for banks and the Togolese state initiative MIFA, while unlocking automated **Parametric Micro-Insurance** payouts via Mobile Money (T-Money / Moov Flooz).
4. **Delivers to the Last Mile:** It strips away digital barriers by streaming critical sowing and rotation alerts via **unencrypted 2G SMS and USSD menus in local national languages (Éwé, Kabyè)**.

---

## 2. How Does TERRA-ORBIT Address the Challenge?

The NASA Challenge **"Field Shift: Adapting Farms with NASA Data"** specifically asks teams to design a decision-support tool that uses Earth observation data to explore, evaluate, and optimize **crop rotation strategies** to improve soil health, water efficiency, and climate resilience.

TERRA-ORBIT addresses every dimension of the prompt:
* **Water Efficiency Optimization:** By tracking the root-zone soil reservoir ($RU$) rather than superficial rainfall, our model guides farmers on whether their soil holds sufficient moisture to sustain a second-season crop (such as short-cycle cowpea or bio-soybean).
* **Soil Health Regeneration:** The system calculates the net nitrogen balance ($\Delta N$) and organic matter trajectory across rotation cycles, penalizing soil-mining monocultures and rewarding legume-cereal alternations.
* **Topographic & Erosion Prevention:** Integrating NASA SRTM slope and elevation models with USLE cover factors ($C$-factor), our simulator identifies vulnerable hillside plots (e.g., in the Monts Kabyè or Plateaux regions) and prescribes deep-root soil-stabilizing rotations.
* **From Academic Modeling to Economic Reality:** By giving financial institutions a reason to subsidize the transition, we ensure that crop rotation recommendations are actually implemented in the field.

---

## 3. NASA Earth Observations & Partner Datasets Used

| Mission / Dataset | Agency | Spatial / Temporal Resolution | Specific Function in TERRA-ORBIT |
|---|---|---|---|
| **SMAP L3 (SPL3SMP)** | NASA | 9 km - 36 km / 2–3 days | Core baseline for volumetric root-zone soil moisture ($m^3/m^3$) via L-band microwave radiometry. |
| **ECOSTRESS (L2/L4)** | NASA (ISS) | 70 m / Variable (precession orbit) | Measures radiometric Land Surface Temperature ($T_s$) and Evaporative Stress Index (ESI) to detect stomatal closure 7–10 days before visual wilting. |
| **GPM IMERG** | NASA / JAXA | 0.1° (~10 km) / 3 hours | Global precipitation calibration and early detection of extreme storm-runoff vs. infiltration. |
| **NASA POWER** | NASA Langley | 0.5° / Daily Point Time-Series | Real-time agroclimatology: Solar irradiance ($ALLSKY\_SFC\_SW\_DWN$), $T_{min}$, $T_{max}$, $RH_{2m}$, and reference evapotranspiration ($ET_0$). |
| **SRTM DEM** | NASA / USGS | 30 m / Static | Slope analysis, hydrological flow direction, and Topographic Wetness Index ($TWI = \ln(a / \tan \beta)$). |
| **Sentinel-2 MSI** | ESA / Copernicus | 10 m - 20 m / 5 days | Optical and Red-Edge vegetation vigor ($NDVI$, $EVI$) and canopy moisture ($NDWI$) used as fine boundary constraints. |

---

## 4. Scientific Innovation: The Multi-Sensor Downscaling Formulation

Global soil moisture products like SMAP cannot be used directly on typical West African smallholder plots (1–2 hectares) due to their ~9 km to 36 km pixel footprint. 

TERRA-ORBIT overcomes this using the **Apparent Thermal Inertia (ATI) and Temperature-Vegetation Dryness Index (TVDI)** downscaling approach:

$$TVDI = \frac{T_s - T_{s\_min}(NDVI)}{T_{s\_max}(NDVI) - T_{s\_min}(NDVI)}$$

Where:
* $T_s$ is the high-resolution radiometric temperature from **NASA ECOSTRESS (70 m)**.
* $T_{s\_max}$ and $T_{s\_min}$ define the dry and wet edges of the evapotranspiration trapezoid as a function of **Sentinel-2 NDVI (10 m)**.

We then resolve downscaled soil moisture ($\theta_{30m}$) by modulating the coarse SMAP microwave observation ($\theta_{SMAP}$) through local thermal evaporative stress and SRTM topography:

$$\theta_{30m} = \theta_{SMAP} \cdot \left[ 1 - \alpha (TVDI - \overline{TVDI}) + \beta \frac{TWI - \overline{TWI}}{\overline{TWI}} \right]$$

This mathematical formulation gives an actionable root-zone estimate at **30-meter resolution**, validated against GPM rainfall histories.

---

## 5. Continuity with NASA Harvest in Togo (Historical Context)

In 2020, during the COVID-19 pandemic, **NASA Harvest** partnered with the Government of Togo (Ministère de l'Économie Numérique) to rapidly produce a national 10-meter cropland map used for the **NOVISSI** and **YOLIM** social relief programs.

TERRA-ORBIT directly builds upon this historic foundation:
* **2020 NASA Harvest Achievement:** Static parcel localization (*"Where are the fields?"*).
* **2026 TERRA-ORBIT Breakthrough:** Dynamic, predictive agronomic and financial intelligence (*"What crop to rotate, when to sow safely, and how to de-risk agricultural credit?"*).

---

## 6. Alignment with UN Sustainable Development Goals (SDGs)

* **SDG 1 (No Poverty):** Unlocks fair agricultural credit for marginalized rural households and prevents catastrophic crop failure.
* **SDG 2 (Zero Hunger):** Increases multi-season yield resilience and food security through nitrogen-fixing rotations.
* **SDG 8 (Decent Work & Economic Growth):** Expands the formalization of agricultural microfinance in Togo and West Africa.
* **SDG 13 (Climate Action):** Empowers smallholder farmers with satellite-grade climate adaptation tools.
