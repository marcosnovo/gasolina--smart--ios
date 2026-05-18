// Static metadata about supported countries.
// Mirrors COUNTRY_INFO in the Bun backend's src/index.ts.

export interface CountryInfo {
  displayName: string;
  currency: string;
  currencySymbol: string;
  supportedFuels: string[];
  dataFreshness: string;
  attribution: { text: string; url: string; license: string };
}

export const COUNTRY_INFO: Record<string, CountryInfo> = {
  ES: {
    displayName: "España",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["gasolina95", "gasolina98", "dieselA", "dieselPremium", "glp"],
    dataFreshness: "within1hour",
    attribution: {
      text: "Ministerio para la Transición Ecológica y el Reto Demográfico",
      url: "https://geoportalgasolineras.es",
      license: "Reutilización libre",
    },
  },
  GB: {
    displayName: "United Kingdom",
    currency: "GBP",
    currencySymbol: "£",
    supportedFuels: ["e10", "e5", "gasolina98", "dieselA", "dieselPremium"],
    dataFreshness: "within30min",
    attribution: {
      text: "Crown copyright. Source: Fuel Finder, operated by VE3 Global Ltd under the Motor Fuel Price (Open Data) Regulations 2025",
      url: "https://developer.fuel-finder.service.gov.uk",
      license: "Open Government Licence v3.0",
    },
  },
  FR: {
    displayName: "France",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e10", "e5", "gasolina98", "dieselA", "e85", "glp"],
    dataFreshness: "within1hour",
    attribution: {
      text: "Licence Ouverte / Open Licence. Source: data.economie.gouv.fr",
      url: "https://data.economie.gouv.fr",
      license: "Licence Ouverte v2.0",
    },
  },
  DE: {
    displayName: "Deutschland",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e5", "e10", "dieselA"],
    dataFreshness: "realtime",
    attribution: {
      text: "Spritpreis-Daten von Tankerkönig, lizenziert unter CC BY 4.0",
      url: "https://creativecommons.tankerkoenig.de",
      license: "CC BY 4.0",
    },
  },
  IT: {
    displayName: "Italia",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e5", "gasolina98", "dieselA", "dieselPremium", "glp", "gnc"],
    dataFreshness: "daily",
    attribution: {
      text: "Ministero delle Imprese e del Made in Italy (MIMIT)",
      url: "https://www.mimit.gov.it/it/open-data/elenco-dataset/carburanti-prezzi-praticati-e-anagrafica-degli-impianti",
      license: "IODL 2.0",
    },
  },
  US: {
    displayName: "United States",
    currency: "USD",
    currencySymbol: "$",
    // No public station-level fuel-price feed exists in the US (EIA only
    // publishes state-weekly averages, GasBuddy has no public API). We
    // ship the US as charging-only — `supportedFuels: []` is what the
    // iOS client uses to hide the fuel UI for this country.
    supportedFuels: [],
    dataFreshness: "daily",
    attribution: {
      text: "Charging data © OpenChargeMap contributors",
      url: "https://openchargemap.org",
      license: "CC BY-SA 4.0",
    },
  },
  MX: {
    displayName: "México",
    currency: "MXN",
    currencySymbol: "$",
    // Mexico (CRE) publishes 'regular' (≈87 octanos), 'premium' (≥91)
    // and 'diesel'. We map them onto the shared fuel enum:
    //   regular → gasolina95, premium → gasolina98, diesel → dieselA.
    supportedFuels: ["gasolina95", "gasolina98", "dieselA"],
    dataFreshness: "daily",
    attribution: {
      text: "Comisión Reguladora de Energía (CRE), datos abiertos",
      url: "https://datos.gob.mx/busca/dataset/precios-vigentes-de-gasolinas-y-diesel",
      license: "Libre uso MX",
    },
  },
};

export const SUPPORTED_COUNTRIES = Object.keys(COUNTRY_INFO);
