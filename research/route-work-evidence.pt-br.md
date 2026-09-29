# De onde vêm os padrões do route-work

[English](route-work-evidence.md)

Alimenta a tabela de roteamento que a skill `route-work`, do plugin `delegation`, traz como padrão.
Expira quando essa tabela mudar uma linha, ou quando uma medição nova cobrir uma linha que esta página
marca como prior ou hipótese.

**A resposta.** A tabela de modelo e effort vem de medição de uso real:

- 6 das 12 linhas foram decididas por experimento pareado com gabarito escrito antes das execuções.
- 5 repousam em delegações reais verificadas, sem braço de comparação.
- 1 é definição.

O argumento de custo por trás dos conselhos de topologia também é medido. Os conselhos para o loop
principal são outro caso. Eles partem de um comportamento de cache medido, mas a ordem de preferência e a
escolha do modelo inicial são hipóteses que nenhum experimento testou. Cada linha repousa em amostra
pequena: 2 ou 3 tarefas por forma de trabalho. Confiança: **moderada**.

> **Atribuição.** Achados externos são **linkados inline na primeira menção**. Tudo o que não tem link é
> análise do autor: a classificação de cada recomendação em medida, prior ou hipótese, e todas as
> contagens, razões e percentuais.

## Termos

- **Delegação**: trabalho que a sessão principal entrega a um subagente, ou a um agente dentro de um
  workflow multiagente.
- **Loop principal**: a sessão que o usuário abriu e com a qual conversa. O modelo dela é escolhido ao
  abrir.
- **Effort**: quanto raciocínio se pede ao modelo (`low · medium · high · xhigh · max`).
- **Gate**: uma verificação com passa ou falha claro: um build, uma suíte de testes, uma revisão
  adversarial.
- **Experimento pareado**: uma tarefa rodada em dois ou mais braços, cada braço um par de modelo e
  effort. Cada braço roda numa sessão headless limpa, e um juiz cego pontua o resultado contra um gabarito
  escrito antes da execução.
- **Prior**: afirmação tirada de fonte publicada, como documentação ou benchmark do fornecedor, e não
  medida aqui.

## A tabela de modelos, linha por linha

Os custos são **relativos**. O uso rodou numa assinatura, então nenhum valor em dólar foi cobrado. Cada
razão abaixo é contagem de tokens precificada pela tabela do fornecedor, com leitura e escrita de cache
contabilizadas, comparada entre braços.

