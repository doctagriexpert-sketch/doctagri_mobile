// Togo Agro-Ecological and Administrative Data Reference
import togoCantonsRaw from "./togo_cantons.json";

export interface TogoRegion {
  id: string;
  name: string;
  chefLieu: string;
  lat: number;
  lon: number;
  climat: string;
  regimePluviometrique: string;
  pluviometrieAnnuelleMoy: number;
  solDominant: string;
  reserveUtileSolMm: number;
  culturesPrincipales: string[];
  risqueMajeur: string;
  altitudeMoySrtm: number;
  penteMoyenneDeg: number;
  pathD: string;
  color: string;
}

export const TOGO_REGIONS: Record<string, TogoRegion> = {
  Savanes: {
    id: "savanes",
    name: "Savanes",
    chefLieu: "Dapaong",
    lat: 10.8631,
    lon: 0.2078,
    climat: "Soudano-Sahélien",
    regimePluviometrique: "Monomodal (Mai - Octobre)",
    pluviometrieAnnuelleMoy: 1050,
    solDominant: "Sols ferrugineux tropicaux lessivés (faible rétention)",
    reserveUtileSolMm: 85,
    culturesPrincipales: ["Maïs", "Sorgho", "Soja", "Niébé", "Coton", "Arachide"],
    risqueMajeur: "Poches de sécheresse sévères, faux départ des pluies, vent d'Harmattan",
    altitudeMoySrtm: 310,
    penteMoyenneDeg: 2.1,
    color: "#eab308",
    pathD: "M 45,15 L 140,12 L 155,50 L 120,68 L 52,65 Z",
  },
  Kara: {
    id: "kara",
    name: "Kara",
    chefLieu: "Kara",
    lat: 9.5511,
    lon: 1.1861,
    climat: "Soudano-Guinéen de transition",
    regimePluviometrique: "Monomodal (Mai - Octobre)",
    pluviometrieAnnuelleMoy: 1200,
    solDominant: "Sols sur roches cristallines, lithosols et vertisols",
    reserveUtileSolMm: 95,
    culturesPrincipales: ["Sorgho", "Igname", "Maïs", "Soja", "Coton"],
    risqueMajeur: "Érosion hydrique sur pentes montagneuses (Kabyè), ruissellement",
    altitudeMoySrtm: 415,
    penteMoyenneDeg: 5.8,
    color: "#f97316",
    pathD: "M 52,65 L 120,68 L 155,50 L 160,115 L 75,122 L 48,92 Z",
  },
  Centrale: {
    id: "centrale",
    name: "Centrale",
    chefLieu: "Sokodé",
    lat: 8.9833,
    lon: 1.1333,
    climat: "Guinéen de savane",
    regimePluviometrique: "Intermédiaire tendance monomodale (Avril - Octobre)",
    pluviometrieAnnuelleMoy: 1300,
    solDominant: "Sols ferrugineux tropicaux profonds",
    reserveUtileSolMm: 110,
    culturesPrincipales: ["Maïs", "Soja", "Manioc", "Igname", "Coton", "Anacarde"],
    risqueMajeur: "Dégradation organique des sols, aléas de mi-saison",
    altitudeMoySrtm: 340,
    penteMoyenneDeg: 3.2,
    color: "#22c55e",
    pathD: "M 75,122 L 160,115 L 175,185 L 90,195 L 68,155 Z",
  },
  Plateaux: {
    id: "plateaux",
    name: "Plateaux",
    chefLieu: "Atakpamé / Kpalimé",
    lat: 7.5278,
    lon: 1.1292,
    climat: "Subéquatorial de montagne et forêt",
    regimePluviometrique: "Bimodal (Mars - Juillet & Septembre - Novembre)",
    pluviometrieAnnuelleMoy: 1450,
    solDominant: "Sols ferrallitiques rouges et bruns profonds",
    reserveUtileSolMm: 135,
    culturesPrincipales: ["Maïs", "Soja Biologique", "Café", "Cacao", "Manioc"],
    risqueMajeur: "Ravinement lors des pluies torrentielles, lessivage des nutriments",
    altitudeMoySrtm: 480,
    penteMoyenneDeg: 7.4,
    color: "#059669",
    pathD: "M 90,195 L 175,185 L 182,275 L 85,280 L 72,235 Z",
  },
  Maritime: {
    id: "maritime",
    name: "Maritime",
    chefLieu: "Tsévié / Lomé",
    lat: 6.4261,
    lon: 1.2133,
    climat: "Subéquatorial côtier (Anomalie sèche du Dahomey Gap)",
    regimePluviometrique: "Bimodal (Avril - Juillet & Septembre - Novembre)",
    pluviometrieAnnuelleMoy: 900,
    solDominant: "Terres de barre (sols ferrallitiques sablo-argileux)",
    reserveUtileSolMm: 75,
    culturesPrincipales: ["Maïs", "Manioc", "Niébé", "Arachide", "Maraîchage"],
    risqueMajeur: "Sécheresses intra-saisonnières marquées, surexploitation et acidification",
    altitudeMoySrtm: 65,
    penteMoyenneDeg: 1.2,
    color: "#0284c7",
    pathD: "M 85,280 L 182,275 L 195,355 L 98,360 Z",
  },
};

