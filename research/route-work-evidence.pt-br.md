# O que dá suporte à recomendação de modelos do route-work?

[English](route-work-evidence.md)

***Expira quando** houver novas medições, respostas às hipóteses ou revisão das afirmações externas não
medidas; no lançamento do Sonnet 5.5 e do Haiku 5.5; ou com novas recomendações da Anthropic.*

**A resposta.** A recomendação de modelos do `route-work` se apoia em 391 leituras do uso do autor,
tomadas até a hora em que a tabela foi escrita: 241 delegações reais verificadas (trabalho entregue a um subagente e conferido antes de ser aceito) e
150 testes pareados com gabarito — cada delegação ou teste é uma leitura. As leituras de uso real mostram que o modelo escolhido funciona em quatro formas de trabalho —
implementação, revisão, localização e tradução. Os testes que comparam um modelo com outro têm 2 a 5
tarefas por braço, e por isso a escolha entre Sonnet e Opus é a parte menos firme. Confiança **moderada**,
para a `route-work` como um todo.

> **Atribuição.** Achados externos são **linkados inline na primeira menção**. Tudo o que não tem link é
> análise do autor: a classificação de cada recomendação, todas as contagens, tokens e razões.

## Por que esta pesquisa existe

O `route-work` responde a uma pergunta que aparece toda vez que um agente de código trabalha: quem faz
isto, onde, e com quanto raciocínio (o effort, de `low` a `max`)? A pergunta vai além dos subagentes. Ela também decide se o trabalho
fica na sessão principal — o loop principal, a conversa que o usuário abriu —, vai para um subagente ou para um Workflow com vários agentes, e como a sessão
principal sobe de capacidade quando o trabalho aperta. A skill traz uma tabela pronta — Sonnet para
localizar e corrigir, Opus para revisar e reproduzir, Haiku só para cópia mecânica — e convida quem a
instala a trocar cada linha pela evidência do próprio uso. Na versão publicada, toda linha diz apenas
`shipped default`.

Esta pesquisa conta o que havia por trás de cada recomendação quando ela foi escrita. A maior parte é
observação: uso real e testes lado a lado. Onde os números não bastavam, a recomendação veio de fontes
publicadas (os priors) e de estudos anteriores do autor. O Opus 5.5 começar em `medium` é um exemplo: `medium` é o
padrão que a Anthropic definiu para o modelo e o primeiro degrau da escada de effort que ela publicou, e
um teste confirmou que ele iguala o `xhigh` em 6 tarefas. A tabela de modelos é a parte mais medida; onde
o trabalho roda tem medição de custo; e o loop principal ainda é um piloto — o comportamento de cache foi
medido, a forma de trabalhar que a skill sugere não foi testada.

## A análise

O levantamento juntou duas famílias de leitura. Os **testes pareados** puseram a mesma tarefa diante de
modelos diferentes, com o gabarito escrito antes e um juiz cego conferindo o resultado. O **uso real** é o
trabalho do dia a dia: cada delegação que a sessão verificou antes de aceitar. As duas famílias se
completam. O teste compara modelos na mesma tarefa, mas com poucas tarefas; o uso real acumula volume, mas
quase sempre com um modelo só. Um teste que se repete de 1 a N vezes conta como uma leitura, e vale a
execução de maior teto; no uso real, cada delegação é uma leitura. Acerto, no teste, é cobrir todo o
gabarito sem nenhuma afirmação falsa; no uso real, é segurar na verificação.

Cada linha da tabela reúne três informações. À esquerda, a recomendação da skill: o modelo e o effort em
negrito, sobre o nome da tarefa. No meio, a forma de análise que a sustenta. À direita, a evidência, que
abre com uma frase contando o que as leituras mostram, segue com a contagem por modelo e fecha com os
tokens. Algumas recomendações vêm "atrás de gate": o resultado só é aceito depois de passar numa
verificação com passa/falha claro, como uma suíte de testes ou uma revisão adversarial.

A contagem por modelo traz os acertos, os erros e um rótulo que resume se a amostra basta para confiar no
modelo naquela tarefa. O rótulo sai do intervalo de Wilson a 95 % — o pior e o melhor caso compatíveis com
a amostra —, comparado com uma régua que acompanha o risco da tarefa. Onde errar custa caro, a régua é 75 %
de acerto. Na classificação, a régua é o chute: responder sempre o rótulo mais comum acerta 43 %, e um
classificador só serve se acertar mais que isso. Quando até o pior caso passa da régua, o rótulo é
**acompanhar**: o modelo segura, e basta seguir observando. Quando a régua cai dentro da margem de erro, o
rótulo é **medir mais**. Quando nem o melhor caso chega à régua, é **não usar**. E com 3 leituras ou
menos, o intervalo fica largo demais para dizer qualquer coisa: **falta análise**.