| Linha | Padrão | Tipo | Evidência |
|---|---|---|---|
| Enumerar, grep, contar | sem agente | definição | Trabalho determinístico, feito no loop principal por definição |
| Transcrição literal, conversão de formato | `haiku` | uso real, sem comparação | Os dados voltaram idênticos byte a byte. A prosa que ele devia só mover foi parafraseada, e uma das paráfrases introduziu um erro factual |
| Localizar arquivos, ler trechos | `sonnet` `medium` | pareado | Sonnet 5 e Opus 5.5 com 2/2 cada; o Opus a 1,4× o custo por acerto. O Haiku 4.5 igualou o Sonnet 5 em 3 tarefas de busca (9/9 itens do gabarito cada) a 86 % do custo, com o dobro de turnos. Em uso real anterior, o Sonnet não errou em 9 buscas; um Opus herdado errou 2 em 51 e levou o dobro do tempo |
| Traduzir, amostrar, escrever fixtures, auditar contra um template | `sonnet` `medium` | uso real, sem comparação | Cerca de 27 delegações sem retrabalho. Nenhuma registrou o nível de effort |
| Corrigir um doc contra o código, com `file:line` dado | `sonnet` `medium` | pareado | Sonnet 5 com 2/2 a 54 % do custo do Opus 5.5 (também 2/2). O Opus em `low` fez 1/2 |
| Classificar numa taxonomia fechada | `opus` `low` | pareado | 35 itens. O Opus 5.5 `low` foi o único braço claramente acima da linha de base da classe majoritária. O Sonnet 5 ficou no limite, à metade do custo. O Haiku 4.5 ficou abaixo da linha de base, a cerca do custo do Opus e 12× o tempo |
| Ficha com `file:line` | `opus` `medium` | pareado, contestado | Opus 5.5 com 2/2. Sonnet 5 com 1/2, com duas afirmações falsas. O custo por acerto empatou. Várias delegações reais tiveram o Sonnet segurando essa forma |
| Revisão adversarial de um diff | `opus` `medium` | pareado | Sonnet 5 com 0/2: achou os defeitos plantados, mas fez uma afirmação falsa em cada revisão. Opus 5.5 em `medium` e em `low`, ambos 2/2. Em mais 3 tarefas de revisão, `medium` igualou `xhigh` (3/3) a 56 % do custo; `low` fez 2/3 |
| Implementação de arquivo único | `sonnet` `medium` atrás de um gate | uso real, sem comparação | 7 delegações seguraram atrás de uma suíte de testes. Em 2 delas o gate ficou verde e uma revisão ainda achou defeitos bloqueadores |
| Reproduzir um bug; mudança transversal | `opus` `medium` atrás de um gate | pareado (reproduzir) | `medium` igualou `xhigh` (3/3) a 72 % do custo; `low` fez 2/3 |
| Desenho, com a spec inteira no prompt | `opus` `high` | uso real, modelo anterior | 12/12 no Opus 5, contra 4 erros em 9 de um planejador que herdou o modelo. Ainda não medido no Opus 5.5 |
| Contestar a premissa | loop principal ou `opus` `high` | uso real | 4 delegações, uma delas no Opus 5.5 `high`. Nada mede a metade do loop principal |

## O resto da skill

**Onde o trabalho roda: o argumento de custo é medido.** Um censo cobriu 25 execuções de workflow
multiagente, com 194 agentes. Ele achou três coisas:

- **O modelo move o custo mais do que a largura.** Um agente Opus 5 custou 7,9× um agente Sonnet 5. Duas
  execuções da mesma forma diferiram 6,6×: 12 agentes Opus contra 13 agentes Sonnet.
- **Agentes longos são caros.** Os que passaram de 20 minutos foram 5 % dos agentes e 11 % do gasto, e é
  por isso que a skill corta trabalho longo em checkpoints.
- **Agentes de comando fixo são desperdício.** Os que só rodavam um comando fixo muitas vezes não
  produziram saída nenhuma.

Os degraus da escada e as três restrições do teste de alargamento vêm do
[sistema de pesquisa multiagente da Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)
e de [Building multi-agent systems: when and how to use them](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them).
A ordem entre eles é análise do autor.

**Subir capacidade no loop principal: o custo de cada movimento é medido; a ordem preferida é
hipótese.**

- **Trocar o effort:** no Opus 5.5 e no Fable 5.1, uma troca limpa de effort leu 99 % do contexto do
  cache. No Opus 5 leu 7 %, e no Sonnet 5 nada.