export interface CropInfo {
  id: string;
  name: string;
  nomScientifique: string;
  cycleJours: number;
  kcIni: number;
  kcMid: number;
  kcEnd: number;
  profondeurRacinaireM: number;
  besoinEauCycleMm: number;
  sensibiliteStressKy: number;
  bilanAzoteKgHa: number;
  couvertureSolMaxPct: number;
  valeurCommercialeKgFcfa: number;
  rendementMoyenTHa: number;
  description: string;
  category: "cereal" | "legume" | "tuber" | "industrial";
  iconName: string;
}

export const CROPS_DATA: Record<string, CropInfo> = {
  "Maïs": {
    id: "mais",
    name: "Maïs",
    nomScientifique: "Zea mays",
    cycleJours: 105,
    kcIni: 0.40,
    kcMid: 1.20,
    kcEnd: 0.60,
    profondeurRacinaireM: 0.90,
    besoinEauCycleMm: 520,
    sensibiliteStressKy: 1.25,
    bilanAzoteKgHa: -85,
    couvertureSolMaxPct: 85,
    valeurCommercialeKgFcfa: 250,
    rendementMoyenTHa: 2.2,
    description: "Céréale vivrière majeure du Togo. Grande exigence en eau au stade floraison (paniculage).",
    category: "cereal",
    iconName: "Wheat",
  },
  "Soja Biologique": {
    id: "soja",
    name: "Soja Biologique",
    nomScientifique: "Glycine max",
    cycleJours: 95,
    kcIni: 0.40,
    kcMid: 1.15,
    kcEnd: 0.50,
    profondeurRacinaireM: 0.70,
    besoinEauCycleMm: 450,
    sensibiliteStressKy: 0.85,
    bilanAzoteKgHa: 35,
    couvertureSolMaxPct: 90,
    valeurCommercialeKgFcfa: 420,
    rendementMoyenTHa: 1.4,
    description: "Légumineuse pivot de rotation. Fixe l'azote atmosphérique (Rhizobium) et protège le sol.",
    category: "legume",
    iconName: "Sprout",
  },
  "Sorgho": {
    id: "sorgho",
    name: "Sorgho",
    nomScientifique: "Sorghum bicolor",
    cycleJours: 115,
    kcIni: 0.35,
    kcMid: 1.05,
    kcEnd: 0.55,
    profondeurRacinaireM: 1.20,
    besoinEauCycleMm: 410,
    sensibiliteStressKy: 0.90,
    bilanAzoteKgHa: -50,
    couvertureSolMaxPct: 75,
    valeurCommercialeKgFcfa: 220,
    rendementMoyenTHa: 1.6,
    description: "Céréale ultra-rustique résistante au stress thermique et aux arrêts précoces de pluie.",
    category: "cereal",
    iconName: "Shield",
  },
  "Niébé (Haricot)": {
    id: "niebe",
    name: "Niébé (Haricot)",
    nomScientifique: "Vigna unguiculata",
    cycleJours: 75,
    kcIni: 0.40,
    kcMid: 1.05,
    kcEnd: 0.40,
    profondeurRacinaireM: 0.60,
    besoinEauCycleMm: 320,
    sensibiliteStressKy: 0.75,
    bilanAzoteKgHa: 45,
    couvertureSolMaxPct: 95,
    valeurCommercialeKgFcfa: 500,
    rendementMoyenTHa: 0.9,
    description: "Cycle ultra-court idéal en dérobée ou pour sécuriser la fin de saison des pluies.",
    category: "legume",
    iconName: "Leaf",
  },
  "Igname": {
    id: "igname",
    name: "Igname",
    nomScientifique: "Dioscorea alata / cayenensis",
    cycleJours: 210,
    kcIni: 0.30,
    kcMid: 1.10,
    kcEnd: 0.70,
    profondeurRacinaireM: 0.80,
    besoinEauCycleMm: 850,
    sensibiliteStressKy: 1.10,
    bilanAzoteKgHa: -110,
    couvertureSolMaxPct: 65,
    valeurCommercialeKgFcfa: 350,
    rendementMoyenTHa: 8.5,
    description: "Culture reine des régions Centrale et Kara. Exige des sols profonds et bien aérés.",
    category: "tuber",
    iconName: "Egg",
  },
  "Coton": {
    id: "coton",
    name: "Coton",
    nomScientifique: "Gossypium hirsutum",
    cycleJours: 150,
    kcIni: 0.35,
    kcMid: 1.20,
    kcEnd: 0.65,
    profondeurRacinaireM: 1.10,
    besoinEauCycleMm: 680,
    sensibiliteStressKy: 0.85,
    bilanAzoteKgHa: -95,
    couvertureSolMaxPct: 70,
    valeurCommercialeKgFcfa: 300,
    rendementMoyenTHa: 1.2,
    description: "Principale culture de rente industrielle. Exigeante en azote et longue en terre.",
    category: "industrial",
    iconName: "Flower",
  },
  "Manioc": {
    id: "manioc",
    name: "Manioc",
    nomScientifique: "Manihot esculenta",
    cycleJours: 240,
    kcIni: 0.30,
    kcMid: 1.00,
    kcEnd: 0.50,
    profondeurRacinaireM: 1.00,
    besoinEauCycleMm: 600,
    sensibiliteStressKy: 0.65,
    bilanAzoteKgHa: -60,
    couvertureSolMaxPct: 80,
    valeurCommercialeKgFcfa: 180,
    rendementMoyenTHa: 12.0,
    description: "Tubercule de sécurité alimentaire résilient aux sécheresses prolongées grâce à ses réserves racinaires.",
    category: "cereal",
    iconName: "Trees",
  },
};

