"""
=============================================================================
TERRA-ORBIT TOGO : Moteur d'Arbitrage Agro-Hydrique & De-risking Financier
Plateforme de Démonstration Officielle - NASA Space Apps Challenge
=============================================================================
"""

import streamlit as st
import pandas as pd
import numpy as np
import altair as alt

from terra_orbit.pipeline.togo_regions import TOGO_REGIONS
from terra_orbit.pipeline.nasa_power_client import NASAPowerClient
from terra_orbit.pipeline.earthdata_smap_ecostress import MultiSensorDownscaler
from terra_orbit.simulation.crop_models import CROP_DATABASE
from terra_orbit.simulation.rotation_engine import CropRotationEngine
from terra_orbit.fintech.credit_risk_scorer import ClimateCreditScorer
from terra_orbit.fintech.parametric_insurance import ParametricInsuranceEngine

# Configuration de la page Streamlit
st.set_page_config(
    page_title="TERRA-ORBIT TOGO | NASA Space Apps",
    page_icon="🌍",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Style CSS personnalisé et simulateur de téléphone mobile
st.markdown("""
<style>
    .main-header {
        background: linear-gradient(135deg, #0b3d91 0%, #1e3c72 50%, #2a5298 100%);
        padding: 24px;
        border-radius: 12px;
        color: white;
        margin-bottom: 24px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.15);
    }
    .metric-card {
        background-color: #f8fafc;
        border-left: 5px solid #0b3d91;
        padding: 16px;
        border-radius: 8px;
        margin-bottom: 12px;
    }
    .badge-nasa {
        background-color: #fc3d21;
        color: white;
        padding: 4px 10px;
        border-radius: 12px;
        font-size: 0.85em;
        font-weight: bold;
    }
    .badge-togo {
        background-color: #006a4e;
        color: white;
        padding: 4px 10px;
        border-radius: 12px;
        font-size: 0.85em;
        font-weight: bold;
    }
    .phone-container {
        max-width: 340px;
        background: #111;
        border: 12px solid #2d3748;
        border-radius: 36px;
        padding: 16px;
        margin: 0 auto;
        color: #fff;
        font-family: monospace;
        box-shadow: 0 8px 30px rgba(0,0,0,0.4);
    }
    .phone-screen {
        background: #9cad86;
        color: #111;
        padding: 14px;
        border-radius: 12px;
        min-height: 280px;
        font-size: 0.9em;
        line-height: 1.4;
    }
</style>
""", unsafe_allow_html=True)

# En-tête principal
st.markdown("""
<div class="main-header">
    <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
            <span class="badge-nasa">NASA SPACE APPS CHALLENGE</span>
            <span class="badge-togo">TOGO INNOVATION</span>
            <h1 style="margin: 8px 0 4px 0; color: white;">TERRA-ORBIT TOGO</h1>
            <p style="margin: 0; font-size: 1.1em; opacity: 0.95;">
                Moteur Satellitaire d’Optimisation de Rotation Culturale & de Dé-risquage du Crédit Agricole
            </p>
        </div>
        <div style="text-align: right; font-size: 0.9em;">
            <b>Missions NASA mobilisées :</b><br/>
            🛰️ SMAP (L-Band) | 🌡️ ECOSTRESS (ISS)<br/>
            🌧️ GPM IMERG | 🏔️ SRTM | ☀️ NASA POWER
        </div>
    </div>
</div>
""", unsafe_allow_html=True)

# Barre latérale : Paramètres territoriaux et agronomiques
with st.sidebar:
    st.header("📍 1. Sélection Territoriale (Togo)")
    selected_region_name = st.selectbox(
        "Région économique & agro-écologique :",
        options=list(TOGO_REGIONS.keys()),
        index=0
    )
    region_info = TOGO_REGIONS[selected_region_name]

    st.info(
        f"**Chef-lieu :** {region_info['chef_lieu']}\n\n"
        f"**Régime pluviométrique :** {region_info['regime_pluviometrique']}\n\n"
        f"**Pluvio moyenne :** {region_info['pluviometrie_annuelle_moy']} mm/an\n\n"
        f"**Sol dominant :** {region_info['sol_dominant']}\n\n"
        f"**Altitude SRTM :** {region_info['altitude_moy_srtm']} m (Pente : {region_info['pente_moyenne_deg']}°)"
    )

    st.markdown("---")
    st.header("🌱 2. Conception de la Rotation")
    st.caption("Définissez la succession des cultures sur 3 saisons :")

    available_crops = list(CROP_DATABASE.keys())
    crop_1 = st.selectbox("Saison 1 (Cycle principal) :", options=available_crops, index=0)
    crop_2 = st.selectbox("Saison 2 (Rotation dérobée) :", options=available_crops, index=1)
    crop_3 = st.selectbox("Saison 3 (Stabilisation sol) :", options=available_crops, index=2)

    st.markdown("---")
    st.header("🛰️ 3. Données Satellitaires Récentes")
    use_live_nasa_power = st.checkbox("Interroger l'API NASA POWER en direct", value=True)

# Chargement des données agroclimatiques
with st.spinner("Synchronisation avec les données agroclimatiques NASA POWER..."):
    climate_df = NASAPowerClient.fetch_climate_data(
        lat=region_info["lat"],
        lon=region_info["lon"],
        region_name=selected_region_name
    )

# Exécution de la simulation de rotation
rotation_sequence = [crop_1, crop_2, crop_3]
sim_result = CropRotationEngine.simulate_rotation(
    crop_sequence=rotation_sequence,
    region_name=selected_region_name,
    climate_df=climate_df
)

st.warning("Prototype exploratoire : données météo réelles ou synthétiques selon la source affichée. Les entrées sol sont fixes dans cette démonstration Python. Aucun crédit, paiement ou SMS réel.")

# Simulation du Downscaling spatial (SMAP + ECOSTRESS + Sentinel-2)
smap_raw = 0.17  # Humidité moyenne régionale m3/m3
ecostress_lst = 37.8  # Température de surface LST
sentinel_ndvi = 0.52
downscale_result = MultiSensorDownscaler.downscale_soil_moisture(
    smap_sm_coarse=smap_raw,
    ecostress_lst=ecostress_lst,
    ndvi=sentinel_ndvi,
    slope_deg=region_info["pente_moyenne_deg"],
    region_name=selected_region_name
)

# Évaluation FinTech (Credit Scoring & Assurance)
credit_eval = ClimateCreditScorer.evaluate_loan_application(
    agronomic_resilience_score=sim_result["resilience_score"],
    paw_percent=downscale_result["paw_percent"],
    requested_amount_fcfa=250000,
    crop_rotation_plan=rotation_sequence,
    region_name=selected_region_name,
    delta_nitrogen_kg_ha=sim_result["bilan_azote_total_kg_ha"],
    soil_erosion_protection_score=sim_result["score_protection_erosion"],
    water_efficiency_wue=sim_result["wue_fcfa_par_mm_eau"]
)

# ----------------- TABS PRINCIPALES -----------------
tab_agri, tab_data, tab_finance, tab_lowtech, tab_benchmark = st.tabs([
    "🌾 Simulation de Rotation (What-If)",
    "🛰️ Fusion & Downscaling NASA (30m)",
    "🏦 Dé-risquage Crédit & Assurance",
    "📱 Dernier Kilomètre (SMS / USSD)",
    "📊 Benchmark vs Autres Équipes"
])

# ================= TAB 1 : AGRONOMIE & ROTATION =================
with tab_agri:
    col_score, col_recom = st.columns([1, 2])

    with col_score:
        score = sim_result["resilience_score"]
        color = "#10b981" if score >= 70 else ("#f59e0b" if score >= 50 else "#ef4444")
        st.markdown(f"""
        <div style="background-color: #f1f5f9; padding: 20px; border-radius: 12px; text-align: center; border-top: 6px solid {color};">
            <h4 style="margin: 0; color: #475569;">SCORE DE RÉSILIENCE CLIMATIQUE</h4>
            <h1 style="font-size: 3.2em; margin: 10px 0; color: {color};">{score} / 100</h1>
            <p style="margin: 0; font-weight: bold; color: {color};">{'🟢 PLAN CERTIFIÉ OPTIMAL' if score >= 70 else ('🟠 PLAN MOYEN' if score >= 50 else '🔴 PLAN À RISQUE DÉGRADANT')}</p>
        </div>
        """, unsafe_allow_html=True)

    with col_recom:
        st.subheader(f"Diagnostic de la rotation : {' ➔ '.join(rotation_sequence)}")
        st.info(sim_result["recommandation_agronomique"])
        st.write(
            f"**Zone agro-écologique :** Région {selected_region_name} | "
            f"**Pluviométrie moyenne annuelle :** {region_info['pluviometrie_annuelle_moy']} mm | "
            f"**Type de sol :** {region_info['sol_dominant']}"
        )

    st.markdown("---")
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Bilan Azote Sol (N)", f"{sim_result['bilan_azote_total_kg_ha']} kg/ha",
              delta=f"{sim_result['bilan_azote_total_kg_ha']} kg" if sim_result['bilan_azote_total_kg_ha'] > 0 else f"{sim_result['bilan_azote_total_kg_ha']} kg")
    m2.metric("Besoin en Eau Cumulé", f"{sim_result['besoin_eau_total_mm']} mm")
    m3.metric("Efficience de l'Eau (WUE)", f"{sim_result['wue_fcfa_par_mm_eau']} FCFA/mm")
    m4.metric("Protection Érosion (SRTM)", f"{sim_result['score_protection_erosion']} %")

    # Détails des cycles
    st.subheader("Détail cycle par cycle")
    df_cycles = pd.DataFrame(sim_result["details_cycles"])
    st.dataframe(df_cycles, use_container_width=True)

