# SMAP v2

SMAP é o formato binário embutido usado pelo `shape_map`. Todos os valores são little-endian.

## Cabeçalho

`SMAP` (4 bytes), versão `u8` (2), `viewBox.width`, `viewBox.height` e escala de quantização (`f32`), contagem de regiões em varint sem sinal e flags (`u8`: bit 0 = `innerBorders`, bit 1 = `outline`). A escala representa unidades do viewBox por passo inteiro.

## Tabela de strings

Uma contagem em varint sem sinal seguida por entradas com comprimento UTF-8 em varint e bytes UTF-8. IDs e nomes de cada região referenciam esta tabela por índices em varint sem sinal.

## Regiões e linhas

Cada região contém id e nome (índices varint), bbox (`i32` x4), âncora (`i32` x2), contagem de anéis em varint e cada anel com contagem de pontos em varint. O primeiro ponto do anel é absoluto e os seguintes são deltas; cada coordenada é codificada como varint zigzag. Os anéis são implicitamente fechados.

Streams opcionais usam a mesma codificação, mas representam polylines abertas. `innerBorders` contém somente arestas compartilhadas por exatamente duas regiões, encadeadas em polylines longas; `outline` contém somente arestas usadas uma vez no contorno exterior, também encadeadas. A decodificação valida magic, versão, limites, strings, contagens e varints antes de montar geometrias lazy.

A decodificação pesada pode ser executada em `Isolate.run` por `ShapeMapData.decode(ByteData)`. Os mapas gerados guardam apenas uma string base64 constante e só são decodificados quando o getter correspondente de `ShapeMaps` é acessado.

## Implementação do decoder

O formato permanece SMAP v2. O decoder atual lê cada stream em um único passe e materializa buffers planos (`Int32List` para coordenadas, bboxes e âncoras; `Uint32List` para offsets), mantendo as geometrias como views sem copiar anéis. A decodificação assíncrona transfere esses buffers entre isolates; `Path` só é criado na primeira pintura/hit-test.
