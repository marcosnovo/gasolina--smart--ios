import { fetchFromMinisterio } from "./fetcher";

console.log("Fetching stations from Ministerio API...");
const result = await fetchFromMinisterio();
console.log(`Done: ${result.count} stations in ${result.duration}ms`);
process.exit(0);
