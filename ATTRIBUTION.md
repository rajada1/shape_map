# Map data attribution

- Natural Earth 50m admin-0 cultural (manifest date 2025-02-01): public domain, downloaded from https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip.
- IBGE UFs (manifest date 2025-02-01): https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&intrarregiao=UF&qualidade=intermediaria, intermediate quality; names from https://servicodados.ibge.gov.br/api/v1/localidades/estados. The geometry was simplified with a 0.6 view-box-unit tolerance, topology-preserving keep-shapes, and quantized to a 0.25 view-box-unit grid.
- IBGE municipalities (manifest date 2025-02-01): https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&intrarregiao=municipio&qualidade=intermediaria, intermediate quality; names from https://servicodados.ibge.gov.br/api/v1/localidades/municipios. Simplified and quantized like the UFs; distributed only as the optional example asset example/assets/maps/brazil_municipalities.smap, not inside lib/.
- Source credit: "Fonte: IBGE" must accompany apps that display the Brazilian layers. Confirm the current IBGE terms of use before commercial distribution.
- Build tools: mapshaper 0.7.98 (MIT), polylabel 2.1.0 (ISC). They are build-only dependencies; the Flutter package has no runtime dependency.

Kosovo is retained as XK when present. Somaliland, Northern Cyprus and other unrecognized disputed fragments are omitted in favor of their sovereign feature; Antarctica is excluded. French Guiana is merged into FR for the world map and retained as GF in regional maps.
