;; ====================================================== INTERFACE =========================================================

;; ---------------------------- Buttons
;; setup                        Calls setup function: clears all, resets ticks, setup the seed (also separated button), calls initialise-population function, sets patches to color white
;; setup-seed                   Calls setup-seed function: switch manualSeed? wether random seed or seed from input manual-seed
;; initialise-tax-burden        Calls initialise-tax-burden function (turtle button): calculates tax-burden, sets income-group, sets color of individual accordingly
;; setup-network                Calls setup-network function (turtle button): creates links and, thus, forms a network
;; layout                       Calls layout function (go-forever button): layout of individuals in relation to links
;; simulate-tax-morale          Calls simulate-tax-morale function (go-forever button): runs the underlying simulation of tax evasion and tax compliance

;; ---------------------------- On-Off-Switches
;; randomSeed?                  Switch whether to use a random seed = on or the seed from manual-seed input = off
;; social-influencer-network?   Switch whether to form network according to Di Gioacchino and Fichera 2022 = on or Schulz, Mayerhofer, and Gebhard (2022) = off
;; z-score?                     Switch whether to use z-scoring = on or min-max-normalization = off to make income manageabel for Netlogo

;; ---------------------------- Inputs
;; manual-seed                  Input for the manual input of a seed

;; ---------------------------- Sliders
;; num-individuals              [0;100,000] Sets the number of turtles in both simulation
;; networksize                  [0;50] Sets the number of connections one turtle makes in both simulations
;; homophilystrength            [0;1] Sets the strength of the income homophily in the
;; updatingshare                [0;1] Sets share of turtles updating their tax morale in the simulation each period
;; socialweight                 [0;1] Sets the importance of tax morale in the social network of an individual
;; reputationweight             [0;1] Sets the importance of reputation for the individual
;; detectionpunishment          [0;1] Sets the share of income lost in the event of detected tax evasion of the individual by the tax authority

;; ---------------------------- Outputs (defined within R Studio nlrx-package behaviour space)
;; tax-evasion-share            Share of agents with tax_decision == 1
;;
;; te-incomegroup-1             Share of agents with tax_decision == 1 and income group == 1
;; te-incomegroup-2             Share of agents with tax_decision == 1 and income group == 2
;; te-incomegroup-3             Share of agents with tax_decision == 1 and income group == 3
;; te-incomegroup-4             Share of agents with tax_decision == 1 and income group == 4
;; te-incomegroup-5             Share of agents with tax_decision == 1 and income group == 5

;; ====================================================== DECLARATIONS ======================================================
extensions[
 csv                         ;; csv-extension to read in R generated income data
 Rnd                         ;; rnd-extension for the weighted drawing from other individuals
 Nw                          ;; nw-extension for network counting functions
]

;; ---------------------------- Breed Individuals for the homophilic network; entails all turtles
breed[
  individuals individual
]

;; ---------------------------- Undirected link for homophilic network formation
undirected-link-breed[
  permalinks permalink
]


globals[
  ;; -------------------------- Seed
  used-random-seed           ;; Seed generated using the
  sim-income-data            ;; R generated income data from realistic income distribution; R code in seperate document
  ;networks                   ;; List of lists with individuals of shared network
  individuals-connected      ;; Number of individuals embeded in network of wanted size

  links-formed               ;; Global count of links formed in the social-influencer network model
]

turtles-own[
  ;; -------------------------- Income
  income                     ;; Income read from csv-file: generation of German Income Distribution from income brackets and the assumption of a uniform distribution within the brackets
  normalized-income          ;; Normalized income of the individual; defined within the normalize-income function which uses the min-max-feature scaling
  income-group               ;; Income group defined within the initialise-tax-burden function analogous to german tax brackets

  ;; -------------------------- Tax
  taxable-income             ;; Share of income without basic allowance defined within the initialise-tax-burden function
  tax-burden                 ;; (simplified) tax burden of the individual; calculated within the initialise-tax-burden function analogous to german tax law from 2020
  tax-rate                   ;; Tax-burden / income => rate of taxes; defined within the initialise-tax-burden function

  ;; -------------------------- Network
  link-count                 ;; Count of permalinks the Individual has with other individuals
  avg-income-neighbourhood   ;; Average income of an individual's link nieghbours
  avg-income-group           ;; Average income group of an individual's link nieghbours

  ;; -------------------------- Model Parameter
  tax-morale                 ;; Float [0,1]; showing the individuals motivation to pay taxes
  tax-morale-previous        ;; Float [0,1] (randomly assigned in initialise-population); tax morale from the previous period t-1
  tax-decision               ;; Binary value; decision whether to pay (tax-decision = 0) or evade taxes (tax-decision = 1)
  tax-reputation             ;; Difference between the mean of the tax morale of tax paying neighbors and the mean of the tax morale of tax evading neighbors

  ;; -------------------------- Decision Parameter
  payoff-taxes               ;; Payoff from paying taxes; Income - tax-burden + reputation from paying taxes
  payoff-evasion             ;; Payoff from evading taxes; Income - Punishment - reputation from paying taxes
  social-tax-morale          ;; Expected value of tax morale within the social network of the individual
  decision-threshold         ;; Threshold of tax decision defined by Di Gioacchino and Fichera (2020); decision-threshold = payoff-taxes - payoff-evasion
]




