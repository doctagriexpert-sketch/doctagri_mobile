"use client";

import React, { useState } from "react";
import {
  ClimateCreditScorer,
  ParametricInsuranceEngine,
  CreditEvaluationResult,
  InsuranceClaimResult,
} from "@/lib/simulationEngine";

interface InstitutionalTabProps {
  resilienceScore: number;
  pawPercent: number;
  regionName: string;
}

function decisionTone(code: string): "good" | "warn" | "bad" {
  if (code === "GREEN_LIGHT") return "good";
  if (code === "ORANGE_LIGHT") return "warn";
  return "bad";
}

export const InstitutionalTab: React.FC<InstitutionalTabProps> = ({
  resilienceScore,
  pawPercent,
  regionName,
}) => {
  const [requestedAmount, setRequestedAmount] = useState<number>(250000);
  const [smapAnomaly, setSmapAnomaly] = useState<number>(-32);
  const [ecostressAnomaly, setEcostressAnomaly] = useState<number>(3.4);
  const [droughtDays, setDroughtDays] = useState<number>(16);
  const [insuredCapital] = useState<number>(200000);
  const [operator] = useState<string>("T-Money (Togocom)");
  const [farmerPhone] = useState<string>("+228 90 24 58 11");

  const creditEval: CreditEvaluationResult = ClimateCreditScorer.evaluateLoanApplication(
    resilienceScore,
    pawPercent,
    requestedAmount
  );

  const insuranceResult: InsuranceClaimResult = ParametricInsuranceEngine.evaluateClaimTrigger(
    smapAnomaly,
    ecostressAnomaly,
    droughtDays,
    insuredCapital,
    farmerPhone,
    operator
  );

  const tone = decisionTone(creditEval.decisionCode);

  return (
    <div className="stack">
      <section className="panel">
        <div className="panel-head">
          <div>
            <h2>Scénarios de crédit</h2>
            <p className="lede">
              Règles hypothétiques pour {regionName}. Aucun organisme n’a validé ces scores,
              aucune garantie n’est accordée.
            </p>
          </div>
          <span className="tag">Sans garantie réelle</span>
        </div>

        <label className="slider-block" style={{ marginBottom: "1rem" }}>
          <span className="slider-top">
            <span>Montant demandé par hectare</span>
            <strong className="num">{requestedAmount.toLocaleString("fr-FR")} FCFA</strong>
          </span>
          <input
            type="range"
            min={100000}
            max={1000000}
            step={25000}
            value={requestedAmount}
            onChange={(event) => setRequestedAmount(Number(event.target.value))}
          />
        </label>

        <div className="figures">
          <article>
            <h3>Défaut de référence</h3>
            <p className="tone-bad">{creditEval.tauxDefautHistoriquePct}%</p>
            <p className="fine">Hypothèse fixe de 22,5 %</p>
          </article>
          <article>
            <h3>Défaut simulé</h3>
            <p className="tone-good">{creditEval.tauxDefautProjetePct}%</p>
            <p className="fine">Écart de {creditEval.reductionRisquePct} points</p>
          </article>
          <article>
            <h3>Taux proposé</h3>
            <p>{creditEval.tauxInteretRecommandePct}%</p>
            <p className="fine">Référence affichée : 16,5 %</p>
          </article>
          <article>
            <h3>Écart théorique</h3>
            <p>
              {creditEval.perteFinanciereEviteeFcfa.toLocaleString("fr-FR")}
              <span style={{ fontSize: "0.8rem", fontWeight: 500 }}> FCFA</span>
            </p>
            <p className="fine">Hypothèse non validée</p>
          </article>
        </div>

        <div className="decision">
          <div>
            <h3 className={`tone-${tone}`}>{creditEval.statutCredit}</h3>
            <p>{creditEval.avisAnalysteMifa}</p>
          </div>
          <div className="amount">
            <span>Montant simulé</span>
            <strong className="num">{creditEval.montantAccordeFcfa.toLocaleString("fr-FR")} FCFA</strong>
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panel-head">
          <div>
            <h2>Assurance paramétrique</h2>
            <p className="lede">
              Démonstration à partir des anomalies saisies. Capital assuré de{" "}
              {insuredCapital.toLocaleString("fr-FR")} FCFA, opérateur {operator}, numéro{" "}
              {farmerPhone}. Aucun contrat ni paiement.
            </p>
          </div>
          <span className="tag">Démonstration</span>
        </div>

        <div className="sliders">
          <label>
            <span className="slider-top">
              <span>Anomalie d’humidité</span>
              <strong className={`num ${smapAnomaly <= -25 ? "tone-bad" : ""}`}>
                {smapAnomaly}%
              </strong>
            </span>
            <input
              type="range"
              min={-60}
              max={20}
              step={1}
              value={smapAnomaly}
              onChange={(event) => setSmapAnomaly(Number(event.target.value))}
            />
            <span className="fine">Seuil de déclenchement : −25 %</span>
          </label>
          <label>
            <span className="slider-top">
              <span>Anomalie de température</span>
              <strong className={`num ${ecostressAnomaly >= 2.5 ? "tone-bad" : ""}`}>
                {ecostressAnomaly > 0 ? "+" : ""}
                {ecostressAnomaly} °C
              </strong>
            </span>
            <input
              type="range"
              min={-2}
              max={6}
              step={0.1}
              value={ecostressAnomaly}
              onChange={(event) => setEcostressAnomaly(Number(event.target.value))}
            />
            <span className="fine">Seuil de déclenchement : +2,5 °C</span>
          </label>
          <label>
            <span className="slider-top">
              <span>Jours de stress</span>
              <strong className={`num ${droughtDays >= 14 ? "tone-bad" : ""}`}>{droughtDays} j</strong>
            </span>
            <input
              type="range"
              min={1}
              max={30}
              step={1}
              value={droughtDays}
              onChange={(event) => setDroughtDays(Number(event.target.value))}
            />
            <span className="fine">Seuil de déclenchement : 14 jours</span>
          </label>
        </div>

        {insuranceResult.sinistreDeclenche ? (
          <div className="claim">
            <header>
              <strong className="tone-good">{insuranceResult.statutIndemnisation}</strong>
              <span className="num">{insuranceResult.montantIndemniseFcfa.toLocaleString("fr-FR")} FCFA</span>
            </header>
            <p className="sms">{insuranceResult.smsTransaction}</p>
          </div>
        ) : (
          <div className="claim">
            <header>
              <strong>{insuranceResult.statutIndemnisation}</strong>
              <span>Aucun versement</span>
            </header>
          </div>
        )}
      </section>
    </div>
  );
};