Os tokens aparecem em duas partes, com os turnos entre parênteses: o cache lido e os tokens novos
(entrada, escrita de cache e saída). A leitura de cache custa o mesmo no Opus 5.5 e no Sonnet 5 e pesa pouco
no preço, mas cresce a cada turno — quem termina em menos turnos relê menos. Os tokens novos custam no Opus
5.5 o dobro do Sonnet 5. O uso rodou numa assinatura, então o consumo aparece em tokens e nunca em
dinheiro.

## O que as leituras mostram

| Tarefa | Forma de análise | Evidência |
|---|---|---|
| **sem agente**<br>Enumerar, grep, listar, contar | definição | Trabalho determinístico, feito no loop principal.<br>0 leituras |
| **`haiku` — effort omitido**<br>`publishing:edit-applier`<br>Transcrição literal, conversão de formato | uso real | O Haiku 4.5 devolveu os dados idênticos byte a byte; a prosa que devia só mover voltou parafraseada, com um erro factual.<br>2 leituras: Haiku 4.5 2 (1 acerto nos dados, 1 erro na prosa; falta análise)<br>Tokens: não registrados |
| **`sonnet — medium`**<br>`delegation:plan-scout` · `delegation:miner`<br>Localizar arquivos, ler trechos | teste pareado<br>uso real | O Sonnet 5 e o Opus 5.5 localizaram em todas as tentativas. O Haiku 4.5 empatou nos testes, mas errou 2 de 5 vezes em uso real, uma delas inventando um fato.<br>80 leituras: Sonnet 5 17 (17 acertos; acompanhar) — 8 em `medium`, 9 sem effort registrado · Opus 5.5 `medium` 2 (2; falta análise) · Opus 5.5 `low` 2 (2; falta análise) · Haiku 4.5 8 (6 acertos, 2 erros; medir mais) · Opus 5 no modelo da sessão (a delegação não nomeou o modelo e rodou no da conversa principal) 51 (49 acertos, 2 erros; acompanhar — a alternativa)<br>Tokens (cache + novos, turnos): teste com Opus — Sonnet 672 mil + 64 mil (10) · Opus `medium` 391 mil + 56 mil (9) · Opus `low` 200 mil + 42 mil (4); teste com Haiku — Sonnet 310 mil + 40 mil (10) · Haiku 935 mil + 49 mil (21); uso real — Sonnet 171 mil + 72 mil (3) · Haiku 531 mil + 65 mil (10) |
| **`sonnet — medium`**<br>Traduzir, amostrar, escrever fixtures, auditar contra template | uso real | O Sonnet 5 fez as 27 delegações sem retrabalho; nenhuma registrou o effort.<br>27 leituras: Sonnet 5 27 (27 acertos; acompanhar)<br>Tokens: não registrados |
| **`sonnet — medium`**<br>Corrigir doc contra o código, `file:line` dado | teste pareado<br>uso real | O Sonnet 5 acertou todas as correções, nos testes e em uso real. O Opus 5.5 `medium` também, e em `low` introduziu uma afirmação falsa.<br>9 leituras: Sonnet 5 `medium` 5 (5 acertos; medir mais) · Opus 5.5 `medium` 2 (2; falta análise) · Opus 5.5 `low` 2 (1 acerto, 1 erro; falta análise)<br>Tokens (cache + novos, turnos): Sonnet 131 mil + 38 mil (5) · Opus `medium` 156 mil + 36 mil (6) · Opus `low` 155 mil + 36 mil (6) |
| **`opus — low`**<br>Classificar em taxonomia fechada | teste pareado | O Opus 5.5 `low` ficou claramente acima do chute — responder sempre o rótulo mais comum acerta 43 % —; o Sonnet 5 passou no limite, e o Haiku 4.5 acertou tanto quanto o chute.<br>102 leituras: Opus 5.5 `low` 35 (23 acertos, 12 erros; acompanhar) · Sonnet 5 `medium` 33 (20, 13; acompanhar) · Haiku 4.5 34 (15, 19; medir mais)<br>Tokens: sem cache, um turno — Opus 1,4 mil · Sonnet 1,5 mil · Haiku 3,2 mil, e o Haiku levou 12× o tempo |
| **`opus — medium`**<br>`delegation:fact-sheet`<br>Ficha de subsistema com `file:line` | teste pareado<br>uso real | O Opus 5.5 `medium` acertou todas as fichas. O Sonnet 5 errou 1 de 2 nos testes e segurou 11 de 14 em uso real.<br>24 leituras: Opus 5.5 `medium` 5 (5 acertos; medir mais) · Opus 5.5 `low` 2 (1, 1; falta análise) · Sonnet 5 16 (12 acertos, 4 erros; medir mais) · Opus 5 `high` 1 (0, 1; falta análise)<br>Tokens (cache + novos, turnos): Opus `medium` 516 mil + 39 mil (11) · Sonnet 137 mil + 50 mil (4) · Opus `low` 170 mil + 31 mil (4) |
| **`opus — medium`**<br>`delegation:reviewer` · `delegation:hand-off`<br>Revisão adversarial de diff | teste pareado<br>uso real | O Opus 5.5 achou os defeitos sem afirmação falsa em todas as revisões. O Sonnet 5 achou os defeitos plantados, mas inventou um em cada teste; em uso real segurou 3 de 3.<br>38 leituras: Opus 5.5 `medium` 19 (19 acertos; acompanhar) · Opus 5.5 `low` 5 (4, 1; medir mais) · Opus 5.5 `xhigh` 3 (3; falta análise) · Sonnet 5 5 (3 acertos, 2 erros; medir mais) · Opus 5 6 (5, 1; medir mais)<br>Tokens (cache + novos, turnos): teste — Opus `medium` 507 mil + 49 mil (11) · Opus `low` 423 mil + 45 mil (9) · Opus `xhigh` 1,19 milhão + 93 mil (21) · Sonnet 873 mil + 52 mil (14); uso real — Opus `medium` 4,15 milhões + 127 mil (51) · Sonnet 1,76 milhão + 82 mil (36) |
| **`sonnet — medium` atrás de gate**<br>`delegation:implementer` · `delegation:hand-off`<br>Implementação bem especificada, um arquivo | uso real | O Sonnet 5 atrás de gate segurou em 61 de 68 implementações; nas que falharam, o Opus 5.5 foi a escalada.<br>79 leituras: Sonnet 5 68 (61 acertos, 7 erros; acompanhar) · Opus 5.5 10 (9, 1; medir mais) · Opus 5 `xhigh` 1 (1; falta análise)<br>Tokens (cache + novos, turnos), uso real: Sonnet 5,60 milhões + 146 mil (58) · Opus 5.5 18,73 milhões + 403 mil (95) |
| **`opus — medium` atrás de gate**<br>Reproduzir bug; mudança transversal | teste pareado<br>uso real | O Opus 5.5 `medium` reproduziu todos os bugs, como o `xhigh`, com menos tokens; o `low` deixou um item do gabarito de fora.<br>10 leituras: Opus 5.5 `medium` 3 (3 acertos; falta análise) · `xhigh` 3 (3; falta análise) · `low` 3 (2, 1; falta análise) · Opus 5 1 (1; falta análise)<br>Tokens (cache + novos, turnos): `medium` 365 mil + 38 mil (9) · `xhigh` 439 mil + 53 mil (13) · `low` 295 mil + 34 mil (7) |
| **`opus — high`**<br>Desenho, com a spec inteira no prompt | uso real | O Opus com `high` e a spec inteira desenhou sem erro; um planejador que rodou no modelo da sessão errou 4 de 9.<br>16 leituras: Opus 5 `high` 5 (5 acertos; medir mais) · Opus 5.5 2 (2; falta análise) · `Plan` no modelo da sessão 9 (5, 4; medir mais)<br>Tokens: não registrados |
| **loop principal ou `opus — high`**<br>Contestar a premissa; síntese entre repositórios | uso real | O Opus `high` contestou a premissa com `file:line` nas quatro vezes registradas, uma delas no Opus 5.5.<br>4 leituras: Opus 4 (4 acertos; medir mais)<br>Tokens: não registrados |