;; ====================================================== MAIN CALLING PROCEDURES =============================================
;; ------------------------------------------------------ SETUP ---------------------------------------------------------------
to setup
  clear-all
  reset-ticks
  ; file-close
  ask patches[
    set pcolor white]

  setup-seed
  initialise-population
  ask turtles[
    initialise-tax-burden
  ]
  ask one-of turtles[
    setup-network
  ]
end

;; ------------------------------------------------------ GO ------------------------------------------------------------------
to go
  tick
  simulate-tax-morale
end





;; ====================================================== SETUP PROCEDURES ====================================================
;; ------------------------------------------------------ SEED PROCEDURES -----------------------------------------------------
to setup-seed
  ;; used-random-seed as on-off-switch in Netlogo Interface; manual-seed as input option in Netlogo Interface
  set used-random-seed ifelse-value (randomSeed?) [new-seed] [manual-seed]
  random-seed used-random-seed
  output-print used-random-seed
end

;; ----------------------------------------------------- POPULATION PROCEDURES ------------------------------------------------
to initialise-population
  ;; Population initialisation
  create-individuals num-individuals[
      initialise-income]

  ;; Intitialisation of tax-morale and tax-decision
  ask turtles[
    setxy random-xcor random-ycor
    set tax-morale 0
    set tax-morale-previous random-float 1
    set tax-decision one-of [0 1]
    set social-tax-morale 0
  ]
end

;; ----------------------------------------------------- INCOME PROCEDURES ----------------------------------------------------
to initialise-income
  ;; Income distribution generated in R based on real distribution data; Reading of distribution .csv:
  set sim-income-data csv:from-file "sim_income_data_germany.csv"
  set sim-income-data reduce sentence sim-income-data

  ;; Income of turtles set as one income from distribution .csv
  set income one-of sim-income-data

  ;; Income is normalized whether by z-scoring or normalization; Decision as switch on Netlogo interface:
  ;; on  = z-scoring
  ;; off = normalization
  ifelse z-score?[
    z-score-income][
    normalize-income
  ]
end

;; z-scoring
to z-score-income
  let income-data [income] of turtles
  let mean-income mean income-data
  let sd-income standard-deviation [income] of turtles
  set normalized-income ((income - mean-income ) / (sd-income))
end

;; normalization
to normalize-income
  let poorest-individual min-one-of turtles [income]
  let richest-individual max-one-of turtles [income]
  set normalized-income ((income - [income] of poorest-individual) / ([income] of richest-individual - [income] of poorest-individual))
end