export const CROP_DATABASE = CROPS_DATA;
export type CropData = CropInfo;

export const ROTATION_PRESETS = [
  {
    name: "Monoculture Maïs (Pratique Dégradante)",
    sequence: ["Maïs", "Maïs", "Maïs"],
    description: "Appauvrit massivement le sol en azote (-255 kg/ha) et crée un risque hydrique critique.",
    type: "bad",
  },
  {
    name: "Rotation Soja Bio (Recommandée Agro-Filière)",
    sequence: ["Maïs", "Soja Biologique", "Sorgho"],
    description: "Équilibre parfait : fixation d'azote, couverture de sol et forte valorisation économique.",
    type: "good",
  },
  {
    name: "Bouclier Climat Extrême (Résilience Sécheresse)",
    sequence: ["Maïs", "Niébé (Haricot)", "Sorgho"],
    description: "Cycle court et enracinement profond pour résister aux pires dérèglements climatiques.",
    type: "optimal",
  },
];

export interface RecommendedRotation {
  id: string;
  name: string;
  badge: string;
  sequence: string[];
  role: string;
  agronomicWhy: string;
  points: {
    sol: string;
    eau: string;
    economie: string;
  };
}

export const RECOMMENDED_ROTATIONS: RecommendedRotation[] = [
  {
    id: "soja-filiere",
    name: "Synergie Céréale & Soja Bio",
    badge: "🌱 Recommandation Agro-Filière",
    sequence: ["Maïs", "Soja Biologique", "Sorgho"],
    role: "Maximiser le revenu et restaurer l'azote sans engrais chimique",
    agronomicWhy:
      "Le soja biologique fixe l'azote de l'air grâce à ses nodosités (Rhizobium). Ce reliquat azoté (+35 kg/ha) nourrit directement le sorgho qui le suit. Le sorgho, très rustique, valorise l'eau résiduelle profonde avec ses racines plongeantes.",
    points: {
      sol: "+35 kg N/ha d’azote naturel restitué au sol",
      eau: "Enracinement étagé (0,7 m à 1,2 m) qui explore les couches d'humidité",
      economie: "Soja bio très recherché au Togo (~420 F/kg bord-champ)",
    },
  },
  {
    id: "bouclier-secheresse",
    name: "Bouclier Anti-Sécheresse",
    badge: "🛡️ Sécurisation Climat Extrême",
    sequence: ["Maïs", "Niébé (Haricot)", "Sorgho"],
    role: "Esquiver les arrêts précoces de pluie et protéger le sol",
    agronomicWhy:
      "Le niébé boucle son cycle en seulement 75 jours et forme un tapis dense couvrant 95 % du sol, stoppant l'évaporation de l'eau utile. Si la pluie s'arrête prématurément en fin de saison, la récolte est déjà sécurisée.",
    points: {
      sol: "Couverture du sol à 95 % limitant l'érosion par ruissellement",
      eau: "Cycle court (75 j) esquivant les poches de sécheresse",
      economie: "Forte demande sur les marchés locaux (~500 F/kg)",
    },
  },
  {
    id: "restauration-sol",
    name: "Cure Régénératrice pour Sols Fatigués",
    badge: "🔋 Reconstitution de Fertilité",
    sequence: ["Niébé (Haricot)", "Soja Biologique", "Maïs"],
    role: "Recharger une terre épuisée par la monoculture continue",
    agronomicWhy:
      "Deux légumineuses consécutives rompent le cycle des parasites du maïs (comme le Striga) et accumulent une réserve massive de nutriments organiques (+80 kg N/ha cumulés). Le maïs semé en troisième cycle bénéficie d'une vigueur exceptionnelle (+15 % de rendement).",
    points: {
      sol: "Recharge record de +80 kg N/ha cumulés en azote symbiotique",
      eau: "Restauration de la matière organique qui retient mieux l'eau",
      economie: "Économie de plusieurs sacs d'engrais chimiques coûteux",
    },
  },
];