No total, são 391 leituras: 150 de teste (localizar 12, corrigir 6, classificar 102, ficha 6, revisão 15,
reproduzir 9) e 241 de uso real.

As recomendações que o uso real já sustenta sozinho são quatro: a implementação no Sonnet atrás de gate
(61 de 68), a revisão no Opus 5.5 `medium` (19 de 19), a tradução no Sonnet (27 de 27) e a localização no
Sonnet (17 de 17). Na classificação, o Opus 5.5 `low` e o Sonnet 5 também saem com **acompanhar**, contra
a régua do chute. Nenhuma contagem sai com **não usar**. O resto fica entre **medir mais** e **falta
análise** — e é onde está a comparação entre modelos, a parte que os testes ainda cobrem com poucas
tarefas.

Os turnos explicam boa parte do consumo. Em localizar, o Sonnet 5 releu 672 mil tokens de cache em 10
turnos, contra 391 mil do Opus 5.5 `medium` em 9; como a leitura de cache custa o mesmo nos dois, a
diferença de custo fica nos tokens novos, onde o Sonnet sai mais barato. Em ficha de subsistema acontece o
contrário: o Opus usou 11 turnos contra 4 do Sonnet e releu quase 4 vezes mais cache. Não existe uma razão
única entre modelos; ela muda com a forma do trabalho.

