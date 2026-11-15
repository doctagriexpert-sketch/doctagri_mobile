"""
TERRA-ORBIT TOGO - Geospatial & Regional Specifications
Définition des 5 régions économiques et agro-écologiques du Togo.
"""

TOGO_REGIONS = {
    "Savanes": {
        "chef_lieu": "Dapaong",
        "lat": 10.8631,
        "lon": 0.2078,
        "climat": "Soudano-Sahélien",
        "regime_pluviometrique": "Monomodal (Mai - Octobre)",
        "pluviometrie_annuelle_moy": 1050,  # mm/an
        "sol_dominant": "Sols ferrugineux tropicaux lessivés (faible rétention)",
        "reserve_utile_sol_mm": 85,  # Réserve utile du sol en mm
        "cultures_principales": ["Maïs", "Sorgho", "Soja", "Niébé", "Coton", "Arachide"],
        "risque_majeur": "Poches de sécheresse sévères, faux départ des pluies, vent d'Harmattan",
        "altitude_moy_srtm": 310,  # mètres
        "pente_moyenne_deg": 2.1
    },
    "Kara": {
        "chef_lieu": "Kara",
        "lat": 9.5511,
        "lon": 1.1861,
        "climat": "Soudano-Guinéen de transition",
        "regime_pluviometrique": "Monomodal (Mai - Octobre)",
        "pluviometrie_annuelle_moy": 1200,
        "sol_dominant": "Sols sur roches cristallines, lithosols et vertisols",
        "reserve_utile_sol_mm": 95,
        "cultures_principales": ["Sorgho", "Igname", "Maïs", "Soja", "Coton"],
        "risque_majeur": "Érosion hydrique sur pentes montagneuses (Kabyè), ruissellement",
        "altitude_moy_srtm": 415,
        "pente_moyenne_deg": 5.8
    },
    "Centrale": {
        "chef_lieu": "Sokodé",
        "lat": 8.9833,
        "lon": 1.1333,
        "climat": "Guinéen de savane",
        "regime_pluviometrique": "Intermédiaire tendance monomodale (Avril - Octobre)",
        "pluviometrie_annuelle_moy": 1300,
        "sol_dominant": "Sols ferrugineux tropicaux profonds",
        "reserve_utile_sol_mm": 110,
        "cultures_principales": ["Maïs", "Soja", "Manioc", "Igname", "Coton", "Anacarde"],
        "risque_majeur": "Dégradation organique des sols, aléas de mi-saison",
        "altitude_moy_srtm": 340,
        "pente_moyenne_deg": 3.2
    },
    "Plateaux": {
        "chef_lieu": "Atakpamé / Kpalimé",
        "lat": 7.5278,
        "lon": 1.1292,
        "climat": "Subéquatorial de montagne et forêt",
        "regime_pluviometrique": "Bimodal (Mars - Juillet & Septembre - Novembre)",
        "pluviometrie_annuelle_moy": 1450,
        "sol_dominant": "Sols ferrallitiques rouges et bruns profonds",
        "reserve_utile_sol_mm": 135,
        "cultures_principales": ["Maïs", "Soja biologique", "Café", "Cacao", "Manioc"],
        "risque_majeur": "Ravinement lors des pluies torrentielles, lessivage des nutriments",
        "altitude_moy_srtm": 480,
        "pente_moyenne_deg": 7.4
    },
    "Maritime": {
        "chef_lieu": "Tsévié / Aného",
        "lat": 6.4261,
        "lon": 1.2133,
        "climat": "Subéquatorial côtier (Anomalie sèche du Dahomey Gap)",
        "regime_pluviometrique": "Bimodal (Avril - Juillet & Septembre - Novembre)",
        "pluviometrie_annuelle_moy": 900,
        "sol_dominant": "Terres de barre (sols ferrallitiques sablo-argileux)",
        "reserve_utile_sol_mm": 100,
        "cultures_principales": ["Maïs", "Manioc", "Niébé", "Maraîchage"],
        "risque_majeur": "Faible pluviométrie côtière, sécheresses précoces, salinisation nappes",
        "altitude_moy_srtm": 65,
        "pente_moyenne_deg": 1.2
    }
}
