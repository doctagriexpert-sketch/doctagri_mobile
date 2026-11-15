import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export interface EarthdataGranule {
  title: string;
  timeStart: string;
  timeEnd?: string;
  dataset: string;
  shortName: string;
  granuleUr?: string;
  cmrLink?: string;
}

export interface EarthdataResponse {
  regionCoordinates: { lat: number; lon: number };
  queriedAt: string;
  source: string;
  smapGranule: EarthdataGranule | null;
  ecostressGranule: EarthdataGranule | null;
  error?: string;
}

export async function GET(request: NextRequest) {
  const lat = Number(request.nextUrl.searchParams.get("lat"));
  const lon = Number(request.nextUrl.searchParams.get("lon"));

  if (
    !request.nextUrl.searchParams.has("lat") ||
    !request.nextUrl.searchParams.has("lon") ||
    !Number.isFinite(lat) ||
    !Number.isFinite(lon) ||
    Math.abs(lat) > 90 ||
    Math.abs(lon) > 180
  ) {
    return NextResponse.json({ error: "Coordonnées invalides" }, { status: 400 });
  }

  try {
    const fetchGranules = async (shortName: string, datasetName: string): Promise<EarthdataGranule | null> => {
      const cmrUrl = `https://cmr.earthdata.nasa.gov/search/granules.json?short_name=${encodeURIComponent(
        shortName
      )}&point=${lon},${lat}&sort_key=-start_date&page_size=1`;

      const res = await fetch(cmrUrl, {
        headers: {
          "User-Agent": "TerraOrbit-Togo-NASA-SpaceApps/1.0",
        },
        signal: AbortSignal.timeout(8000),
        next: { revalidate: 3600 },
      });

      if (!res.ok) {
        return null;
      }

      const json = await res.json();
      const entries = json?.feed?.entry ?? [];
      if (!entries.length) return null;

      const e = entries[0];
      const links = e.links ?? [];
      const httpLink = links.find((l: { href?: string }) => l.href?.startsWith("http"))?.href;

      return {
        title: e.title ?? "Granule non titré",
        timeStart: e.time_start ?? "",
        timeEnd: e.time_end ?? "",
        dataset: datasetName,
        shortName,
        granuleUr: e.id,
        cmrLink: httpLink || `https://cmr.earthdata.nasa.gov/search/concepts/${e.id}`,
      };
    };

    const [smap, ecostress] = await Promise.all([
      fetchGranules("SPL3SMP_E", "NASA SMAP L3 Enhanced Radiometer Soil Moisture (9 km)"),
      fetchGranules("ECO_L2T_LSTE", "NASA ECOSTRESS L2T LST & Emissivity (70 m)"),
    ]);

    const result: EarthdataResponse = {
      regionCoordinates: { lat, lon },
      queriedAt: new Date().toISOString(),
      source: "NASA EOSDIS Common Metadata Repository (CMR)",
      smapGranule: smap,
      ecostressGranule: ecostress,
    };

    return NextResponse.json(result);
  } catch (err) {
    return NextResponse.json(
      {
        error: err instanceof Error ? err.message : "Erreur de connexion NASA Earthdata",
        smapGranule: null,
        ecostressGranule: null,
      },
      { status: 502 }
    );
  }
}