export interface CantonDivision {
  id: string;
  name: string;
  canton: string;
  commune: string;
  commune_id: string;
  prefecture: string;
  prefecture_id: string;
  region: string;
  region_admin: string;
  lat: number;
  lon: number;
  penteDeg: number;
}

export const TOGO_OFFICIAL_CANTONS: CantonDivision[] = togoCantonsRaw as CantonDivision[];

export interface FieldLocation {
  id: string;
  name: string;
  locality: string;
  canton?: string;
  commune?: string;
  prefecture?: string;
  region: string;
  region_admin?: string;
  lat: number;
  lon: number;
  penteDeg: number;
  description?: string;
  isGps?: boolean;
}

export interface AgriculturalCooperative {
  id: string;
  name: string;
  zone: string;
  region: string;
  lat: number;
  lon: number;
  membres: number;
  superficieTotaleHa: number;
  filiere: string;
}

// Convert all official cantons into FieldLocation objects
export const TOGO_LOCALITIES: FieldLocation[] = (togoCantonsRaw as CantonDivision[]).map((c) => ({
  id: c.id,
  name: `${c.name} (${c.commune})`,
  locality: `${c.canton}, ${c.prefecture}`,
  canton: c.canton,
  commune: c.commune,
  prefecture: c.prefecture,
  region: c.region,
  region_admin: c.region_admin,
  lat: c.lat,
  lon: c.lon,
  penteDeg: c.penteDeg,
  description: `Canton officiel de ${c.name} • Commune ${c.commune} • Préfecture de ${c.prefecture} • Région ${c.region_admin}`,
}));

export const TOGO_COOPERATIVES: AgriculturalCooperative[] = [
  {
    id: "scoops_espoir",
    name: "SCOOPS Espoir de Tandjouaré",
    zone: "Tandjouaré & Dapaong",
    region: "Savanes",
    lat: 10.6583,
    lon: 0.1917,
    membres: 145,
    superficieTotaleHa: 220,
    filiere: "Soja Biologique & Maïs",
  },
  {
    id: "urpco_savanes",
    name: "Union Régionale des Producteurs de Céréales (URPCO)",
    zone: "Plaines de l'Oti & Tône",
    region: "Savanes",
    lat: 10.8631,
    lon: 0.2078,
    membres: 480,
    superficieTotaleHa: 850,
    filiere: "Maïs blanc, Sorgho & Niébé",
  },
  {
    id: "coop_igname_bassar",
    name: "Coopérative des Planteurs d'Igname de Bassar",
    zone: "Bassar & Kabou",
    region: "Kara",
    lat: 9.2500,
    lon: 0.7833,
    membres: 210,
    superficieTotaleHa: 310,
    filiere: "Igname Labaco & Soja",
  },
  {
    id: "covi_notse",
    name: "Coopérative Vivrière de Notsé (COVI-Notsé)",
    zone: "Haho & Kpélé",
    region: "Plateaux",
    lat: 6.9500,
    lon: 1.1667,
    membres: 320,
    superficieTotaleHa: 540,
    filiere: "Maïs certifié & Légumineuses",
  },
  {
    id: "maraitogo_aneho",
    name: "Union Maraîchère Littorale du Togo",
    zone: "Lacs & Bas-Mono",
    region: "Maritime",
    lat: 6.2278,
    lon: 1.5917,
    membres: 175,
    superficieTotaleHa: 130,
    filiere: "Maraîchage de contre-saison & Vivrier",
  },
];

export function getRegionForCoordinates(lat: number, lon: number): string {
  if (lat >= 10.1) return "Savanes";
  if (lat >= 9.1) return "Kara";
  if (lat >= 8.1) return "Centrale";
  if (lat >= 6.7) return "Plateaux";
  return "Maritime";
}