# ================= TAB 2 : SCIENTIFIQUE / DOWNSCALING =================
with tab_data:
    st.subheader("🔬 Le Cœur Scientifique : Downscaling Multi-Capteurs à la Parcelle (30 m)")
    st.markdown("""
    Les autres équipes utilisent l'humidité du sol **SMAP brute (pixel de 9 à 36 km)**, totalement inadaptée aux petites parcelles togolaises (1 à 2 ha).
    **TERRA-ORBIT** applique la méthode physique du **Triangle Température-Végétation (TVDI)** couplée à l'infrarouge thermique d'**ECOSTRESS (70 m)**,
    à l'optique **Sentinel-2 (10 m)** et au relief **SRTM (30 m)**.
    """)

    c_down1, c_down2 = st.columns(2)

    with c_down1:
        st.markdown("#### Comparaison d'échelle spatiale")
        st.markdown(f"""
        - **NASA SMAP Brut (Bande L, micro-ondes) :** `{downscale_result['smap_coarse_m3m3']} m³/m³` (Pixel régional ~9 km)
        - **NASA ECOSTRESS LST (Thermique) :** `{ecostress_lst} °C` (Température radiométrique foliaire)
        - **Copernicus Sentinel-2 (NDVI) :** `{sentinel_ndvi}` (Couvert végétal de surface)
        - **NASA SRTM TWI (Indice topographique d'humidité) :** `{downscale_result['twi']}` (Drainage de pente)
        - 🎯 **Humidité Résolue TERRA-ORBIT (30 m) :** **`{downscale_result['sm_percentage']} %`** (`{downscale_result['sm_fine_30m_m3m3']} m³/m³`)
        - **Efficacité Évaporative du Sol (SEE / DISPATCH) :** `{downscale_result.get('evaporative_efficiency', 0.5)}`
        - **Pédologie régionale :** `{downscale_result.get('soil_parameters', {}).get('soil_type', region_info['sol_dominant'])}`
        """)

    with c_down2:
        st.markdown("#### Fenêtre de Semis Sécurisée (Anti-Faux Départ)")
        is_safe = downscale_result["seed_safe"]
        status_box = "#dcfce7" if is_safe else "#fee2e2"
        border_box = "#16a34a" if is_safe else "#dc2626"
        st.markdown(f"""
        <div style="background-color: {status_box}; border: 2px solid {border_box}; padding: 16px; border-radius: 8px;">
            <h4 style="margin: 0; color: {border_box};">
                {'✅ FENÊTRE FAVORABLE AU SEMIS' if is_safe else '⚠️ SEMIS DÉCONSEILLÉ (RISQUE BRÛLURE DES GRAINES)'}
            </h4>
            <p style="margin: 8px 0 0 0;">
                <b>Eau Disponible pour la Plante (PAW) :</b> {downscale_result['paw_percent']} %<br/>
                <b>Diagnostic de stress :</b> {downscale_result['stress_level']}<br/>
                <b>Avis agronomique :</b> {downscale_result.get('agronomic_advice', '')}
            </p>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("---")
    st.subheader(f"Série agroclimatique — source ({climate_df['source'].iloc[0]})")
    chart_rain = alt.Chart(climate_df).mark_bar(color="#0284c7").encode(
        x=alt.X("date:T", title="Date"),
        y=alt.Y("precipitation:Q", title="Précipitations journalières (mm)")
    ).properties(height=220)

    chart_temp = alt.Chart(climate_df).mark_line(color="#e11d48").encode(
        x=alt.X("date:T"),
        y=alt.Y("temp_mean:Q", title="Température moyenne (°C)")
    ).properties(height=220)

    st.altair_chart(chart_rain, use_container_width=True)
    st.altair_chart(chart_temp, use_container_width=True)

# ================= TAB 3 : FINTECH & DÉ-RISQUAGE =================
with tab_finance:
    st.subheader("🏦 Dé-risquage Financier : Le Modèle B2B (Banques, Microfinances & MIFA)")
    st.markdown("""
    Au Togo, les banques et microfinances (FUCEC, WAGES, Orabank) refusent 70% des crédits agricoles à cause du risque de sécheresse imprévisible.
    **Simulation financière exploratoire : aucun partenariat, garantie MIFA, crédit ou paiement réel n’est attesté.**
    """)

    col_mfi, col_opt = st.columns([1, 1])
    with col_mfi:
        selected_mfi = st.selectbox(
            "Institution financière partenaire :",
            options=["FUCEC Togo", "WAGES", "COOPEC-AD", "Orabank Togo"],
            index=0
        )
    with col_opt:
        has_offtake = st.checkbox("Contrat d'agrégation / filière certifiée (Bio Togo, ESOP)", value=True)

    # Réévaluation dynamique avec l'institution choisie
    credit_eval = ClimateCreditScorer.evaluate_loan_application(
        agronomic_resilience_score=sim_result["resilience_score"],
        paw_percent=downscale_result["paw_percent"],
        requested_amount_fcfa=250000,
        crop_rotation_plan=rotation_sequence,
        region_name=selected_region_name,
        has_offtaker_contract=has_offtake,
        mfi_partner=selected_mfi,
        delta_nitrogen_kg_ha=sim_result["bilan_azote_total_kg_ha"],
        soil_erosion_protection_score=sim_result["score_protection_erosion"],
        water_efficiency_wue=sim_result["wue_fcfa_par_mm_eau"]
    )

    f1, f2, f3, f4 = st.columns(4)
    f1.metric("Défaut Sans Audit", f"{credit_eval['taux_defaut_historique_pct']} %", delta="-22.5% risque brut", delta_color="inverse")
    f2.metric("Défaut TERRA-ORBIT", f"{credit_eval['taux_defaut_projete_pct']} %", delta=f"-{credit_eval['reduction_risque_pct']}% d'impayés", delta_color="normal")
    f3.metric("Taux d'Intérêt Bonifié", f"{credit_eval['taux_interet_recommande_pct']} %", delta=f"-{credit_eval['decomposition_taux_interet']['rabais_garantie_mifa_pct'] + credit_eval['decomposition_taux_interet']['bonus_rotation_climat_pct']:.1f}% bonifié")
    f4.metric("Garantie d'État MIFA", f"{credit_eval['mifa_garantie_taux_pct']} %", delta=f"{credit_eval['mifa_montant_garanti_fcfa']:,} FCFA")

    st.markdown(f"""
    <div class="metric-card">
        <h4>Décision d'octroi de crédit ({selected_mfi}) : <b>{credit_eval['statut_credit']}</b></h4>
        <p><b>Score de crédit composite :</b> {credit_eval['score_credit_total_100']} / 100 | <b>Ratio couverture dette (DSCR) :</b> {credit_eval['dscr_projete']}</p>
        <p><b>Montant demandé :</b> {credit_eval['montant_demande_fcfa']:,} FCFA | <b>Montant accordé :</b> {credit_eval['montant_accorde_fcfa']:,} FCFA | <b>Exposition nette {selected_mfi} :</b> {credit_eval['mfi_exposition_nette_fcfa']:,} FCFA</p>
        <p><b>Pertes financières évitées :</b> {credit_eval['perte_financiere_evitee_fcfa']:,} FCFA | <b>Allègement provisions BCEAO :</b> {credit_eval['economie_provisions_bceao_fcfa']:,} FCFA / ha</p>
        <p><b>Avis de conformité MIFA S.A. :</b> {credit_eval['avis_analyste_mifa']}</p>
    </div>
    """, unsafe_allow_html=True)

    with st.expander("📊 Détail des 4 Piliers de Notation & Décomposition du Taux"):
        p_col1, p_col2 = st.columns(2)
        with p_col1:
            st.markdown("##### Notation Multi-Piliers TERRA-ORBIT")
            st.write(f"- 🛰️ **Pilier Biophysique Satellite (35%) :** `{credit_eval['details_score_piliers']['biophysique_satellite_pct']} %`")
            st.write(f"- 🌱 **Pilier Agro-Écologique & Azote (25%) :** `{credit_eval['details_score_piliers']['agroecologique_azote_pct']} %`")
            st.write(f"- 📈 **Pilier Viabilité Économique (25%) :** `{credit_eval['details_score_piliers']['viabilite_economique_pct']} %`")
            st.write(f"- 🤝 **Pilier Offtake & Caution Solidaire (15%) :** `{credit_eval['details_score_piliers']['institutionnel_offtake_pct']} %`")
        with p_col2:
            st.markdown("##### Décomposition du Taux d'Intérêt Subventionné")
            decomp = credit_eval["decomposition_taux_interet"]
            st.write(f"- Taux commercial de base ({selected_mfi}) : `{decomp['taux_commercial_base_pct']} %`")
            st.write(f"- Déduction Garantie de Partage de Risque MIFA : `-{decomp['rabais_garantie_mifa_pct']} %`")
            st.write(f"- Bonus Climat Rotation Régénératrice : `-{decomp['bonus_rotation_climat_pct']} %`")
            st.write(f"- ➔ **Taux effectif bonifié au producteur :** **`{decomp['taux_final_bonifie_pct']} %`**")

    st.markdown("---")
    st.subheader("🛡️ Simulation d'Assurance Indicielle Paramétrique (Déclenchement Mobile Money)")
    st.caption("Les anomalies saisies servent à simuler un montant ; aucun virement n’est exécuté :")

    c_ins1, c_ins2, c_ins3 = st.columns(3)
    with c_ins1:
        test_operator = st.selectbox("Opérateur Mobile Money (Togo) :", ["T-Money (Togocom)", "Moov Money (Flooz)"], index=0)
        test_stage = st.selectbox("Stade phénologique :", ["FLORAISON_REMPLISSAGE", "EMERGENCE_VEGETATIF", "MATURATION_SENESCENCE"], index=0)
    with c_ins2:
        test_anomaly_sm = st.slider("Anomalie d'humidité SMAP sous-sol (%) :", -60.0, 20.0, -32.0, 2.0)
        test_anomaly_lst = st.slider("Anomalie thermique foliaire ECOSTRESS (°C) :", -2.0, 6.0, 3.4, 0.2)
    with c_ins3:
        test_days = st.slider("Jours consécutifs sous double anomalie :", 1, 30, 16)
        farmer_test_phone = "+228 90 12 34 56" if "T-Money" in test_operator else "+228 98 76 54 32"

    ins_result = ParametricInsuranceEngine.evaluate_claim_trigger(
        soil_moisture_anomaly_pct=test_anomaly_sm,
        ecostress_lst_anomaly_deg=test_anomaly_lst,
        consecutive_drought_days=test_days,
        insured_capital_fcfa=200000,
        farmer_phone=farmer_test_phone,
        operator=test_operator,
        growth_stage=test_stage,
        region_name=selected_region_name
    )

    if ins_result["sinistre_declenche"]:
        st.success(f"🔔 **{ins_result['statut_indemnisation']}** — *Palier: {ins_result['palier_sinistre']}*")
        st.markdown(f"**Indemnité théorique simulée :** `{ins_result['montant_indemnise_fcfa']:,} FCFA` ({ins_result['taux_indemnisation_pct']}%) pour `{ins_result['beneficiaire']}` via `{ins_result['canal_versement']}`. **Réf. audit:** `{ins_result['transaction_id']}`")
        st.code(ins_result["sms_transaction"], language="text")
    else:
        st.warning(f"ℹ️ {ins_result['statut_indemnisation']}")

    with st.expander("📡 Hypothèses du scénario et exemple de payload non transmis"):
        st.json(ins_result["mobile_money_payload"])

    with st.expander(f"📑 Calcul Actuariel de la Prime (Normes CIMA & Subvention État MIFA 50% - {selected_region_name})"):
        act_prem = ParametricInsuranceEngine.calculate_actuarial_premium(200000, selected_region_name)
        st.write(
            f"- **Capital assuré :** `{act_prem['capital_assure_fcfa']:,} FCFA/ha` | "
            f"**Fréquence historique sécheresse ({selected_region_name}) :** `{act_prem['frequence_sinistre_historique_pct']} %`\n"
            f"- **Prime Pure de Risque :** `{act_prem['prime_pure_fcfa']:,} FCFA` ({act_prem['taux_prime_pure_pct']}%)\n"
            f"- **Prime Commerciale Totale (avec rétrocession réassurance) :** `{act_prem['prime_commerciale_totale_fcfa']:,} FCFA` ({act_prem['taux_prime_commerciale_pct']}%)\n"
            f"- 🏛️ **Subvention Climat MIFA (50%) :** `-{act_prem['subvention_mifa_fcfa']:,} FCFA`\n"
            f"- ➔ **Prime Nette à la charge du producteur :** **`{act_prem['prime_nette_producteur_fcfa']:,} FCFA`** (soit `{act_prem['taux_net_producteur_pct']}%` du capital)"
        )

    with st.expander("🏛️ Simulation Macro-Économique à l'Échelle d'un Portefeuille (1 000 Producteurs)"):
        port_sim = ClimateCreditScorer.simulate_mfi_portfolio(1000, 250000, selected_mfi, 80.0)
        st.write(
            f"Pour un portefeuille de **1 000 producteurs** ({port_sim['volume_portefeuille_total_fcfa']:,} FCFA) financé par **{selected_mfi}** :\n"
            f"- **Taux de défaut historique sans satellite :** `{port_sim['taux_defaut_historique_pct']} %`\n"
            f"- **Taux de défaut global sous TERRA-ORBIT :** **`{port_sim['taux_defaut_nouveau_portefeuille_pct']} %`**\n"
            f"- 💰 **Volume d'impayés évité (Cash préservé) :** **`{port_sim['impayes_historiques_evites_fcfa']:,} FCFA`**\n"
            f"- 🛡️ **Volume sécurisé par la garantie MIFA (75%) :** `{port_sim['volume_garanti_mifa_fcfa']:,} FCFA`\n"
            f"- 🏦 **Préservation des fonds propres réglementaires BCEAO :** `{port_sim['gain_fonds_propres_bceao_fcfa']:,} FCFA`"
        )

# ================= TAB 4 : DERNIER KILOMÈTRE (LOW-TECH) =================
with tab_lowtech:
    st.subheader("📱 Inclusion Rurale : Diffusion par SMS & USSD (Zéro Barrière Smartphone)")
    st.markdown("""
    Un projet qui exige un iPhone ou une connexion 4G au champ est voué à l'échec en Afrique rurale.
    **TERRA-ORBIT diffuse ses alertes critiques par SMS basique et menu vocal USSD en langues nationales.**
    """)

    lang_choice = st.radio("Langue de diffusion pour le producteur :", ["Français", "Éwé (Mina)", "Kabyè"], horizontal=True)

    if lang_choice == "Français":
        sms_text = (
            f"[TERRA-ORBIT ALERTE]\n"
            f"Zone: {selected_region_name}\n"
            f"Humidite sol: {downscale_result['sm_percentage']}%\n"
            f"Conseil Semis: {'AUTORISE - Semez maintenant' if downscale_result['seed_safe'] else 'ATTENTION - Attendez 6 jours'}\n"
            f"Rotation recommandee: {crop_2} apres {crop_1}."
        )
    elif lang_choice == "Éwé (Mina)":
        sms_text = (
            f"[TERRA-ORBIT KPLƆM]\n"
            f"Kɔƒe: {selected_region_name}\n"
            f"Anyigba tsi: {downscale_result['sm_percentage']}%\n"
            f"Nukunu dede: {'Míede fifia' if downscale_result['seed_safe'] else 'Míelala ŋkeke ade'}\n"
            f"Agblede bubu: {crop_2} le {crop_1} megbe."
        )
    else:
        sms_text = (
            f"[TERRA-ORBIT TƆM]\n"
            f"Tɛtʊ: {selected_region_name}\n"
            f"Tɛtʊ lɩm: {downscale_result['sm_percentage']}%\n"
            f"Haye haʊ: {'I ha lɛɛlɛɛyɔ' if downscale_result['seed_safe'] else 'I daŋ kɩyakɩŋ looɖo'}\n"
            f"Tɔm kɩbaŋ: {crop_2} pɩtɩŋna {crop_1} wayɩ."
        )

    st.markdown(f"""
    <div class="phone-container">
        <div style="text-align: center; font-size: 0.75em; margin-bottom: 8px; color: #a0aec0;">TOGOCOM / MOOV 2G</div>
        <div class="phone-screen">
            <b>MESSAGE REÇU</b><br/>
            ------------------------<br/>
            {sms_text.replace(chr(10), '<br/>')}
            <br/>------------------------<br/>
            <small>Tapez *880# pour changer de culture</small>
        </div>
        <div style="text-align: center; margin-top: 12px; font-size: 0.8em; color: #718096;">TERRA-ORBIT RURAL HUB</div>
    </div>
    """, unsafe_allow_html=True)

# ================= TAB 5 : BENCHMARK COMPÉTITION =================
with tab_benchmark:
    st.subheader("🏆 Pourquoi TERRA-ORBIT gagne face aux 30 équipes concurrentes")
    
    comp_df = pd.DataFrame({
        "Critère d'évaluation": [
            "Résolution Humidité du Sol",
            "Détection du Stress Hydrique",
            "Alignement Défi Rotation",
            "Inclusion Paysanne Terrain",
            "Modèle Commercial & Monétisation",
            "Preuve Scientifique NASA"
        ],
        "Les 30 Équipes Classiques": [
            "SMAP Brut (9-36 km, inutilisable sur micro-parcelle)",
            "NDVI basique (plante déjà morte quand détectée)",
            "Tableau de bord théorique sans modèle de sol",
            "Application pour smartphone 4G (inaccessible)",
            "Gratuit / Sans modèle économique viable",
            "Simple affichage de carte sans calcul physique"
        ],
        "TERRA-ORBIT TOGO (Notre Projet)": [
            "Downscaling 30 m par fusion SMAP + ECOSTRESS + SRTM",
            "Thermique ECOSTRESS (alerte stomatique 10j avant flétrissement)",
            "Moteur dynamique multi-saisons FAO-56 & Bilan N",
            "SMS & USSD en langues locales (Éwé, Kabyè) sur 2G",
            "B2B/B2G payé par banques, microfinances et MIFA",
            "Équations physiques TVDI & TWI documentées"
        ]
    })
    st.table(comp_df)

# Footer
st.markdown("---")
st.markdown("""
<div style="text-align: center; color: #64748b; font-size: 0.85em;">
    TERRA-ORBIT TOGO © 2026 - Conçu pour le NASA Space Apps Challenge<br/>
    Technologies : NASA Earthdata | NASA POWER | Copernicus Sentinel | Streamlit | Python Open-Source
</div>
""", unsafe_allow_html=True)