;; ----------------------------------------------------- TAX PROCEDURES ----------------------------------------------------
to initialise-tax-burden
  ;; Income taxation (see https://esth.bundesfinanzministerium.de/esth/2020/A-Einkommensteuergesetz/IV-Tarif/Paragraf-32a/inhalt.html)
  ;; Upper tax zone boundaries:
  let basic_allowance 9408
  let tax_zone_1 14532
  let tax_zone_2 57051
  let tax_zone_3 270500

  ;; Calculation of the taxable income (income - basic-allowance)
  (ifelse
    income > basic_allowance [
      set taxable-income (income - basic_allowance)][
      set taxable-income 0])

  ;; Helper values for the calculation of the tax burden
  let tax_calc_y ((income - basic_allowance) / 10000)
  let tax_calc_z ((income - tax_zone_1) / 10000)

  ;; Calculation of the tax-burden
  (ifelse
    income < (basic_allowance + 1) [
      set tax-burden 0
      set income-group 1
      set color 15]
    income < (tax_zone_1 + 1) [
      set tax-burden (((972.87 * tax_calc_y) + 1400) * tax_calc_y)
      set income-group 2
      set color 25]
    income < (tax_zone_2 + 1) [
      set tax-burden (((212.02 * tax_calc_z) + 2397) * tax_calc_z + 972.79)
      set income-group 3
      set color 45
    ]
    income < (tax_zone_3 + 1) [
      set tax-burden ((0.42 * taxable-income) - 8963.74)
      set income-group 4
      set color 55
    ]
    [
      set tax-burden ((0.42 * taxable-income) - 17078.74)
      set income-group 5
      set color 85
    ]
  )
  (ifelse income > 0 [
    set tax-rate (tax-burden / income)
    ]
    [
    set tax-burden 0
    ])

end


;; ----------------------------------------------------- NETWORK PROCEDURES ------------------------------------------------------
to setup-network
  ;; Deleting of links to allow for new network formation
  ask links[
    die]
  set link-count count link-neighbors

  ;; call homophilic-network formation (homophilic network formation mechanism by Schulz, Mayerhofer, and Gebhard (2022)) defined in the function below
  setup-homophilic-network
end

to setup-homophilic-network
  ;; Individuals with a network smaller than the defined size of the network are asked to perform the containing code
  ask individuals [
    if ((count out-link-neighbors + 1) < networksize)[
      ;; set function specific variable myincome to the normalized income
      let myincome normalized-income

      ;; set the number of individuals the by the function called individual needs to reach networksize
      let search (networksize - link-count - 1)
      if (search < 1) [stop]

      ;; creates agentset pool with all turtles with less links than exogenous defined networksize
      ;let pool turtles with [out-link-count + 1 < networksize]
      ;if (search > count (other pool) ) [set search count (other pool)]

      ;; creates agentset with weighted draw from agent set pool;
      ;; weight represents income homophily, i.e., the smaller the income difference the more probable the drawing into attachto agentset
      ;; (dependent on exogenously set homophilystrength)
      ;let attachto rnd:weighted-n-of search (other turtles with [(networksize - out-link-count) < (search)]) [1 / (e ^ (homophilystrength * abs (normalized-income - myincome) ) ) ]
      ;let attachto rnd:weighted-n-of search (other pool) [1 / (e ^ (homophilystrength * abs (normalized-income - myincome) ) ) ]
      let attachto rnd:weighted-n-of search (other turtles) [1 / (e ^ (homophilystrength * abs (normalized-income - myincome) ) ) ]

      ;; agentset attachto is asked to create bidirected links with the individual called by the function
      ask attachto[
        create-permalink-with myself
      ]

      ;; all individuals are asked to update their out-link-count
      ask individuals[
        set link-count count out-link-neighbors
      ]
    ]
  ]

  ask individuals[
    let incomes-neighbourhood [income] of out-link-neighbors
    let income-groups-neighbourhood [income-group] of out-link-neighbors
    set avg-income-neighbourhood mean incomes-neighbourhood
    set avg-income-group mean income-groups-neighbourhood
  ]

end


;; ----------------------------------------------------- VISUALISATION OF NETWORKS ------------------------------------------------------
to layout
  ;; layout-spring function arranges network; suitable input values dependent on network size and num-indidivuals
  layout-spring turtles links 0.5 1 25
end


;; ====================================================== SIMULATION CODE ======================================================
to simulate-tax-morale
  ;; initialisation of function specific variable social-tax-morale
  ;let social-tax-morale 0

  ;; an exogenously set portion of turtles updates their tax-morale and tax-decision
  ask n-of (updatingshare * num-individuals) turtles[

    ;; Calculaton of tax morale in the neighborhood
    let neighbors-tax-morale [tax-morale-previous] of out-link-neighbors
    let neighbors-evading-morale [tax-morale-previous] of out-link-neighbors with [tax-decision = 1]
    set social-tax-morale mean neighbors-tax-morale

    ;; Calculation of tax morale of the individual called by the function
    set tax-morale ((1 - socialweight) * tax-morale-previous + socialweight * social-tax-morale)

    ;; Helper visualisation
    ;print([tax-morale] of out-link-neighbors with [tax-decision = 0])
    ;print([tax-morale] of out-link-neighbors with [tax-decision = 1])

    ;; Tax evasion decision
    let tax-paying-neighbors 0
    let tax-evading-neighbors 0

    ;; Mean tax-morale of tax paying neighbors
    if (count out-link-neighbors with [tax-decision = 0] != 0)[
      set tax-paying-neighbors mean [tax-morale-previous] of out-link-neighbors with [tax-decision = 0]]

    ;; Mean tax-morale of tax evading neighbors
    if (count out-link-neighbors with [tax-decision = 1] != 0)[
      set tax-evading-neighbors mean [tax-morale-previous] of out-link-neighbors with [tax-decision = 1]]

    ;; Calculation of tax-reputation & payoffs from evasion/compliance analogous to Di Gioacchino and Fichera 2020
    set tax-reputation (tax-paying-neighbors - tax-evading-neighbors)
    set payoff-taxes (income - tax-burden + reputationweight * tax-paying-neighbors)
    set payoff-evasion (income - detectionpunishment * income - tax-reputation + reputationweight * tax-evading-neighbors)

    ;; Calculation of decision-threshold
    set decision-threshold (tax-burden - detectionpunishment * income - reputationweight * tax-reputation)

    ;; Decision whether to evade = 1 or pay taxes = 0
    ifelse (tax-morale > decision-threshold)[
      set tax-decision 0][
      set tax-decision 1]
  ]

  ask individuals [
    ;; Storage of tax morale for following periods
    set tax-morale-previous tax-morale
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
212
10
1230
529
-1
-1
10.0
1
10
1
1
1
0
1
1
1
-50
50
-25
25
0
0
1
ticks
30.0

BUTTON
12
24
87
57
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
96
24
167
57
NIL
setup-seed
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
12
97
167
157
manual-seed
-125478.0
1
0
Number

SWITCH
12
61
167
94
randomSeed?
randomSeed?
0
1
-1000

SLIDER
11
162
183
195
num-individuals
num-individuals
0
10000
190.0
10
1
NIL
HORIZONTAL

BUTTON
1236
10
1379
43
NIL
initialise-tax-burden
NIL
1
T
TURTLE
NIL
NIL
NIL
NIL
1

SLIDER
11
218
183
251
networksize
networksize
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
11
259
183
292
homophilystrength
homophilystrength
0
1
0.74
0.01
1
NIL
HORIZONTAL

BUTTON
1354
60
1417
93
NIL
layout
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1243
182
1381
215
NIL
simulate-tax-morale
T
1
T
TURTLE
NIL
NIL
NIL
NIL
1

SLIDER
13
407
185
440
socialweight
socialweight
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
13
449
185
482
reputationweight
reputationweight
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
13
490
185
523
detectionpunishment
detectionpunishment
0
1
0.25
0.01
1
NIL
HORIZONTAL

PLOT
1245
224
1603
534
Tax Evasion/Compliance Share
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -13840069 true "" "if (count turtles > 0) [plot (count turtles with [tax-decision = 0]) / (count turtles)]"
"pen-1" 1.0 0 -2674135 true "" "if (count turtles > 0) [plot (count turtles with [tax-decision = 1]) / (count turtles)]"

MONITOR
1245
545
1367
590
Tax Compliance Share
(count turtles with [tax-decision = 0]) / count turtles
17
1
11

MONITOR
1469
544
1603
589
Tax Evasion Share
(count turtles with [tax-decision = 1]) / count turtles
17
1
11

SWITCH
350
586
454
619
z-score?
z-score?
1
1
-1000

SLIDER
12
365
184
398
updatingshare
updatingshare
0
1
0.25
0.01
1
NIL
HORIZONTAL

BUTTON
1236
60
1348
93
NIL
setup-network
NIL
1
T
TURTLE
NIL
NIL
NIL
NIL
1

MONITOR
215
533
341
578
Connected
count turtles with [link-count + 1 = networksize]
17
1
11

MONITOR
350
534
407
579
NIL
ticks
17
1
11

MONITOR
214
583
304
628
Disconnected 
count turtles with [link-count + 1 < networksize]
17
1
11

MONITOR
416
534
501
579
NIL
count turtles
17
1
11

PLOT
536
540
736
690
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [income] of turtles"

BUTTON
1238
103
1301
136
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1000" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>(count turtles with [tax-decision = 0]/(count turtles))</metric>
    <metric>(count turtles with [tax-decision = 1]/(count turtles))</metric>
    <enumeratedValueSet variable="networksize">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomSeed?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="detectionpunishment">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="updatingshare">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="z-score?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-individuals">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reputationweight">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="socialweight">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="homophilystrength">
      <value value="0.73"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="manual-seed">
      <value value="-125478"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
