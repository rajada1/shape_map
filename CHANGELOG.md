## 0.2.0

* Adiciona animação de entrada configurável para regiões e marcadores (`fade`, `grow`, `stagger` e `draw`), com controller interno ou externo.
* `draw` traça o contorno com `drawColor`/`drawWidth` configuráveis e faz a transição para a borda final.
* Adiciona controles de reprodução, reversão, pausa, reset, replay, duração, estilo e ordem ao app de exemplo.

## 0.1.1

* Separa animações de dados, marcadores e highlight, preservando o estado interpolado ao interromper uma transição.
* Evita rebuild da árvore do mapa em hover/seleção; somente o tooltip é reconstruído.
* Adiciona `MapDefinition.regionById`/`indexOf`, igualdade por conteúdo nos modelos e igualdade nos estilos.
* Adiciona `MapMarkerData.showLabel` e suporte a marcador sem texto; `MapRegionData.label` passa a ser usado no tooltip.
* Faz cache de bordas em `ui.Picture`, caminhos transformados e layouts de texto dos marcadores.
* Corrige seleção fora das regiões, posição de tooltip com override de marcador e largura de borda sem hacks por mapa.
* Atualiza o exemplo para reproduzir os dois SVGs de referência e adiciona regressões e goldens.

## 0.1.0

* Adiciona mapas embutidos da América do Sul e das 27 UFs brasileiras.
* Adiciona widget interativo com cores por região, hit-test, seleção, hover e tooltip.
* Adiciona marcadores com escala linear, overrides e animações nativas.
* Adiciona gerador offline determinístico e testes de parser, geometria, layout e widgets.