## Além da tabela

### Onde o trabalho roda

O modelo de cada agente pesa mais no custo que a quantidade de agentes. Os dados vêm de um censo de 25
runs de Workflow e 194 agentes, ao longo de cerca de dois meses.

| Observação | Dado |
|---|---|
| Agente Opus 5 contra agente Sonnet 5 | 7,9× o custo |
| Mesma forma de run: 12 Opus contra 13 Sonnet | 6,6× |
| Agentes além de 20 minutos | 9 de 194 agentes, 11 % do gasto |
| Agentes que só rodavam um comando fixo | zero token em 6 de 10 e em 5 de 8 |

A escada de topologia e o teste de alargamento são priors
([Anthropic, How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system);
[Claude, Building multi-agent systems: when and how to use them](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)),
ordenados por análise do autor.

### Subir capacidade no loop principal

Trocar o effort mantém o cache só nos modelos mais novos, e trocar de modelo quase sempre o perde. Daí a
skill mandar subir primeiro pelo effort, depois delegando, e trocar de modelo só com contexto curto. Essa
ordem é hipótese: os custos foram medidos nos transcripts das sessões, a ordem não
([documentação de prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)).

| Modelo | Troca | Efeito no cache |
|---|---|---|
| Opus 5.5 | effort | 99 % lido do cache (11 trocas) |
| Fable 5.1 | effort | 99 % lido do cache (8) |
| Opus 5 | effort | 7 % lido (11) |
| Sonnet 5 | effort | 0 % lido (9) |
| qualquer | para um modelo novo | cache frio em 13 de 20 trocas |
| qualquer | de volta a um modelo já usado | cache frio em 10 de 11 |

### Escalonamento

O único degrau medido é `medium` contra `xhigh`; o resto vem da escada de effort que a Anthropic publicou
para o Opus 5.5, ou é decisão da skill.

