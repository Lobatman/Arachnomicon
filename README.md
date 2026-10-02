# Arachnomicon <img src="https://img.shields.io/badge/status-em%20desenvolvimento-orange" alt="status: em desenvolvimento"/>

> **⚠️ Pacote em desenvolvimento (versão 0.1.3).**
> A API, os nomes de colunas e o comportamento das funções ainda podem mudar
> sem aviso. Use com cautela e confira manualmente os resultados antes de
> usá-los em publicações. Veja também as
> [limitações conhecidas](#limitações-conhecidas).

**Arachnomicon** é um pacote R para **padronizar e atualizar nomes científicos
de aranhas** em tabelas de dados (planilhas de coleta, listas de espécies,
bancos de ocorrência). Ele normaliza a grafia dos nomes e os confere no
[World Spider Catalog](https://wsc.nmbe.ch/) (via
[`arakno`](https://cran.r-project.org/package=arakno)) e no
[GBIF](https://www.gbif.org/) (via [`rgbif`](https://docs.ropensci.org/rgbif/)).
Para cada nome, devolve o nome aceito atual, o status taxonômico, a família,
o LSID e a chave do GBIF.

## Para que serve

Quem trabalha com listas de aranhas costuma ter dados assim:

```
"  phoneutria NIGRIVENTER"   # grafia inconsistente
"lycosa erythrognata"        # erro de digitação
"Nephila clavipes"           # combinação antiga: hoje Trichonephila clavipes
```

Corrigir isso à mão em centenas ou milhares de linhas é lento e sujeito a erro.
O Arachnomicon automatiza:

- a **normalização** da grafia (espaços, maiúsculas/minúsculas);
- a **consulta taxonômica** de cada nome único (sem repetir nomes duplicados),
  com o WSC como fonte principal e o GBIF como alternativa;
- a **atualização de sinônimos e combinações antigas** para o nome aceito;
- a **correção de pequenos erros de digitação**;
- a obtenção da **família**, do **LSID** do WSC e da chave do GBIF;
- o **cache em disco** e os **checkpoints**, para que listas grandes possam ser
  processadas em várias sessões sem refazer consultas;
- um **resumo** da qualidade da correção.

Público-alvo: aracnólogos, ecólogos e gestores de coleções que precisam
padronizar nomes de aranhas antes de análises.

## Instalação

O pacote ainda não está no CRAN. Instale a versão de desenvolvimento a partir
do GitHub:

```r
# install.packages("remotes")
remotes::install_github("Lobatman/Arachnomicon")
```

Dependências (instaladas automaticamente): `arakno`, `rgbif` e `utils`.
É necessária conexão com a internet para as consultas taxonômicas.

## Funções disponíveis

| Função | O que faz |
|---|---|
| `spp_norm()` | Normaliza a grafia de nomes científicos (remove espaços extras, gênero com inicial maiúscula, epíteto em minúsculas). Aceita vetores. Não consulta a internet. |
| `correct_taxon()` | Função principal. Recebe um `data.frame`, normaliza a coluna de espécies, consulta cada nome único no WSC e no GBIF e adiciona colunas com o resultado taxonômico. Usa cache e checkpoint em arquivos `.rds`. |
| `spider_family()` | Retorna a família de **uma** espécie (a do nome aceito, no caso de sinônimos). |
| `taxon_summary()` | Calcula métricas resumidas a partir da saída de `correct_taxon()`: nº de espécies únicas, nº de sinônimos e proporção de registros sem resolução. |

### Como cada nome é resolvido

1. O nome é consultado no **WSC** (`arakno::checkNames()`):
   - nome válido → `ACCEPTED`;
   - sinônimo ou combinação antiga → `SYNONYM`, com o nome aceito em
     `Especie_match` e `Sinonimo_de`;
   - erro de digitação de até 2 caracteres → `MISSPELLING`, com a grafia
     corrigida em `Especie_match`. Sugestões mais distantes não são aceitas,
     apenas registradas em `Observacao_taxonomia`.
2. Se o WSC não resolver o nome, usa-se o **GBIF** (`rgbif::name_backbone()`).
3. Se nenhuma das fontes resolver → `NOT_FOUND`, com `Especie_match` igual a `NA`.

### Colunas adicionadas por `correct_taxon()`

| Coluna | Conteúdo |
|---|---|
| `Especie_normalizada` | Nome com grafia padronizada por `spp_norm()` |
| `Especie_match` | Nome aceito atual (`NA` se não encontrado) |
| `Fonte_taxonomia` | Fonte do nome aceito (`"WSC/arakno"` ou `"GBIF/rgbif"`) |
| `Status_taxonomico` | `ACCEPTED`, `SYNONYM`, `MISSPELLING`, `NOT_FOUND` ou outro status do GBIF |
| `Sinonimo_de` | Nome aceito, quando o nome informado é sinônimo |
| `LSID` | LSID do WSC para o nome aceito |
| `GBIF_usageKey` | Chave do nome informado no GBIF |
| `Confianca_match` | Confiança do *match* no GBIF (0–100) |
| `Observacao_taxonomia` | Observações do processo de resolução |
| `Familia` | Família (apenas com `include_family = TRUE`) |
| `LSID_input` | LSID fornecido pelo usuário (apenas com `col_lsid`) |

O resultado também traz os atributos `tempo_execucao_seg`, `nomes_unicos` e
`nomes_consultados`.

## Demonstração

A demonstração abaixo foi executada com a versão atual do código
(R 4.6.1, `arakno` 1.3.3, `rgbif` 3.8.5). Os resultados vêm de consultas reais
e podem mudar conforme o WSC e o GBIF forem atualizados.

### 1. Normalizando nomes

```r
library(Arachnomicon)

spp_norm(c("   ACTINOPUS   ANSELMOI ", "LOXOSCELES intermedia", NA))
#> [1] "Actinopus anselmoi"    "Loxosceles intermedia" NA
```

### 2. Corrigindo uma tabela de ocorrências

Uma planilha de campo típica, com grafia inconsistente, um erro de digitação
(*Lycosa erythrognata*), uma combinação antiga (*Nephila clavipes*) e um nome
inexistente:

```r
ocorrencias <- data.frame(
  Ponto   = c("P1", "P1", "P2", "P3", "P3", "P4"),
  Especie = c("  phoneutria NIGRIVENTER", "Loxosceles intermedia",
              "lycosa erythrognata", "Nephila clavipes",
              "actinopus   anselmoi", "Aranhus inventadus")
)

res <- correct_taxon(ocorrencias, include_family = TRUE, verbose = FALSE)
#> Retrieving latest data from the World Spider Catalogue...

res[, c("Especie", "Especie_match", "Fonte_taxonomia",
        "Status_taxonomico", "Familia")]
#>                    Especie          Especie_match Fonte_taxonomia Status_taxonomico       Familia
#> 1   phoneutria NIGRIVENTER Phoneutria nigriventer      WSC/arakno          ACCEPTED      Ctenidae
#> 2    Loxosceles intermedia  Loxosceles intermedia      WSC/arakno          ACCEPTED    Sicariidae
#> 3      lycosa erythrognata   Lycosa erythrognatha      WSC/arakno       MISSPELLING     Lycosidae
#> 4         Nephila clavipes Trichonephila clavipes      WSC/arakno           SYNONYM     Araneidae
#> 5     actinopus   anselmoi     Actinopus anselmoi      WSC/arakno          ACCEPTED Actinopodidae
#> 6       Aranhus inventadus                   <NA>            <NA>         NOT_FOUND          <NA>
```

Em uma única chamada, o pacote:

- corrigiu a grafia de todos os nomes;
- corrigiu o erro de digitação em *Lycosa erythrognatha*;
- atualizou *Nephila clavipes* para *Trichonephila clavipes*;
- adicionou a família de cada espécie;
- marcou como `NOT_FOUND` o nome que não existe, em vez de forçar uma
  correspondência.

Também foram preenchidos os identificadores de cada nome:

```r
res[, c("Especie_match", "LSID", "GBIF_usageKey", "Confianca_match")]
#>            Especie_match                             LSID GBIF_usageKey Confianca_match
#> 1 Phoneutria nigriventer urn:lsid:nmbe.ch:spidersp:020787       2152822              99
#> 2  Loxosceles intermedia urn:lsid:nmbe.ch:spidersp:002700       5170653              99
#> 3   Lycosa erythrognatha urn:lsid:nmbe.ch:spidersp:018239       5169305              96
#> 4 Trichonephila clavipes urn:lsid:nmbe.ch:spidersp:013943       2149478              98
#> 5     Actinopus anselmoi urn:lsid:nmbe.ch:spidersp:052433      11377509              99
#> 6                   <NA>                             <NA>          <NA>            <NA>
```

A coluna `Observacao_taxonomia` explica o que foi feito em cada caso:

```r
res[c(3, 4, 6), c("Especie_normalizada", "Observacao_taxonomia")]
#>   Especie_normalizada                                         Observacao_taxonomia
#> 3 Lycosa erythrognata  WSC: grafia corrigida para Lycosa erythrognatha (distância 1)
#> 4    Nephila clavipes                                     WSC: Nomenclature change
#> 6  Aranhus inventadus  WSC: nome não encontrado (sugestão mais próxima: Araneus argentatus);
#>                        GBIF: sem correspondência em nível de espécie (matchType = NONE)
```

Os resultados ficam salvos em `cache_taxonomia_aranhas.rds`. Ao rodar de novo,
nenhum nome é consultado outra vez:

```r
res2 <- correct_taxon(ocorrencias)
#> Iniciando resolução taxonômica: 0 nomes únicos pendentes.
attr(res2, "nomes_consultados")
#> [1] 0
```

### 3. Família de uma espécie

```r
spider_family("Phoneutria nigriventer")
#> [1] "Ctenidae"

spider_family("Nephila clavipes")   # sinônimo: família do nome aceito
#> [1] "Araneidae"
```

### 4. Resumo da correção

```r
taxon_summary(res)
#>   n_especies_unicas n_sinonimos_corrigidos taxa_erro
#> 1                 5                      1 0.1666667
```

Cinco espécies válidas, um sinônimo atualizado e um registro em seis (16,7%)
sem resolução.

### 5. Listas grandes

Para milhares de nomes, ajuste a pausa entre consultas e a frequência de
salvamento. Se a execução for interrompida, basta chamar a função de novo com
os mesmos arquivos: ela retoma a partir do checkpoint.

```r
res <- correct_taxon(
  minha_planilha,
  col_species     = "Especie",
  cache_file      = "cache_aranhas.rds",
  checkpoint_file = "checkpoint_aranhas.rds",
  batch_size      = 50,   # salva a cada 50 consultas
  sleep_s         = 0.5   # pausa entre consultas (limite de requisições)
)
```

## Limitações conhecidas

- Na primeira consulta de cada sessão, o `arakno` baixa a tabela completa do
  WSC e a guarda no ambiente global do R como `wscData`.
- O WSC só confere nomes de até duas palavras. Subespécies e nomes com
  qualificadores que o `arakno` não remove (ex.: `"sp."`) são resolvidos apenas
  pelo GBIF.
- O limite de 2 caracteres para aceitar uma correção de grafia é fixo. Erros de
  digitação maiores aparecem como `NOT_FOUND`, com a sugestão do WSC em
  `Observacao_taxonomia`.
- `spider_family()` processa um nome por vez. Para muitos nomes, use
  `correct_taxon(..., include_family = TRUE)`, que aproveita o cache.
- Os arquivos de cache e checkpoint são gravados, por padrão, no diretório de
  trabalho atual.
- A documentação das funções está em português; a descrição do pacote
  (`DESCRIPTION`), em inglês.

## Contribuindo

Sugestões, relatos de erro e *pull requests* são bem-vindos em
<https://github.com/Lobatman/Arachnomicon/issues>.

## Licença

GPL (>= 3). Veja [LICENSE.md](LICENSE.md).

## Autor

Victor Lobato dos Santos