- **Trocar o modelo:** trocar para um modelo novo deixou o cache frio em 65 % das trocas. Voltar para um
  modelo já usado deixou o cache frio em 91 %. A
  [documentação de prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
  explica por quê: cada modelo tem o próprio cache, e a busca por uma entrada anterior recua um número
  limitado de blocos.

A partir desses custos, a skill recomenda subir primeiro pelo effort, depois delegando, e trocar de
modelo só enquanto o contexto é curto, e sugere um modelo inicial. Nem a ordem nem o modelo inicial foram
testados como forma de trabalhar.

**O escalonamento é medido em parte.**

- **Medido:** `medium` igualou `xhigh` nas seis tarefas de reproduzir e revisar.
- **Prior:** o degrau `high` vem da escada de effort que o fornecedor publicou para o Opus 5.5.
- **Decisão do autor:** voltar ao loop principal quando `xhigh` falha. O fornecedor recomenda trocar para
  o Fable 5.1.
- **Um escalonamento registrado:** no único escalonamento registrado em uso real, quem o disparou foi uma
  revisão; o gate de testes tinha ficado verde.

**"Nunca rotear um subagente acima do Opus" é um prior de preço e benchmark.** A
[página de lançamento do Opus 5.5](https://www.anthropic.com/claude-opus-5-5) o põe igual ou acima do
Fable 5.1 nos benchmarks que lista. Seus tokens de entrada e saída custam 40 % dos do Fable; a leitura de
cache custa 80 %.

**A primeira execução de uma skill nova vai para um subagente cego: medido em uso, sem controle.** As
execuções cegas acharam defeitos que o autor não tinha visto: 3 num caso, 17 lacunas em outro. Nenhuma
execução do próprio autor foi comparada com elas.

## Onde a skill diz mais do que a evidência

- **Ficha no Opus** repousa em 2 tarefas a custo empatado, enquanto delegações reais tiveram o Sonnet
  segurando.
- **Revisão:** o braço mais barato que passou foi o Opus em `low`. O `medium` ficou porque segurou em
  mais três tarefas.
- **Classificação:** o Sonnet também passou no eixo principal, no limite.
- **Custo por agente:** o 7,9× compara Opus 5 com Sonnet 5. Com o Opus 5.5, a razão por token é cerca de
  1,5×. O conselho de trocar o modelo antes de alargar continua valendo, com margem menor: só a largura
  moveu o custo por execução cerca de 4× entre as faixas de 1–4 e de 9–12 agentes.
- **Escalonamento:** a skill diz que o gate o dispara; em uso real, quem disparou foi uma revisão.
- **Modelo inicial:** a seção do loop principal dá como conselho o que a evidência sustenta como
  hipótese.

## Como isto foi medido

Os dados de roteamento cobrem cerca de dois meses de uso do próprio autor, medidos por vários
instrumentos:

- **Censos sobre transcripts de sessão.** Cerca de 400 delegações e cerca de 200 sessões com seis
  mensagens ou mais. As janelas dos censos se sobrepõem, então as contagens não são somadas.
- **Um registro de delegações reais,** cada uma verificada pela sessão que a despachou.
- **Experimentos pareados:** 17 tarefas e 48 execuções sobre código de vários repositórios, mais uma
  rodada de classificação de 35 itens rotulados à mão, em 3 braços.

Cada braço de experimento rodou numa sessão headless limpa do Claude Code. Um juiz cego Opus 5.5 pontuou
cada resultado contra um gabarito escrito antes das execuções.

Cada número desta página foi rastreado até a medição que o produziu, e quatro foram conferidos de novo à
mão.

## Rejeitado, e o que reabriria

- **Publicar custos absolutos.** O uso rodou numa assinatura, então um valor em dólar a preço de tabela
  descreveria um gasto que não aconteceu. Reabre se uma medição rodar em uso de API cobrado.
- **Um total único entre instrumentos.** As janelas se sobrepõem, e uma soma conta a mesma delegação mais
  de uma vez. Reabre com um censo único, deduplicado por id de agente.
- **Marcar a origem de cada linha dentro da skill.** A skill traz a tabela como padrão para ajustar, e
  esta página carrega a proveniência. Reabre quando uma linha mudar.

## Em aberto

- Nenhuma linha tem mais de 3 tarefas pareadas por forma, nem mais de uma execução por braço.
- As tarefas e os gabaritos foram escritos pelo Opus 5.5 e julgados pela mesma família de modelos.
- Nenhum experimento rodou dentro de um subagente. Levar resultados de sessões headless para subagentes
  é uma suposição.
- Três coisas ainda não têm medição: o Opus 5.5 em `high`, o desenho no Opus 5.5 e o custo, em tokens, de
  uma troca de modelo no loop principal.
- As hipóteses do loop principal não foram rodadas como experimento.