| Degrau | Origem | Dado |
|---|---|---|
| Opus 5.5 começa em `medium` | medido + prior | o Opus 5.5 `medium` igualou o Opus 5.5 `xhigh` em 6 de 6 tarefas; o `xhigh` gastou 1,2× a 2,3× os tokens |
| `medium` → `high` | prior | escada de effort da Anthropic para o Opus 5.5 |
| falhou em `xhigh` → loop principal | decisão da skill | o fornecedor recomenda trocar para o Fable 5.1 |
| nunca acima de Opus em subagente | prior | [página do Opus 5.5](https://www.anthropic.com/claude-opus-5-5): igual ou acima do Fable 5.1 nos benchmarks listados, a 40 % do preço por token |

### Primeira execução de uma skill nova

Mandar a primeira execução para um subagente cego é recomendação medida sem controle. Três execuções
cegas acharam o que o autor não viu — 3 defeitos numa, 17 lacunas noutra —, e nenhuma execução do
próprio autor foi posta ao lado para comparar. O catálogo traz o agente para isso,
`delegation:blind-run` (Sonnet `medium`): ele segue a skill ou o procedimento exatamente como escrito,
sem ter visto a sessão que o escreveu, e devolve onde o texto falhou.

## Como isto foi apurado

A contagem para no commit que criou o catálogo público com a tabela da skill, em 2026-09-28. Nada
registrado depois dele entra, porque não informou a tabela.

| Fonte | O que deu |
|---|---|
| Registro de leituras de uma ferramenta de observação do autor | os testes pareados e o uso real verificado, por modelo, effort e forma de trabalho |
| Registro de delegações dos hooks do Claude Code | o uso real mais recente, com o modelo que rodou e o julgamento de cada delegação |
| Transcripts das sessões | os tokens do uso real, ligados a cada delegação pelo id do agente |
| Resultados das execuções de teste | os tokens dos testes, por forma e braço |
| Um registro de delegações anterior, mantido à mão | o uso real mais antigo: transcrição, tradução, a busca com o Opus 5 no modelo da sessão, o planejador no modelo da sessão e contestar a premissa |

Nos testes, acerto é cobrir todo o gabarito sem nenhuma afirmação falsa; o resultado bate com as tabelas
publicadas de cada experimento. Os testes rodaram em sessões headless limpas do Claude Code, e um juiz
cego Opus 5.5 pontuou cada resultado contra um gabarito escrito antes.

O instrumento tem dois limites. O registro mantido à mão não guarda tokens, então quatro linhas ficam sem
eles. E o registro de delegações só passou a guardar tokens nos últimos dias da janela, por isso os
tokens do uso real vêm dos transcripts.

## Correções na skill

As leituras apontam oito pontos em que a skill deve mudar no próximo ajuste da tabela.

| Onde | Hoje a skill diz | As leituras mostram | Correção |
|---|---|---|---|
| Linha de ficha e agente `delegation:fact-sheet` | Opus `medium` | Sonnet segurou 11 de 14 em uso real, a um terço dos tokens | medir mais o Sonnet; considerar Sonnet como padrão, na linha e no agente |
| Linha de revisão | Opus `medium` | `low` acertou 4 de 5 com 16 % menos tokens | manter `medium`; medir mais o `low` |
| Linha de classificação | Opus `low` | Sonnet passou no limite, com tokens parecidos | medir mais o Sonnet |
| Passo 0b | ordem de subida dada como conselho | a ordem nunca foi testada | marcar como hipótese |
| Ponte de fallback | Opus começa em `high` | as linhas medidas começam em `medium` | alinhar em `medium` |
| Passo 4 | o gate dispara o escalonamento | dois escalonamentos vieram de revisão com o gate verde | incluir a revisão como gatilho |
| Linha de tradução | `medium` | effort nunca registrado | declarar o effort como não medido |
| Linha de transcrição | só `haiku` | a prosa volta parafraseada | recolocar "prosa com cautela" |

## O que foi rejeitado, e o que o reabriria

- **Marcar a origem de cada linha dentro da skill.** A skill traz a tabela como padrão para ajustar, e
  esta página carrega a proveniência. Reabre quando uma linha mudar.
- **Custo em dinheiro.** O uso foi por assinatura; tokens e razões descrevem o consumo sem sugerir um
  gasto que não houve. Reabre se alguma medição rodar em uso de API cobrado.
- **Contar as leituras depois do corte.** Elas não informaram a tabela publicada. Reabre no próximo
  ajuste da tabela, que deve usá-las.
- **Usar o veredito automático da ferramenta de observação.** Com estas amostras, ele diz só que o n é
  pequeno, o que a tabela já mostra com mais detalhe. Reabre quando a amostra crescer.

## O que ficou em aberto

- Nenhuma forma tem mais de 5 tarefas pareadas por braço, e cada tarefa rodou uma vez.
- Transcrição, tradução, desenho e contestação ficam sem tokens registrados.
- O degrau `high` do Opus 5.5 e o custo em tokens de uma troca de modelo no loop principal não foram
  medidos.
- As hipóteses do loop principal não foram experimentadas.
- Os testes pareados rodaram em sessão headless, e não em subagente, com tarefas e gabaritos escritos
  pelo Opus 5.5 e julgados pela mesma família.
- O 7,9× por agente compara Opus 5 com Sonnet 5. Com o Opus 5.5, o preço por token fica 2× o do Sonnet, e
  a razão de tokens varia por forma (0,6× em localizar, 3,0× em ficha); o censo de topologia não foi
  refeito no Opus 5.5.
- Há 98 leituras novas, posteriores ao corte, em quarentena: ainda não passaram por esta análise e
  entram no próximo ajuste da tabela.
